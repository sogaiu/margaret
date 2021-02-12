(import ../margaret/meg)

(comment

  (type (meg/compile ~(capture 1)))
  # => :function

  (meg/match
    (meg/compile ~(capture 1))
    "xy"
    0)
  # => @["x"]

  (type (comptime (meg/compile ~(capture 1))))
  # => :function

  (meg/match
    (comptime
      (meg/compile ~(capture 1)))
    "xy"
    0)
  # => @["x"]

  (try
    (let [compiled-peg (meg/compile ~(capture 1))]
      (meg/match compiled-peg "xy" -4))
    ([err]
      err))
  # => "start argument out of range"

)
