(import ../margaret/meg :as peg)

# `(til sep patt)`

# Match `patt` up to (but not including) the first character of what
# `(to sep)` matches.

# If `(to sep)` does not match, the entire pattern does not match.

# If match succeeds, advance one character beyond the last character
# matched by `(to sep)`.

# Any captures made by `(to sep)` are dropped.

# `(til set patt)` might be seen as short for:

# `(sequence (sub (drop (to sep)) patt) (drop sep))`

(comment

  (peg/match ~(sequence (til "bcde" (capture (to -1)))
                        (capture (to -1)))
             "abcdef")
  # =>
  @["a" "f"]

  # basic matching
  (peg/match ~(til "d" "abc")
             "abcdef")
  # =>
  @[]

  # second pattern can't see past the first occurrence of first pattern
  (peg/match ~(til "d" (sequence "abc" -1))
             "abcdef")
  # =>
  @[]

  # fails if first pattern fails
  (peg/match ~(til "x" "abc")
             "abcdef")
  # =>
  nil

  # fails if second pattern fails
  (peg/match ~(til "abc" "x")
             "abcdef")
  # =>
  nil

  # discards captures from initial pattern
  (peg/match ~(til (capture "d") (capture "abc"))
             "abcdef")
  # =>
  @["abc"]

  # positions inside second match are still relative to the entire input
  (peg/match ~(sequence "one\ntw"
                        (til 0 (sequence (position) (line) (column))))
             "one\ntwo\nthree\n")
  # =>
  @[6 2 3]

  # advances to the end of the first pattern's first occurrence
  (peg/match ~(sequence (til "d" "ab") "e")
             "abcdef")
  # =>
  @[]

  )

