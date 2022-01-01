(import ../margaret/meg :as peg)

# "<s>" -- where <s> is string literal content

# Matches a literal string, and advances a corresponding number of characters.

(comment

  (peg/match "cat" "cat")
  # =>
  @[]

  (peg/match "cat" "cat1")
  # =>
  @[]

  (peg/match "" "")
  # =>
  @[]

  (peg/match "" "a")
  # =>
  @[]

  (peg/match "cat" "dog")
  # =>
  nil

)
