(import ../margaret/meg :as peg)

# `(not patt)`

# Matches only if `patt` does not match.

# Will not produce captures or advance any characters.

# `(! patt)` is an alias for `(not patt)`

(comment

  (peg/match ~(not "cat") "dog")
  # =>
  @[]

  (peg/match ~(sequence (not "cat")
                        (set "dgo"))
             "dog")
  # =>
  @[]

  (peg/match ~(! "cat") "dog")
  # =>
  @[]

  # https://github.com/janet-lang/janet/issues/1026
  (peg/match ~(not (sequence (constant 7) "a"))
             "hello")
  # =>
  @[]

  # https://github.com/janet-lang/janet/issues/1026
  (peg/match ~(if (not (sequence (constant 7) "a")) "hello")
             "hello")
  # =>
  @[]

  )

