(import ../margaret/meg)

(comment

  (meg/match ~(capture 1)
             "xy"
             0)
  # => @["x"]

  (meg/match ~(capture 1)
             "xy"
             1)
  # => @["y"]

  (meg/match ~(capture 1)
             "xy"
             2)
  # => nil

  (try
    (meg/match ~(capture 1)
               "xy"
               3)
    ([err]
      err))
  # => "start argument out of range"

  (meg/match ~(capture 1)
             "xy"
             -1)
  # => nil

  (meg/match ~(capture 1)
             "xy"
             -2)
  # => @["y"]

  (meg/match ~(capture 1)
             "xy"
             -3)
  # => @["x"]

  (try
    (meg/match ~(capture 1)
               "xy"
               -4)
    ([err]
      err))
  # => "start argument out of range"

)
