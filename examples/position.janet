(import ../margaret/meg :as peg)

# `(position ?tag)`

# Captures the current index into the text and advances no input.

# `($ ?tag)` is an alias for `(position ?tag)`

(comment

  (peg/match ~(position) "a")
  # =>
  @[0]

  (peg/match ~(sequence "a"
                        (position))
             "ab")
  # =>
  @[1]

  (peg/match ~(sequence (capture "w")
                        (position :p)
                        (backref :p))
             "whatever")
  # =>
  @["w" 1 1]

  (peg/match ~($) "a")
  # =>
  @[0]

  (peg/match ~(sequence "a"
                        ($))
             "ab")
  # =>
  @[1]

  (def rand-int
    (-> (os/cryptorand 3)
        math/rng
        (math/rng-int 90)
        inc))

  (def a-buf
    (buffer/new-filled rand-int 66))

  rand-int
  # =>
  (- (- ;(peg/match ~(sequence (position)
                               (some 1)
                               -1
                               (position))
                    a-buf)))

  )

