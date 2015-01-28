#!/usr/bin/env coffee

fs = require("fs")

main = ->
  text = fs.readFileSync(process.argv[2], {encoding: "utf8"})
  text = text.replace(/#.*/g, "").replace(/\s/g, "")
  solutions = new Puzzle(text).solve()
  console.log "#{solutions.length} solutions"

class Puzzle
  constructor: (setup) ->
    # Create the Positions.

    @positions = (new Position(@, n) for n in [0...81])

    # Create an ExclusionSet for each row, containing the Positions
    # in the row.

    rows = [0...9].map (row) =>
      new ExclusionSet "row #{row}",
        (@positions[row*9 + col] for col in [0...9])

    # Create an ExclusionSet for each column.

    cols = [0...9].map (col) =>
      new ExclusionSet "column #{col}",
        (@positions[row*9 + col] for row in [0...9])

    # Create an ExclusionSet for each square.

    squares = [0...9].map (square) =>
      # row and col of upper left corner of square
      row = ((square / 3)|0) * 3
      col = square % 3 * 3
      new ExclusionSet "square " + square,
        (@positions[(row + n/3|0)*9 + (col + n%3)] for n in [0...9])

    @exclusion_sets = rows.concat(cols).concat(squares)

    # Set each Position's exclusive_positions to an Array of all the
    # other Positions either in the same row, column, or square.  If
    # we place a number in this Position, we can't place the same
    # number in any of these other Positions.  Note that this list
    # may contain duplicates but that doesn't matter.

    @positions.forEach (position) =>
      position.set_exclusive_positions(
        @exclusion_sets.filter (set) =>
          set.contains(position)
        .flatMap (set) =>
          set.positions
        .minus [position]
      )

    # Within a square, if the only possible places for a given digit
    # are in the same row/col, then the digit can be removed from the
    # possibilities for the rest of the Positions in that row/col.
    #
    # The reverse of the situation is also true.  In a given row or
    # column if it is only possible to place a given digit within a
    # single square, then the digit can be eliminated from the other
    # Positions of that square.

    @tricky_sets = rows.concat(cols).product(squares).flatMap (args) =>
      [row, square] = args
      common = row.positions.intersect(square.positions)
      if !common.is_empty()
        # Each Array in @tricky_sets contains three
        # ExclusionSets.  If a digit is possible in the first
        # set but not the second, it will be set to "not
        # possible" in the third.
        [
          [common, square.positions.minus(common), row.positions.minus(common)],
          [common, row.positions.minus(common), square.positions.minus(common)]
        ]
      else
        []

    # Set initial pattern.

    # if filename
    # setup = File.read(filename).gsub(/#.*/, "").gsub(/\s/, "")
    # end

    setup.split("").zip(@positions).forEach (args) =>
      [c, position] = args
      if c != "-"
        console.log "placing initial #{c} in position #{position.number}"
        position.place(Number(c))

  place_one_missing: ->
    # Try to place a digit where there is only one Position in the
    # set where it can possibly go, and return true if a digit was
    # placed.  This is pretty inefficient since it has to look
    # through all the digits and positions repeatedly but so what.
    [1..9].some (digit) =>
      @exclusion_sets.some (set) =>
        # Does the set contain only one position that allows the
        # digit?
        positions_for_digit = set.possible_positions(digit)
        if positions_for_digit.length == 1
          console.log "placing missing #{digit}" +
                      " from #{set} in position " +
                      positions_for_digit[0].number
          @print_puzzle()
                
          positions_for_digit[0].place(digit)
          true

  place_one_forced: ->
    @positions.some  (position) =>
      if !position.placed && position.possible.length == 1
        console.log "placing forced #{position.possible[0]}" +
                    " in position #{position.number}"
        @print_puzzle()
        position.place(position.possible[0])
        true

  # Returns an Array of solved Puzzles.

  solve: ->
    # In order to come up with a sequence somewhat like a person
    # would, we preferentially try to place missing digits, then
    # forced digits, and if we can't do either we run the tricky sets
    # elimination.  This doesn't actually end up doing things like I
    # would though.  Oh well.

    while @place_one_missing() || @place_one_forced() || @eliminate_with_tricky_sets()
      null  # Looks like a coffeescript while loop can't be empty.

    # We get here either because we're done, we've failed, or we have
    # to guess and recure.  We can distibguish examining the position
    # with the fewest possibilities remaining.  Note that if there is
    # a Position with only one possibility then place_on_forced would
    # already have placed a digit there.

    next_position = @positions.min_by (position) =>
      if position.placed then 10 else position.possible.length

    switch
      when next_position.placed
        # Solved.  Return this as a solution.
        console.log "Solved:"
        @print_puzzle()
        [@]
      when next_position.possible.is_empty()
        # Failed.  No solution to return.
        console.log "Backing out."
        []
      else
        # Found an unplaced position with possibilities.  Guess each
        # possibility recursively, and return any solutions we find.
        next_position.possible.flatMap (digit) =>
          console.log "trying #{digit} in position " +
                      "#{next_position.number} #{next_position.possible}"
          puzzle = new Puzzle(@to_string())
          puzzle.position(next_position.number).place(digit)
          puzzle.solve()

  eliminate_with_tricky_sets: ->
    @tricky_sets.some (args) =>
      [subset, rest_of_set, elimination_set] = args
      subset.flatMap (position) =>
        if position.placed then [] else position.possible
      .uniq().filter (digit) =>
        !rest_of_set.some (position) =>
          position.is_possible_for(digit)
      .some (digit) =>
        elimination_set.some (position) =>
          if position.is_possible_for(digit)
            console.log("eliminating #{digit} from position " + position.number)
            position.not_possible(digit)
            true

  position: (number) ->
    @positions[number]

  print_puzzle: ->
    result = ""
    @to_string().split("").each_slice 27, (rows) =>
      rows.each_slice 9, (row) =>
        row.each_slice 3, (digits) =>
          result += digits.join("")
          result += " "
        result += "\n"
      result += "\n"
    process.stdout.write(result)

  to_string: ->
    (p.digit_or_dash() for p in @positions).join("")

# Each position in the Puzzle gets a Position which remembers the
# number we've placed in this Position and some other book-keeping
# information like which numbers are possible to put here, i.e., have
# not been eliminated by previous placements.

class Position
  constructor: (puzzle, number) ->
    # Remember our containing puzzle, for output.
    @puzzle = puzzle
    # The ordinal number of this Position.
    @number = number
    # The possible digits this Position may contain.
    @possible = [1..9]
    # The digit finally placed in this position.
    @placed = undefined
    # Array of all Positions in the same row, col, or square as this Position.
    @exclusive_positions = undefined

  toString: ->
    "#{@number}: @{@possible.toString()}"

  digit_or_dash: ->
    if @placed then @placed.toString() else "-"

  place: (digit) ->
    @placed = digit
    @possible = [digit]
    (position.not_possible(digit) for position in @exclusive_positions)

  is_possible_for: (digit) ->
    @possible.contains(digit)

  is_placed: ->
    @placed != undefined

  not_possible: (digit) ->
    @possible = @possible.minus([digit])

  set_exclusive_positions: (@exclusive_positions) ->

# An ExclusionSet has a name so it can be identified for printing
# messages, and an Array of Positions that are all in the same row,
# column, or square.

class ExclusionSet
  constructor: (@name, @positions) ->

  toString: -> @name

  contains: (position) ->
    @positions.contains(position)

  possible_positions: (digit) ->
    (p for p in @positions when !p.placed && p.is_possible_for(digit))

Array::flatMap = (lambda) ->
  Array::concat.apply([], @map(lambda))

Array::product = (other) ->
  @flatMap (x) -> other.map (y) -> [x, y]

if !Array::contains
  Array::contains = (e) -> @indexOf(e) != -1

Array::intersect = (other) ->
  (e for e in @ when other.contains(e))

Array::minus = (other) ->
  (e for e in @ when !other.contains(e))

Array::min_by = (map) ->
  @reduce((accum, e) ->
    n = map(e)
    if accum.n == undefined || n < accum.n
      accum.n = n
      accum.obj = e
    accum
  , { obj: undefined, n: undefined}
  ).obj

Array::is_empty = ->  @length == 0

# Zip together multiple lists into a single array -- elements that
# share an index go together.
Array::zip = (other) ->
  @reduce (accum, e, i) ->
    accum.push([e, other[i]])
    accum
  , []

Array::uniq = ->
  @reduce (accum, e) ->
    accum.push(e) unless accum.contains(e)
    accum
  , []

Array::each_slice = (size, func) ->
  (func(@slice(i, i + size)) for i in [0...@length] by size)

main()
