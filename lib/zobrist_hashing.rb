
class ZobristHash

  @@height = 6
  @@width = 7

  @@max_range = 107374182300
  #@@max_range = 100
  @@first_time_through = false

  def initialize
    @zobrist_table = generate_zobrist_hash_table(@@height,@@width, @@max_range)
  end

  def generate_zobrist_hash_table(height, width, range)
    rng = Random.new
    zobrist_hash = Array.new(2) { Array.new(height) { Array.new(width) { rng.rand(range) } } }
    return zobrist_hash
  end

  def hash_entire_board(board)
    hash = 0
    board.each_index do |h|
      board[h].each_index do |w|
        if board[h][w] == '1'
          hash = hash ^ @zobrist_table[0][h][w]
        elsif board[h][w] == '2'
          hash = hash ^ @zobrist_table[1][h][w]
        end
      end
    end
    return hash
  end

  def hash_position_with_board(hash, height, width, piece, board)
    if piece == '1'
      hash ^= @zobrist_table[0][height][width]
    elsif piece == '2'
      hash ^= @zobrist_table[1][height][width]
    end
    return hash
  end

end
