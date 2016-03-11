# ai player for general games
# has 3 options for use
# an iterative deepening negamax search that won't exceed the given time_limit
# a combined negamax and monte carlo simulation that won't exceed the time limit
# and a 4-ply deep straight negamax search with no time limit (usually quite fast)

require_relative "monte_carlo_analytics"
require_relative "negamax_analytics"
require_relative "zobrist_hashing"

class Player

  include MonteCarloAnalysis
  include NegamaxAnalysis

  attr_reader :player_name, :piece

  def initialize(player_name, symbol, brain_type, algorithm_limit, aigames_io)
    @our_hasher = ZobristHash.new
    @try_board_dup = true
    @use_heuristics = false
    @player_name = player_name
    @piece = symbol
    @brain_type = brain_type
    @algorithm_limit = algorithm_limit
    @ratio_of_negamax_to_montecarlo = 0.5

    @our_io_stream = $stderr if aigames_io
    @our_io_stream = $stdout if !aigames_io
    @lowest_score = Node.new(-1, -8192, 0, -1)
    @highest_score = Node.new(-1, 8192, 0, -1)
    @value_of_tie = Node.new(-1, 0, 0, -1)
    @value_of_win = Node.new(-1, -8192, 0, -1)
    @value_of_unknown = Node.new(-1, nil, 0, -1)
    @first_move = Node.new(4, 0, 0, -1)

    super()
  end

  def make_a_move(board)
    # stats variables that currently aren't printed out
    @recursion_counter = 0
    start_time = Time.now

    ai_move = ai_main_loop(board, @piece, @algorithm_limit)
    @our_io_stream.puts("Made move #{ai_move.move} in #{@recursion_counter} recursions, in #{Time.now - start_time} seconds. RPS:#{@recursion_counter/(Time.now - start_time)}")
    return ai_move.move
  end

  def ai_main_loop(board, active_piece, time_limit)
    # if this is the first turn, always move in the center.
    return @first_move if board.turns <= 1
    @our_io_stream.puts "Size of Transposition Table:#{@transposition_table.size}"
    print_result = false
    start_time = Time.now
    case @brain_type
    when "MonteCarlo"
      list_of_moves = board.get_available_moves
      max_games = 50000
      ai_move = monte_carlo_time_limited(board, list_of_moves, active_piece, time_limit, max_games, print_result)
      puts "Time Excess: #{(Time.now - start_time) - time_limit}"
    when "Negamax"
      ai_move = negamax(board, active_piece, time_limit, @lowest_score, @highest_score, print_result)
    when "IterativeNegamax"
      ai_move = iterative_deepening_negamax_search(board, active_piece, time_limit, @lowest_score, @highest_score, print_result)
      puts "Time Excess: #{(Time.now - start_time) - time_limit}"
    when "Mixed"
      nega_analysis_time_limit = time_limit * @ratio_of_negamax_to_montecarlo
      nega_analysis_start_time = Time.now
      # we split our time between negamax analysis and monte carlo analysis
      # negamax check for any known winning, unknown outcome, known losing moves.
      list_of_sorted_moves = get_negamax_ranked_moves(board, active_piece, nega_analysis_time_limit, print_result)
      # pick from the best category available
      # (ie, choose only winning, or only unknown moves, or if losing, only losing moves)
      list_of_moves = select_best_move_set(list_of_sorted_moves)
      # done with nega analysis
      time_in_nega_analysis = Time.now - nega_analysis_start_time
      bonus_time = nega_analysis_time_limit - time_in_nega_analysis
      @our_io_stream.puts "Negamax Pre-MonteCarlo Analysis in #{time_in_nega_analysis} seconds. Unspent Time: #{bonus_time}. Move Set: #{list_of_moves}"
      # take our set of moves and analyse them with monte carlo
      monte_analysis_time_limit = (time_limit * (1-@ratio_of_negamax_to_montecarlo)) + bonus_time
      ai_move = monte_carlo_time_limited(board, list_of_moves, active_piece, monte_analysis_time_limit, 50000, print_result)
      puts "Time Excess: #{(Time.now - start_time) - time_limit}"
    else
      @our_io_stream.puts "Unknown brain type for AI: #{@brain_type}. Exiting."
      exit
    end
    #@our_io_stream.puts "Move took #{Time.now - start_time}, found: #{ai_move}"
    return ai_move
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
      subnode_best = -iterative_deepening_negamax_search(trial_move_board, swap_pieces(active_piece), (time_limit/board.get_available_moves.size), @lowest_score, @highest_score, print_result)
      trial_move_board.undo_move if !@try_board_dup
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
    str = "Player:#{@player_name} Piece:#{@piece}, Brain:#{@brain_type}, Limit:#{@algorithm_limit}, Ratio:#{@ratio_of_negamax_to_montecarlo}, BoardDup?#{@try_board_dup}, Heuristics?##{@use_heuristics}"
    return str
  end

end
