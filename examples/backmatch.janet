(import ../margaret/meg)

# `(backmatch ?tag)`

# If `tag` is provided, matches against the tagged capture.

# If no tag is provided, matches against the last capture, but only if that
# capture is untagged.

# The peg advances if there was a match.

(comment

  (meg/match ~(sequence (capture "a")
                        "b"
                        (capture (backmatch)))
             "aba")
  # => @["a" "a"]

  (meg/match ~(sequence (capture "a" :a)
                        (capture "b")
                        (capture (backmatch)))
             "abb")
  # => @["a" "b" "b"]

  (meg/match ~(sequence (capture "a" :a)
                        (capture "b")
                        (capture (backmatch :a)))
             "aba")
  # => @["a" "b" "a"]

  (meg/match ~(sequence (capture "a" :target)
                        (capture (some "b"))
                        (capture (backmatch :target)))
             "abbba")
  # => @["a" "bbb" "a"]

  (meg/match ~(sequence (capture "a")
                        (capture (some "b"))
                        (capture (backmatch))) # referring to captured "b"s
             "abbba")
  # => nil

  (meg/match ~(sequence (capture "a")
                        (some "b")
                        (capture (backmatch))) # referring to captured "a"
             "abbba")
  # => @["a" "a"]

  (def backmatcher-1
    '(sequence (capture (any "x") :1)
               "y"
               (backmatch :1)
               -1))

  (meg/match backmatcher-1 "y")
  # => @[""]

  (meg/match backmatcher-1 "xyx")
  # => @["x"]

  (meg/match backmatcher-1 "xxxxxxxyxxxxxxx")
  # => @["xxxxxxx"]

  (meg/match backmatcher-1 "xyxx")
  # => nil

  (meg/match backmatcher-1
             (string "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                     "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy"))
  # => nil

  (def backmatcher-2
    '(sequence '(any "x")
               "y"
               (backmatch)
               -1))

  (meg/match backmatcher-2 "y")
  # => @[""]

  (meg/match backmatcher-2 "xyx")
  # => @["x"]

  (meg/match backmatcher-2 "xxxxxxxyxxxxxxx")
  # => @["xxxxxxx"]

  (meg/match backmatcher-2 "xyxx")
  # => nil

  (meg/match backmatcher-2
             (string "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                     "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy"))
  # => nil

  (meg/match backmatcher-2
             (string (string/repeat "x" 1000) "y"))
  # => nil

  (meg/match backmatcher-2
             (string (string/repeat "x" 1000)
                     "y"
                     (string/repeat "x" 1000)))
  # => (array (string/repeat "x" 1000))

  (def longstring-2
    '(sequence (capture (any "`"))
               (any (if-not (backmatch) 1))
               (backmatch)
               -1))

  (meg/match longstring-2 "`john")
  # => nil

  (meg/match longstring-2 "abc")
  # => nil

  (meg/match longstring-2 "` `")
  # => @["`"]

  (meg/match longstring-2 "`  `")
  # => @["`"]

  (meg/match longstring-2 "``  ``")
  # => @["``"]

  (meg/match longstring-2 "``` `` ```")
  # => @["```"]

  (meg/match longstring-2 "``  ```")
  # =>  nil

  )
