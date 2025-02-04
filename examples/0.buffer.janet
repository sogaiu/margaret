(import ../margaret/meg :as peg)

# `@"<b>"` -- where <s> is buffer content

# Matches a literal buffer, and advances a corresponding number of characters.

(comment

  (peg/match @"cat" "cat")
  # =>
  @[]

  (peg/match @"cat" "cat1")
  # =>
  @[]

  (peg/match @"" "")
  # =>
  @[]

  (peg/match @"" "a")
  # =>
  @[]

  (peg/match @"cat" "dog")
  # =>
  nil

  )

