#!/usr/bin/env ruby

# Sudoku solver: ./sudoku.rb filename
# where filename is a file containing a puzzle looking something
# like this.  Whitespace is ignored, comments are "#"  to end of line.
# 1-- 3-- -6-
# 3-7 495 1--
# --- 621 --3
# 
# 6-3 --- 2--
# -48 --- 61-
# --1 --- 9-4
# 
# 7-- 543 ---
# --9 812 7-6
# -2- --9 --1
#
# The Puzzle class may also be used independently by
# require "sudoku"
# puzzle = Puzzle.new(...)

# Having to guess and back out seems wimpy.  Anything can be solved
# that way, given a solution and enough time.  But if there are
# multiple solutions then things come down to that.  But there are
# some other strategies that can be implemenmted which should reduce
# guessing.

class Puzzle
  # filename: optional file to load a setup from
  # setup: a string containing a digit from 1-9 or "-" for each position. 

  def initialize(filename:nil, setup:nil)
    # Note that it's not possible to create the exclusive_positions
    # cross references at the same time we create the Positions, so we
    # have to create the Positions then fill in the cross-references.
    # I'd prefer if @exclusive_positions were immutable, but oh well.

    @positions = (0..80).map do |number|
      Position.new(self, number)
    end

    # Create an ExclusionSet for each row, containing the Positions
    # in the row.

    rows = (0..8).map do |row|
      ExclusionSet.new(
        "row #{row}",
        (0..8).map do |col|
          @positions[row*9 + col]
        end
      )
    end

    # Create an ExclusionSet for each column.

    cols = (0..8).map do |col|
      ExclusionSet.new(
        "column #{col}",
        (0..8).map do |row|
          @positions[row*9 + col]
        end
      )
    end

    # Create an ExclusionSet for each square.

    squares = (0..8).map do |square|
      # row and col of upper left corner of square
      row = square / 3 * 3
      col = square % 3 * 3
      ExclusionSet.new(
        "square #{square}",
        (0..8).map do |n|
          @positions[(row + n/3)*9 + (col + n%3)]
        end
      )
    end

    @exclusion_sets = rows + cols + squares

    # Set each Position's exclusive_positions to an Array of all the
    # other Positions either in the same row, column, or square.  If
    # we place a number in this Position, we can't place the same
    # number in any of these other Positions.  Note that this list may
    # contain duplicates but that doesn't matter.

    @positions.each do |position|
      position.set_exclusive_positions(
        @exclusion_sets.select do |set|
          set.include?(position)
        end.flat_map do |set|
          set.positions
        end - [position]
      )
    end

    # Within a square, if the only possible places for a given digit
    # are in the same row/col, then the digit can be removed from the
    # possibilities for the rest of the Positions in that row/col.
    #
    # The reverse of the situation is also true.  In a given row or
    # column if it is only possible to place a given digit within a
    # single square, then the digit can be eliminated from the other
    # Positions of that square.

    @tricky_sets = (rows + cols).product(squares).flat_map do |row, square|
      common = row.positions & square.positions
      if !common.empty?
        # Each Array in @tricky_sets contains three ExclusionSets.  If
        # a digit is possible in the first set but not the second, it
        # will be set to "not possible" in the third.
        [
          [common, square.positions - common, row.positions - common],
          [common, row.positions - common, square.positions - common]
        ]
      else
        []
      end
    end

    # Set initial pattern.

    if filename
      setup = File.read(filename).gsub(/#.*/, "").gsub(/\s/, "")
    end

    setup.each_char.zip(@positions) do |c, position|
      if c != "-"
        puts "placing initial #{c} in position #{position.number}"
        position.place(c.to_i)
      end
    end
  end

  def place_one_missing
    # Try to place a digit where there is only one Position in the set
    # where it can possibly go, and return true if a digit was placed.
    # This is pretty inefficient since it has to look through all the
    # digits and positions repeatedly but so what.
    (1..9).any? do |digit|
      @exclusion_sets.any? do |set|
        # Does the set contain only one position that allows the digit?
        positions_for_digit = set.possible_positions(digit)
        if positions_for_digit.size == 1
          puts "placing missing #{digit} from #{set} in position #{positions_for_digit.first.number}"
          #puts set.map{|x| x.number}.to_s
          print_puzzle
  
          positions_for_digit.first.place(digit)
          true
        end
      end
    end
  end

  def place_one_forced
    @positions.any? do |position|
      if !position.placed && position.possible.size == 1
        puts "placing forced #{position.possible.first} in position #{position.number}"
        print_puzzle
        position.place(position.possible.first)
        true
      end
    end
  end

  # Passes each solved Puzzle to the yielder.

  def solve(yielder)
    # In order to come up with a sequence somewhat like a person would, we
    # preferentially try to place missing digits, then forced digits, and
    # if we can't do either we run the tricky sets elimination.  This doesn't
    # actually end up doing things like I would though.  Oh well.

    while place_one_missing || place_one_forced || eliminate_with_tricky_sets
    end

    # We get here either because we're done, we've failed, or we have
    # to guess and recurse.  We can distinguish by examining the
    # position with the fewest possibilities remaining.  Note that if
    # there is a Position with only one possibility then
    # place_one_forced would already have placed a digit there.

    next_position = @positions.min_by do |position|
      if position.placed?
        10
      else
        position.possible.size
      end
    end

    case
    when next_position.placed?
      # Solved.  Yield self as a solution.
      puts "Solved:"
      print_puzzle
      yielder << self
    when next_position.possible.empty?
      # Failed.  No solution to return.
      puts "Backing out."
    else
      # Found an unplaced position with possibilities.  Guess each
      # possibility recursively, and yield any solutions we find.
      next_position.possible.each do |digit|
        puts "trying #{digit} in position #{next_position.number} #{next_position.possible}"
        puzzle = Puzzle.new(setup: to_string)
        puzzle.position(next_position.number).place(digit)
        puzzle.solve(yielder)
      end
    end
  end

  def eliminate_with_tricky_sets
    @tricky_sets.any? do |subset, rest_of_set, elimination_set|
      subset.flat_map do |position|
        if position.placed?
          []
        else
          position.possible
        end
      end.uniq.select do |digit|
        !rest_of_set.any?{|position| position.possible?(digit)}
      end.any? do |digit|
        elimination_set.any? do |position|
          if position.possible?(digit)
            puts "eliminating #{digit} from position #{position.number}"
            position.not_possible(digit)
            true
          end
        end
      end
    end
  end

  def position(number)
    @positions[number]
  end

  def print_puzzle
    to_string.each_char.each_slice(27) do |rows|
      rows.each_slice(9) do |row|
        row.each_slice(3) do |digits|
          print digits.join("") + " "
        end
        puts
      end
      puts
    end
  end

  def to_string
    @positions.map do |position|
      position.placed? ? position.placed.to_s : "-"
    end.join("")
  end
end

# Each position in the Puzzle gets a Position which remembers the
# number we've placed in this Position and some other book-keeping
# information like which numbers are possible to put here, i.e., have
# not been eliminated by previous placements.

class Position
  def initialize(puzzle, number)
    # Remember our containing puzzle, for output.
    @puzzle = puzzle
    # The ordinal number of this Position.
    @number = number
    # The possible digits this Position may contain.
    @possible = [1,2,3,4,5,6,7,8,9]
    # The digit finally placed in this position.
    @placed = nil
    # Array of all Positions in the same row, col, or square as this Position.
    @exclusive_positions = nil
  end

  def inspect
    "#{@number}: #{@possible.to_s}"
  end

  def place(digit)
    @placed = digit
    @possible = [digit]
    @exclusive_positions.each do |position|
      position.not_possible(digit)
    end
  end

  def possible
    @possible
  end

  def possible?(digit)
    @possible.include?(digit)
  end

  def number
    @number
  end

  def placed
    @placed
  end

  def placed?
    !@placed.nil?
  end

  def not_possible(digit)
    @possible.delete(digit)
  end

  def set_exclusive_positions(exclusive_positions)
    @exclusive_positions = exclusive_positions;
  end
end

# An ExclusionSet has a name so it can be identified for printing
# messages, and an Array of Positions that are all in the same row,
# column, or square.

class ExclusionSet
  def initialize(name, positions)
    @name = name
    @positions = positions
  end

  def to_s
    @name
  end

  def include?(position)
    @positions.include?(position)
  end

  def possible_positions(digit)
    @positions.select do |position|
      !position.placed? && position.possible?(digit)
    end
  end

  def positions
    @positions
  end
end

if __FILE__ == $0
  count = Enumerator.new do |yielder|
    Puzzle.new(filename: ARGV[0]).solve(yielder)
  end.to_a.size
  puts "#{count} solutions"
end
