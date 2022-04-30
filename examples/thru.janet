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

  # https://github.com/janet-lang/janet/issues/971
  (peg/match
    '{:dd (sequence :d :d)
      :sep (set "/-")
      :date (sequence :dd :sep :dd)
      :wsep (some (set " \t"))
      :entry (group (sequence (capture :date) :wsep (capture :date)))
      :main (some (thru :entry))}
    "1800-10-818-9-818 16/12\n17/12 19/12\n20/12 11/01")
  # =>
  @[@["17/12" "19/12"]
    @["20/12" "11/01"]]

  )

