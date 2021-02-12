(import ../margaret/meg)

# `(group patt ?tag)`

# Captures an array of all of the captures in `patt`

(comment

  (meg/match ~(group (sequence (capture 1)
                               (capture 1)
                               (capture 1)))
           "abc")
  # => @[@["a" "b" "c"]]

  (first
    (meg/match ~(group (sequence (capture "(")
                                 (capture (any (if-not ")" 1)))
                                 (capture ")")))
               "(defn hi [] 1)"))
  # => @["(" "defn hi [] 1" ")"]

  (meg/match ~(group (* (capture "a")
                        (group (capture "b"))))
             "ab")
  # => @[@["a" @["b"]]]

  )
