(import ../margaret/meg)

# `<n>` -- where <n> is an integer

# Matches a number of characters, and advances that many characters.


# If negative, matches if not that many characters and does not advance.

# For example, -1 will match the end of a string because the length of
# the empty string is 0, which is less than 1 (i.e. "not that many
# characters").

(comment

  (meg/match 0 "")
  # => @[]

  (meg/match 1 "")
  # => nil

  (meg/match 1 "a")
  # => @[]

  (meg/match 3 "cat")
  # => @[]

  (meg/match 2 "cat")
  # => @[]

  (meg/match 4 "cat")
  # => nil

  (meg/match -1 "")
  # => @[]

  (meg/match -2 "")
  # => @[]

  (meg/match -1 "cat")
  # => nil

  (meg/match -2 "o")
  # => @[]

)
