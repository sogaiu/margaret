(import ../margaret/meg)

# `(argument n ?tag)`

# Captures the nth extra argument to the `match` function and does not advance.

(comment

  (meg/match ~(sequence "abc"
                        (argument 0))
             "abc"
             0
             :smile)
  # => @[:smile]

  (meg/match ~(argument 0) "whatever"
             0
             :zero :one :two)
  # => @[:zero]

  (meg/match ~(argument 2) "whatever"
             0
             :zero :one :two)
  # => @[:two]


  )
