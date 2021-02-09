(import ../margaret/meg)

# `(choice a b ...)`

# Tries to match a, then b, and so on.

# Will succeed on the first successful match, and fails if none of the
# arguments match the text.

# `(+ a b c ...)` is an alias for `(choice a b c ...)`

(comment

  (meg/match ~(choice) "")
  # => nil

  (meg/match ~(choice) "a")
  # => nil
  
  (meg/match ~(choice 1)
             "a")
  # => @[]

  (meg/match ~(choice (capture 1))
             "a")
  # => @["a"]

  (meg/match ~(choice "a" "b")
             "a")
  # => @[]

  (meg/match ~(choice "a" "b")
             "b")
  # => @[]

  (meg/match ~(choice "a" "b")
             "c")
  # => nil

  (meg/match ~(+ "a" "b")
             "a")
  # => @[]

  )
