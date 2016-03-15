
require_relative "node"

module NegamaxAnalysis

  def initialize
    @killer_moves = Array.new(2) { Hash.new }
    @enable_transposition_tables = true
    @enable_limited_table_replacement = false
    @enable_killer_moves = true
    @enable_alpha_beta = true
    @enable_move_sorting = true
    @fail_soft_enabled = true
    @enable_heuristics = false # bugged due to win-check optimization
    @size_of_table = 100000

    @iterative_depth_limit = 20
    @transposition_table = Array.new(@size_of_table)
    @lowest_score = Node.new(-1, -1073741824, 0, -1)
    @highest_score = Node.new(-1, 1073741824, 0, -1)
    @value_of_tie = Node.new(-1, 0, 0, -1)
    @value_of_win = Node.new(-1, -1073741824, 0, -1)
    @value_of_unknown = Node.new(-1, nil, 0, -1)
    # don't start another search if last was more than 1/Xth the max time
    @iterative_deepening_stop_ratio = 2.5
    super()
  end

  def lookup_hash(hash, depth, alpha, beta)
    modulod_hash = hash % @size_of_table
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
    modulod_hash = hash % @size_of_table
    if @transposition_table[modulod_hash] != nil && @enable_limited_table_replacement
      if @transposition_table[modulod_hash]["depth"] < depth
        @transposition_table[modulod_hash] = { "hash" => hash, "depth" => depth, "value" => value, "alpha" => alpha.value, "beta" => beta.value, "flag" => flag}
      end
    else
      @transposition_table[modulod_hash] = { "hash" => hash, "depth" => depth, "value" => value, "alpha" => alpha.value, "beta" => beta.value, "flag" => flag}
    end
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
    alpha = nil
    start_time = Time.now
    last_loop_start = Time.now
    @recursion_counter = 0
    # repeatedly call negamax with increasing depth,
    # will return the best move found on the last level of depth called
    while ( (Time.now - last_loop_start) <= (time_limit/@iterative_deepening_stop_ratio) )
      last_loop_start = Time.now
      @recursion_counter = 0
      alpha = @lowest_score
      subtree_best = negamax(board, active_piece, current_depth, alpha, beta)
      time_limit -= (Time.now - last_loop_start)
      puts "ID:#{current_depth}, Rec:#{@recursion_counter}, Time:#{(Time.now-last_loop_start).round(2)}, TL:#{(time_limit).round(2)}, RPS: #{(@recursion_counter/(Time.now-last_loop_start)).round(2)} Move: #{subtree_best}" if print_result
      if subtree_best.value > alpha.value
        alpha = insert_move_into_results(subtree_best, subtree_best.move)
      end
      current_depth += 1
      if current_depth > @iterative_depth_limit
        break
      end
    end
    #puts "Iterative deepening loop exiting at depth: #{current_depth-1} with move #{alpha} in #{(Time.now - start_time)} seconds."
    return cut_node_value_by_half(alpha)
  end

  def insert_move_into_results(subnode, move_into_subnode)
    # this is used to mark a move with the value of the move, was repeated all over
    return Node.new(move_into_subnode, subnode.value, subnode.depth+1, subnode)
  end

  def cut_node_value_by_half(subnode)
    # this is used to mark a move with the value of the move, was repeated all over
    return Node.new(subnode.move, subnode.value/2.0, subnode.depth, subnode.subnode)
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
        if alpha.value >= beta.value
          return hash_lookup_result["value"]
        end
      end
    end
    # win/tie check, return a value if found
    result = check_board_for_final_square_value(board, active_piece, depth)
    return result unless result == nil
    alpha = @lowest_score if !@enable_alpha_beta
    list_of_moves = board.get_available_moves
    # move sorting
    sort_moves(list_of_moves, depth, previous_best_move) if @enable_move_sorting
    # iterate over possible moves and get their values (down to depth limit)
    list_of_moves.each do |move|
      # we are making/undoing moves rather than duping the board, better performance
      trial_move_board = board
      trial_move_board.make_move(move, active_piece)
      subtree_best = -negamax(trial_move_board, trial_move_board.change_players(active_piece), depth-1, -beta, -alpha)
      puts "M#{move}:#{subtree_best}" if print_result
      trial_move_board.undo_move
      #subtree_best = insert_move_into_results(subtree_best, move)
      if subtree_best.value > alpha.value
        # new local alpha (best move) was found
        #alpha = subtree_best
        puts "New Local Best (Alpha) Found, Val:#{alpha.value}, subtreeVal:#{subtree_best.value}" if print_result
        alpha = insert_move_into_results(subtree_best, move)
      end
      # alpha beta (and killer moves)
      if subtree_best.value >= beta.value && @enable_alpha_beta
        #puts "Beta break, beta val #{beta.value}, subtreeVal:#{subtree_best.value}" if depth > 4
        if @enable_killer_moves
          # storing two killer moves, but only if they are different than the move currently considered
          if subtree_best.move != @killer_moves[1][depth] && subtree_best.move != @killer_moves[0][depth]
            @killer_moves[0][depth] = @killer_moves[1][depth]
            @killer_moves[1][depth] = subtree_best
          end
        end
        # Beta cutoff, break out of this level with our alpha
        # returning best value would be "fail soft"
        break if @fail_soft_enabled
        # returning beta is "fail hard"
        alpha = beta if !@fail_soft_enabled
        break if !@fail_soft_enabled
      end
    end
    if @enable_transposition_tables
      # make a flag for the hash table indicating if it's an exact value
      flag = ""
      if alpha.value <= @lowest_score.value
        flag = "Upper"
      elsif alpha.value >= beta.value
        flag = "Lower"
      else
        flag = "Exact"
      end
      store_hash(hash, depth, alpha, alpha, beta, flag)
    end
    return cut_node_value_by_half(alpha)
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
    list_of_moves = promote_move_to_front(list_of_moves, 2)
    list_of_moves = promote_move_to_front(list_of_moves, 6)
    list_of_moves = promote_move_to_front(list_of_moves, 3)
    list_of_moves = promote_move_to_front(list_of_moves, 5)
    list_of_moves = promote_move_to_front(list_of_moves, 4)
    if @enable_killer_moves
      if @killer_moves[0][depth] != nil
        promote_move_to_front(list_of_moves, @killer_moves[0][depth].move)
      end
      if @killer_moves[1][depth] != nil
        promote_move_to_front(list_of_moves, @killer_moves[1][depth].move)
      end
    end
    if @enable_transposition_tables && hash_lookup_result
      promote_move_to_front(list_of_moves, hash_lookup_result.move)
    end
    return list_of_moves
  end

  def promote_move_to_front(list_of_moves, possible_move)
    if list_of_moves.delete(possible_move)
      list_of_moves.unshift(possible_move)
    end
    return list_of_moves
  end

end
