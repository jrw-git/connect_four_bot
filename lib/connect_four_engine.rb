require "./ai_player"
require "./human_player"
require "./connect_four_gameboard"
require "./node"

class ConnectFourEngine

  @@board_height = 6
  @@board_width = 7

  def initialize(log_name, p1 = ConnectFour.setup_player(GameBoard::PlayerOneSymbol), p2 = ConnectFour.setup_player(GameBoard::PlayerTwoSymbol))
    if log_name != nil
      @log_enabled = true
      @log_name = log_name
      setup_log(@log_name)
    else
      @log_enabled = false
    end
    @board = GameBoard.new(@@board_height, @@board_width, p1)
    @current_player = p1
    @next_player = p2
    #@current_player = self.setup_player(GameBoard::PlayerOneSymbol)
    #@next_player = self.setup_player(GameBoard::PlayerTwoSymbol)
    if false
      puts @board.get_aigames_setup(@current_player.piece) + "\n"
    end
  end

  # THE HEURISTIC DOESN'T WORK PROPERLY
  # ITERATIVE DEEPENING WORKS
  # ALPHA BETA WORKS
  # MOVE SORTING SORTA KINDA WORKS - in that I just shuffle the center positions to be checked first

  def run_game
    end_of_game = false
    until end_of_game
      puts "Turn: #{@current_player} #{@current_player.piece}"
      end_of_game = next_move(@current_player)
      @current_player = swap_players
    end
    return end_of_game
  end

  def next_move(player)
    @board.print_me
    if false
      puts @board.get_aigames_update
      puts "action move 10000\n\n"
    end
    player_move = player.make_a_move(@board)
    @board.place_piece_in_column(player_move, player.piece)
    puts
    if @board.is_there_a_win?
      if player.piece == GameBoard::PlayerOneSymbol
        log_game_results(1, 0, 0, 1) if @log_enabled
      else
        log_game_results(0, 1, 0, 1) if @log_enabled
      end
      puts '=' * 50
      puts "Final Game Board:"
      puts '=' * 50
      @board.print_me
      puts '=' * 50
      puts "Congrats! #{player} #{player.piece} won!"
      puts "Pausing for 5 seconds, then proceeding (or exiting)"
      puts '=' * 50
      sleep(5)
      return true
    end
    if @board.is_there_a_tie?
      log_game_results(0, 0, 1, 1) if @log_enabled
      puts '=' * 50
      puts "Final Game Board:"
      puts '=' * 50
      @board.print_me
      puts '=' * 50
      puts "Tied game."
      puts "Pausing for 5 seconds, then proceeding (or exiting)"
      puts '=' * 50
      sleep(5)
      return true
    end

  end

  def log_game_results(p1_wins_add, p2_wins_add, draws_add, total_games_add)
    puts "File #{@log_name} exists? #{File.exist?(@log_name)}"
    open_log = File.open(@log_name, 'r+')
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
  def swap_players
    @will_be_next_player = @current_player
    @current_player = @next_player
    @next_player = @will_be_next_player
    return @current_player
  end

  def self.setup_player(player_symbol)
    time_to_iterate = 0.5
    use_aigames_interface = false
    print "Do you want Player #{player_symbol} to be human? (y/n): "
    choice = $stdin.gets.chomp
    if choice == 'y'
      return PlayerHuman.new("Human", player_symbol)
    elsif choice == 'n'
      puts "How long will you let the AI think for? The higher the number the better the performance."
      print "Enter number of seconds (0.5 minimum): "
      time_to_iterate = $stdin.gets.chomp.to_f
      if time_to_iterate < 0.5
        time_to_iterate = 0.5
      end
      puts "Letting AI think for #{time_to_iterate} seconds per turn."
      #print "Do you want a (m)ixed Monte Carlo/Negamax AI or a pure (n)egamax-deep-iterating AI? (m/n): "
      print "Do you want an (e)asy AI that searches 2 moves ahead, or a (h)ard AI? (e/h): "
      choice = $stdin.gets.chomp
      if choice == 'h'
        monte_carlo = true
        use_deep_iteration = false
        return Player.new("AI Monte Carlo", player_symbol, time_to_iterate, use_deep_iteration, monte_carlo, use_aigames_interface)
      elsif choice == 'n'
        monte_carlo = false
        use_deep_iteration = true
        return Player.new("AI Nega-Deep", player_symbol, time_to_iterate, use_deep_iteration, monte_carlo, use_aigames_interface)
      elsif choice == 'e'
        monte_carlo = false
        use_deep_iteration = false
        return Player.new("AI Negamax-Simple", player_symbol, time_to_iterate, use_deep_iteration, monte_carlo, use_aigames_interface)
      else
        setup_player(player_symbol)
      end
    else
      setup_player(player_symbol)
    end
  end

  def setup_log(log_name)
    #log_name = "connect_four_run_statistics.txt"
    log_file = File.open(@log_name, "w")
    log_file.write("0\n")
    log_file.write("0\n")
    log_file.write("0\n")
    log_file.write("0\n")
    log_file.write(@current_player.inspect + "\n")
    log_file.write(@next_player.inspect + "\n")
    log_file.close
  end

end

puts "Welcome to Connect Four - Game and AI/bot"
puts "Written 2016 by John White"
puts "You can play against two different AI/bots, or play vs another human."
#puts "Results are logged to a log file so that AI vs AI matches can run infinitely."
puts "To exit, hit control-c or close the window. By default 100 games will occur."

log_name = nil
if false
  print "Enter log file (.txt added): "
  log_name = $stdin.gets.chomp
  log_name += ".txt"
  puts "Logging to #{log_name}"
end

p1 = ConnectFourEngine.setup_player(GameBoard::PlayerOneSymbol)
p2 = ConnectFourEngine.setup_player(GameBoard::PlayerTwoSymbol)
number_runs = 100
(1..number_runs).each do |x|
  connect_four_game = ConnectFourEngine.new(log_name, p1, p2)

  connect_four_game.run_game
end
