(import ../margaret/meg :as peg)

# `(choice patt-1 patt-2 ...)`

# Tries to match patt-1, then patt-2, and so on.

# Will succeed on the first successful match, and fails if none of the
# arguments match the text.

# `(+ patt-1 patt-2 ...)` is an alias for `(choice patt-1 patt-2 ...)`

(comment

  (peg/match ~(choice) "")
  # =>
  nil

  (peg/match ~(choice) "a")
  # =>
  nil

  (peg/match ~(choice 1)
             "a")
  # =>
  @[]

  (peg/match ~(choice (capture 1))
             "a")
  # =>
  @["a"]

  (peg/match ~(choice "a" "b")
             "a")
  # =>
  @[]

  (peg/match ~(+ "a" "b")
             "a")
  # =>
  @[]

  (peg/match ~(choice "a" "b")
             "b")
  # =>
  @[]

  (peg/match ~(choice "a" "b")
             "c")
  # =>
  nil

  )

