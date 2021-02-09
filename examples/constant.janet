(import ../margaret/meg)

# `(constant k ?tag)`

# Captures a constant value and advances no characters.

(comment

  (meg/match ~(constant "smile")
             "whatever")
  # => @["smile"]

  (meg/match ~(constant {:fun :value})
             "whatever")
  # => @[{:fun :value}]

  (meg/match ~(sequence (constant :relax)
                        (position))
             "whatever")
  # => @[:relax 0]

  )
