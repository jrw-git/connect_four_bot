class PlayerHuman

  attr_reader :player, :piece

  def initialize(player_type, symbol)
    @player_type = player_type
    @piece = symbol
  end

  def make_a_move(board)
    begin
      puts "Enter number from 1 to 7 to put a piece in that column: "
      print "Please enter your move, or enter 'q' to quit: "
      input = $stdin.gets.chomp
      selected_column = input.to_i
      if input == 'q'
        exit
      end
    end until (board.is_column_empty?(selected_column) && (selected_column > 0) && (selected_column < 8))
    #board.place_piece_in_column(selected_column, @piece)
    return selected_column
  end

  def to_s
    @player_type
  end

end
