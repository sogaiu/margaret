(import ../margaret/meg :as peg)

# `(number patt ?tag)`

# Capture a number if `patt` matches and the matched text scans as a number.

# Note that if the capture is tagged, the captured content is a number
# and not a string.

(comment

  (peg/match '(number :d+) "18")
  # => @[18]

  (peg/match ~(number :w+) "0xab")
  # => @[171]

  (peg/match '(number (sequence (some (choice :d "_"))))
             "60_000 ganges rivers")
  # => @[60000]

  (peg/match ~(number :d+ :my-tag) "18")
  # => @[18]

  (peg/match '(number :w+ :your-tag) "0xab")
  # => @[171]

  (peg/match ~(sequence (number :d+ :a)
                        (backref :a))
             "28")
  # => @[28 28]

  )
