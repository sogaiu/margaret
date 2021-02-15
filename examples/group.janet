(import ../margaret/meg :as peg)

# `(group patt ?tag)`

# Captures an array of all of the captures in `patt`

(comment

  (peg/match ~(group (sequence (capture 1)
                               (capture 1)
                               (capture 1)))
           "abc")
  # => @[@["a" "b" "c"]]

  (first
    (peg/match ~(group (sequence (capture "(")
                                 (capture (any (if-not ")" 1)))
                                 (capture ")")))
               "(defn hi [] 1)"))
  # => @["(" "defn hi [] 1" ")"]

  (peg/match ~(group (* (capture "a")
                        (group (capture "b"))))
             "ab")
  # => @[@["a" @["b"]]]

  )
