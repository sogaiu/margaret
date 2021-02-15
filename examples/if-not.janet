(import ../margaret/meg :as peg)

# `(if-not cond patt)`

# Tries to match only if `cond` does not match.

# `cond` will not produce any captures.

(comment

  (peg/match ~(if-not 2 "a")
             "a")
  # => @[]

  (peg/match ~(if-not 5 (set "iknw"))
             "wink")
  # => @[]

  )
