(import ../margaret/meg :as peg)

# `(any patt)`

# Matches 0 or more repetitions of `patt`

(comment

  # any with empty string
  (peg/match ~(any "a")
             "")
  # =>
  @[]

  # any
  (peg/match ~(any "a")
             "aa")
  # =>
  @[]

  # any with capture
  (peg/match ~(capture (any "a"))
             "aa")
  # =>
  @["aa"]

  )

