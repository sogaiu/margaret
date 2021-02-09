(import ../margaret/meg)

# `(column ?tag)`

# Captures the column of the current index into the text and advances no input.

(comment

  (meg/match ~(column) 
             "a")
  # => @[1]

  (meg/match ~(sequence "a"
                        (column))
             "ab")
  # => @[2]

  (meg/match ~(sequence "a\n"
                        (column))
             "a\nb")
  # => @[1]

  (meg/match ~(sequence "a\nb"
                        (column))
             "a\nb")
  # => @[2]

  (meg/match ~(sequence "ab"
                        (column)
                        (capture "c"))
             "abc")
  # => @[3 "c"]

  )
