(import ../margaret/meg)

# `(sequence a b c ...)`

# Tries to match a, b, c and so on in sequence.

# If any of these arguments fail to match the text, the whole pattern fails.

# `(* a b c ...)` is an alias for `(sequence a b c ...)`

(comment

  (meg/match ~(sequence) "a")
  # => @[]

  (meg/match ~(sequence "a" "b" "c")
             "abc")
  # => @[]

  (meg/match ~(sequence "a" "b" "c")
             "abcd")
  # => @[]

  (meg/match ~(sequence "a" "b" "c")
             "abx")
  # => nil

  (meg/match ~(sequence (capture 1 :a)
                        (capture 1)
                        (capture 1 :c))
             "abc")
  # => @["a" "b" "c"]

  (meg/match ~(* "a" "b" "c")
             "abc")
  # => @[]
  
  )
