(import ../margaret/meg)

# `(look offset patt)`

# Matches only if `patt` matches at a fixed offset.

# `offset` can be any integer.

# `patt` will not produce captures [*] and the peg will not advance any
# characters.

# `(> offset patt)` is an alias for `(look offset patt)`

(comment

  (meg/match ~(look 3 "cat")
             "my cat")
  # => @[]

  (meg/match ~(look 3 (capture "cat"))
             "my cat")
  # => @["cat"]

  (meg/match ~(look -4 (capture "cat"))
             "my cat")
  # => nil

  (meg/match ~(sequence (look 3 "cat")
                        "my")
             "my cat")
  # => @[]

  (meg/match ~(sequence "my"
                        (look -2 "my")
                        " "
                        (capture "cat"))
             "my cat")
  # => @["cat"]

  (meg/match ~(capture (look 3 "cat"))
             "my cat")
  # => @[""]

  (meg/match ~(> 3 "cat")
             "my cat")
  # => @[]

  (meg/match ~(sequence (> 3 "cat")
                        "my")
             "my cat")
  # => @[]

  )
