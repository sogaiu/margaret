(import ../margaret/meg)

# `(set chars)`

# Match any character in the argument string. Advances 1 character.

(comment

  (meg/match ~(set "act")
             "cat")
  # => @[]

  (meg/match ~(set "act!")
             "cat!")
  # => @[]

  (meg/match ~(set "bo")
             "bob")
  # => @[]

  (meg/match ~(capture (set "act"))
             "cat")
  # => @["c"]

  )
