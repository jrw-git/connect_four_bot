require_relative "node"

# first we run a quick negamax analysis for winning/losing moves
# we devote no more than half the time alloted in this negamax search
# in the other half, we do a very basic monte carlo analysis

module MonteCarloAnalysis


  def initialize
    @ratio_of_negamax_to_montecarlo = 0.5
    super()
  end

  # this is a front end to iterative deepening that gets us a ranked list of moves
  # normally we just get the best move, not a list
  # we then can process the list for just winning, just okay, or just losing moves
  # to further explore
  def get_negamax_ranked_moves(board, active_piece, time_limit, print_result)
    start_time = Time.now
    sorted_list = Array.new
    board.get_available_moves.each do |move|
      trial_move_board = nil
      # duping the board and discarding it rather than make/undo moves
      trial_move_board = board.dup
      trial_move_board.make_move(move, active_piece)
      subnode_best = -iterative_deepening_negamax_search(trial_move_board, board.change_players(active_piece), (time_limit/board.get_available_moves.size), @lowest_score, @highest_score, print_result)
      sorted_list.push(insert_move_into_results(subnode_best, move))
    end
    sorted_list.sort_by! { |object| object.value }
    return sorted_list
  end

  def select_best_move_set(list_of_sorted_moves)
    winning_moves = list_of_sorted_moves.map { |node| node.move if node.value > 0 }.compact
    okay_moves = list_of_sorted_moves.map { |node| node.move if node.value == 0 }.compact
    losing_moves = list_of_sorted_moves.map { |node| node.move if node.value < 0 }.compact
    if winning_moves.size > 0
      puts "Winning moves seen:#{winning_moves}"
      return winning_moves
    elsif okay_moves.size > 0
      return okay_moves
    else
      puts "Losing moves seen:#{losing_moves}"
      return losing_moves
    end
  end

  def monte_carlo_time_limited(board, list_of_moves, active_piece, time_limit, game_limit, print_result = false)
    #begin monte carlo analysis
    start_time = Time.now
    hash_of_moves = Hash.new
    # form a list of moves with # of plays and # of wins attached
    list_of_moves.each do |move|
      hash_of_moves[move] = { "plays" => 0, "wins" => 0 }
    end
    recursion_counter = 0
    # as long as we've got time to spend, keep simulating Monte Carlo playouts
    while ((Time.now - start_time) <= (time_limit) && recursion_counter <= game_limit)
      recursion_counter += 1
      # make a copy of the game board to work with
      trial_move_board = board.dup if @try_board_dup
      trial_move_board = board if !@try_board_dup
      result = simulate_monte_carlo_playout(trial_move_board, list_of_moves, active_piece)
      if result.value > 0
        hash_of_moves[result.move]["wins"] += 1
      end
      hash_of_moves[result.move]["plays"] += 1
    end
    # rank moves
    sorted = get_best_monte_carlo_result(hash_of_moves)
    if print_result
      puts "Monte Carlo Results:"
      hash_of_moves.each { |x, move | puts "Move#{x}: #{move}" }
    end
    puts "Monte Carlo games: #{recursion_counter} in #{Time.now - start_time} seconds, bestM:#{sorted.move} bestV:#{sorted.value}"
    return sorted
  end

  def simulate_monte_carlo_playout(trial_move_board, list_of_moves, current_player)
      win = trial_move_board.is_there_a_win?
      tie = trial_move_board.is_there_a_tie?
      # a negative gets flipped to a positive by the recursive call
      return Node.new(-1, -1, 0, -1) if win
      return Node.new(-1, 0, 0, -1) if tie
      current_player = trial_move_board.change_players(current_player)
      # get a random move from the list of good moves to make
      random_index = Random.rand(list_of_moves.size)
      move = list_of_moves[random_index]
      trial_move_board.make_move(move, current_player)
      subtree_node = -simulate_monte_carlo_playout(trial_move_board, trial_move_board.get_available_moves, current_player)
      trial_move_board.undo_move if !@try_board_dup
      return Node.new(move, subtree_node.value, subtree_node.depth+1, subtree_node)
  end

  def get_best_monte_carlo_result(hash_of_moves)
    highest_percentage = 0.0
    best_move = 0
    hash_of_moves.each do |key, subhash|
      if subhash["plays"] != 0.0
        hash_of_moves[key]["percentage"] = subhash["wins"] / subhash["plays"].to_f * 100.0
      else
        hash_of_moves[key]["percentage"] = 0.0
      end
      if hash_of_moves[key]["percentage"] >= highest_percentage
        highest_percentage = hash_of_moves[key]["percentage"]
        best_move = key
      end
    end
    result = Node.new(best_move, highest_percentage, 0, hash_of_moves)
    return result
  end

end
