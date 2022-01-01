(import ../../../margaret/meg :as peg)

(comment

  # infer.janet
  (defn- secs
    [&opt m]
    (default m 1)
    (fn [t] (* (scan-number t) m)))

  (def time-grammar
    (comptime
      (peg/compile
        ~{:num (range "09")
          :reqwsoe (+ (some :s+) -1)
          :optws (any :s+)
          :secs (/ '(some :num) ,(secs))
          :mins (/ '(some :num) ,(secs 60))
          :hrs (/ '(some :num) ,(secs 3600))
          :tsecs (* :secs :optws (* "s" (any "ec") (any "ond") (any "s")))
          :tmins (* :mins :optws (* "m" (any "in") (any "ute") (any "s"))
                    :optws)
          :thrs (* :hrs :optws (* "h" (+ (any "rs") (any "our")) (any "s"))
                   :optws)
          :text (* (any :thrs) (any :tmins) (any :tsecs))
          :colon (* :hrs ":" :mins (any (if ":" (* ":" :secs))))
          :main (+ (some :text) (some :colon))})))

  (peg/match
    time-grammar
    "1 hour 10 mins")
  # => @[3600]

  (peg/match
    time-grammar
    "1:10")
  # => @[3600 600]

  (defn dc [t]
    (fn [a] {t a}))

  (defn num-dec [n] (-> n scan-number dec))

  (def date-range-grammar
    ~{:sep (set "/-")
      :year (* (constant :year) (/ '(repeat 4 :d) ,scan-number))
      :month (* (constant :month)
                (/
                  '(+ (* "0" (range "09"))
                      (* (set "01") (range "02")))
                  ,num-dec))
      :day (* (constant :month-day)
              (/ '(+ (* (range "02") (range "09")) (* "3" (set "01")))
                 ,num-dec))
      :date (/ (* :year :sep :month :sep :day) ,(fn [& a] (table ;a)))
      :date-range (* (/ :date ,(dc :from)) :s+ :sep :s+ (/ :date ,(dc :to)))
      :main :date-range})

  (deep=
    (peg/match
      date-range-grammar
      "2001-03-08 - 2002-02-26")
    #
    @[{:from @{:month 2 :year 2001 :month-day 7}}
      {:to @{:month 1 :year 2002 :month-day 25}}]
    ) # => true

  (deep=
    #
    (peg/match
      date-range-grammar
      "1997/08/08 - 1997/08/10")
    #
    @[{:from @{:month 7 :year 1997 :month-day 7}}
      {:to @{:month 7 :year 1997 :month-day 9}}]
    ) # => true

)
