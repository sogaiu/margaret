(import ../margaret/meg :as peg)

# `(if cond patt)`

# Tries to match `patt` only if `cond` matches as well.

# `cond` will not produce any captures. [*]

(comment

  (peg/match ~(if 1 "a")
             "a")
  # => @[]

  (peg/match ~(if 5 (set "eilms"))
             "smile")
  # => @[]

  (peg/match ~(if 5 (set "eilms"))
             "wink")
  # => nil

  )
