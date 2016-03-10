
require_relative "node"

module NegamaxAnalysis

  @@enable_killer_moves = true
  @@try_board_dup = true

  # CURRENTLY DEPENDS ON PARENT FUNCTION swap_pieces(current_player)

  # try_board_dup is for optimization testing
  # toggles a change between duping a board then discarding it when done
  # vs making a move, then unmaking a move, on the original board

  # depends on a BUNCH of parent variables....

  def check_board_for_final_square_value(board, active_piece, depth)
    if board.is_there_a_win?
      # if there's a win, return a value of -1,
      # which gets flipped by the negamax recursion so that the
      # player calling it sees a positive 1 for a winning board
      return  @value_of_win
    elsif board.is_there_a_tie?
      return @value_of_tie
    end
    if depth <= 0
      # heurisitics would be calculated here
      return @value_of_tie
      #return @value_of_unknown
    end
    return nil
  end

  def negamax(board, active_piece, depth, alpha, beta)
    @recursion_counter += 1
    start_time = Time.now
    # win/tie check, return a value if found
    result = check_board_for_final_square_value(board, active_piece, depth)
    return result unless result == nil
    new_best_move = @lowest_score
    list_of_moves = board.get_available_moves
    # move sorting
    sort_moves(list_of_moves, depth) if true
    # iterate over possible moves and get their values (down to depth limit)
    list_of_moves.each do |move|
      trial_move_board = nil
      trial_move_board = board.dup if @@try_board_dup
      trial_move_board = board if !@@try_board_dup
      trial_move_board.make_move(move, active_piece)
      subtree_best = -negamax(trial_move_board, swap_pieces(active_piece), depth-1, -beta, -alpha)
      trial_move_board.undo_move(move, active_piece) if !@@try_board_dup
      # CRAZY !@#$%^&* BUG IF I USED SPACESHIP OPERATOR TO COMPARE NODES DIRECTLY....
      # kept insisting that the "other" was a nil object.
      # switching to comparing values directly
      # seriously spent hours on this !@#$%^&* bug
      # looks like if you include any nil items in the data structure, the <=> goes bonkers
      if subtree_best.value > new_best_move.value
        new_best_move = Node.new(move, subtree_best.value/2.0, subtree_best.depth+1, subtree_best)
      end
      # alpha beta
      if new_best_move.value >= beta.value
        @killer_moves[depth] = new_best_move if @@enable_killer_moves
        break
      end
      if new_best_move.value > alpha.value
        alpha = new_best_move
      end
    end
    return new_best_move
  end

  def sort_moves(list_of_moves, depth)
    if list_of_moves.delete(2)
      list_of_moves.unshift(2)
    end
    if list_of_moves.delete(6)
      list_of_moves.unshift(6)
    end
    if list_of_moves.delete(3)
      list_of_moves.unshift(3)
    end
    if list_of_moves.delete(5)
      list_of_moves.unshift(5)
    end
    if list_of_moves.delete(4)
      list_of_moves.unshift(4)
    end
    if @killer_moves[depth] != nil && @@enable_killer_moves
      possible_move = @killer_moves[depth]
      #puts "PossMove:#{possible_move}, killer moves:#{@killer_moves}"
      if list_of_moves.include?(possible_move.move)
        list_of_moves.delete(possible_move.move)
        list_of_moves.unshift(possible_move.move)
      end
    end
    return list_of_moves
  end

end
