(import ../margaret/meg)

# `(int n ?tag)`

# Captures `n` bytes interpreted as a little endian integer.

(comment

  (meg/match ~(int 1) "a")
  # => @[97]

  (meg/match ~(int 2) "ab")
  # => @[25185]

  (type
    (first
      (meg/match ~(int 8) "abcdefgh")))
  # => :core/s64

  (meg/match ~(sequence (int 2 :a)
                        (backref :a))
             "ab")
  # => @[25185 25185]

  # (meg/match '(int 1) "a")
  # # => @[(chr "a")]

  # (meg/match '(int 1) "\xFF")
  # # => @[-1]

  # (meg/match '(int 2) "\xFF\x7f")
  # # => @[0x7fff]

  # (meg/match '(int 8)
  #            "\xff\x7f\x00\x00\x00\x00\x00\x00")
  # # => @[(int/s64 0x7fff)]

  # (meg/match '(int 7)
  #            "\xff\x7f\x00\x00\x00\x00\x00")
  # # => @[(int/s64 0x7fff)]

  # (meg/match '(sequence (int 2) -1)
  #            "123")
  # # => nil

  )
