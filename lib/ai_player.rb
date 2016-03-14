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
    @player_name = player_name
    @piece = symbol
    @brain_type = brain_type
    @algorithm_limit = algorithm_limit
    $stdout = $stderr if aigames_io
    @first_move = Node.new(4, 0, 0, -1)
    super()
  end

  def make_a_move(board)
    @recursion_counter = 0
    start_time = Time.now
    ai_move = ai_main_loop(board, @piece, @algorithm_limit)
    puts("Made move #{ai_move.move} in #{@recursion_counter} recursions, in #{Time.now - start_time} seconds. RPS:#{@recursion_counter/(Time.now - start_time)}")
    return ai_move.move
  end

  def ai_main_loop(board, active_piece, time_limit)
    # if this is the first turn, always move in the center.
    return @first_move if board.turns <= 1
    #puts "Size of Transposition Table:#{@transposition_table.size}"
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
      puts "Negamax Pre-MonteCarlo Analysis in #{time_in_nega_analysis} seconds. Unspent Time: #{bonus_time}. Move Set: #{list_of_moves}"
      # take our set of moves and analyse them with monte carlo
      monte_analysis_time_limit = (time_limit * (1-@ratio_of_negamax_to_montecarlo)) + bonus_time
      ai_move = monte_carlo_time_limited(board, list_of_moves, active_piece, monte_analysis_time_limit, 50000, print_result)
      puts "Time Excess: #{(Time.now - start_time) - time_limit}"
    else
      puts "Unknown brain type for AI: #{@brain_type}. Exiting."
      exit
    end
    #puts "Move took #{Time.now - start_time}, found: #{ai_move}"
    return ai_move
  end

  def to_s
    str = "Player:#{@player_name} Piece:#{@piece}, Brain:#{@brain_type}, Limit:#{@algorithm_limit}"
    return str
  end

end
