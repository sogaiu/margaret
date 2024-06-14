(import ../margaret/meg :as peg)

(comment

  (type (peg/compile ~(capture 1)))
  # =>
  :function

  (peg/match
    (peg/compile ~(capture 1))
    "xy"
    0)
  # =>
  @["x"]

  (type (comptime (peg/compile ~(capture 1))))
  # =>
  :function

  (peg/match
    (comptime
      (peg/compile ~(capture 1)))
    "xy"
    0)
  # =>
  @["x"]

  (string/has-prefix?
    "start "
    (try
      (let [compiled-peg (peg/compile ~(capture 1))]
        (peg/match compiled-peg "xy" -4))
      ([e] e)))
  # =>
  true

  )

