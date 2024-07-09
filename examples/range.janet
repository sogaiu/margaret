(import ../margaret/meg :as peg)

# `(range r1 ?r2 .. ?rn)`

# Matches characters in a range and advances 1 character.

(comment

  (peg/match ~(range "aa")
             "a")
  # =>
  @[]

  (peg/match ~(capture (range "az"))
             "c")
  # =>
  @["c"]

  (peg/match ~(capture (range "az" "AZ"))
             "J")
  # =>
  @["J"]

  (peg/match ~(capture (range "09"))
             "123")
  # =>
  @["1"]

  (let [text (if (< (math/random) 0.5)
               "b"
               "y")]
    (peg/match ~(range "ac" "xz")
               text))
  # =>
  @[]

  )

