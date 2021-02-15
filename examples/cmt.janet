(import ../margaret/meg :as peg)

# `(cmt patt fun ?tag)`

# Invokes `fun` with all of the captures of `patt` as arguments (if
# `patt` matches).

# If the result is truthy, then captures the result.

# The whole expression fails if `fun` returns false or nil.

(comment

  (peg/match ~(cmt (capture 1)
                   ,(fn [cap]
                      (= cap "a")))
             "a")
  # => @[true]

  (peg/match ~(cmt (capture 1)
                   ,(fn [cap]
                      (= cap "a")))
             "b")
  # => nil

  (peg/match ~(cmt (capture "hello")
                   ,(fn [cap]
                      (string cap "!")))
             "hello")
  # => @["hello!"]

  (peg/match ~(cmt (sequence (capture "hello")
                             (some (set " ,"))
                             (capture "world"))
                   ,(fn [cap1 cap2]
                      (string cap2 ": yes, " cap1 "!")))
             "hello, world")
  # => @["world: yes, hello!"]

  (peg/match ~{:main :pair
               :pair (sequence (cmt (capture :key)
                                    ,identity)
                               "="
                               (cmt (capture :value)
                                    ,identity))
               :key (any (sequence (not "=")
                                   1))
               :value (any (sequence (not "&")
                                     1))}
             "name=tao")
  # => @["name" "tao"]

  )

