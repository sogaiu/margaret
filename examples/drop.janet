(import ../margaret/meg :as peg)

# `(drop patt)`

# Ignores (drops) all captures from `patt`.

(comment

  (peg/match ~(drop (capture 1))
             "a")
  # => @[]

  (peg/match ~(sequence (drop (cmt (capture 3)
                                   ,scan-number))
                        (capture (any 1)))
             "-1.89")
  # => @["89"]

  )
