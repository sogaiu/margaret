(import ../margaret/meg)

# `(if cond patt)`

# Tries to match `patt` only if `cond` matches as well.

# `cond` will not produce any captures. [*]

(comment

  (meg/match ~(if 1 "a")
             "a")
  # => @[]

  (meg/match ~(if 5 (set "eilms"))
             "smile")
  # => @[]

  (meg/match ~(if 5 (set "eilms"))
             "wink")
  # => nil

  )
