
require_relative "node"

module NegamaxAnalysis
  
  def initialize
    @killer_moves = Array.new(2) { Hash.new }
    @enable_transposition_tables = false
    @enable_killer_moves = true
    @enable_alpha_beta = true
    @enable_move_sorting = true
    @enable_heuristics = false # bugged due to win-check optimization
    @size_of_table = 1000

    @deepening_depth_limit = 20
    @transposition_table = Array.new(@size_of_table)
    @lowest_score = Node.new(-1, -8192, 0, -1)
    @highest_score = Node.new(-1, 8192, 0, -1)
    @value_of_tie = Node.new(-1, 0, 0, -1)
    @value_of_win = Node.new(-1, -8192, 0, -1)
    @value_of_unknown = Node.new(-1, nil, 0, -1)
    # don't start another search if last was more than 1/Xth the max time
    @iterative_deepening_stop_ratio = 2.0
    super()
  end

  def lookup_hash(hash, depth, alpha, beta)
    modulod_hash = hash % @size_of_table
    #puts "Table:#{@transposition_table[modulod_hash]} Class:#{@transposition_table[modulod_hash].class} Nil?#{@transposition_table[modulod_hash] == nil}"
    if @transposition_table[modulod_hash] != nil
      table_hash = @transposition_table[modulod_hash]["hash"]
      if table_hash != hash
        #puts "Hash collision! Ourhash: #{hash} %(#{hash % @size_of_table}) TableHash:#{table_hash} %(#{table_hash % @size_of_table})"
        return nil
      end
      return @transposition_table[modulod_hash]
    end
    return nil
  end

  def store_hash(hash, depth, value, alpha, beta, flag)
    @transposition_table[hash % @size_of_table] = { "hash" => hash, "depth" => depth, "value" => value, "alpha" => alpha.value, "beta" => beta.value, "flag" => flag}
    #puts "Hash stored: #{hash}, entry: #{@transposition_table[hash]}, entire table:#{@transposition_table}"
  end

  def heuristic_value(board, piece)
    return @value_of_tie if !@enable_heuristics
    strings = board.get_cached_neighbors
    piece = board.change_players(piece)
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

  def iterative_deepening_negamax_search(board, active_piece, time_limit, alpha, beta, print_result = false)
    current_depth = 0
    depth_best_move = nil
    start_time = Time.now
    # repeatedly call negamax with increasing depth,
    # will return the best move found on the last level of depth called
    while ( (Time.now - start_time) <= (time_limit/@iterative_deepening_stop_ratio) )
      depth_best_move = @lowest_score
      subnode_best = negamax(board, active_piece, current_depth, alpha, beta)
      puts "ID#{current_depth}: #{subnode_best}" if print_result
      if subnode_best.value > depth_best_move.value
        depth_best_move = process_subnode_and_move_into_node(subnode_best, subnode_best.move)
      end
      current_depth += 1
      if current_depth > @deepening_depth_limit
        return depth_best_move
      end
    end
    #puts "Iterative deepening loop exiting at depth: #{current_depth-1} with move #{depth_best_move} in #{(Time.now - start_time)} seconds."
    return depth_best_move
  end

  def process_subnode_and_move_into_node(subnode, move_into_subnode)
    # this is used to mark a move with the value of the move, was repeated all over
    return Node.new(move_into_subnode, subnode.value/2.0, subnode.depth+1, subnode)
  end

  def negamax(board, active_piece, depth, alpha, beta, print_result = false)
    @recursion_counter += 1
    start_time = Time.now
    hash = board.hash
    previous_best_move = nil
    if @enable_transposition_tables
      hash_lookup_result = lookup_hash(hash, depth, alpha, beta)
      if (hash_lookup_result != nil) &&  hash_lookup_result["depth"] >= depth
        #puts "Got a valid position from table using zobrist hash"
        flag = hash_lookup_result["flag"]
        previous_best_move = hash_lookup_result["value"]
        case flag
        when "Exact"
          return hash_lookup_result["value"]
        when "Lower"
          if alpha.value < hash_lookup_result["alpha"]
            alpha = hash_lookup_result["value"]
          end
        when "Upper"
          if beta.value > hash_lookup_result["beta"]
            beta = hash_lookup_result["value"]
          end
        end
        if alpha.value > beta.value
          return hash_lookup_result["value"]
        end
      end
    end
    # win/tie check, return a value if found
    result = check_board_for_final_square_value(board, active_piece, depth)
    return result unless result == nil
    depth_best_move = @lowest_score
    list_of_moves = board.get_available_moves
    # move sorting
    sort_moves(list_of_moves, depth, previous_best_move) if @enable_move_sorting
    # iterate over possible moves and get their values (down to depth limit)
    list_of_moves.each do |move|
      trial_move_board = nil
      trial_move_board = board.dup if @try_board_dup
      trial_move_board = board if !@try_board_dup
      trial_move_board.make_move(move, active_piece)
      subnode_best = -negamax(trial_move_board, trial_move_board.change_players(active_piece), depth-1, -beta, -alpha)
      puts "M#{move}:#{subnode_best}" if print_result
      trial_move_board.undo_move if !@try_board_dup
      # looks like nil items make custom <=>'s go bonkers, switched to value comparison
      if subnode_best.value > depth_best_move.value
        depth_best_move = process_subnode_and_move_into_node(subnode_best, move)
      end
      # alpha beta (and killer moves)
      if depth_best_move.value >= beta.value && @enable_alpha_beta
        if @enable_killer_moves
          # storing two killer moves, but only if they are different than the move currently considered
          if depth_best_move.move != @killer_moves[1][depth] && depth_best_move.move != @killer_moves[0][depth]
            @killer_moves[0][depth] = @killer_moves[1][depth]
            @killer_moves[1][depth] = depth_best_move
          end
        end
        # Beta cutoff, break out of this level
        break
      end
      if depth_best_move.value > alpha.value && @enable_alpha_beta
        # new local alpha was found
        alpha = depth_best_move
      end
    end
    if @enable_transposition_tables
      # make a flag for the hash table indicating if it's an exact value
      flag = ""
      if depth_best_move.value <= alpha.value
        flag = "Upper"
      elsif depth_best_move.value >= beta.value
        flag = "Lower"
      else
        flag = "Exact"
      end
      store_hash(hash, depth, depth_best_move, alpha, beta, flag)
    end
    return depth_best_move
  end

  def check_board_for_final_square_value(board, active_piece, depth)
    # if there's a win, return a value of -1,
    # which gets flipped by the negamax recursion so that the
    # player calling it sees a positive 1 for a winning board
    return @value_of_win if board.is_there_a_win?
    return @value_of_tie if board.is_there_a_tie?
    return heuristic_value(board,active_piece) if depth <= 0
    return nil
  end

  def sort_moves(list_of_moves, depth, hash_lookup_result)
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
    if @enable_transposition_tables && hash_lookup_result
      possible_move = hash_lookup_result
      if list_of_moves.include?(possible_move.move)
        list_of_moves.delete(possible_move.move)
        list_of_moves.unshift(possible_move.move)
        #puts "Found previous best move, shifting it"
      end
    end
    if @enable_killer_moves && @killer_moves[0][depth] != nil
      possible_move = @killer_moves[0][depth]
      if list_of_moves.include?(possible_move.move)
        list_of_moves.delete(possible_move.move)
        list_of_moves.unshift(possible_move.move)
      end
    end
    if @enable_killer_moves && @killer_moves[1][depth] != nil
      possible_move = @killer_moves[1][depth]
      if list_of_moves.include?(possible_move.move)
        list_of_moves.delete(possible_move.move)
        list_of_moves.unshift(possible_move.move)
      end
    end

    return list_of_moves
  end

end
