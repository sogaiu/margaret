(import ../margaret/meg)

# `(position ?tag)`

# Captures the current index into the text and advances no input.

# `($ ?tag)` is an alias for `(position ?tag)`

(comment

  (meg/match ~(position) "a")
  # => @[0]

  (meg/match ~(sequence "a"
                        (position))
             "ab")
  # => @[1]

  (meg/match ~(sequence (capture "w")
                        (position :p)
                        (backref :p))
             "whatever")
  # => @["w" 1 1]

  (meg/match ~($) "a")
  # => @[0]

  (meg/match ~(sequence "a"
                        ($))
             "ab")
  # => @[1]

  )
