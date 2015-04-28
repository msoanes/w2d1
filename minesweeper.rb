# track time
# track best time

require 'colorize'
require 'yaml'

class Board
  attr_reader :board

  def initialize
    @board = Array.new(9) { Array.new(9) }
    @board.each.with_index do |row, y|
      row.map!.with_index { |pos, x| Tile.new({board: self, coordinates: [x,y]}) }
    end
    seed_bombs
  end

  def [](y)
    @board[y]
  end

  def length
    @board.length
  end

  def seed_bombs
    results = []
    until results.length == 10
      x = rand(length)
      y = rand(length)
      unless results.include?([x,y])
        results << [x,y]
        @board[x][y].set_bomb
      end
    end
  end

  def won?
    @board.all? do |row|
      row.all? { |tile| tile.bombed? || tile.revealed? }
    end
  end

end

class Tile
  attr_reader :coordinates

  NEIGHBOR_CHANGES = [
    [0, 1],
    [0, -1],
    [1, 0],
    [1, 1],
    [1, -1],
    [-1, 0],
    [-1, 1],
    [-1, -1]
  ]

  def initialize(options)
    @coordinates = options[:coordinates]
    @board = options[:board]
    @bombed = false
    @flagged = false
    @revealed = false
  end

  def bombed?
    @bombed
  end

  def flagged?
    @flagged
  end

  def toggle_flag
    @flagged = !@flagged
  end

  def neighbors
    neighbor_coordinates = NEIGHBOR_CHANGES.map do |change|
      [@coordinates.last + change.first, @coordinates.first + change.last]
    end

    invalid = Proc.new do |coordinates|
      coordinates.any? { |coord| coord < 0 || coord >= @board.length }
    end

    neighbor_coordinates.reject!(&invalid)
    neighbor_coordinates.map do |coordinate|
      @board[coordinate.first][coordinate.last]
    end
  end

  def neighbors_bomb_count
    neighbors.count { |tile| tile.bombed? }
  end

  def revealed?
    @revealed
  end

  def reveal
    return nil if self.revealed? || self.flagged?
    @revealed = true
    neighbors.each(&:reveal) if neighbors_bomb_count == 0
  end

  def set_bomb
    @bombed = true
  end

  def symbol
    symbol_hash = Hash.new { :red }
    symbol_hash.merge!({ 1 => :blue, 2 => :green })
    return 'F'.yellow if flagged?
    return '*' unless revealed?
    return '_' if neighbors_bomb_count == 0
    n_count = neighbors_bomb_count
    n_count.to_s.send(symbol_hash[n_count])
  end

  def inspect
    "Coords: #{@coordinates},\n  Bombed: #{bombed?},\n  Flagged: #{flagged?},\n  Revealed: #{revealed?},\n  Neighbor bomb count: #{neighbors_bomb_count}."
  end
end

class Game
  MOVE_PROMPT = "Select 'r' for reveal, 'f' to toggle flag,\nand enter the column and row of the tile you want."
  SAVED_FILE = 'minesweeper_save.yml'

  def initialize(board = nil)
    @start_time = Time.now
    @current_time = Time.now
    @board = board
    @board ||= Board.new
    @game_over = false
  end

  def run
    until @game_over || @board.won? || @quit
      render_board
      choice, coords = move
      case choice
      when :q
        @quit = true
      when :s
        save
      when :r
        reveal(coords)
      when :f
        flag(coords)
      end
    end

    if @game_over
      game_over
    elsif @board.won?
      won
    else
      puts "Quitter.".red
    end
  end

  def elapsed_time
    @current_time = Time.now
    "#{(@current_time - @start_time).round(1)} seconds elapsed".green
  end

  def render_board
    @board.board.each do |row|
      rendered_row = row.map do |tile|
        tile.symbol
      end
      puts rendered_row.join(' ')
    end

    puts ''
    puts elapsed_time
  end

  def move
    choice = nil
    coords = nil
    until valid_move?(choice, coords)
      move_string = prompt(MOVE_PROMPT)
      choice, row_char, column_char = move_string.split(/[,\s]*/)

      choice = choice.downcase.to_sym
      coords = [column_char.to_i - 1, row_char.to_i - 1]
    end
    [choice, coords]
  end

  def valid_move?(choice, coords)
    return true if [:q, :s].include?(choice)
    return true if valid_coords?(coords) && [:f, :r].include?(choice)
    false
  end

  def valid_coords?(coords)
    return false if coords.nil?
    return false if coords.length != 2
    within_range = Proc.new { |coord| (0...@board.length).include?(coord) }
    return false unless coords.all?(&within_range)
    true
  end

  def prompt(prompt_string)
    puts prompt_string
    print "> "
    gets.chomp
  end

  def get_tile(coords)
    @board.board[@board.length - 1 - coords.first][coords.last]
  end

  def reveal(coords)
    tile = get_tile(coords)
    if tile.bombed?
      @game_over = true
    else
      tile.reveal
    end
  end

  def flag(coords)
    tile = get_tile(coords)
    tile.toggle_flag unless tile.revealed?
  end

  def game_over
    puts "Hooray! You exploded with excitement! But you lost.".green
    File.delete(SAVED_FILE) if File.exist?(SAVED_FILE)
  end

  def save
    @current_time = Time.now
    File.open(SAVED_FILE, 'w') do |f|
      f.puts self.to_yaml
    end
    puts "Game saved.".green
    puts "Do you want to quit? Y/N"
    print "> "
    @quit = gets.chomp.downcase == 'y'
  end

  def won
    puts "You managed to avoid being scattered across the game board. Congrats.".yellow
    File.delete(SAVED_FILE) if File.exist?(SAVED_FILE)
  end
end

if __FILE__ == $PROGRAM_NAME
  if File.exist?(Game::SAVED_FILE)
    game = YAML.load_file(Game::SAVED_FILE)
  else
    game = Game.new
  end
  game.run
end
