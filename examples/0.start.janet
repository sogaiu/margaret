(import ../margaret/meg :as peg)

(comment

  (peg/match ~(capture 1)
             "xy"
             0)
  # => @["x"]

  (peg/match ~(capture 1)
             "xy"
             1)
  # => @["y"]

  (peg/match ~(capture 1)
             "xy"
             2)
  # => nil

  (try
    (peg/match ~(capture 1)
               "xy"
               3)
    ([err]
      err))
  # => "start argument out of range"

  (peg/match ~(capture 1)
             "xy"
             -1)
  # => nil

  (peg/match ~(capture 1)
             "xy"
             -2)
  # => @["y"]

  (peg/match ~(capture 1)
             "xy"
             -3)
  # => @["x"]

  (try
    (peg/match ~(capture 1)
               "xy"
               -4)
    ([err]
      err))
  # => "start argument out of range"

)
