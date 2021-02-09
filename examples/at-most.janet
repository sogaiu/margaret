(import ../margaret/meg)

# `(at-most n patt)`

# Matches at most n repetitions of patt

(comment

  (meg/match ~(at-most 3 "z") "zz")
  # => @[]

  (meg/match ~(sequence (at-most 3 "z") "z")
             "zzz")
  # => nil

)
