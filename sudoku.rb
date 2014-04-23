#!/usr/bin/env ruby

class Slot
  def initialize(number)
    # The ordinal number of this Slot.
    @number = number
    # The possible digits this Slot may contain.
    @possible = [1,2,3,4,5,6,7,8,9]
    # The digit finally placed in this slot.
    @placed = nil
    # Array of all Slots in the same row, col, or square as this Slot.
    @exclusive = nil
    # Array of all Slots, for output.
    @slots = nil
  end

  def inspect
    "#{@number}: #{@possible.to_s}"
  end

  def place(digit)
    @placed = digit
    @possible = [digit]
    @exclusive.each do |slot|
      slot.not_possible(digit)
    end
  end

  def possible
    @possible
  end

  def number  # debug
    @number
  end

  def placed
    @placed
  end

  def not_possible(digit)
    if @possible.delete(digit) && @possible.size == 1
      puts "placing forced #{@possible.first} in slot #{@number}"
      dump
      place(@possible.first)
    end
  end

  def dump
    @slots.each_slice(27) do |rows|
      rows.each_slice(9) do |row|
        row.each_slice(3) do |slots|
          slots.each do |slot|
            if slot.placed
              print slot.placed
            else
              print "-"
            end
          end
          print " "
        end
        puts
      end
      puts
    end
  end

  def make_exclusive(slots)
    @exclusive = same_row(@number, slots) +
      same_col(@number, slots) +
      same_square(@number, slots) -
      [self]
    @slots = slots
  end

  def same_row(number, slots)
    row = number / 9
    (0..8).map do |col|
      slots[row*9 + col]
    end
  end

  def same_col(number, slots)
    col = number % 9
    (0..8).map do |row|
      slots[row*9 + col]
    end
  end

  def same_square(number, slots)
    # row and col of upper left corner of containing square
    row = number / 9 / 3 * 3
    col = number % 9 / 3 * 3
    (0..8).map do |n|
      slots[(row + n/3)*9 + (col + n%3)]
    end
  end
end

slots = (0..80).map do |number|
  Slot.new(number)
end

slots.each do |slot|
  slot.make_exclusive(slots)
end

# Each slot goes into a row, col, and square.

rows = (0..8).map do |row|
  (0..8).map do |col|
    slots[row*9 + col]
  end
end

cols = (0..8).map do |col|
  (0..8).map do |row|
    slots[row*9 + col]
  end
end

squares = (0..8).map do |square|
  # row and col of upper left corner of square
  row = square / 3 * 3
  col = square % 3 * 3
  (0..8).map do |n|
    slots[(row + n/3)*9 + (col + n%3)]
  end
end

sets = rows + cols + squares

# Set initial pattern.

File.read(ARGV[0]).gsub(/\s/, "").each_char.zip(slots) do |c, slot|
  if c != "-"
    puts "placing initial #{c} in slot #{slot.number}"
    slot.place(c.to_i)
  end
end

while (sets.find do |set|
  # Try to place a digit where a set is missing a single digit, and return
  # true if a digit was placed.
  (1..9).find do |digit|
    # Does the set contain only one slot that allows the digit?
    slots_for_digit = set.select do |slot|
      slot.placed.nil? && slot.possible.any?{|x| x == digit}
    end
    if slots_for_digit.size == 1

      puts "placing missing #{digit} in slot #{slots_for_digit.first.number}"
      #puts set.map{|x| x.number}.to_s
      slots.first.dump

      slots_for_digit.first.place(digit)
      true
    end
  end
end) do
end

# Print the output.

slots.each_slice(27) do |rows|
  rows.each_slice(9) do |row|
    row.each_slice(3) do |slots|
      slots.each do |slot|
        if slot.placed
          print slot.placed
        else
          print "-"
        end
      end
      print " "
    end
    puts
  end
  puts
end
