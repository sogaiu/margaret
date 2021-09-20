(import ../margaret/meg :as peg)

# `(number patt ?tag)`

# Capture a number if `patt` matches and the matched text scans as a number.

(comment

  (peg/match '(number :d+) "18")
  # => @[18]

  (peg/match ~(number :w+) "0xab")
  # => @[171]

  (peg/match ~(number :d+ :my-tag) "18")
  # => @[18]

  (peg/match '(number :w+ :your-tag) "0xab")
  # => @[171]

  )
