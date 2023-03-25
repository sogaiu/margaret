(import ../margaret/meg :as peg)

# `(backmatch ?tag)`

# If `tag` is provided, matches against the tagged capture.

# If no tag is provided, matches against the last capture, but only if that
# capture is untagged.

# The peg advances if there was a match.

(comment

  (peg/match ~(sequence (capture "a")
                        "b"
                        (capture (backmatch)))
             "aba")
  # =>
  @["a" "a"]

  (peg/match ~(sequence (capture "a" :a)
                        (capture "b")
                        (capture (backmatch)))
             "abb")
  # =>
  @["a" "b" "b"]

  (peg/match ~(sequence (capture "a" :a)
                        (capture "b")
                        (capture (backmatch :a)))
             "aba")
  # =>
  @["a" "b" "a"]

  (peg/match ~(sequence (capture "a" :target)
                        (capture (some "b"))
                        (capture (backmatch :target)))
             "abbba")
  # =>
  @["a" "bbb" "a"]

  (peg/match ~(sequence (capture "a")
                        (capture (some "b"))
                        (capture (backmatch))) # referring to captured "b"s
             "abbba")
  # =>
  nil

  (peg/match ~(sequence (capture "a")
                        (some "b")
                        (capture (backmatch))) # referring to captured "a"
             "abbba")
  # =>
  @["a" "a"]

  )

(comment

  (def backmatcher-1
    '(sequence (capture (any "x") :1)
               "y"
               (backmatch :1)
               -1))

  (peg/match backmatcher-1 "y")
  # =>
  @[""]

  (peg/match backmatcher-1 "xyx")
  # =>
  @["x"]

  (peg/match backmatcher-1 "xxxxxxxyxxxxxxx")
  # =>
  @["xxxxxxx"]

  (peg/match backmatcher-1 "xyxx")
  # =>
  nil

  (peg/match backmatcher-1
             (string "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                     "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy"))
  # =>
  nil

  (def backmatcher-2
    '(sequence '(any "x")
               "y"
               (backmatch)
               -1))

  (peg/match backmatcher-2 "y")
  # =>
  @[""]

  (peg/match backmatcher-2 "xyx")
  # =>
  @["x"]

  (peg/match backmatcher-2 "xxxxxxxyxxxxxxx")
  # =>
  @["xxxxxxx"]

  (peg/match backmatcher-2 "xyxx")
  # =>
  nil

  (peg/match backmatcher-2
             (string "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                     "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy"))
  # =>
  nil

  (peg/match backmatcher-2
             (string (string/repeat "x" 1000) "y"))
  # =>
  nil

  (peg/match backmatcher-2
             (string (string/repeat "x" 1000)
                     "y"
                     (string/repeat "x" 1000)))
  # =>
  (array (string/repeat "x" 1000))

  (def longstring-2
    '(sequence (capture (any "`"))
               (any (if-not (backmatch) 1))
               (backmatch)
               -1))

  (peg/match longstring-2 "`john")
  # =>
  nil

  (peg/match longstring-2 "abc")
  # =>
  nil

  (peg/match longstring-2 "` `")
  # =>
  @["`"]

  (peg/match longstring-2 "`  `")
  # =>
  @["`"]

  (peg/match longstring-2 "``  ``")
  # =>
  @["``"]

  (peg/match longstring-2 "``` `` ```")
  # =>
  @["```"]

  (peg/match longstring-2 "``  ```")
  # =>
  nil

  )

