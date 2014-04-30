#!/usr/bin/env ruby

# Having to guess and back out seems wimpy.  Anything can be solved
# that way, given a solution and enough time.  But if there are
# multiple solutions then things may coe down to that.  But there are
# some other strategies that can be implemenmted which should reduce
# guessing.

# For example: within a square, if the only possible places for a
# given digit are in the same row, then the digit can be removed from
# the possibilities for the rest of the Slots in that row.
#
# The reverse of the situation is also true.  In a given row or column if it
# is only possible to place a given digit within a single square, then the
# digit can be eliminated from the other Slots of that square.

class Puzzle
  def initialize(filename)
    # Note that it's not possible to create the exclusive_with crosss
    # references at the same time we create the Slots, so we have to
    # create the Slots then fill in the cross-references.  I'd prefer
    # if @exclusive_with were immutable, but oh well.

    @slots = (0..80).map do |number|
      Slot.new(self, number)
    end

    @slots.each do |slot|
      slot.make_exclusive_with
    end

    # Each slot goes into a row, col, and square.

    rows = (0..8).map do |row|
      (0..8).map do |col|
        @slots[row*9 + col]
      end
    end

    cols = (0..8).map do |col|
      (0..8).map do |row|
        @slots[row*9 + col]
      end
    end

    squares = (0..8).map do |square|
      # row and col of upper left corner of square
      row = square / 3 * 3
      col = square % 3 * 3
      (0..8).map do |n|
        @slots[(row + n/3)*9 + (col + n%3)]
      end
    end

    @sets = rows + cols + squares

    # Set initial pattern.

    File.read(filename).gsub(/#.*/, "").gsub(/\s/, "").each_char.zip(@slots) do |c, slot|
      if c != "-"
        puts "placing initial #{c} in slot #{slot.number}"
        slot.place(c.to_i)
      end
    end
  end

  def solve
    while (@sets.any? do |set|
      # Try to place a digit where there is only one Slot in the set where
      # it can possibly go, and return true if a digit was placed.
      (1..9).any? do |digit|
        # Does the set contain only one slot that allows the digit?
        slots_for_digit = set.select do |slot|
          !slot.placed? && slot.possible?(digit)
        end
        if slots_for_digit.size == 1
          puts "placing missing #{digit} in slot #{slots_for_digit.first.number}"
          #puts set.map{|x| x.number}.to_s
          print_puzzle

          slots_for_digit.first.place(digit)
          true
        end
      end
    end) do
    end

    # Find the slot with the fewest possibilities remaining.

    next_slot = @slots.min_by do |slot|
      if slot.placed?
        10
      else
        slot.possible.size
      end
    end

    # Did we find an empty slot with possibilities?  If so, try all
    # the possibilities.

    case
    when next_slot.possible.size == 0
      # Failed.
      puts "Backing out."
    when next_slot.placed?
      # Print the solved puzzle.
      puts "Solved:"
      print_puzzle
    else
      # Found an empty slot with possibilities.  Try each one.
      next_slot.possible.each do |digit|
        puts "trying #{digit} in slot #{next_slot.number}"
        puzzle = Marshal.load(Marshal.dump(self))
        puzzle.slot(next_slot.number).place(digit)
        puzzle.solve
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
    @exclusive_with = nil
  end

  def inspect
    "#{@number}: #{@possible.to_s}"
  end

  def place(digit)
    @placed = digit
    @possible = [digit]
    @exclusive_with.each do |slot|
      slot.not_possible(digit)
    end

    # This is efficient but not necessary.  The "missing" strategy will
    # pick these up since there's only one place in a set to put the
    # missing digit.

    false && @exclusive_with.each do |slot|
      if !slot.placed? && slot.possible.size == 1
        puts "placing forced #{slot.possible.first} in slot #{slot.number}"
        @puzzle.print_puzzle
        slot.place(slot.possible.first)
      end
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

  def make_exclusive_with
    @exclusive_with = same_row + same_col + same_square - [self]
  end

  def same_row
    row = @number / 9
    (0..8).map do |col|
      @puzzle.slot(row*9 + col)
    end
  end

  def same_col
    col = @number % 9
    (0..8).map do |row|
      @puzzle.slot(row*9 + col)
    end
  end

  def same_square
    # row and col of upper left corner of containing square
    row = @number / 9 / 3 * 3
    col = @number % 9 / 3 * 3
    (0..8).map do |n|
      @puzzle.slot((row + n/3)*9 + (col + n%3))
    end
  end
end

Puzzle.new(ARGV[0]).solve
