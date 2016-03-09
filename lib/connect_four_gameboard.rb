class GameBoard

  attr_reader :board, :height, :width, :last_move, :last_player, :turns

  DefaultSymbol = '0'
  PlayerOneSymbol = '1'
  PlayerTwoSymbol = '2'

  def initialize(height, width, current_player, current_turn = 1, board_array = nil)
    @original = true
    @height = height.to_i
    @width = width.to_i
    if board_array == nil
      @board = Array.new(@height) { Array.new(@width, DefaultSymbol) }
    else
      @board = board_array
    end
    @turns = current_turn.to_i
    @last_move = Hash.new
    @current_player = current_player
  end

  def initialize_dup(other)
    @original = false
    @height = other.height
    @width = other.width
    @board = Array.new(@height) { Array.new(@width, @default) }
    other.board.each_index do |height_index|
      @board[height_index] = other.board[height_index].dup
    end
  end

  def get_piece(h, w)
    if h >= @height || w >= @width || h < 0 || w < 0
      return ""
    else
      return @board[h][w]
    end
  end

  def get_neighbors(last_move, last_player,h_shift, w_shift)
    pre = ""
    post = ""
    (1..3).each do |x|
      w = last_move["width"]
      h = last_move["height"]
      hs = h_shift*x
      ws = w_shift*x
      pre += get_piece((h-hs), (w-ws))
      post += get_piece((h+hs), (w+ws))
    end
    # was getting a hilarious bug because I didn't think through the pre + post sequencing. pre needs reversal.
    return pre.reverse + last_player + post
  end

  def is_there_a_win?
    if @turns < 7
      return false
    end
    if @last_move["width"] == nil
      return false
    end
    win = false
    win = win || check_string_for_win(@last_player, get_neighbors(@last_move, @last_player, 0, 1))
    win = win || check_string_for_win(@last_player, get_neighbors(@last_move, @last_player, 1, 0))
    win = win || check_string_for_win(@last_player, get_neighbors(@last_move, @last_player, -1, 1))
    win = win || check_string_for_win(@last_player, get_neighbors(@last_move, @last_player, 1, -1))
    win = win || check_string_for_win(@last_player, get_neighbors(@last_move, @last_player, -1, -1))
    return win
  end

  def get_available_moves
    coord_array = Array.new
    (1..@width).each do |column_number|
      coord_array.push(column_number) if is_column_empty?(column_number)
    end
    return coord_array
  end

  def place_piece(height, width, gamepiece)
    @last_move = {"height" => height, "width" => width}
    @last_player = gamepiece
    @turns += 1
    @board[height][width] = gamepiece
  end

  def make_move(column, gamepiece)
    h = get_height_of_first_empty_location_in_column(column)
    place_piece(h, column-1, gamepiece)
  end

  def get_height_of_first_empty_location_in_column(column)
    # really need to validate this by passing through is_column_empty? first
    (0...@height).each do |height_index|
      if is_location_empty?(@height - height_index-1, column-1)
        return @height - height_index-1
      end
    end
  end

  def is_column_empty?(column)
    if is_location_empty?(0, column-1)
      return true
    else
      return false
    end
  end

  def is_location_empty?(h, w)
    if get_piece(h, w) == DefaultSymbol
      true
    else
      false
    end
  end

  def check_string_for_win(symbol, string)
    if string.include?("#{symbol}#{symbol}#{symbol}#{symbol}")
      return true
    else
      return false
    end
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
