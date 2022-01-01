(import ../margaret/meg :as peg)

# `(int-be n ?tag)`

# Captures `n` bytes interpreted as a big endian integer.

(comment

  (peg/match '(int-be 1) "a")
  # =>
  @[(chr "a")]

  (peg/match ~(int-be 2) "ab")
  # =>
  @[24930]

  (deep=
    (peg/match ~(int-be 8) "abcdefgh")
    @[(int/s64 "7017280452245743464")])
  # =>
  true

  (peg/match ~(sequence (int-be 2 :a)
                        (backref :a))
             "ab")
  # =>
  @[24930 24930]

  (peg/match '(int-be 1) "\xFF")
  # =>
  @[-1]

  (peg/match '(int-be 2) "\x7f\xff")
  # =>
  @[0x7fff]

  )
