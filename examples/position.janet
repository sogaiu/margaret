(import ../margaret/meg :as peg)

# `(position ?tag)`

# Captures the current index into the text and advances no input.

# `($ ?tag)` is an alias for `(position ?tag)`

(comment

  (peg/match ~(position) "a")
  # => @[0]

  (peg/match ~(sequence "a"
                        (position))
             "ab")
  # => @[1]

  (peg/match ~(sequence (capture "w")
                        (position :p)
                        (backref :p))
             "whatever")
  # => @["w" 1 1]

  (peg/match ~($) "a")
  # => @[0]

  (peg/match ~(sequence "a"
                        ($))
             "ab")
  # => @[1]

  )
