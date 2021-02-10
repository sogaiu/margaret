(import ../margaret/meg :fresh true)

# `(cmt patt fun ?tag)`

# Invokes `fun` with all of the captures of `patt` as arguments (if
# `patt` matches).

# If the result is truthy, then captures the result.

# The whole expression fails if `fun` returns false or nil.

(comment

  (meg/match ~(cmt (capture 1)
                   ,(fn [cap]
                      (= cap "a")))
             "a")
  # => @[true]

  (meg/match ~(cmt (capture 1)
                   ,(fn [cap]
                      (= cap "a")))
             "b")
  # => nil

  (meg/match ~(cmt (capture "hello")
                   ,(fn [cap]
                      (string cap "!")))
             "hello")
  # => @["hello!"]

  (meg/match ~(cmt (sequence (capture "hello")
                             (some (set " ,"))
                             (capture "world"))
                   ,(fn [cap1 cap2]
                      (string cap2 ": yes, " cap1 "!")))
             "hello, world")
  # => @["world: yes, hello!"]

  (meg/match ~{:main :pair
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

