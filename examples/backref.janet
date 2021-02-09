(import ../margaret/meg)

# `(backref prev-tag ?tag)`

# Duplicates the last capture with tag `prev-tag`.

# If no such capture exists then the match fails.

# `(-> prev-tag ?tag)` is an alias for `(backref prev-tag ?tag)`

(comment

  (meg/match ~(sequence (capture 1 :a)
                        (backref :a))
             "a")
  # => @["a" "a"]

  (meg/match ~(sequence (capture "a" :target)
                        (backref :target))
             "b")
  # => nil

  (meg/match ~(sequence (capture 1 :a)
                        (backref :a)
                        (capture 1))
             "ab")
  # => @["a" "a" "b"]

  (meg/match ~(sequence (capture "a" :target)
                        (capture "b" :target-2)
                        (backref :target-2)
                        (backref :target))
             "ab")
  # => @["a" "b" "b" "a"]

  (meg/match ~(sequence (capture "a" :target)
                        (-> :target))
             "a")
  # => @["a" "a"]

  (meg/match ~(sequence (capture "a" :target)
                        (capture "b" :target-2)
                        (-> :target-2)
                        (-> :target))
             "ab")
  # => @["a" "b" "b" "a"]

  (meg/match ~(sequence (capture "a" :target)
                        (-> :target))
             "b")
  # => nil

  )
