(import ../margaret/meg)

# `(between min max patt)`

# Matches between `min` and `max` (inclusive) repetitions of `patt`

# `(opt patt)` and `(? patt)` are aliases for `(between 0 1 patt)`

(comment

  # between
  (meg/match ~(between 1 3 "a")
             "aa")
  # => @[]

  # between matching max
  (meg/match ~(between 0 1 "a")
             "a")
  # => @[]

  # between matching min 0 on empty string
  (meg/match ~(between 0 1 "a")
             "")
  # => @[]

  # between matching 0 occurrences
  (meg/match ~(between 0 8 "b")
             "")
  # => @[]

  # between with sequence
  (meg/match ~(sequence (between 0 2 "c")
                        "c")
             "ccc")
  # => @[]

  # between matched max, so sequence fails
  (meg/match ~(sequence (between 0 3 "c")
                        "c")
             "ccc")
  # => nil

  # opt
  (meg/match ~(opt "a")
             "a")
  # => @[]

  # opt with empty string
  (meg/match ~(opt "a")
             "")
  # => @[]

  (meg/match ~(? "a") "a")
  # => @[]

  (meg/match ~(? "a") "")
  # => @[]

)
