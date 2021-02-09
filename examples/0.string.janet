(import ../margaret/meg)

# "<s>" -- where <s> is string literal content

# Matches a literal string, and advances a corresponding number of characters.

(comment

  (meg/match "cat" "cat")
  # => @[]

  (meg/match "cat" "cat1")
  # => @[]

  (meg/match "" "")
  # => @[]

  (meg/match "" "a")
  # => @[]

  (meg/match "cat" "dog")
  # => nil

)
