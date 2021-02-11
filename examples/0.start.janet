(import ../margaret/meg)

(comment

  (meg/match ~(capture 1)
             "ab"
             0)
  # => @["a"]

  (meg/match ~(capture 1)
             "ab"
             1)
  # => @["b"]

  (meg/match ~(capture 1)
             "ab"
             2)
  # => nil

)
