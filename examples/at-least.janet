(import ../margaret/meg :as peg)

# `(at-least n patt)`

# Matches at least n repetitions of patt

(comment

  (peg/match ~(at-least 3 "z")
             "zz")
  # => nil

  (peg/match ~(at-least 3 "z")
             "zzz")
  # => @[]

)
