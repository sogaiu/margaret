(import ../margaret/meg :as peg)

(comment

  (peg/match ~(capture 1)
             "xy"
             0)
  # =>
  @["x"]

  (peg/match ~(capture 1)
             "xy"
             1)
  # =>
  @["y"]

  (peg/match ~(capture 1)
             "xy"
             2)
  # =>
  nil

  (string/has-prefix?
    "start "
    (try
      (peg/match ~(capture 1)
                 "xy"
                 3)
      ([e] e)))
  # =>
  true

  (peg/match ~(capture 1)
             "xy"
             -1)
  # =>
  nil

  (peg/match ~(capture 1)
             "xy"
             -2)
  # =>
  @["y"]

  (peg/match ~(capture 1)
             "xy"
             -3)
  # =>
  @["x"]

  (string/has-prefix?
    "start "
    (try
      (peg/match ~(capture 1)
                 "xy"
                 -4)
      ([e] e)))
  # =>
  true

  )

