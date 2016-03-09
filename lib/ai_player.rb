class Player

  attr_reader :player, :piece

  def initialize(player_type, symbol, algorithm_time_limit, deepening, monte_carlo_on, aigames_interface_on)
    @player_type = player_type
    @piece = symbol
    @use_only_deep_negamax = deepening
    @use_monte_carlo = monte_carlo_on
    @aigames_interface_on = aigames_interface_on
    if @aigames_interface_on
      @our_io_stream = $stderr
    else
      @our_io_stream = $stdout
    end
    @deepening_depth_limit = 20
    @algorithm_time_limit = algorithm_time_limit.to_f
    @lowest_score = Node.new(-1, -10000, 0, -1)
    @highest_score = Node.new(-1, 10000, 0, -1)
    @value_of_tie = Node.new(-1, 0, 0, -1)
    @value_of_win = Node.new(-1, -8192, 0, -1)
    @first_move = Node.new(-1, 0, 0, -1)
    @ratio_of_negamax_to_montecarlo = 0.4
    @iterative_deepening_time_divider = 8.0
  end

  def set_piece(symbol)
    @piece = symbol
  end

  def make_a_move(board)
    @alpha_cutoffs = 0
    @alpha_upgrades = 0
    @recursion_counter = 0
    @final_boards_encountered = 0
    @depth_limited_searches = 0
    start_time = Time.now
    if @use_only_deep_negamax
      ai_move = iterative_deepening_negamax_search(board, @piece, @deepening_depth_limit, @algorithm_time_limit, @lowest_score, @highest_score)
    elsif @use_monte_carlo
      ai_move = ai_main_loop(board, @piece, @algorithm_time_limit)
    else
      ai_move = negamax(board, @piece, 2, @lowest_score, @highest_score)
    end
    @our_io_stream.puts("Made move #{ai_move.move} in #{Time.now - start_time} seconds. Fulldata:#{ai_move}")
    return ai_move.move
  end

  def ai_main_loop(board, active_piece, time_limit)
    # we split our time between negamax analysis and monte carlo analysis
    # begin negamax analysis
    nega_analysis_time_limit = time_limit * @ratio_of_negamax_to_montecarlo
    nega_analysis_start_time = Time.now
    # if this is the first turn, always move in the center.
    if board.turns <= 1
      return @first_move
    end
    # check for any known winning, unknown outcome, known losing moves.
    list_of_sorted_moves = get_ranked_moves(board, active_piece, nega_analysis_time_limit)
    # pick from the best category available
    list_of_moves = get_best_set_of_moves_from_evaluations(list_of_sorted_moves)
    # done with nega analysis
    time_in_nega_analysis = Time.now - nega_analysis_start_time
    bonus_time = nega_analysis_time_limit - time_in_nega_analysis
    @our_io_stream.puts "Monte Negamax Analysis in #{time_in_nega_analysis} seconds. Unspent Time: #{bonus_time}. Move Set: #{list_of_moves}"

    monte_analysis_start_time = Time.now
    monte_analysis_time_limit = (time_limit * (1-@ratio_of_negamax_to_montecarlo)) + bonus_time
    best_monte_move = monte_carlo_time_limited(board, list_of_moves, active_piece, monte_analysis_time_limit)
    return best_monte_move
  end

  def monte_carlo_time_limited(board, list_of_moves, active_piece, time_limit)
    #begin monte carlo analysis
    start_time = Time.now
    hash_of_moves = Hash.new
    # form a list of moves with # of plays and # of wins attached
    list_of_moves.each do |move|
      hash_of_moves[move] = { "plays" => 0, "wins" => 0 }
    end
    @recursion_counter = 0
    # as long as we've got time to spend, keep simulating Monte Carlo playouts
    while (Time.now - start_time) <= (time_limit)
      @recursion_counter += 1
      # make a copy of the game board to work with
      trial_game = board.dup
      result = simulate_monte_carlo_playout(trial_game, list_of_moves, active_piece)
      if result.value > 0
        hash_of_moves[result.move]["wins"] += 1
      end
      hash_of_moves[result.move]["plays"] += 1
    end
    # rank moves
    sorted = get_best_monte_carlo_result(hash_of_moves)
    #@our_io_stream.puts "Monte Carlo Moves: #{sorted.to_s}"
    @our_io_stream.puts "Monte Carlo games: #{@recursion_counter} in #{Time.now - start_time} seconds."
    return sorted
  end

  def simulate_monte_carlo_playout(trial_game, list_of_moves, current_player)
      win = trial_game.is_there_a_win?
      tie = trial_game.is_there_a_tie?
      if win
        # a negative gets flipped to a positive by the recursive call
        return Node.new(-1, -1, 0, -1)
      elsif tie
        return Node.new(-1, 0, 0, -1)
      end
      current_player = swap_pieces(current_player)
      # get a random move from the list of good moves to make
      number = Random.rand(list_of_moves.size)
      move = list_of_moves[number]
      trial_game.make_move(move, current_player)
      subtree_node = -simulate_monte_carlo_playout(trial_game, trial_game.get_available_moves, current_player)
      return Node.new(move, subtree_node.value, subtree_node.depth+1, subtree_node)
  end

  def get_best_monte_carlo_result(hash_of_moves)
    highest_percentage = 0.0
    best_move = 0
    hash_of_moves.each do |key, subhash|
      #puts "Move: #{key}  Subhash: #{subhash}"
      if subhash["plays"] != 0.0
        hash_of_moves[key]["percentage"] = subhash["wins"] / subhash["plays"].to_f
      end
      if hash_of_moves[key]["percentage"] >= highest_percentage
        highest_percentage = hash_of_moves[key]["percentage"]
        best_move = key
      end
    end
    result = Node.new(best_move, highest_percentage, 0, hash_of_moves)
    return result
  end

  def get_random_move_from_board(board)
    list_of_moves = board.get_available_moves
    random_pick = Random.rand(list_of_moves.size)
    return list_of_moves[random_pick]
  end

  def get_ranked_moves(board, active_piece, time_limit)
    start_time = Time.now
    sorted_list = Array.new
    board.get_available_moves.each do |column|
      trial_move_board = board.dup
      trial_move_board.make_move(column, active_piece)
      estimated_value = -iterative_deepening_negamax_search(trial_move_board, swap_pieces(active_piece), @deepening_depth_limit, (time_limit/board.get_available_moves.size), @lowest_score, @highest_score)
      sorted_list.push(Node.new(column, estimated_value.value/2.0, estimated_value.depth+1, estimated_value))
    end
    sorted_list.sort_by! { |object| object.value }
    return sorted_list
  end

  def get_best_set_of_moves_from_evaluations(list_of_sorted_moves)
    winning_moves = list_of_sorted_moves.map{ |node| node.move if node.value > 0 }.compact
    okay_moves = list_of_sorted_moves.map { |node| node.move if node.value == 0 }.compact
    losing_moves = list_of_sorted_moves.map { |node| node.move if node.value < 0 }.compact
    if winning_moves.size > 0
      #puts "Winning moves seen:#{winning_moves}"
      return winning_moves
    elsif okay_moves.size > 0
      return okay_moves
    else
      #puts "Losing moves seen:#{losing_moves}"
      return losing_moves
    end
  end

  def iterative_deepening_negamax_search(board, active_piece, max_depth, time_limit, alpha, beta)
    current_depth = 0
    best_move = nil
    #best_move = @lowest_score
    start_time = Time.now
    # repeatedly call negamax with increasing depth
    # will return the best move found on the last level of depth called
    begin
      best_move = @lowest_score
      subtree_best = negamax(board, active_piece, current_depth, alpha, beta)
      if subtree_best.value > best_move.value
        best_move = Node.new(subtree_best.move, subtree_best.value/2.0, subtree_best.depth+1, subtree_best)
      end
      loop_elapsed_time = (Time.now - start_time)
      ##puts "Iterative deepening loop depth: #{current_depth} V:#{best_move.value} move:#{best_move} in #{loop_elapsed_time}"
      current_depth += 1
      if current_depth > max_depth
        ##puts "Iterative deepening loop exiting at depth: #{current_depth-1} with move #{best_move} in #{loop_elapsed_time} seconds."
        return best_move
        #break
      end
    end while (loop_elapsed_time <= (time_limit/@iterative_deepening_time_divider))
    if best_move.move == nil
      best_move = get_random_move(best_move)
      #puts "No clear found with negamax search!"
    end
    #@our_io_stream.puts "Iterative deepening loop exiting at depth: #{current_depth-1} with move #{best_move} in #{loop_elapsed_time} seconds."
    return best_move
  end

  def get_random_move(move)
    #random number from 0 to 2, plus 3 yields 3 4 or 5
    #random_spot = Random.rand(2) + 3
    random_spot = Random.rand(7) + 1
    random_move = Node.new(random_spot, 0, 0, move.subnode)
    return random_move
  end

  def check_board_for_final_square_value(board, active_piece, depth)
    if board.is_there_a_win?
      # if there's a win, return a value of -1,
      # which gets flipped by the negamax recursion so that the
      # player calling it sees a positive 1 for a winning gameboard
      @final_boards_encountered += 1
      return  @value_of_win
    elsif board.is_there_a_tie?
      @final_boards_encountered += 1
      return @value_of_tie
    end
    if depth <= 0
      @depth_limited_searches += 1
      # heurisitics would be calculated here
      return @value_of_tie
    end
    #return nil
    return nil
    #return @value_of_tie
  end

  def negamax(board, active_piece, depth, alpha, beta)
    @recursion_counter += 1
    start_time = Time.now
    # win/tie check, return a value if found
    result = check_board_for_final_square_value(board, active_piece, depth)
    #puts "Result: #{result}... is it nil? #{result.value == nil}"
    return result unless result == nil
    #puts "Result2: #{result}... is it nil? #{result.value == nil}"
    new_best_move = @lowest_score
    list_of_moves = board.get_available_moves
    # move sorting
    sort_moves(list_of_moves) if true
    # iterate over possible moves and get their values (down to depth limit)
    list_of_moves.each do |column|
      trial_move_board = board.dup
      trial_move_board.make_move(column, active_piece)
      #subtree_best = @lowest_score
      subtree_best = -negamax(trial_move_board, swap_pieces(active_piece), depth-1, -beta, -alpha)

      # CRAZY !@#$%^&* BUG IF I USED SPACESHIP OPERATOR TO COMPARE NODES DIRECTLY....
      # kept insisting that the "other" was a nil object.
      # switching to comparing values directly
      # seriously spent hours on this !@#$%^&* bug
      # and who knows if it's me, ruby, or something else
      if subtree_best.value > new_best_move.value
        new_best_move = Node.new(column, subtree_best.value/2.0, subtree_best.depth+1, subtree_best)
      end
      # alpha beta
      if new_best_move.value > alpha.value
        alpha = new_best_move
        @alpha_upgrades += 1
      end
      if alpha.value > beta.value
        @alpha_cutoffs += 1
        break
      end
    end
    return new_best_move
  end

  def sort_moves(list_of_moves)
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
    return list_of_moves
  end

  def swap_pieces(active_piece)
    if active_piece == GameBoard::PlayerOneSymbol
      GameBoard::PlayerTwoSymbol
    else
      GameBoard::PlayerOneSymbol
    end
  end

  def to_s
    @player_type
  end

end
