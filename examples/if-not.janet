(import ../margaret/meg)

# `(if-not cond patt)`

# Tries to match only if `cond` does not match.

# `cond` will not produce any captures.

(comment

  (meg/match ~(if-not 2 "a")
             "a")
  # => @[]

  (meg/match ~(if-not 5 (set "iknw"))
             "wink")
  # => @[]

  )
