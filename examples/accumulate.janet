(import ../margaret/meg :as peg)

# `(accumulate patt ?tag)`

# Capture a string that is the concatenation of all captures in `patt`.

# `(% patt ?tag)` is an alias for `(accumulate patt ?tag)`

(comment

  (peg/match ~(accumulate (sequence (capture 1)
                                    (capture 1)
                                    (capture 1)))
             "abc")
  # =>
  @["abc"]

  (peg/match ~(sequence (accumulate (sequence (capture "a")
                                              (capture "b"))
                                    :my-tag)
                        (backref :my-tag))
             "abc")
  # =>
  @["ab" "ab"]

  (peg/match ~(accumulate (sequence (capture "a")
                                    (capture "b")
                                    (capture "c")))
             "abc")
  # =>
  @["abc"]

  (peg/match ~(accumulate (sequence (capture "a")
                                    (position)
                                    (capture "b")
                                    (position)
                                    (capture "c")
                                    (position)))
             "abc")
  # =>
  @["a1b2c3"]

  (peg/match ~(% (sequence (capture "a")
                           (capture "b")
                           (capture "c")))
             "abc")
  # =>
  @["abc"]

  (peg/match ~(% (sequence (capture "a")
                           (position)
                           (capture "b")
                           (position)
                           (capture "c")
                           (position)))
             "abc")
  # =>
  @["a1b2c3"]

  )

