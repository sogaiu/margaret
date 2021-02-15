(import ../margaret/meg :as peg)

# `(to patt)`

# Match up to `patt` (but not including it).

# If the end of the input is reached and `patt` is not matched, the entire
# pattern does not match.

(comment

  (peg/match ~(to "\n")
             "this is a nice line\n")
  # => @[]

  (peg/match ~(sequence (to "\n")
                        "\n")
             "this is a nice line\n")
  # => @[]

  )


