(import ../margaret/meg :as peg)

# `(constant k ?tag)`

# Captures a constant value and advances no characters.

(comment

  (peg/match ~(constant "smile")
             "whatever")
  # =>
  @["smile"]

  (peg/match ~(constant {:fun :value})
             "whatever")
  # =>
  @[{:fun :value}]

  (peg/match ~(sequence (constant :relax)
                        (position))
             "whatever")
  # =>
  @[:relax 0]

  )

