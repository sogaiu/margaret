(import ../margaret/meg)

# `(not patt)`

# Matches only if `patt` does not match.

# Will not produce captures or advance any characters.

# `(! patt)` is an alias for `(not patt)`

(comment

  (meg/match ~(not "cat") "dog")
  # => @[]

  (meg/match ~(sequence (not "cat")
                        (set "dgo"))
             "dog")
  # => @[]

  (meg/match ~(! "cat") "dog")
  # => @[]

  )
