(import ../margaret/meg)

# `(range r1 ?r1 .. ?rn)`

# Matches characters in a range and advances 1 character.

(comment

  (meg/match ~(range "aa")
             "a")
  # => @[]

  (meg/match ~(capture (range "az"))
             "c")
  # => @["c"]

  (meg/match ~(capture (range "az" "AZ"))
             "J")
  # => @["J"]

  (meg/match ~(capture (range "09"))
             "123")
  # => @["1"]

  (let [text (if (< (math/random) 0.5)
               "b"
               "y")]
    (meg/match ~(range "ac" "xz")
               text))
  # => @[]

  )
