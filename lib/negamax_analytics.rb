
require_relative "node"

module NegamaxAnalysis

  # CURRENTLY DEPENDS ON PARENT FUNCTION swap_pieces(current_player)

  # try_board_dup is for optimization testing
  # toggles a change between duping a board then discarding it when done
  # vs making a move, then unmaking a move, on the original board

  # depends on a BUNCH of parent variables....

  def initialize
    @killer_moves = Hash.new
    @enable_killer_moves = true
    # if our previous depth search was within X (2.0 here) times of the time limit, don't start another
    @iterative_deepening_time_divider = 2.0
  end

  def lookup_hash(hash, depth, alpha, beta)
    if @transposition_table[hash]
      result = @transposition_table[hash]["value"]
      return result
    end
  end

  def store_hash(hash, depth, value, alpha, beta)
    @transposition_table[hash] = {"value" => value, "depth" => depth, "alpha" => alpha, "beta" => beta,}
  end

  def heuristic_value(board, piece) #p is piece
    return @value_of_tie if !@use_heuristics
    strings = board.get_cached_neighbors
    piece = swap_pieces(piece)
    super_combo = 0
    high_value_combo = 0
    med_value_combo = 0
    score = 0
    strings.each do |str|
      super_combo += str.scan("0#{piece}#{piece}#{piece}0").size
      high_value_combo += str.scan("0#{piece}#{piece}#{piece}").size
      high_value_combo += str.scan("#{piece}0#{piece}#{piece}").size
      high_value_combo += str.scan("#{piece}#{piece}0#{piece}").size
      high_value_combo += str.scan("#{piece}#{piece}#{piece}0").size
      med_value_combo += str.scan("#{piece}00#{piece}").size
      med_value_combo += str.scan("#{piece}0#{piece}0").size
      med_value_combo += str.scan("0#{piece}0#{piece}").size
      score += super_combo * 2048
      score += high_value_combo * 1024
      score += med_value_combo * 128
    end
    return Node.new(-1, -score, 0, -1)
  end

  def iterative_deepening_negamax_search(board, active_piece, max_depth, time_limit, alpha, beta, print_result = false)
    current_depth = 0
    depth_best_move = nil
    start_time = Time.now
    # repeatedly call negamax with increasing depth,
    # will return the best move found on the last level of depth called
    while ( (Time.now - start_time) <= (time_limit/@iterative_deepening_time_divider) )
      depth_best_move = @lowest_score
      subnode_best = negamax(board, active_piece, current_depth, alpha, beta)
      @our_io_stream.puts "ID#{current_depth}: #{subnode_best}" if print_result
      if subnode_best.value > depth_best_move.value
        depth_best_move = process_subnode_and_move_into_node(subnode_best, subnode_best.move)
      end
      current_depth += 1
      if current_depth > max_depth
        return depth_best_move
      end
    end
    #@our_io_stream.puts "Iterative deepening loop exiting at depth: #{current_depth-1} with move #{depth_best_move} in #{(Time.now - start_time)} seconds."
    return depth_best_move
  end

  def process_subnode_and_move_into_node(subnode, move_into_subnode)
    # this is used to mark a move with the value of the move, was repeated all over
    return Node.new(move_into_subnode, subnode.value/2.0, subnode.depth+1, subnode)
  end

  def negamax(board, active_piece, depth, alpha, beta, print_result = false)
    @recursion_counter += 1
    start_time = Time.now
    # win/tie check, return a value if found
    result = check_board_for_final_square_value(board, active_piece, depth)
    return result unless result == nil
    depth_best_move = @lowest_score
    list_of_moves = board.get_available_moves
    # move sorting
    sort_moves(list_of_moves, depth) if true
    # iterate over possible moves and get their values (down to depth limit)
    list_of_moves.each do |move|
      trial_move_board = nil
      trial_move_board = board.dup if @try_board_dup
      trial_move_board = board if !@try_board_dup
      trial_move_board.make_move(move, active_piece)
      subnode_best = -negamax(trial_move_board, swap_pieces(active_piece), depth-1, -beta, -alpha)
      @our_io_stream.puts "M#{move}: #{subnode_best}" if print_result
      trial_move_board.undo_move if !@try_board_dup
      # CRAZY !@#$%^&* BUG IF I USED SPACESHIP OPERATOR TO COMPARE NODES DIRECTLY....
      # kept insisting that the "other" was a nil object. switching to comparing values directly
      # seriously spent hours on this !@#$%^&* bug
      # looks like if you include any nil items in the data structure, the <=> goes bonkers
      if subnode_best.value > depth_best_move.value
        depth_best_move = process_subnode_and_move_into_node(subnode_best, move)
      end
      # alpha beta
      if depth_best_move.value >= beta.value
        @killer_moves[depth] = depth_best_move if @enable_killer_moves
        break
      end
      if depth_best_move.value > alpha.value
        alpha = depth_best_move
      end
    end
    return depth_best_move
  end

  def check_board_for_final_square_value(board, active_piece, depth)
    if board.is_there_a_win?
      # if there's a win, return a value of -1,
      # which gets flipped by the negamax recursion so that the
      # player calling it sees a positive 1 for a winning board
      return @value_of_win
    elsif board.is_there_a_tie?
      return @value_of_tie
    end
    if depth <= 0
      return heuristic_value(board,active_piece)
      #return @value_of_tie
    end
    return nil
  end

  def sort_moves(list_of_moves, depth)
    if list_of_moves.delete(2)
      list_of_moves.unshift(2)
    end
    if list_of_moves.delete(6)
      list_of_moves.unshift(6)
    end
    if list_of_moves.delete(3)
      list_of_moves.unshift(3)
    end
    if list_of_moves.delete(5)
      list_of_moves.unshift(5)
    end
    if list_of_moves.delete(4)
      list_of_moves.unshift(4)
    end
    if @killer_moves[depth] != nil && @enable_killer_moves
      possible_move = @killer_moves[depth]
      #@our_io_stream.puts "PossMove:#{possible_move}, killer moves:#{@killer_moves}"
      if list_of_moves.include?(possible_move.move)
        list_of_moves.delete(possible_move.move)
        list_of_moves.unshift(possible_move.move)
      end
    end
    return list_of_moves
  end

end
