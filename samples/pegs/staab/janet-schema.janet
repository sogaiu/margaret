(import ../../../margaret/meg :as peg)

(comment

  (def uuid-pattern
    '{:digit (range "09" "af" "AF")
      :digit4 (between 4 4 :digit)
      :digit8 (between 8 8 :digit)
      :digit12 (between 12 12 :digit)
      :main (* :digit8 "-" :digit4 "-" :digit4 "-" :digit4 "-" :digit12 -1)})

  (peg/match
    uuid-pattern
    "00000000-0000-0000-0000-000000000000")
  # => @[]

  (peg/match
    uuid-pattern  
    "123e4567-e89b-12d3-a456-426614174000")
  # => @[]

  (def year-pattern '(between 4 4 (range "09")))
  (def month-pattern '(+ (* "0" (range "19")) (* "1" (range "02"))))
  (def day-pattern '(+ (* "0" (range "19"))
                       (* (range "12") (range "09"))
                       (* "3" (range "01"))))
  (def hour-pattern '(+ (* "0" (range "09"))
                        (* "1" (range "09"))
                        (* "2" (range "03"))))
  (def minute-pattern '(+ (* "0" (range "09")) (* (range "15") (range "09"))))
  (def second-pattern '(+ (* "0" (range "09")) (* (range "15") (range "09"))))
  (def ms-pattern '(between 3 3 (range "09")))
  (def date-pattern ~(* ,year-pattern "-" ,month-pattern "-" ,day-pattern))
  (def time-pattern ~(* ,hour-pattern ":" ,minute-pattern ":" ,second-pattern
                        "." ,ms-pattern))
  (def datetime-pattern ~(* ,date-pattern "T" ,time-pattern "Z"))

  (peg/match
    datetime-pattern
    "2020-01-01T03:28:01.987Z")
  # => @[]

  )
