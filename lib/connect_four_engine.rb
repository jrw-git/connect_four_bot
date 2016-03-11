require_relative "ai_player"
require_relative "human_player"
require_relative "connect_four_gameboard"
require_relative "node"

require_relative "zobrist_hashing"

class ConnectFourEngine

  @@board_height = 6
  @@board_width = 7
  @@pause_length = 1

  @@bot_testing = false
  @@log_game_results = false

  def initialize(p1, p2)

    if @@log_name != nil
      @log_enabled = true
      if !File.exist?(@@log_name)
        setup_log(@@log_name)
      end
    else
      @log_enabled = false
    end
    @board = GameBoard.new(@@board_height, @@board_width, p1)
    @current_player = p1
    @next_player = p2
    puts @board.get_aigames_setup() + "\n" if @@bot_testing
  end

  def run_game
    end_of_game = false
    until end_of_game
      start_time = Time.now
      puts "Turn: #{@current_player}  Symbol:#{@current_player.piece}"
      end_of_game = next_move(@current_player)
      @current_player = swap_players
    end
    return end_of_game
  end

  def next_move(player)
    @board.print_me
    puts @board.get_aigames_update if @@bot_testing
    puts "action move 10000\n\n" if @@bot_testing
    player_move = player.make_a_move(@board)
    @board.make_move(player_move, player.piece)
    puts
    if @board.is_there_a_win?
      if player.piece == GameBoard::PlayerOneSymbol
        log_game_results(1, 0, 0, 1) if @log_enabled
      else
        log_game_results(0, 1, 0, 1) if @log_enabled
      end
      print_final_board
      puts "Congrats! #{player} #{player.piece} won!"
      sleep(@@pause_length)
      return true
    end
    if @board.is_there_a_tie?
      log_game_results(0, 0, 1, 1) if @log_enabled
      print_final_board
      puts "Tied game. Nobody wins or loses."
      sleep(@@pause_length)
      return true
    end
  end

  def print_final_board
    puts '=' * 50
    puts "Final Game Board:"
    puts '=' * 50
    @board.print_me
    puts '=' * 50
    puts "Pausing for #{@@pause_length} seconds, then proceeding (control-c exits)"
    puts '=' * 50
  end

  def swap_players
    @will_be_next_player = @current_player
    @current_player = @next_player
    @next_player = @will_be_next_player
    return @current_player
  end

  def self.setup_player(player_symbol)
    search_limit = 0.5
    aigames_io = false
    use_heuristics = false
    puts "Select from the options for player #{player_symbol}:"
    puts "1) Human"
    puts "2) Easy - Negamax 6"
    puts "3) Medium (AI Games Difficulty), Mixed Negamax and Monte Carlo"
    puts "4) You Specify Pure Negamax Search Depth"
    puts "5) You Specify Iterative Negamax Time Limit"
    puts "6) You Specify Mixed AI Time Limit"
    puts "7) You Specify Monte Carlo AI Time Limit"
    print "Enter a number: "
    choice = $stdin.gets.chomp
    case choice
    when '1'
      return PlayerHuman.new("Human", player_symbol)
    when '2'
      brain = "Negamax"
      search_limit = 6
      puts "Forcing AI to #{brain}, #{search_limit} moves ahead."
      return Player.new("AI:#{brain}-#{search_limit}.", player_symbol, brain, search_limit, aigames_io)
    when '3'
      brain = "Mixed"
      search_limit = 0.7
      puts "Forcing AI to #{brain}, #{search_limit} seconds per turn"
      return Player.new("AI:#{brain}-#{search_limit}.", player_symbol, brain, search_limit, aigames_io)
    when '4'
      brain = "Negamax"
      search_limit = get_depth_limit
      puts "Forcing AI to #{brain}, #{search_limit} moves ahead."
      return Player.new("AI:#{brain}-#{search_limit}.", player_symbol, brain, search_limit, aigames_io)
    when '5'
      brain = "IterativeNegamax"
      search_limit = get_time_limit
      puts "Forcing AI to #{brain}, #{search_limit} seconds per turn"
      return Player.new("AI:#{brain}-#{search_limit}.", player_symbol, brain, search_limit, aigames_io)
    when '6'
      brain = "Mixed"
      search_limit = get_time_limit
      puts "Forcing AI to #{brain}, #{search_limit} seconds per turn"
      return Player.new("AI:#{brain}-#{search_limit}.", player_symbol, brain, search_limit, aigames_io)
    when '7'
      brain = "MonteCarlo"
      search_limit = get_time_limit
      puts "Forcing AI to #{brain}, #{search_limit} seconds per turn"
      return Player.new("AI:#{brain}-#{search_limit}.", player_symbol, brain, search_limit, aigames_io)
    else
      setup_player(player_symbol)
    end
  end

  def self.get_depth_limit
    puts "How many plies deep will you let the AI search?"
    print "Enter number of moves to search (2 minimum): "
    search_limit = $stdin.gets.chomp.to_i
    search_limit = 2 if search_limit < 2
    return search_limit
  end

  def self.get_time_limit
    puts "How long will you let the AI think for? The higher the number the better the performance."
    print "Enter number of seconds (0.5 minimum): "
    search_limit = $stdin.gets.chomp.to_f
    search_limit = 0.5 if search_limit < 0.5
    return search_limit
  end

  def log_game_results(p1_wins_add, p2_wins_add, draws_add, total_games_add)
    puts "Logging results to file #{@@log_name}"
    open_log = File.open(@@log_name, 'r+')
    p1_wins = open_log.readline.chomp.to_i
    p2_wins = open_log.readline.chomp.to_i
    tied_games = open_log.readline.chomp.to_i
    total_games = open_log.readline.chomp.to_i

    p1_wins += p1_wins_add
    p2_wins += p2_wins_add
    tied_games += draws_add
    total_games += total_games_add

    open_log.rewind

    open_log.write("#{p1_wins}\n")
    open_log.write("#{p2_wins}\n")
    open_log.write("#{tied_games}\n")
    open_log.write("#{total_games}\n")
    open_log.close
  end

  def setup_log(log_name)
    log_file = File.open(@@log_name, "w")
    log_file.write("0\n0\n0\n0\n")
    log_file.write("Above format: Player 1 Win Total, Player 2 Win Total, Draws, Total Games Played")
    log_file.write(@current_player.to_s + "\n")
    log_file.write(@next_player.to_s + "\n")
    log_file.close
  end

  def self.print_intro
    puts "Welcome to Connect Four - Game and AI/bot"
    puts "Written 2016 by John White"
    puts "You can play against two different AI/bots, or play vs another human."
    puts "Results are logged to a log file so that AI vs AI matches can run without your input."
    puts "To exit, hit control-c or close the window. By default 1000 games will occur."
  end

  def self.ask_user_about_bot_output
    puts "Do you want to output data for bot testing?"
    puts "If yes, then you will see lines of data you can copy/paste to the bot window"
    print "Output data for copy/pasting to bot? (y/n): "
    bot_testing = $stdin.gets.chomp
    if bot_testing == 'y'
      @@bot_testing = true
    else
      @@bot_testing = false
    end
  end

  def self.ask_user_about_logging
    @@log_name = nil
    print "Do you want to save win/loss/draw data to a file for statistical purposes? (y/n): "
    log_choice = $stdin.gets.chomp
    if log_choice == 'y'
      print "Enter log file (.txt added): "
      @@log_name = $stdin.gets.chomp
      @@log_name += ".txt"
      puts "Logging to #{@@log_name}"
    end
  end

end

ConnectFourEngine.print_intro
ConnectFourEngine.ask_user_about_bot_output
ConnectFourEngine.ask_user_about_logging
p1 = ConnectFourEngine.setup_player(GameBoard::PlayerOneSymbol)
p2 = ConnectFourEngine.setup_player(GameBoard::PlayerTwoSymbol)
number_runs = 1000
(1..number_runs).each do |x|
  connect_four_game = ConnectFourEngine.new(p1, p2)
  connect_four_game.run_game
end
