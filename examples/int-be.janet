(import ../margaret/meg)

# `(int-be n)`

# Captures `n` bytes interpreted as a big endian integer.

(comment

  (meg/match ~(int-be 2) "ab")
  # => @[24930]

  (type
    (first
      (meg/match ~(int-be 8) "abcdefgh")))
  # => :core/s64

  # (meg/match '(int-be 1) "a")
  # # => @[(chr "a")]

  # (meg/match '(int-be 1) "\xFF")
  # # => @[-1]

  # (meg/match '(int-be 2) "\x7f\xff")
  # # => @[0x7fff]

  )