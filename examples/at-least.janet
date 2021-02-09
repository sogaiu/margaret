(import ../margaret/meg)

# `(at-least n patt)`

# Matches at least n repetitions of patt

(comment

  (meg/match ~(at-least 3 "z")
             "zz")
  # => nil

  (meg/match ~(at-least 3 "z")
             "zzz")
  # => @[]

)
