(import ../margaret/meg :as peg)

# `(repeat n patt)`

# Matches exactly n repetitions of x

# `(n patt)` is an alias for `(repeat n patt)`

(comment

  (peg/match ~(repeat 3 "m")
             "mmm")
  # =>
  @[]

  (peg/match ~(repeat 2 "m")
             "m")
  # =>
  nil

  (peg/match ~(3 "m")
             "mmm")
  # =>
  @[]

  (peg/match ~(2 "m")
             "m")
  # =>
  nil

)
