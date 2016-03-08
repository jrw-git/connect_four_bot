#!/usr/bin/env ruby

# bot for theaigames.com
# connect 4
# written by John White 2016

#require_relative "./lib/connect_four_engine"
require_relative "./lib/connect_four_gameboard"
require_relative "./lib/node"
require_relative "./lib/ai_player"

class BotParser

  def initialize
    # set up engine
    @settings = Hash.new
  end

  def process_field_into_board(field)
    board_array = field.split(";")
    board = board_array.map { |string| string.split(",") }
    return board
  end

  def run
    # look for commands from the server
    while true
      next_line = $stdin.readline
      # skip to next iteration unless we get a line
      next unless next_line
      # clear some formatting
      instruction_array = next_line.strip.split
      instruction = instruction_array[0]
      case instruction
      when "settings"
        # timebank, time_per_move, player_names, your_bot, your_botid, field_columns, field_rows
        # 10000        500       player1,player2   player1   1        7    6
        @settings[instruction_array[1]] = instruction_array[2]
        if instruction_array[1] == "your_botid"
          bot_name = "AI-Monte-Carlo:#{@settings["your_bot"]}"
          time_limit = 0.5 #seconds
          use_deep_iteration = false
          monte_carlo = true
          use_aigames_interface = true
          @our_bot = Player.new(bot_name, @settings["your_botid"], time_limit, use_deep_iteration, monte_carlo, use_aigames_interface)
          $stderr.puts @our_bot.inspect
        end
      when "update"
        # THE SECOND THING FOUND IS GAME!!
        # CANNOT JUST JUMP RIGHT INTO ARRAY[1]
        # update game round 1
        # update game field 0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0
        case instruction_array[2]
        when "round"
          @turn = instruction_array[3]
        when "field"
          $stderr.puts "Field processed, round #{@turn}, field: #{instruction_array[3]}"
          new_field = process_field_into_board(instruction_array[3])
          @our_gameboard = GameBoard.new(@settings["field_rows"], @settings["field_columns"], @settings["your_botid"], @turn, new_field)
          #@our_gameboard.print_me
          # need to give the board to something... nah made it an instance var
        else
          $stderr.puts "ERROR: Unknown update detected: #{instruction_array}"
        end
      when "action"
        # action move 10000   (10000 is timeleft)
        @time_left = instruction_array[2]
        @our_move = @our_bot.make_a_move(@our_gameboard)
        $stdout.puts("place_disc #{@our_move}")
      else
        $stderr.puts "ERROR: Unknown action detected: #{instruction_array}"
      end
    end
  end

end

new_bot_parser = BotParser.new
new_bot_parser.run
