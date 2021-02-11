(import ../margaret/meg)

# `(int n ?tag)`

# Captures `n` bytes interpreted as a little endian integer.

(comment

  (meg/match ~(int 1) "a")
  # => @[97]

  (meg/match ~(int 2) "ab")
  # => @[25185]

  (deep= (meg/match ~(int 8) "abcdefgh")
         @[(int/s64 "7523094288207667809")])
  # => true

  (meg/match ~(sequence (int 2 :a)
                        (backref :a))
             "ab")
  # => @[25185 25185]

  (meg/match '(int 1) "\xFF")
  # => @[-1]

  (meg/match '(int 2) "\xFF\x7f")
  # => @[0x7fff]

  (deep= (meg/match '(int 8)
                    "\xff\x7f\x00\x00\x00\x00\x00\x00")
         @[(int/s64 0x7fff)])
  # => true

  (deep=  (meg/match '(int 7)
                     "\xff\x7f\x00\x00\x00\x00\x00")
          @[(int/s64 0x7fff)])
  # => true

  (meg/match '(sequence (int 2) -1)
             "123")
  # => nil

  )
