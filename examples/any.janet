(import ../margaret/meg)

# `(any patt)`

# Matches 0 or more repetitions of `patt`

(comment

  # any with empty string
  (meg/match ~(any "a") 
             "")
  # => @[]

  # any
  (meg/match ~(any "a") 
             "aa")
  # => @[]

  # any with capture
  (meg/match ~(capture (any "a"))
             "aa")
  # => @["aa"]

)

