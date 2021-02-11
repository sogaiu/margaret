(import ../margaret/meg)

# `(uint n ?patt)`

# Captures `n` bytes interpreted as a little endian unsigned integer.

(comment

  (meg/match ~(uint 1) "a")
  # => @[97]

  (meg/match '(uint 1) "\xFF")
  # => @[255]

  (meg/match '(uint 2)
             "\xff\x7f")
  # => @[0x7fff]

  (deep= (meg/match '(uint 8)
                    "\xff\x7f\x00\x00\x00\x00\x00\x00")
         @[(int/u64 0x7fff)])
  # => true

  (deep= (meg/match '(uint 7)
                    "\xff\x7f\x00\x00\x00\x00\x00")
         @[(int/u64 0x7fff)])
  # => true

  (deep= (meg/match ~(uint 8) "abcdefgh")
         @[(int/u64 "7523094288207667809")])
  # => true

  (meg/match ~(sequence (uint 2 :a)
                        (backref :a))
             "ab")
  # => @[25185 25185]

  )
