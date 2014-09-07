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
    # Note that it's not possible to create the exclusive_slots cross
    # references at the same time we create the Slots, so we have to
    # create the Slots then fill in the cross-references.  I'd prefer
    # if @exclusive_slots were immutable, but oh well.

    @slots = (0..80).map do |number|
      Slot.new(self, number)
    end

    # Create an ExclusionSet for each row, containing the Slots
    # in the row.

    rows = (0..8).map do |row|
      ExclusionSet.new(
        "row #{row}",
        (0..8).map do |col|
          @slots[row*9 + col]
        end
      )
    end

    # Create an ExclusionSet for each column.

    cols = (0..8).map do |col|
      ExclusionSet.new(
        "column #{col}",
        (0..8).map do |row|
          @slots[row*9 + col]
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
          @slots[(row + n/3)*9 + (col + n%3)]
        end
      )
    end

    @exclusion_sets = rows + cols + squares

    @slots.each do |slot|
      slot.make_exclusive_slots(@exclusion_sets)
    end

    # Within a square, if the only possible places for a given digit
    # are in the same row/col, then the digit can be removed from the
    # possibilities for the rest of the Slots in that row/col.
    #
    # The reverse of the situation is also true.  In a given row or
    # column if it is only possible to place a given digit within a
    # single square, then the digit can be eliminated from the other
    # Slots of that square.

    @tricky_sets = (rows + cols).product(squares).flat_map do |row, square|
      common = row.slots & square.slots
      if !common.empty?
        # Each Array in @tricky_sets contains three ExclusionSets.  If
        # a digit is possible in the first set but not the second, it
        # will be set to "not possible" in the third.
        [
          [common, square.slots - common, row.slots - common],
          [common, row.slots - common, square.slots - common]
        ]
      else
        []
      end
    end

    # Set initial pattern.

    if filename
      setup = File.read(filename).gsub(/#.*/, "").gsub(/\s/, "")
    end

    setup.each_char.zip(@slots) do |c, slot|
      if c != "-"
        puts "placing initial #{c} in slot #{slot.number}"
        slot.place(c.to_i)
      end
    end
  end

  def place_one_missing
    # Try to place a digit where there is only one Slot in the set where
    # it can possibly go, and return true if a digit was placed.
    # This is pretty inefficient since it has to look through all the digits
    # and slots repeatedly but so what.
    (1..9).any? do |digit|
      @exclusion_sets.any? do |set|
        # Does the set contain only one slot that allows the digit?
        slots_for_digit = set.possible_slots(digit)
        if slots_for_digit.size == 1
          puts "placing missing #{digit} from #{set} in slot #{slots_for_digit.first.number}"
          #puts set.map{|x| x.number}.to_s
          print_puzzle
  
          slots_for_digit.first.place(digit)
          true
        end
      end
    end
  end

  def place_one_forced
    @slots.any? do |slot|
      if !slot.placed && slot.possible.size == 1
        puts "placing forced #{slot.possible.first} in slot #{slot.number}"
        print_puzzle
        slot.place(slot.possible.first)
        true
      end
    end
  end

  # Returns an Array of solved Puzzles.

  def solve
    # In order to come up with a sequence somewhat like a person would, we
    # preferentially try to place missing digits, then forced digits, and
    # if we can't do either we run the tricky sets elimination.  This doesn't
    # actually end up doing things like I would though.  Oh well.

    while place_one_missing || place_one_forced || eliminate_with_tricky_sets
    end

    # Find the Slot with the fewest possibilities remaining.

    next_slot = @slots.min_by do |slot|
      if slot.placed?
        10
      else
        slot.possible.size
      end
    end

    # Did we find an empty Slot with possibilities?  If so, try all
    # the possibilities.

    case
    when next_slot.possible.size == 0
      # Failed.
      puts "Backing out."
      []
    when next_slot.placed?
      # Print the solved puzzle.
      puts "Solved:"
      print_puzzle
      [self]
    else
      # Found an empty slot with possibilities.  Try each one recursively.
      next_slot.possible.flat_map do |digit|
        puts "trying #{digit} in slot #{next_slot.number} #{next_slot.possible}"
        puzzle = Marshal.load(Marshal.dump(self))
        puzzle.slot(next_slot.number).place(digit)
        puzzle.solve
      end
    end
  end

  def eliminate_with_tricky_sets
    @tricky_sets.any? do |subset, rest_of_set, elimination_set|
      subset.flat_map do |slot|
        if slot.placed?
          []
        else
          slot.possible
        end
      end.uniq.select do |digit|
        !rest_of_set.any?{|slot| slot.possible?(digit)}
      end.any? do |digit|
        elimination_set.any? do |slot|
          if slot.possible?(digit)
            puts "eliminating #{digit} from slot #{slot.number}"
            slot.not_possible(digit)
            true
          end
        end
      end
    end
  end

  def slot(number)
    @slots[number]
  end

  def print_puzzle
    @slots.each_slice(27) do |rows|
      rows.each_slice(9) do |row|
        row.each_slice(3) do |slots|
          slots.each do |slot|
            print slot.placed || "-"
          end
          print " "
        end
        puts
      end
      puts
    end
  end
end

# Each position in the Puzzle gets a Slot which remembers the number
# we've placed in this Slot and some other book-keeping information
# like which numbers are possible to put here, i.e., have not been
# eliminated by previous placements.

class Slot
  def initialize(puzzle, number)
    # Remember our containing puzzle, for output.
    @puzzle = puzzle
    # The ordinal number of this Slot.
    @number = number
    # The possible digits this Slot may contain.
    @possible = [1,2,3,4,5,6,7,8,9]
    # The digit finally placed in this slot.
    @placed = nil
    # Array of all Slots in the same row, col, or square as this Slot.
    @exclusive_slots = nil
  end

  def inspect
    "#{@number}: #{@possible.to_s}"
  end

  def place(digit)
    @placed = digit
    @possible = [digit]
    @exclusive_slots.each do |slot|
      slot.not_possible(digit)
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

  # Set @exclusive_slots to an Array of all the other Slots either in
  # the same row, column, or square.  If we place a number in this
  # Slot, we can't place the same number in any of these other Slots.
  # Note that this list may contain duplicates but that doesn't
  # matter.

  def make_exclusive_slots(exclusion_sets)
    @exclusive_slots = exclusion_sets.select do |set|
      set.include?(self)
    end.flat_map do |set|
      set.slots
    end - [self]
  end
end

# An ExclusionSet has a name so it can be identified for printing
# messages, and an Array of Slots that are all in the same row,
# column, or square.

class ExclusionSet
  def initialize(name, slots)
    @name = name
    @slots = slots
  end

  def to_s
    @name
  end

  def include?(slot)
    @slots.include?(slot)
  end

  def possible_slots(digit)
    @slots.select do |slot|
      !slot.placed? && slot.possible?(digit)
    end
  end

  def slots
    @slots
  end
end

if __FILE__ == $0
  puts "#{Puzzle.new(filename: ARGV[0]).solve.size} solutions"
end
