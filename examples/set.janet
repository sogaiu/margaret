(import ../margaret/meg :as peg)

# `(set chars)`

# Match any character in the argument string. Advances 1 character.

(comment

  (peg/match ~(set "act")
             "cat")
  # =>
  @[]

  (peg/match ~(set "act!")
             "cat!")
  # =>
  @[]

  (peg/match ~(set "bo")
             "bob")
  # =>
  @[]

  (peg/match ~(capture (set "act"))
             "cat")
  # =>
  @["c"]

  )
