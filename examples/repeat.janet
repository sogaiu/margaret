(import ../margaret/meg)

# `(repeat n patt)`

# Matches exactly n repetitions of x

# `(n patt)` is an alias for `(repeat n patt)`

(comment

  (meg/match ~(repeat 3 "m")
             "mmm")
  # => @[]

  (meg/match ~(repeat 2 "m")
             "m")
  # => nil

  (meg/match ~(3 "m")
             "mmm")
  # => @[]

  (meg/match ~(2 "m")
             "m")
  # => nil

)
