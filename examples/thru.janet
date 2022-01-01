(import ../margaret/meg :as peg)

# `(thru patt)`

# Match up through `patt` (thus including it).

# If the end of the input is reached and `patt` is not matched, the entire
# pattern does not match.

(comment

  (peg/match ~(thru "\n")
             "this is a nice line\n")
  # =>
  @[]

  (peg/match ~(sequence (thru "\n")
                        "\n")
             "this is a nice line\n")
  # =>
  nil

  (peg/match ~(sequence "(" (thru ")"))
             "(12345)")
  # =>
  @[]

  (peg/match ~(sequence "(" (thru ")"))
             " (12345)")
  # =>
  nil

  (peg/match ~(sequence "(" (thru ")"))
             "(12345")
  # =>
  nil

  # issue #640 in janet
  (peg/match '(thru -1) "aaaa")
  # =>
  @[]

  (peg/match ''(thru -1) "aaaa")
  # =>
  @["aaaa"]

  (peg/match '(thru "b") "aaaa")
  # =>
  nil

  )
