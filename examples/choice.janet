(import ../margaret/meg :as peg)

# `(choice a b ...)`

# Tries to match a, then b, and so on.

# Will succeed on the first successful match, and fails if none of the
# arguments match the text.

# `(+ a b c ...)` is an alias for `(choice a b c ...)`

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

  (peg/match ~(choice "a" "b")
             "b")
  # =>
  @[]

  (peg/match ~(choice "a" "b")
             "c")
  # =>
  nil

  (peg/match ~(+ "a" "b")
             "a")
  # =>
  @[]

  )

