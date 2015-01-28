#!/usr/bin/env node

var fs = require("fs");

function main() {
    var text = fs.readFileSync(process.argv[2], {encoding: "utf8"});
    text = text.replace(/#./g, "").replace(/\s/g, "");
    var solutions = new Puzzle(text).solve();
    console.log(solutions.length + " solutions");
};

function Puzzle(setup) {
    var self = this;

    // Create the Positions.

    self.positions = iota(81).map(function (n) {
	return new Position(self, n);
    });

    // Create an ExclusionSet for each row, containing the Positions
    // in the row.

    var rows = iota(9).map(function (row) {
	return new ExclusionSet(
	    "row " + row,
	    iota(9).map(function (col) {
		return self.positions[row*9 + col];
	    })
	);
    });

    // Create an ExclusionSet for each column.

    var cols = iota(9).map(function (col) {
	return new ExclusionSet(
	    "column " + col,
	    iota(9).map(function (row) {
		return self.positions[row*9 + col];
	    })
	);
    });

    // Create an ExclusionSet for each square.

    var squares = iota(9).map(function (square) {
	// row and col of upper left corner of square
	var row = ((square / 3)|0) * 3;
	var col = square % 3 * 3;
	return new ExclusionSet(
	    "square " + square,
	    iota(9).map(function (n) {
		return self.positions[(row + n/3|0)*9 + (col + n%3)];
	    })
	);
    });

    self.exclusion_sets = rows.concat(cols).concat(squares);

    // Set each Position's exclusive_positions to an Array of all the
    // other Positions either in the same row, column, or square.  If
    // we place a number in this Position, we can't place the same
    // number in any of these other Positions.  Note that this list
    // may contain duplicates but that doesn't matter.

    self.positions.forEach(function(position) {
	position.set_exclusive_positions(
	    self.exclusion_sets.filter(function (set) {
		return set.contains(position);
	    }).flatMap(function (set) {
		return set.positions;
	    }).minus([position])
	);
    });

    // Within a square, if the only possible places for a given digit
    // are in the same row/col, then the digit can be removed from the
    // possibilities for the rest of the Positions in that row/col.
    //
    // The reverse of the situation is also true.  In a given row or
    // column if it is only possible to place a given digit within a
    // single square, then the digit can be eliminated from the other
    // Positions of that square.

    self.tricky_sets = rows.concat(cols).product(squares).flatMap(
	function(args) {
	    var row = args.shift();
	    var square = args.shift();
	    var common = row.positions.intersect(square.positions);
	    if (!common.is_empty()) {
		// Each Array in self.tricky_sets contains three
		// ExclusionSets.  If a digit is possible in the first
		// set but not the second, it will be set to "not
		// possible" in the third.
		return [
		    [common, square.positions.minus(common), row.positions.minus(common)],
		    [common, row.positions.minus(common), square.positions.minus(common)]
		];
	    }
	    else {
		return [];
	    }
	}
    );

    // Set initial pattern.

    // if filename
    // setup = File.read(filename).gsub(/#.*/, "").gsub(/\s/, "")
    // end

    setup.split("").zip(self.positions).forEach(function (args) {
	var c = args.shift();
	var position = args.shift();
	if (c !== "-") {
            console.log("placing initial " + c +
			" in position " + position.number);
            position.place(Number(c));
	}
    });
};

Puzzle.prototype.place_one_missing = function () {
    var self = this;

    // Try to place a digit where there is only one Position in the
    // set where it can possibly go, and return true if a digit was
    // placed.  This is pretty inefficient since it has to look
    // through all the digits and positions repeatedly but so what.
    return range(1, 9).some(function (digit) {
	return self.exclusion_sets.some(function (set) {
	    // Does the set contain only one position that allows the
	    // digit?
	    var positions_for_digit = set.possible_positions(digit);
	    if (positions_for_digit.length === 1) {
		console.log("placing missing " + digit +
			    " from " + set + " in position " +
			    positions_for_digit[0].number);
		self.print_puzzle();
		
		positions_for_digit[0].place(digit);
		return true;
	    }
	});
    });
};

Puzzle.prototype.place_one_forced = function() {
    var self = this;

    return self.positions.some(function (position) {
	if (!position.placed && position.possible.length === 1) {
	    console.log("placing forced " + position.possible[0] +
			" in position " + position.number);
	    self.print_puzzle();
	    position.place(position.possible[0]);
	    return true;
	}
    });
};

// Returns an Array of solved Puzzles.

Puzzle.prototype.solve = function() {
    var self = this;

    // In order to come up with a sequence somewhat like a person
    // would, we preferentially try to place missing digits, then
    // forced digits, and if we can't do either we run the tricky sets
    // elimination.  This doesn't actually end up doing things like I
    // would though.  Oh well.

    while (self.place_one_missing() || self.place_one_forced() || self.eliminate_with_tricky_sets()) {
	// Empty.
    }

    // We get here either because we're done, we've failed, or we have
    // to guess and recure.  We can distibguish examining the position
    // with the fewest possibilities remaining.  Note that if there is
    // a Position with only one possibility then place_on_forced would
    // already have placed a digit there.

    var next_position = self.positions.min_by(function (position) {
	return position.placed ? 10 : position.possible.length;
    });

    if (next_position.placed) {
	// Solved.  Return this as a solution.
	console.log("Solved:");
	self.print_puzzle();
	return [self];
    }
    else if (next_position.possible.is_empty()) {
	// Failed.  No solution to return.
	console.log("Backing out.");
	return [];
    }
    else {
	// Found an unplaced position with possibilities.  Guess each
	// possibility recursively, and return any solutions we find.
	return next_position.possible.flatMap(function (digit) {
	    console.log("trying " + digit + " in position " +
			next_position.number + " " +
			next_position.possible);
	    var puzzle = new Puzzle(self.to_string());
	    puzzle.position(next_position.number).place(digit);
	    return puzzle.solve();
	});
    }
};

Puzzle.prototype.eliminate_with_tricky_sets = function () {
    this.tricky_sets.some(function (args) {
	subset = args.shift();
	rest_of_set = args.shift();
	elimination_set = args.shift();
	subset.flatMap(function (position) {
	    if (position.placed) {
		return [];
	    }
	    else {
		return position.possible;
	    }
	}).uniq().filter(function (digit) {
	    return !rest_of_set.some(function (position) {
		return position.is_possible(digit);
	    });
	}).some(function (digit) {
	    elimination_set.some(function (position) {
		if (position.is_possible(digit)) {
		    console.log("eliminating " + digit + " from position " +
				position.number);
		    position.not_possible(digit);
		    return true;
		}
	    });
	});
    });
};

Puzzle.prototype.position = function (number) {
    return this.positions[number];
};

Puzzle.prototype.print_puzzle = function() {
    var result = "";
    this.to_string().split("").each_slice(27, function(rows) {
	rows.each_slice(9, function(row) {
            row.each_slice(3, function (digits) {
		result += digits.join("");
		result += " ";
	    });
	    result += "\n";
	});
	result += "\n";
    });
    process.stdout.write(result);
};

Puzzle.prototype.to_string = function (number) {
    return this.positions.map(function (position) {
	return position.digit_or_dash();
    }).join("");
};

// Each position in the Puzzle gets a Position which remembers the
// number we've placed in this Position and some other book-keeping
// information like which numbers are possible to put here, i.e., have
// not been eliminated by previous placements.

function Position(puzzle, number) {
    // Remember our containing puzzle, for output.
    this.puzzle = puzzle;
    // The ordinal number of this Position.
    this.number = number;
    // The possible digits this Position may contain.
    this.possible = [1,2,3,4,5,6,7,8,9];
    // The digit finally placed in this position.
    this.placed = undefined;
    // Array of all Positions in the same row, col, or square as this Position.
    this.exclusive_positions = undefined;
};

Position.prototype.toString = function() {
    return this.number + ": " + this.possible.toString;
};

Position.prototype.digit_or_dash = function() {
    return this.placed ? this.placed.toString() : "-";
}

Position.prototype.place = function(digit) {
    this.placed = digit;
    this.possible = [digit];
    this.exclusive_positions.forEach(function (position) {
	position.not_possible(digit);
    });
};

Position.prototype.is_possible = function(digit) {
    return this.possible.contains(digit);
};

Position.prototype.is_placed = function() {
    return this.placed !== undefined;
};

Position.prototype.not_possible = function(digit) {
    this.possible = this.possible.minus([digit]);
};

Position.prototype.set_exclusive_positions = function (exclusive_positions) {
    this.exclusive_positions = exclusive_positions;
};

// An ExclusionSet has a name so it can be identified for printing
// messages, and an Array of Positions that are all in the same row,
// column, or square.

function ExclusionSet(name, positions) {
    this.name = name;
    this.positions = positions;
};

ExclusionSet.prototype.toString = function () {
    return this.name;
};

ExclusionSet.prototype.contains = function(position) {
    return this.positions.contains(position);
};

ExclusionSet.prototype.possible_positions = function(digit) {
    return this.positions.filter(function (position) {
	return !position.placed && position.is_possible(digit);
    });
};

Array.prototype.flatMap = function(lambda) {
    return Array.prototype.concat.apply([], this.map(lambda));
}; 

Array.prototype.product = function(that) {
    return this.flatMap(function (x) {
	return that.map(function (y) { return [x, y] });
    });
};

if (!Array.prototype.contains) {
    Array.prototype.contains = function(e) {
	return this.indexOf(e) != -1;
    }
}

Array.prototype.intersect = function(other) {
    return this.reduce(
	function (accum, e) {
	    if (other.contains(e)) {
		accum.push(e);
	    }
	    return accum;
	},
	[]);
};

Array.prototype.minus = function(other) {
    return this.reduce(
	function (accum, e) {
	    if (!other.contains(e)) {
		accum.push(e);
	    }
	    return accum;
	},
	[]);
};

Array.prototype.min_by = function(map) {
    return this.reduce(
	function (accum, e) {
	    var n = map(e);
	    if (accum.n === undefined || n < accum.n) {
		accum.n = n;
		accum.obj = e;
	    }
	    return accum;
	},
	{ obj: undefined, n: undefined}
    ).obj;
};

Array.prototype.is_empty = function() {
    return this.length === 0;
};

// Zip together multiple lists into a single array -- elements that
// share an index go together.
Array.prototype.zip = function(other) {
    return this.reduce(
	function (accum, e, i) {
	    accum.push([e, other[i]]);
	    return accum;
	},
	[]);
    };

Array.prototype.uniq = function() {
    return this.reduce(
	function (accum, e) {
	    if (!accum.contains(e)) {
		accum.push(e);
	    }
	    return accum;
	},
	[]);
    };

Array.prototype.each_slice = function(size, func) {
    for (var i = 0; i < this.length; i += size) {
	func(this.slice(i, i + size));
    }
};

function range(n1, n2) {
    var result = [];
    for (var i = n1; i <= n2; i++) {
	result.push(i);
    }
    return result;
};

function iota(n) {
    return range(0, n-1);
}

function iota_map(n, func) {
    var result = [];
    for (var i = 0; i < n; i++) {
	result.push(func(n));
    }
    return result;
};

main();
