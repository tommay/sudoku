#!/usr/bin/env ruby

require "set"

class Slot
  def initialize(number)
    @number = number
    @possible = [1,2,3,4,5,6,7,8,9]
    @placed = nil
    @sets = nil
  end

  def inspect
    "#{@number}: #{@possible.to_s}"
  end

  def place(digit, dirty)
    @sets.each do |slot|
      slot.not_possible(digit, dirty)
    end
    @possible = [digit]
    @placed = digit
    dirty.delete(self)
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

  def not_possible(digit, dirty)
    if @possible.delete(digit)
      dirty.add(self)
    end
  end

  def make_sets(slots)
    @sets = same_row(@number, slots) +
      same_col(@number, slots) +
      same_square(@number, slots)
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

$slots = slots # debug

slots.each do |slot|
  slot.make_sets(slots)
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

dirty = Set.new

# Set initial pattern.

File.open(ARGV[0], "r") do |file|
  slot = 0
  file.each do |line|
    line.gsub(/\s/, "").each_char do |c|
      if c != "-"
        slots[slot].place(c.to_i, dirty)
      end
      slot += 1
    end
  end
end

def dump
        $slots.each_slice(27) do |rows|
          rows.each_slice(9) do |row|
            row.each_slice(3) do |slots|
              slots.each do |xslot|
                if xslot.placed
                  print xslot.placed
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

begin
  # Place all the digits in slots that have only one possible digit.

  while !dirty.empty?
    slot = dirty.first
    if slot.possible.size == 1
      puts "placing forced #{slot.possible.first} in slot #{slot.number}"
      dump
      slot.place(slot.possible.first, dirty)
    end
    dirty.delete(slot)
  end
end while sets.find do |set|
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
      dump

      slots_for_digit.first.place(digit, dirty)
      true
    end
  end
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
