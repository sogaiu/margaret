(import ../margaret/meg :as peg)

# `(sub window-patt patt)`

# Match `window-patt` and if it succeeds, match `patt` against the
# bytes that `window-patt` matched.

# `patt` cannot match more than `window-patt`; it will see
# end-of-input at the end of the substring matched by `window-patt`.

# If `patt` also succeeds, `sub` will advance to the end of what
# `window-patt` matched.

# If any of the `col`, `line`, `position`, or `error` specials appear
# in `patt`, they still yield values relative to the whole input.

(comment

  # matches the same input twice
  (peg/match ~(sub "abcd" "abc")
             "abcdef")
  # =>
  @[]

  # second pattern cannot match more than the first pattern
  (peg/match ~(sub "abcd" "abcde")
             "abcdef")
  # =>
  nil

  # fails if first pattern fails
  (peg/match ~(sub "x" "abc")
             "abcdef")
  # =>
  nil

  # fails if second pattern fails
  (peg/match ~(sub "abc" "x")
             "abcdef")
  # =>
  nil

  # keeps captures from both patterns
  (peg/match ~(sub (capture "abcd") (capture "abc"))
             "abcdef")
  # =>
  @["abcd" "abc"]

  # second pattern can reference captures from first
  (peg/match ~(sequence (constant 5 :tag)
                        (sub (capture "abc" :tag)
                             (backref :tag)))
             "abcdef")
  # =>
  @[5 "abc" "abc"]

  # second pattern can't see past what the first pattern matches
  (peg/match ~(sub "abc" (sequence "abc" -1))
             "abcdef")
  # =>
  @[]

  # positions inside second match are still relative to the entire input
  (peg/match ~(sequence "one\ntw"
                        (sub "o" (sequence (position) (line) (column))))
             "one\ntwo\nthree\n")
  # =>
  @[6 2 3]

  # advances to the end of the first pattern's match
  (peg/match ~(sequence (sub "abc" "ab")
                        "d")
             "abcdef")
  # =>
  @[]

 (peg/match ~(sequence (sub (capture "abcd" :a)
                            (capture "abc"))
                       (capture (backmatch)))
            "abcdabcd")
  # =>
  @["abcd" "abc" "abc"]

  (peg/match ~(sequence (sub (capture "abcd" :a)
                             (capture "abc"))
                        (capture (backmatch :a)))
             "abcdabcd")
  # =>
  @["abcd" "abc" "abcd"]

  (peg/match ~(sequence (capture "abcd" :a)
                        (sub (capture "abc" :a)
                             (capture (backmatch :a)))
                        (capture (backmatch :a)))
             "abcdabcabcd")
  # =>
  @["abcd" "abc" "abc" "abc"]

  (peg/match ~(sequence (capture "abcd" :a)
                        (sub (capture "abc")
                             (capture (backmatch)))
                        (capture (backmatch :a)))
             "abcdabcabcd")
  # =>
  @["abcd" "abc" "abc" "abcd"]

  (peg/match ~(sub (capture "abcd")
                   (look 3 (capture "d")))
             "abcdcba")
  # =>
  @["abcd" "d"]

  (peg/match ~(sub (capture "abcd")
                   (capture (to "c")))
             "abcdef")
  # =>
  @["abcd" "ab"]

  (peg/match ~(sub (capture (to "d"))
                   (capture "abc"))
             "abcdef")
  # =>
  @["abc" "abc"]

  (peg/match ~(sub (capture (to "d"))
                   (capture (to "c")))
             "abcdef")
  # =>
  @["abc" "ab"]

  (peg/match ~(sequence (sub (capture (to "d"))
                             (capture (to "c")))
                        (capture (to "f")))
             "abcdef")
  # =>
  @["abc" "ab" "de"]

  (peg/match ~(sub (capture "abcd")
                   (capture (thru "c")))
             "abcdef")
  # =>
  @["abcd" "abc"]

  (peg/match ~(sub (capture (thru "d"))
                   (capture "abc"))
             "abcdef")
  # =>
  @["abcd" "abc"]

  (peg/match ~(sub (capture (thru "d"))
                   (capture (thru "c")))
             "abcdef")
  # =>
  @["abcd" "abc"]

  (peg/match ~(sequence (sub (capture (thru "d"))
                             (capture (thru "c")))
                        (capture (thru "f")))
             "abcdef")
  # =>
  @["abcd" "abc" "ef"]

  (peg/match ~(sequence (sub (capture 3)
                             (capture 2))
                        (capture 3))
             "abcdef")
  # =>
  @["abc" "ab" "def"]

  (peg/match ~(sub (capture -7)
                   (capture -1))
             "abcdef")
  # =>
  @["" ""]

  (peg/match ~(sequence (sub (capture -7)
                             (capture -1))
                        (capture 1))
             "abcdef")
  # =>
  @["" "" "a"]

  (peg/match ~(sequence (sub (capture (repeat 3 (range "ac")))
                             (capture (repeat 2 (range "ab"))))
                        (capture (repeat 3 (range "df"))))
             "abcdef")
  # =>
  @["abc" "ab" "def"]

  (peg/match ~(sequence (sub (capture (repeat 3 (set "abc")))
                             (capture (repeat 2 (set "ab"))))
                        (capture (repeat 3 (set "def"))))
             "abcdef")
  # =>
  @["abc" "ab" "def"]

  (peg/match ~(sequence (sub (capture "abcd")
                             (int 1))
                        (int 1))
             "abcdef")
  # =>
  @["abcd" 97 101]

  (peg/match ~(sequence (sub (capture "ab")
                             (int 3)))
             "abcdef")
  # =>
  nil

  (peg/match ~(sub (capture "abcd")
                   (sub (capture "abc")
                        (capture "ab")))
             "abcdef")
  # =>
  @["abcd" "abc" "ab"]

  )

(comment

  (try
    (peg/match ~(sequence "a"
                          (sub "bcd" (error "bc")))
               "abcdef")
    ([e] e))
  # =>
  "match error at line 1, column 2"


  )
