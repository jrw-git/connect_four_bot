#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# bot for theaigames.com
# connect 4
# written by John White 2016

#require_relative "./lib/connect_four_engine"
#require "./lib/connect_four_gameboard"
require_relative "lib/connect_four_gameboard"
#require "./lib/node"
require_relative "lib/node"
#require "./lib/ai_player"
require_relative "lib/ai_player"

STDOUT.sync = true

class BotParser

  def initialize
    # set up engine
    @settings = Hash.new
  end

  def run
    # look for commands from the server
    while !$stdin.closed?
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
          @search_limit = 0.7 #seconds
          #@search_limit = 120 #seconds
          @aigames_io = true
          @brain = "Mixed"
          @bot_id = @settings["your_botid"]
          @bot_name = "AI:#{@brain}-#{@search_limit}-#{@bot_id}."
          @our_bot = Player.new(@bot_name, @bot_id, @brain, @search_limit, @aigames_io)
          $stderr.puts "Bot name: #{@bot_name}, ID: #{@bot_id}"
          $stderr.puts @our_bot
        end
      when "update" # don't forget the "game" in the instruction line
        # update game round 1
        # update game field 0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0;0,0,0,0,0,0,0
        case instruction_array[2]
        when "round"
          @turn = instruction_array[3]
        when "field"
          new_field = GameBoard.process_string_into_board(instruction_array[3], @bot_id, @turn)
          @our_gameboard = GameBoard.new(@settings["field_rows"], @settings["field_columns"], @bot_id, @turn, new_field)
        else
          $stderr.puts "ERROR: Unknown update detected: #{instruction_array}"
        end
      when "action"
        # action move 10000   (10000 is timeleft)
        @time_left = instruction_array[2]
        @our_move = @our_bot.make_a_move(@our_gameboard) - 1
        $stdout.puts("place_disc #{@our_move}")
      else
        $stderr.puts "ERROR: Unknown instruction detected: #{instruction_array}"
      end
    end
  end
end

if __FILE__ == $0
  new_bot_parser = BotParser.new
  new_bot_parser.run
end
