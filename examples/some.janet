(import ../margaret/meg :as peg)

# `(some patt)`

# Matches 1 or more repetitions of `patt`

(comment

  # some with empty string
  (peg/match ~(some "a")
             "")
  # => nil

  # some
  (peg/match ~(some "a")
             "aa")
  # => @[]

  # some with capture
  (peg/match ~(capture (some "a"))
             "aa")
  # => @["aa"]

)
