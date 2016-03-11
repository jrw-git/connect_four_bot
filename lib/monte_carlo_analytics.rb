require_relative "node"

module MonteCarloAnalysis

  # CURRENTLY DEPENDS ON PARENT FUNCTION swap_pieces(current_player)

  # try_board_dup is for optimization testing
  # toggles a change between duping a board then discarding it when done
  # vs making a move, then unmaking a move, on the original board

  def monte_carlo_time_limited(board, list_of_moves, active_piece, time_limit, game_limit)
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
    @our_io_stream.puts "Monte Carlo games: #{recursion_counter} in #{Time.now - start_time} seconds, bestM:#{sorted.move} bestV:#{sorted.value}"
    return sorted
  end

  def simulate_monte_carlo_playout(trial_move_board, list_of_moves, current_player)
      win = trial_move_board.is_there_a_win?
      tie = trial_move_board.is_there_a_tie?
      # a negative gets flipped to a positive by the recursive call
      return Node.new(-1, -1, 0, -1) if win
      return Node.new(-1, 0, 0, -1) if tie
      current_player = self.swap_pieces(current_player)
      # get a random move from the list of good moves to make
      random_index = Random.rand(list_of_moves.size)
      move = list_of_moves[random_index]
      trial_move_board.make_move(move, current_player)
      subtree_node = -simulate_monte_carlo_playout(trial_move_board, trial_move_board.get_available_moves, current_player)
      trial_move_board.undo_move(move, current_player) if !@try_board_dup
      return Node.new(move, subtree_node.value, subtree_node.depth+1, subtree_node)
  end

  def get_best_monte_carlo_result(hash_of_moves)
    highest_percentage = 0.0
    best_move = 0
    hash_of_moves.each do |key, subhash|
      if subhash["plays"] != 0.0
        hash_of_moves[key]["percentage"] = subhash["wins"] / subhash["plays"].to_f * 1000.0
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