(import ../margaret/meg :as peg)

# `(drop patt)`

# Ignores (drops) all captures from `patt`.

(comment

  (peg/match ~(drop (capture 1))
             "a")
  # => @[]

  (peg/match ~(drop (capture 1))
             "a")
  # => @[]

  )
