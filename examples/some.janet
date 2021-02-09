(import ../margaret/meg)

# `some`
# ------

# `(some patt)`

# Matches 1 or more repetitions of `patt`

(comment

  # some with empty string
  (meg/match ~(some "a") 
             "")
  # => nil

  # some
  (meg/match ~(some "a") 
             "aa")
  # => @[]

  # some with capture
  (meg/match ~(capture (some "a"))
             "aa")
  # => @["aa"]

)

