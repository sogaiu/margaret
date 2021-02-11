(import ../margaret/meg)

# `(uint-be n ?tag)`

# Captures `n` bytes interpreted as a big endian unsigned integer.

(comment

  (meg/match ~(uint-be 1) "a")
  # => @[97]

  (meg/match '(uint-be 1) "\xFF")
  # => @[255]

  (meg/match '(uint-be 2)
             "\x7f\xff")
  # => @[0x7fff]

  (deep= (meg/match ~(uint-be 8) "abcdefgh")
         @[(int/u64 "7017280452245743464")])
  # => true

  (meg/match ~(sequence (uint-be 2 :a)
                        (backref :a))
             "ab")
  # => @[24930 24930]

  )
