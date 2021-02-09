(import ../margaret/meg)

# `(line ?tag)`

# Captures the line of the current index into the text and advances no input.

(comment

  (meg/match ~(line) 
             "a")
  # => @[1]

  (meg/match ~(sequence "a\n"
                        (line))
             "a\nb")
  # => @[2]

  (meg/match ~(sequence "a"
                        (line)
                        (capture "b"))
             "ab")
  # => @[1 "b"]

  )
