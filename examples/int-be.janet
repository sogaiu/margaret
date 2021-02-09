(import ../margaret/meg)

# `(int-be n ?tag)`

# Captures `n` bytes interpreted as a big endian integer.

(comment

  (meg/match ~(int-be 2) "ab")
  # => @[24930]

  (type
    (first
      (meg/match ~(int-be 8) "abcdefgh")))
  # => :core/s64

  (meg/match ~(sequence (int-be 2 :a)
                        (backref :a))
             "ab")
  # => @[24930 24930]

  # (meg/match '(int-be 1) "a")
  # # => @[(chr "a")]

  # (meg/match '(int-be 1) "\xFF")
  # # => @[-1]

  # (meg/match '(int-be 2) "\x7f\xff")
  # # => @[0x7fff]

  )
