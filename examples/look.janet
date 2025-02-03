(import ../margaret/meg :as peg)

# `(look offset ?patt)`

# If `patt` is provided, matches only if `patt` matches at a fixed
# offset.  `offset` should be an integer in this case.

# If `patt` is not provided, matching occurs as if the peg had been
# `(look 0 offset)`.  Note that in this case `offset` is not
# restricted to an integer.

# Whether `patt` is provided or not, the peg will not advance any
# characters.

# `(> offset patt)` is an alias for `(look offset patt)`

(comment

  (peg/match ~(look 3 "cat")
             "my cat")
  # =>
  @[]

  (peg/match ~(look 3 (capture "cat"))
             "my cat")
  # =>
  @["cat"]

  (peg/match ~(look -4 (capture "cat"))
             "my cat")
  # =>
  nil

  (peg/match ~(sequence (look 3 "cat")
                        "my")
             "my cat")
  # =>
  @[]

  (peg/match ~(sequence "my"
                        (look -2 "my")
                        " "
                        (capture "cat"))
             "my cat")
  # =>
  @["cat"]

  (peg/match ~(capture (look 3 "cat"))
             "my cat")
  # =>
  @[""]

 (peg/match '(sequence (look 2) (capture 1)) "a")
  # =>
  nil

  (peg/match '(sequence (look 2) (capture 1)) "ab")
  # =>
  @["a"]

  (peg/match ~(> 3 "cat")
             "my cat")
  # =>
  @[]

  (peg/match ~(sequence (> 3 "cat")
                        "my")
             "my cat")
  # =>
  @[]

  )

