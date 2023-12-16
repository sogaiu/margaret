(import ../margaret/meg :as peg)

# `true` or `false`

# Equivalent to `0` and `(not 0)` respectively.

(comment

  (peg/match true "")
  # =>
  @[]

  (peg/match false "")
  # =>
  nil

  (peg/match true "a")
  # =>
  @[]

  (peg/match false "a")
  # =>
  nil

  (peg/match '(choice "a" true) "a")
  # =>
  @[]

  (peg/match '(choice "a" true) "")
  # =>
  @[]

  (peg/match '(choice "a" false) "a")
  # =>
  @[]

  (peg/match '(choice "a" false) "")
  # =>
  nil

  )

