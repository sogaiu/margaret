(import ../margaret/meg :as peg)

# `(between min max patt)`

# Matches between `min` and `max` (inclusive) repetitions of `patt`

# `(opt patt)` and `(? patt)` are aliases for `(between 0 1 patt)`

(comment

  # between
  (peg/match ~(between 1 3 "a")
             "aa")
  # =>
  @[]

  # between matching max
  (peg/match ~(between 0 1 "a")
             "a")
  # =>
  @[]

  # between matching min 0 on empty string
  (peg/match ~(between 0 1 "a")
             "")
  # =>
  @[]

  # between matching 0 occurrences
  (peg/match ~(between 0 8 "b")
             "")
  # =>
  @[]

  # between with sequence
  (peg/match ~(sequence (between 0 2 "c")
                        "c")
             "ccc")
  # =>
  @[]

  # between matched max, so sequence fails
  (peg/match ~(sequence (between 0 3 "c")
                        "c")
             "ccc")
  # =>
  nil

  # opt
  (peg/match ~(opt "a")
             "a")
  # =>
  @[]

  # opt with empty string
  (peg/match ~(opt "a")
             "")
  # =>
  @[]

  (peg/match ~(? "a") "a")
  # =>
  @[]

  (peg/match ~(? "a") "")
  # =>
  @[]

  )

(comment

  # issue 1554 case 1
  (peg/match '(any (> '1)) "abc")
  # =>
  @["a"]

  # issue 1554 case 2
  (peg/match '(any (? (> '1))) "abc")
  # =>
  @["a"]

  # issue 1554 case 3
  (peg/match '(any (> (? '1))) "abc")
  # =>
  @["a"]

  # issue 1554 case 4
  (peg/match '(* "a" (> '1)) "abc")
  # =>
  @["b"]

  # issue 1554 case 5
  (peg/match '(* "a" (? (> '1))) "abc")
  # =>
  @["b"]

  # issue 1554 case 6
  (peg/match '(* "a" (> (? '1))) "abc")
  # =>
  @["b"]

  )

