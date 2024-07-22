(import ../margaret/meg :as peg)

# `(int n ?tag)`

# Captures `n` bytes interpreted as a little endian integer.

(comment

  (peg/match ~(int 1) "a")
  # =>
  @[97]

  (peg/match ~(int 2) "ab")
  # =>
  @[25185]

  (peg/match ~(int 8) "abcdefgh")
  # =>
  @[(int/s64 "7523094288207667809")]

  (peg/match ~(sequence (int 2 :a)
                        (backref :a))
             "ab")
  # =>
  @[25185 25185]

  (peg/match '(int 1) "\xFF")
  # =>
  @[-1]

  (peg/match '(int 2) "\xFF\x7f")
  # =>
  @[0x7fff]

  (peg/match '(int 8)
             "\xff\x7f\x00\x00\x00\x00\x00\x00")
  # =>
  @[(int/s64 0x7fff)]

  (peg/match '(int 7)
             "\xff\x7f\x00\x00\x00\x00\x00")
  # =>
  @[(int/s64 0x7fff)]

  (peg/match '(sequence (int 2) -1)
             "123")
  # =>
  nil

  )

