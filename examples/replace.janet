(import ../margaret/meg :as peg)

# `(replace patt subst ?tag)`

# Replaces the captures produced by `patt` by applying `subst` to them.

# If `subst` is a table or struct, will push `(get subst last-capture)` to
# the capture stack after removing the old captures.

# If `subst` is a function, will call `subst` with the captures of `patt`
# as arguments and push the result to the capture stack.

# Otherwise, will push `subst` literally to the capture stack.

# `(/ patt subst ?tag)` is an alias for `(replace patt subst ?tag)`

(comment

  (peg/match ~(replace (capture "cat")
                       {"cat" "tiger"})
             "cat")
  # =>
  @["tiger"]

  (peg/match ~(replace (capture "cat")
                       ,(fn [original]
                          (string original "alog")))
             "cat")
  # =>
  @["catalog"]

  (peg/match ~(replace (sequence (capture "ca")
                                 (capture "t"))
                       ,(fn [one two]
                          (string one two "alog")))
             "cat")
  # =>
  @["catalog"]

  (peg/match ~(replace (capture "cat")
                       "dog")
             "cat")
  # =>
  @["dog"]

  (peg/match ~(replace (capture "cat")
                       :hi)
             "cat")
  # =>
  @[:hi]

  (peg/match ~(capture (replace (capture "cat")
                                :hi))
             "cat")
  # =>
  @[:hi "cat"]

  (peg/match ~(/ (capture "cat")
                 {"cat" "tiger"})
             "cat")
  # =>
  @["tiger"]

  (peg/match ~(/ (capture "cat")
                 ,(fn [original]
                    (string original "alog")))
             "cat")
  # =>
  @["catalog"]

  (peg/match ~(/ (capture "cat")
                 "dog")
             "cat")
  # =>
  @["dog"]

  )

