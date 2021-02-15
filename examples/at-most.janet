(import ../margaret/meg :as peg)

# `(at-most n patt)`

# Matches at most n repetitions of patt

(comment

  (peg/match ~(at-most 3 "z") "zz")
  # => @[]

  (peg/match ~(sequence (at-most 3 "z") "z")
             "zzz")
  # => nil

)
