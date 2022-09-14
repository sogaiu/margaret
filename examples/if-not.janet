(import ../margaret/meg :as peg)

# `(if-not cond patt)`

# Tries to match only if `cond` does not match.

# `cond` will not produce any captures.

(comment

  (peg/match ~(if-not 2 "a")
             "a")
  # =>
  @[]

  (peg/match ~(if-not 5 (set "iknw"))
             "wink")
  # =>
  @[]

  # https://github.com/janet-lang/janet/issues/1026
  (peg/match ~(if-not (sequence (constant 7) "a") "hello")
             "hello")
  # =>
  @[]

  # https://github.com/janet-lang/janet/issues/1026
  (peg/match ~(if-not (drop (sequence (constant 7) "a")) "hello")
             "hello")
  # =>
  @[]

  )

