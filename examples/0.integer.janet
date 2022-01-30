(import ../margaret/meg :as peg)

# `<n>` -- where <n> is an integer

# Matches a number of characters, and advances that many characters.

# If negative, matches if not that many characters and does not advance.

# For example, -1 will match the end of a string because the length of
# the empty string is 0, which is less than 1 (i.e. "not that many
# characters").

(comment

  (peg/match 0 "")
  # =>
  @[]

  (peg/match 1 "")
  # =>
  nil

  (peg/match 1 "a")
  # =>
  @[]

  (peg/match 3 "cat")
  # =>
  @[]

  (peg/match 2 "cat")
  # =>
  @[]

  (peg/match 4 "cat")
  # =>
  nil

  (peg/match -1 "")
  # =>
  @[]

  (peg/match -2 "")
  # =>
  @[]

  (peg/match -1 "cat")
  # =>
  nil

  (peg/match -2 "o")
  # =>
  @[]

  )

