(import ../margaret/meg)

# `(uint-be n)`

# Captures `n` bytes interpreted as a big endian unsigned integer.

(comment

  (meg/match ~(uint-be 1) "a")
  # => @[97]

  (type
    (first
      (meg/match ~(uint-be 8) "abcdefgh")))
  # => :core/u64

  # (meg/match '(uint-be 1) "a")
  # # => @[(chr "a")]

  # (meg/match '(uint-be 1) "\xFF")
  # # => @[255]

  # (meg/match '(uint-be 2)
  #            "\x7f\xff")
  # # => @[0x7fff]

  )
