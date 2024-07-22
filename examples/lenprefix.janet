(import ../margaret/meg :as peg)

# `(lenprefix n patt)`

# Matches `n` repetitions of `patt`, where `n` is supplied from other parsed
# input and is not constant.

# `n` is obtained from the capture stack.

(comment

  (peg/match ~(lenprefix (number :d) 1)
             "2xy")
  # =>
  @[]

  (peg/match ~(capture (lenprefix (number :d) 1))
             "2xy")
  # =>
  @["2xy"]

  (peg/match ~(sequence (number :d nil :tag)
                        (capture (lenprefix (backref :tag)
                                            1)))
             "3abc")
  # =>
  @[3 "abc"]

  (peg/match ~(replace (sequence (number :d 10 :tag)
                                 (capture (lenprefix (backref :tag)
                                                     1)))
                       ,(fn [num cap]
                          cap))
             "3abc")
  # =>
  @["abc"]

  (peg/match ~(lenprefix
                (replace (sequence (capture (any (if-not ":" 1)))
                                   ":")
                         ,scan-number)
                1)
             "8:abcdefgh")
  # =>
  @[]

  )

(comment

  (def lenprefix-peg
    ~(sequence
       (lenprefix
         (replace (sequence (capture (any (if-not ":" 1)))
                            ":")
                  ,scan-number)
         1)
       -1))

  (peg/match lenprefix-peg "5:abcde")
  # =>
  @[]

  (peg/match lenprefix-peg "5:abcdef")
  # =>
  nil

  (peg/match lenprefix-peg "5:abcd")
  # =>
  nil

  )

