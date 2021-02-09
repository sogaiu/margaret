(import ../margaret/meg)

# `(to patt)`

# Match up to `patt` (but not including it).

# If the end of the input is reached and `patt` is not matched, the entire
# pattern does not match.

(comment

  (meg/match ~(to "\n")
             "this is a nice line\n")
  # => @[]

  (meg/match ~(sequence (to "\n")
                        "\n")
             "this is a nice line\n")
  # => @[]

  )


