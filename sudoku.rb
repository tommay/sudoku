#!/usr/bin/env ruby

numbers = []

# Each number goes into a row, col, and square.

rows = [[]] * 9
cols = [[]] * 9
squares = [[]] * 9

# For each spot, this remembers which sets it belongs to.

sets = []

0.upto(80) do |n|
  row = n / 9
  col = n % 9
  sets[n] = [rows[row], cols[col], squares[(row/3)*3 + (col/3)]]
end

# For each spot, which numbers are possible.

possible = [[1,2,3,4,5,6,7,8,9]] * 81



#!/usr/bin/env ruby

numbers = []

# Each number goes into a row, col, and square.

rows = [[]] * 9
cols = [[]] * 9
squares = [[]] * 9

# For each spot, this remembers which sets it belongs to.

sets = []

0.upto(80) do |n|
  row = n / 9
  col = n % 9
  sets[n] = [rows[row], cols[col], squares[(row/3)*3 + (col/3)]]
end

# For each spot, which numbers are possible.

possible = [[1,2,3,4,5,6,7,8,9]] * 81


Put a digit in slot N.  For each slot in its row/col/square, remove it
from the possibilities.

# Possible should also know its slot.
possible = [[1,2,3,4,5,6,7,8,9]] * 81

rows = (0..8).map do |row|
  (0..8).map do |col|
    possible[row*9 + col]
  end
end

cols = (0..8).map do |col|
  (0..8).map do |row|
    possible[row*9 + col]
  end
end

squares = (0..8).map do |square|
  (0..8).map do |n|
    row = (square/3)*3 + n/3
    col = (square%3)*3 + n%3
    possible[row*9 + col]
  end
end

# For each slot, this remembers which sets it belongs to.

sets = (0..80).map do |n|
  row = n / 9
  col = n % 9
  [rows[row], cols[col], squares[(row/3)*3 + (col/3)]]
end



def place(digit, slot)
  sets[slot].each do |set|
    set.each do |poss|
      poss.delete(digit)
      dirty.add(poss)
    end
  end
end

dirty.each do |poss|
  if poss.size == 1
    place(poss.first, poss.slot)
  end
end
