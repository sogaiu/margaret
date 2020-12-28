# https://bakpakin.com/writing/how-janets-peg-works.html

(defn match-peg-1
  [peg text]
  (match peg
    @[:! x]
    (unless (match-peg-1 x text) 0)
    #
    @[:+ x y]
    (or (match-peg-1 x text)
        (match-peg-1 y text))
    #
    @[:* x y]
    (if-let [lenx (match-peg-1 x text)]
      (if-let [leny (match-peg-1 y (string/slice text lenx))]
        (+ lenx leny)))
    # default is peg is a string literal
    (and (string/has-prefix? peg text)
         (length peg))))

(comment

 (match-peg-1 "a" "a")
 # => 1

 (match-peg-1 "ab" "ab")
 # => 2

 (match-peg-1 @[:! "a"] "b")
 # => 0

 (match-peg-1 @[:! "a"] "a")
 # => nil

 (match-peg-1 @[:+ "a" "b"] "a")
 # => 1

 (match-peg-1 @[:+ "a" "b"] "b")
 # => 1

 (match-peg-1 @[:+ "a" "b"] "c")
 # => false

 (match-peg-1 @[:* "a" "b"] "ab")
 # => 2

 (match-peg-1 @[:* "a" "b"] "abc")
 # => 2

 (def binary-digits
   [:+ "0" "1"])

 (match-peg-1 binary-digits "01")
 # => 1

 (match-peg-1 [:* binary-digits binary-digits]
            "01")
 # => 2

 (def digits
   [:+ "0"
       [:+ "1"
           [:+ "2"
               [:+ "3"
                   [:+ "4"
                       [:+ "5"
                           [:+ "6"
                               [:+ "7"
                                   [:+ "8" "9"]]]]]]]]])

 (def year
   [:* digits
       [:* digits
           [:* digits digits]]])

 (match-peg-1 year "2019")
 # => 4

 (def month
   [:* digits digits])

 (match-peg-1 month "11")
 # => 2

 (def day month)

 (def iso-date
   [:* year
       [:* "-"
           [:* month
               [:* "-" day]]]])

 (match-peg-1 iso-date "2019-06-10")
 # => 10

 (match-peg-1 iso-date "201-06-10")
 # => nil

 )

(defn match-peg-2
  [peg text]
  (match peg
    @[:! x]
    (unless (match-peg-2 x text) 0)
    #
    @[:+]
    (some (fn [x]
            (match-peg-2 x text))
          (tuple/slice peg 1))
    #
    @[:*]
    (do
      (var len 0)
      (var subtext text)
      (var ok true)
      (loop [x :in (tuple/slice peg 1)
             :let [lenx (match-peg-2 x subtext)
                   _ (set ok lenx)]
             :while ok]
        (set subtext (string/slice subtext lenx))
        (+= len lenx))
      (if ok len))
    # default is peg is a string literal
    (and (string/has-prefix? peg text)
         (length peg))))

(comment

 (def digits
   [:+ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"])

 (match-peg-2 digits "0")
 # => 1

 (match-peg-2 [:* digits digits] "01")
 # => 2

 (match-peg-2 [:* digits digits digits] "012")
 # => 3

 (def year
   [:* digits digits digits digits])

 (match-peg-2 year "2019")
 # => 4

 (def month
   [:* digits digits])

 (match-peg-2 month "10")
 # => 2

 (def day month)

 (match-peg-2 day "23")
 # => 2

 (def iso-date
   [:* year "-" month "-" day])

 (match-peg-2 iso-date "2019-06-10")
 # => 10

 (match-peg-2 iso-date "201-06-10")
 # => nil

 )

(defn match-peg-3
  [peg text grammar]
  (match peg
    @[:! x]
    (unless (match-peg-3 x text grammar) 0)
    #
    @[:+]
    (some (fn [x]
            (match-peg-3 x text grammar))
          (tuple/slice peg 1))
    #
    @[:*]
    (do
      (var len 0)
      (var subtext text)
      (var ok true)
      (loop [x :in (tuple/slice peg 1)
             :let [lenx (match-peg-3 x subtext grammar)
                   _ (set ok lenx)]
             :while ok]
        (set subtext (string/slice subtext lenx))
        (+= len lenx))
      (if ok len))
    #
    (x (keyword? x))
    (match-peg-3 (grammar x) text grammar)
    # default is peg is a string literal
    (and (string/has-prefix? peg text)
         (length peg))))

(comment

 (def grammar
   {:digit [:+ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"]
    :year [:* :digit :digit :digit :digit]
    :month [:* :digit :digit]
    :day [:* :digit :digit]
    :main [:* :year "-" :month "-" :day]})

 (match-peg-3 (grammar :main) "2019-06-10" grammar)
 # => 10

 )

(defn match-peg-4
  [peg text grammar]
  (match peg
    @[:set chars]
    (if (string/check-set chars
                          (string/slice text 0 1)) 1)
    #
    @[:! x]
    (unless (match-peg-4 x text grammar) 0)
    #
    @[:+]
    (some (fn [x]
            (match-peg-4 x text grammar))
          (tuple/slice peg 1))
    #
    @[:*]
    (do
      (var len 0)
      (var subtext text)
      (var ok true)
      (loop [x :in (tuple/slice peg 1)
             :let [lenx (match-peg-4 x subtext grammar)
                   _ (set ok lenx)]
             :while ok]
        (set subtext (string/slice subtext lenx))
        (+= len lenx))
      (if ok len))
    #
    (x (keyword? x))
    (match-peg-4 (grammar x) text grammar)
    # default is peg is a string literal
    (and (string/has-prefix? peg text)
         (length peg))))

(comment

 (match-peg-4 [:set "01"] "0" {})
 # => 1

 (match-peg-4 [:* [:set "01"] [:set "01"]] "01" {})
 # => 2

 (def grammar
   {:digit [:set "0123456789"]
    :year [:* :digit :digit :digit :digit]
    :month [:* :digit :digit]
    :day [:* :digit :digit]
    :main [:* :year "-" :month "-" :day]})

 (match-peg-4 (grammar :main) "2019-06-10" grammar)
 # => 10

 )
