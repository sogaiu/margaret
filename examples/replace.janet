(import ../margaret/meg)

# `(replace patt subst ?tag)`

# Replaces the captures produced by `patt` by applying `subst` to them.

# If `subst` is a table or struct, will push `(get subst last-capture)` to
# the capture stack after removing the old captures.

# If `subst` is a function, will call `subst` with the captures of `patt`
# as arguments and push the result to the capture stack.

# Otherwise, will push `subst` literally to the capture stack.

# `(/ patt subst ?tag)` is an alias for `(replace patt subst ?tag)`

(comment

  (meg/match ~(replace (capture "cat")
                       {"cat" "tiger"})
             "cat")
  # => @["tiger"]

  (meg/match ~(replace (capture "cat")
                       ,(fn [original]
                          (string original "alog")))
             "cat")
  # => @["catalog"]

  (meg/match ~(replace (sequence (capture "ca")
                                 (capture "t"))
                       ,(fn [one two]
                          (string one two "alog")))
             "cat")
  # => @["catalog"]

  (meg/match ~(replace (capture "cat")
                       "dog")
             "cat")
  # => @["dog"]

  (meg/match ~(replace (capture "cat")
                       :hi)
             "cat")
  # => @[:hi]

  (meg/match ~(capture (replace (capture "cat")
                                :hi))
             "cat")
  # => @[:hi "cat"]

  (meg/match ~(/ (capture "cat")
                 {"cat" "tiger"})
             "cat")
  # => @["tiger"]

  (meg/match ~(/ (capture "cat")
                 ,(fn [original]
                    (string original "alog")))
             "cat")
  # => @["catalog"]

  (meg/match ~(/ (capture "cat")
                 "dog")
             "cat")
  # => @["dog"]

  )
