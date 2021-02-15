(import ../margaret/meg :as peg)

# `(line ?tag)`

# Captures the line of the current index into the text and advances no input.

(comment

  (peg/match ~(line)
             "a")
  # => @[1]

  (peg/match ~(sequence "a\n"
                        (line))
             "a\nb")
  # => @[2]

  (peg/match ~(sequence "a"
                        (line)
                        (capture "b"))
             "ab")
  # => @[1 "b"]

  )
