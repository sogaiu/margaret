(import ../margaret/meg :as peg)

# `(argument n ?tag)`

# Captures the nth extra argument to the `match` function and does not advance.

(comment

  (peg/match ~(sequence "abc"
                        (argument 0))
             "abc"
             0
             :smile)
  # =>
  @[:smile]

  (peg/match ~(argument 0) "whatever"
             0
             :zero :one :two)
  # =>
  @[:zero]

  (peg/match ~(argument 2) "whatever"
             0
             :zero :one :two)
  # =>
  @[:two]

  )
