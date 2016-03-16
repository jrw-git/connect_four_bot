class GameBoard

  attr_reader :board, :height, :width, :turns, :hash, :last_move_array

  DefaultSymbol = '0'
  PlayerOneSymbol = '1'
  PlayerTwoSymbol = '2'

  def self.process_string_into_board(string, current_player, current_turn)
    # eg 0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,2,0,1,0,0,0;0,2,0,1,0,0,0
    board_array = string.split(";")
    new_board = board_array.map { |string| string.split(",") }
    return new_board
    #return GameBoard.new(6, 7, current_player, current_turn, new_board)
  end

  def initialize(height, width, current_player, current_turn = 1, board_array = nil)
    @enable_win_check_optimization = true
    @all_neighbors_array = Array.new
    @original = true
    @height = height.to_i
    @width = width.to_i
    if board_array == nil
      @board = Array.new(@height) { Array.new(@width, DefaultSymbol) }
    else
      @board = board_array
    end
    @turns = current_turn.to_i
    @last_move_array = Array.new
    @current_player = current_player
    @hasher = ZobristHash.new
    @hash = @hasher.hash_entire_board(@board)
    @reversed_hash = nil
  end

  def initialize_dup(other)
    @original = false
    @last_move_array = other.last_move_array.dup
    @height = other.height
    @width = other.width
    @board = Array.new(@height) { Array.new(@width, @default) }
    other.board.each_index do |height_index|
      @board[height_index] = other.board[height_index].dup
    end
  end

  def change_players(active_piece)
    if active_piece == GameBoard::PlayerOneSymbol
      GameBoard::PlayerTwoSymbol
    else
      GameBoard::PlayerOneSymbol
    end
  end

  def get_piece(h, w)
    if h >= @height || w >= @width || h < 0 || w < 0
      return ""
    else
      return @board[h][w]
    end
  end

  def find_last_move_neighbors(h_shift, w_shift, total_radius)
    pre = ""
    post = ""
    prev_move = @last_move_array[-1]
    (1..total_radius).each do |x|
      w = prev_move["width"]
      h = prev_move["height"]
      hs = h_shift*x
      ws = w_shift*x
      pre_char = get_piece((h-hs), (w-ws))
      post_char = get_piece((h+hs), (w+ws))
      # this HUGELY speeds up win checking but will TOTALLY break Heuristics
      # in that it won't report on sequences with open spots in them
      if @enable_win_check_optimization
        if pre_char != prev_move["player"] && post_char != prev_move["player"]
          break
        end
      end
      pre += pre_char
      post += post_char
    end
    # was getting a hilarious bug because I didn't think through the pre + post sequencing. pre needs reversal.
    return pre.reverse + prev_move["player"] + post
  end

  # used for heuristics... which don't work that well
  def get_cached_neighbors
    if @all_neighbors_array.size > 0
      return @all_neighbors_array
    else
      puts "Error getting cached neighbors, size was zero"
    end
  end

  def get_all_neighbors(depth)
    results = Array.new
    results.push(find_last_move_neighbors(0, 1, depth))
    results.push(find_last_move_neighbors(1, 0, depth))
    results.push(find_last_move_neighbors(-1, 1, depth))
    results.push(find_last_move_neighbors(1, -1, depth))
    results.push(find_last_move_neighbors(-1, -1, depth))
    results.push(find_last_move_neighbors(1, 1, depth))
    return results
  end

  def is_there_a_win?
    if @turns < 7
      return false
    end
    if @last_move_array.size <= 0
      return false
    end
    win = false
    @all_neighbors_array = get_all_neighbors(3)
    (0...@all_neighbors_array.size).each do |x|
      win = win || check_string_for_win(@last_move_array[-1]["player"], @all_neighbors_array[x])
    end
    return win
  end

  def get_available_moves
    coord_array = Array.new
    (1..@width).each do |column_number|
      coord_array.push(column_number) if is_column_empty?(column_number)
    end
    return coord_array
  end

  def make_move(column, gamepiece)
    h = get_height_of_first_empty_location_in_column(column)
    place_piece(h, column-1, gamepiece)
  end

  def place_piece(height, width, gamepiece)
    @last_move_array.push({"height" => height, "width" => width, "player" => gamepiece})
    @turns += 1
    @board[height][width] = gamepiece
    @hash = @hasher.hash_position_with_board(@hash, height, width, gamepiece, @board)
  end

  def undo_move
    prev_move = @last_move_array.pop
    remove_piece(prev_move["height"], prev_move["width"], prev_move["player"])
  end

  def remove_piece(height, width, gamepiece)
    check = @board[height][width]
    if check != gamepiece
      puts "Error removing piece, board is now FUBAR. Board:#{check} Expected#{gamepiece}"
      exit
    end
    @hash = @hasher.hash_position_with_board(@hash, height, width, gamepiece, @board)
    @board[height][width] = DefaultSymbol
    @turns -= 1
  end

  def get_height_of_first_filled_location_in_column(column)
    (0...@height).each do |h|
      return h if !(is_location_empty?(h, column-1))
    end
    return 0
  end

  def get_height_of_first_empty_location_in_column(column)
    top = @height - 1
    (0...@height).each do |height_index|
      return top - height_index if is_location_empty?(top - height_index, column-1)
    end
  end

  def is_column_empty?(column)
    return true if is_location_empty?(0, column-1)
    return false
  end

  def is_location_empty?(h, w)
    return true if get_piece(h, w) == DefaultSymbol
    return false
  end

  def check_string_for_win(symbol, string)
    return true if string.include?("#{symbol}#{symbol}#{symbol}#{symbol}")
    return false
  end

  def is_there_a_tie?
    return false if is_there_a_win?
    return true if get_available_moves.size == 0
  end

  def print_me
    puts "1 2 3 4 5 6 7"
    puts "-------------"
    @board.each_index do |height_index|
      @board[height_index].each_index do |width_index|
        #print "( #{@board[height_index][width_index]} )   "
        print "#{@board[height_index][width_index]} "
        #print " (#{height_index},#{width_index}) "
      end
      puts
    end
    puts "-------------"
  end

  def get_aigames_update
    string = "update game round #{@turns}\nupdate game field "
    @board.each_index do |height_index|
      @board[height_index].each_index do |width_index|
        string += "#{@board[height_index][width_index]},"
      end
      # drop the trailing ","
      string.slice!(-1)
      string += ";"
    end
    # drop the trailing ";"
    string.slice!(-1)
    string += "\n"
    return string
  end

  def get_aigames_setup
    string = "Player One settings:\n"
    string += "settings timebank 10000\n"
    string += "settings time_per_move 500\n"
    string += "settings player_names player1,player2\n"
    string += "settings your_bot player1\n"
    string += "settings your_botid 1\n"
    string += "settings field_columns 7\n"
    string += "settings field_rows 6\n\n"
    string += "Player Two settings:\n"
    string += "settings timebank 10000\n"
    string += "settings time_per_move 500\n"
    string += "settings player_names player1,player2\n"
    string += "settings your_bot player2\n"
    string += "settings your_botid 2\n"
    string += "settings field_columns 7\n"
    string += "settings field_rows 6\n"
    return string
  end

end
