(import ../margaret/meg)

# `(thru patt)`

# Match up through `patt` (thus including it).

# If the end of the input is reached and `patt` is not matched, the entire
# pattern does not match.

(comment

  (meg/match ~(thru "\n")
             "this is a nice line\n")
  # => @[]

  (meg/match ~(sequence (thru "\n")
                        "\n")
             "this is a nice line\n")
  # => nil

  (meg/match ~(sequence "(" (thru ")"))
             "(12345)")
  # => @[]

  (meg/match ~(sequence "(" (thru ")"))
             " (12345)")
  # => nil

  (meg/match ~(sequence "(" (thru ")"))
             "(12345")
  # => nil

  )
