(import ../margaret/meg)

# `(drop patt)`

# Ignores (drops) all captures from `patt`.

(comment

  (meg/match ~(drop (capture 1))
             "a")
  # => @[]

  (meg/match ~(drop (capture 1))
             "a")
  # => @[]

  )
