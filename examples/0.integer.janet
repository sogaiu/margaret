(import ../margaret/meg :as peg)

# `<n>` -- where <n> is an integer

# For n >= 0, try to matches n characters, and if successful, advance
# that many characters.

# For n < 0, matches only if there aren't |n| characters, and do not
# advance.

# For example, -1 will match the end of a string because the length of
# the empty string is 0, which is less than 1 (i.e. |-1| = 1 and there
# aren't that many characters).

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

