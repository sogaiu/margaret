(import ../margaret/meg :as peg)

# `(cms patt fun ?tag)`

# Invokes `fun` with all of the captures of `patt` as arguments (if
# `patt` matches).

# If the result is an indexed type, then captures the elements of the
# result.  If the result is not an indexed type, then captures the
# result.

# The whole expression fails if `fun` returns false or nil.

(comment

  (peg/match ~(cms (sequence 1 (capture 1) 1)
                   ,|[$ $ $])
             "abc")
  # =>
  @["b" "b" "b"]

  (peg/match ~(cms (sequence 1 1 (capture 1))
                   ,|@[$ $ $])
             "abc")
  # =>
  @["c" "c" "c"]

  (peg/match ~(cms (capture 1)
                   ,(fn [cap]
                      (= cap "a")))
             "a")
  # =>
  @[true]

  (peg/match ~(cms (capture 1)
                   ,(fn [cap]
                      (= cap "a")))
             "b")
  # =>
  nil

  (peg/match ~(cms (capture "hello")
                   ,(fn [cap]
                      (string cap "!")))
             "hello")
  # =>
  @["hello!"]

  (peg/match ~(cms (sequence (capture "hello")
                             (some (set " ,"))
                             (capture "world"))
                   ,(fn [cap1 cap2]
                      (string cap2 ": yes, " cap1 "!")))
             "hello, world")
  # =>
  @["world: yes, hello!"]

  )

(comment

  (peg/match ~{:main :pair
               :pair (sequence (cms (capture :key)
                                    ,identity)
                               "="
                               (cms (capture :value)
                                    ,identity))
               :key (any (sequence (not "=")
                                   1))
               :value (any (sequence (not "&")
                                     1))}
             "name=tao")
  # =>
  @["name" "tao"]

  )

