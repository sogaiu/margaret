(import ../margaret/meg)

# `(lenprefix n patt)`

# Matches `n` repetitions of `patt`, where `n` is supplied from other parsed
# input and is not constant.

# `n` is obtained from the capture stack.

(comment

  (def lenprefix-peg
    ~(sequence
       (lenprefix
         (replace (sequence (capture (any (if-not ":" 1)))
                            ":")
                  ,scan-number)
         1)
       -1))

  (meg/match lenprefix-peg "5:abcde")
  # => @[]

  (meg/match lenprefix-peg "5:abcdef")
  # => nil

  (meg/match lenprefix-peg "5:abcd")
  # => nil

)
