#!/usr/bin/env ruby

require "set"

class Slot
  def initialize(number)
    @number = number
    @possible = [1,2,3,4,5,6,7,8,9]
    @sets = nil
  end

  def place(digit, dirty)
    # puts "placing #{digit} in slot #{@number}"
    @sets.each do |slot|
      slot.not_possible(digit, dirty)
    end
    @possible = [digit]
    dirty.delete(self)
  end

  def possible
    @possible
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

slots.each do |slot|
  slot.make_sets(slots)
end

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

while !dirty.empty?
  slot = dirty.first
  if slot.possible.size == 1
    slot.place(slot.possible.first, dirty)
  end
  dirty.delete(slot)
end

slots.each_slice(27) do |rows|
  rows.each_slice(9) do |row|
    row.each_slice(3) do |slots|
      slots.each do |slot|
        if slot.possible.size == 1
          print slot.possible.first
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
