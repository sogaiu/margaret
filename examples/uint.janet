(import ../margaret/meg)

# `(uint n)`

# Captures `n` bytes interpreted as a little endian unsigned integer.

(comment

  (meg/match ~(uint 1) "a")
  # => @[97]

  (type
    (first
      (meg/match ~(uint 8) "abcdefgh")))
  # => :core/u64

  # (meg/match '(uint 1) "a")
  # # => @[(chr "a")]

  # (meg/match '(uint 1) "\xFF")
  # # => @[255]

  # (meg/match '(uint 2) 
  #            "\xff\x7f")
  # # => @[0x7fff]

  # (meg/match '(uint 8)
  #            "\xff\x7f\x00\x00\x00\x00\x00\x00")
  # # => @[(int/u64 0x7fff)]

  # (meg/match '(uint 7)
  #            "\xff\x7f\x00\x00\x00\x00\x00")
  # # => @[(int/u64 0x7fff)]

  )
