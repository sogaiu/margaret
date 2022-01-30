(import ../margaret/meg :as peg)

# `(column ?tag)`

# Captures the column of the current index into the text and advances no input.

(comment

  (peg/match ~(column)
             "a")
  # =>
  @[1]

  (peg/match ~(sequence "a"
                        (column))
             "ab")
  # =>
  @[2]

  (peg/match ~(sequence "a\n"
                        (column))
             "a\nb")
  # =>
  @[1]

  (peg/match ~(sequence "a\nb"
                        (column))
             "a\nb")
  # =>
  @[2]

  (peg/match ~(sequence "ab"
                        (column)
                        (capture "c"))
             "abc")
  # =>
  @[3 "c"]

  )

