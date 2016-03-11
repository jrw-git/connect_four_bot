# ai player for general games
# has 3 options for use
# an iterative deepening negamax search that won't exceed the given time_limit
# a combined negamax and monte carlo simulation that won't exceed the time limit
# and a 4-ply deep straight negamax search with no time limit (usually quite fast)

require_relative "monte_carlo_analytics"
require_relative "negamax_analytics"

class Player

  include MonteCarloAnalysis
  include NegamaxAnalysis

  attr_reader :player_type, :piece

  def initialize(player_type, symbol, algorithm_limit, monte_carlo_on, aigames_interface_on, use_heuristics)
    @try_board_dup = true
    @player_type = player_type
    @use_heuristics = use_heuristics
    @piece = symbol
    @use_monte_carlo = monte_carlo_on
    @aigames_interface_on = aigames_interface_on
    if @aigames_interface_on
      @our_io_stream = $stderr
    else
      @our_io_stream = $stdout
    end
    @deepening_depth_limit = 20
    @algorithm_limit = algorithm_limit.to_f
    @lowest_score = Node.new(-1, -8192, 0, -1)
    @highest_score = Node.new(-1, 8192, 0, -1)
    @value_of_tie = Node.new(-1, 0, 0, -1)
    @value_of_win = Node.new(-1, -8192, 0, -1)
    @value_of_unknown = Node.new(-1, nil, 0, -1)
    @first_move = Node.new(4, 0, 0, -1)
    @ratio_of_negamax_to_montecarlo = 0.5
    super()
  end

  def set_piece(symbol)
    @piece = symbol
  end

  def make_a_move(board)
    # stats variables that currently aren't printed out
    @recursion_counter = 0
    start_time = Time.now
    ai_move = ai_main_loop(board, @piece, @algorithm_limit)
    @our_io_stream.puts("Made move #{ai_move.move} in #{Time.now - start_time} seconds.")
    return ai_move.move
  end

  def ai_main_loop(board, active_piece, time_limit)
    print_result = false
    if !@use_monte_carlo
      # hacky way of letting me set the depth of a straight negamax search from player setup
      # use algorithm time limit as depth limit
      ai_move = negamax(board, @piece, @algorithm_limit, @lowest_score, @highest_score, true)
      return ai_move
    end
    # we split our time between negamax analysis and monte carlo analysis
    # begin negamax analysis
    nega_analysis_time_limit = time_limit * @ratio_of_negamax_to_montecarlo
    nega_analysis_start_time = Time.now
    # if this is the first turn, always move in the center.
    if board.turns <= 1
      return @first_move
    end
    # check for any known winning, unknown outcome, known losing moves.
    list_of_sorted_moves = get_negamax_ranked_moves(board, active_piece, nega_analysis_time_limit, print_result)
    # pick from the best category available
    # (ie, choose only winning, or only unknown moves, or if losing, only losing moves)
    list_of_moves = select_best_move_set(list_of_sorted_moves)
    # done with nega analysis
    time_in_nega_analysis = Time.now - nega_analysis_start_time
    bonus_time = nega_analysis_time_limit - time_in_nega_analysis
    @our_io_stream.puts "Negamax Pre-MonteCarlo Analysis in #{time_in_nega_analysis} seconds. Unspent Time: #{bonus_time}. Move Set: #{list_of_moves}"

    monte_analysis_start_time = Time.now
    monte_analysis_time_limit = (time_limit * (1-@ratio_of_negamax_to_montecarlo)) + bonus_time
    best_monte_move = monte_carlo_time_limited(board, list_of_moves, active_piece, monte_analysis_time_limit, 50000)
    return best_monte_move
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
      trial_move_board = board.dup if @try_board_dup
      trial_move_board = board if !@try_board_dup
      trial_move_board.make_move(move, active_piece)
      subnode_best = -iterative_deepening_negamax_search(trial_move_board, swap_pieces(active_piece), @deepening_depth_limit, (time_limit/board.get_available_moves.size), @lowest_score, @highest_score, print_result)
      trial_move_board.undo_move(move, active_piece) if !@try_board_dup
      sorted_list.push(process_subnode_and_move_into_node(subnode_best, move))
    end
    sorted_list.sort_by! { |object| object.value }
    return sorted_list
  end

  def select_best_move_set(list_of_sorted_moves)
    winning_moves = list_of_sorted_moves.map { |node| node.move if node.value > 0 }.compact
    okay_moves = list_of_sorted_moves.map { |node| node.move if node.value == 0 }.compact
    losing_moves = list_of_sorted_moves.map { |node| node.move if node.value < 0 }.compact
    if winning_moves.size > 0
      @our_io_stream.puts "Winning moves seen:#{winning_moves}"
      return winning_moves
    elsif okay_moves.size > 0
      return okay_moves
    else
      @our_io_stream.puts "Losing moves seen:#{losing_moves}"
      return losing_moves
    end
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
