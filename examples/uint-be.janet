(import ../margaret/meg :as peg)

# `(uint-be n ?tag)`

# Captures `n` bytes interpreted as a big endian unsigned integer.

(comment

  (peg/match ~(uint-be 1) "a")
  # =>
  @[97]

  (peg/match '(uint-be 1) "\xFF")
  # =>
  @[255]

  (peg/match '(uint-be 2)
             "\x7f\xff")
  # =>
  @[0x7fff]

  (peg/match ~(uint-be 8) "abcdefgh")
  # =>
  @[(int/u64 "7017280452245743464")]

  (peg/match ~(sequence (uint-be 2 :a)
                        (backref :a))
             "ab")
  # =>
  @[24930 24930]

  )
