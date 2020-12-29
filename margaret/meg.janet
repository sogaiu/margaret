# . emulate same grammar as janet's c implementation (use struct)
#
#   . string
#   . integer
#   . keyword (:s, :w, etc.)
#   . tuple
#   . struct
#
# . use existing tests / examples for peg/match for testing
#
#   . official janet tests
#   . janet peg tutorial doc has examples
#   . tests in various repositories
#     . clojure-peg
#     . janet-peg
#     . others?
#
# . 2-parameter version of match-peg
#
#   . wrapper function that takes 2 args
#   . create peg-table based on passed in grammar
#     . struct -> check there is a :main key
#     . tuple -> add :main key with tuple as value to peg-table
#     . keyword -> add :main key with keyword as value to peg-table
#     . integer -> add :main key with integer as value to peg-table
#     . string -> add :main key with string as value in peg-table
#   . hook up default-peg-grammar to peg-table:
#     . use proto table: (table/setproto peg-table default-peg-grammar)
#   . define capture stack as array
#   . define tags table
#   . define inner function
#   . call inner function
#   . overall return value
#     . capture stack if match succeeds
#     . nil if match fails
#     . call error if `error` special (?)
#
# . implement constructs in default-peg-grammar
#
#   . set
#   . range
#   . any
#   . some
#   . if-not
#
# . determine and implement rest of constructs
#
# . argument 3 -- where to start
#
# . argument 4+ -- things for use with `argument`
#
# . optimization speculation
#
#   . tco using loop + label as in mal
#   . tuple/slice over drop
#   . consider not using `match`

(defn- peg-match
  [opeg otext]
  #
  (def peg-table
    (case (type opeg)
      :string
       @{:main opeg}
      :number
       (do (assert (int? opeg)
                   (string "number must be an integer: " opeg))
         @{:main opeg})
      :keyword
       (do (assert (default-peg-grammar opeg)
                   (string "default-peg-grammar does not have :" opeg))
         @{:main opeg})
      :tuple
       @{:main opeg}
      :struct
       (table ;(kvs opeg))))
  (assert (peg-table :main)
          "peg needs a :main key")
  (table/setproto peg-table default-peg-grammar)
  #
  (def caps @[])
  (def tags @{})
  #
  (defn peg-match*
    [peg text grammar]
    (cond
      # keyword
      (keyword? peg)
      (do (when (dyn :meg-debug) (print "keyword"))
        (peg-match* (grammar peg) text grammar))
      # string literal
      (string? peg)
      (do (when (dyn :meg-debug) (print "string"))
        (when (string/has-prefix? peg text)
          (length peg)))
      # integer
      (int? peg)
      (do (when (dyn :meg-debug) (print "integer"))
        (when (<= peg (length text))
          (if (pos? peg)
            peg
            0)))
      # struct
      (struct? peg)
      (do (when (dyn :meg-debug) (print "struct"))
        (assert (peg :main)
                "peg does not have :main")
        (peg-match* (peg :main) text peg))
      # tuple
      (tuple? peg)
      (do (when (dyn :meg-debug) (print "tuple"))
        (assert (pos? (length peg))
                "peg must have non-zero length")
        (def special (first peg))
        # XXX: use tuple/slice?
        (def tail (drop 1 peg))
        #
        (cond
          # range
          (= 'range special)
          (do (print special)
            (assert (not (empty? tail))
                    "`range` requires at least one argument")
            (let [target-bytes
                  (reduce (fn [acc elt]
                            (assert (= 2 (length elt))
                                    "range argument must be length 2")
                            (let [left (get elt 0)
                                  right (get elt 1)]
                              (assert (<= left right) "empty range")
                              (array/concat acc (range left (inc right)))))
                          @[]
                          tail)
                  target-set (string/from-bytes ;target-bytes)]
              (when (string/check-set target-set
                                      (string/slice text 0 1))
                1)))
          # set
          (= 'set special)
          (do (when (dyn :meg-debug) (print special))
            (assert (not (empty? tail))
                    "`set` requires at least one argument")
            (when (string/check-set (first tail)
                                    (string/slice text 0 1))
              1))
          #
          (or (= '! special)
              (= 'not special))
          (do (when (dyn :meg-debug) (print special))
            (assert (not (empty? tail))
                    "`not` requires at least one argument")
            (unless (peg-match* (first tail) text grammar)
              0))
          #
          (or (= '+ special)
              (= 'choice special))
          (do (when (dyn :meg-debug) (print special))
            (some (fn [x]
                    (peg-match* x text grammar))
                  (tuple/slice peg 1)))
          #
          (or (= '* special)
              (= 'sequence special))
          (do (when (dyn :meg-debug) (print special))
            (var len 0)
            (var subtext text)
            (var ok true)
            (loop [x :in (tuple/slice peg 1)
                   :let [lenx (peg-match* x subtext grammar)
                         _ (set ok lenx)]
                   :while ok]
              (set subtext (string/slice subtext lenx))
              (+= len lenx))
            (when ok len))
          #
          (= 'any special)
          (do (when (dyn :meg-debug) (print special))
            (assert (not (empty? tail)) "`any` requires one argument")
            (def patt (first tail))
            (var len 0)
            (var subtext text)
            (while (pos? (length subtext))
              (def lenx (peg-match* patt subtext grammar))
              (unless lenx
                (break))
              (set subtext (string/slice subtext lenx))
              (+= len lenx))
            len)
          #
          (= 'some special)
          (do (when (dyn :meg-debug) (print special))
            (assert (not (empty? tail)) "`some` requires one argument")
            (def patt (first tail))
            (var len 0)
            (var subtext text)
            (var had-match false)
            (while (pos? (length subtext))
              (def lenx (peg-match* patt subtext grammar))
              (unless lenx
                (break))
              (set had-match true)
              (set subtext (string/slice subtext lenx))
              (+= len lenx))
            (when had-match len))
          #
          (or (= 'capture special)
              (= 'quote special)
              (= '<- special))
          (do (when (dyn :meg-debug) (print special))
            (assert (not (empty? tail))
                    "`capture` requires at least one argument")
            (let [lenx (peg-match* (first tail)
                                   text grammar)
                  cap (string/slice text 0 lenx)]
              (array/push caps cap)
              (when-let [tag (get tail 1)]
                (put tags
                     tag cap))
              lenx))
          #
          (= 'drop special)
          (do (when (dyn :meg-debug) (print special))
            (assert (not (empty? tail))
                    "`drop` requires at least one argument")
            (let [lenx (peg-match* (first tail)
                                   text grammar)]
              (array/pop caps)
              lenx))
          #
          (= 'backref special)
          (do (when (dyn :meg-debug) (print special))
            (assert (not (empty? tail))
                    "`backref` requires at least one argument")
            (when-let [tag (first tail)
                       last-cap (get tags tag)]
              (array/push caps last-cap)
              (when-let [opt-tag (get tail 1)]
                (put tags
                     opt-tag last-cap))
              0))
          #
          (error (string "unknown special: " special))))
      #
      # unknown
      (error (string "unknown construct: " peg))))
  #
  (def index
    (peg-match* (peg-table :main) otext peg-table))
  (when (dyn :meg-debug)
    (prin "tags: ")
    (pp tags)
    (prin "capture stack: ")
    (pp caps))
  (when index
    (when (dyn :meg-debug)
      (print "index: " index))
    caps))

(comment

 (peg-match "a" "a")
 # => @[]

 (peg-match ~(capture "a") "a")
 # => @["a"]

 (peg-match ~(<- "a") "a")
 # => @["a"]

 (peg-match "ab" "ab")
 # => @[]

 (peg-match ~(capture "ab") "ab")
 # => @["ab"]

 (peg-match 1 "a")
 # => @[]

 (peg-match ~(capture 1) "a")
 # => @["a"]

 (peg-match 2 "ab")
 # => @[]

 (peg-match ~(capture 2) "ab")
 # => @["ab"]

 (peg-match 2 "a")
 # => nil

 (peg-match ~(capture 2) "a")
 # => nil

 (peg-match -1 "")
 # => @[]

 (peg-match ~(capture -1) "")
 # => @[""]

 (peg-match :s " ")
 # => @[]

 (peg-match ~(capture :s) " ")
 # => @[" "]

 (peg-match :v " ")
 # !

 (peg-match ~(set "act") "cat")
 # => @[]

 (peg-match ~(capture (set "act")) "cat")
 # => @["c"]

 (peg-match ~{:main (set "act")} "cat")
 # => @[]

 (peg-match ~(capture {:main (set "act")}) "cat")
 # => @["c"]

 (peg-match ~(* "a" "b") "ab")
 # => @[]

 (peg-match ~(* (capture "a") (capture "b"))
             "ab")
 # => @["a" "b"]

 (peg-match ~(sequence (capture "a") (capture "b"))
             "ab")
 # => @["a" "b"]

 (peg-match ~(capture (* "a" "b"))
             "ab")
 # => @["ab"]

 (peg-match ~(*) "")
 # => @[]

 (peg-match ~(capture (*)) "")
 # => @[""]

 (peg-match ~(* "a" "b") "ac")
 # => nil

 (peg-match ~(capture (* "a" "b")) "ac")
 # => nil

 (peg-match ~(+ "a" "b") "a")
 # => @[]

 (peg-match ~(capture (+ "a" "b")) "a")
 # => @["a"]

 (peg-match ~(+ "a" "b") "b")
 # => @[]

 (peg-match ~(capture (+ "a" "b")) "b")
 # => @["b"]

 (peg-match ~(+ "a" "b" "c") "c")
 # => @[]

 (peg-match ~(capture (+ "a" "b" "c")) "c")
 # => @["c"]

 (peg-match ~(+ "a" "b" (* "c" "d")) "cd")
 # => @[]

 (peg-match ~(capture (+ "a" "b" (* "c" "d")))
             "cd")
 # => @["cd"]

 (peg-match ~(+ "a" "b") "c")
 # => nil

 (peg-match ~(capture (+ "a" "b")) "c")
 # => nil

 (peg-match ~(* "a" (not "b")) "ac")
 # => @[]

 (peg-match ~(capture (* "a" (not "b")))
             "ac")
 # => @["a"]

 (peg-match ~(capture (* "a" (! "b")))
             "ac")
 # => @["a"]

 (peg-match ~(quote (* "a" (! "b")))
             "ac")
 # => @["a"]

 (peg-match ~'(* "a" (! "b"))
             "ac")
 # => @["a"]

 (peg-match ~(drop (capture "a")) "a")
 # => @[]

 (peg-match ~(sequence (drop (capture "a"))
                       (capture "b"))
             "ab")
 # => @["b"]

 (peg-match ~(capture "a" :target) "a")
 # => @["a"]

 (peg-match ~(sequence (capture "a" :target)
                       (backref :target))
             "a")
 # => @["a" "a"]

 (peg-match ~(sequence (capture "a" :a)
                       (backref :a :b)
                       (backref :b))
             "a")
 # => @["a" "a" "a"]

 (peg-match ~(range "az") "c")
 # => @[]

 (peg-match ~(range "aa") "a")
 # => @[]

 (peg-match ~(capture (range "az")) "c")
 # => @["c"]

 (peg-match ~(capture (range "az" "AZ")) "J")
 # => @["J"]

 (peg-match :h "a")
 # => @[]

 (peg-match ~':h "a")
 # => @["a"]

 (peg-match :h "g")
 # => nil

 (peg-match :w "j")
 # => @[]

 (peg-match ~':w "j")
 # => @["j"]

 (peg-match :w " ")
 # => nil

 (peg-match ~(some "a") "")
 # => nil

 (peg-match ~(some "a") "a")
 # => @[]

 (peg-match ~'(some "a") "a")
 # => @["a"]

 (peg-match ~(some "a") "aa")
 # => @[]

 (peg-match ~'(some "a") "aa")
 # => @["aa"]

 (peg-match ~(some (range "az")) "j")
 # => @[]

 (peg-match ~'(some (range "az")) "j")
 # => @["j"]

 (peg-match ~'(some (range "az" "AZ")) "J")
 # => @["J"]

 (peg-match :a+ "J")
 # => @[]

 (peg-match ~':a+ "J")
 # => @["J"]

 (peg-match ~(any 1) "a")
 # => @[]

 (peg-match ~(capture (any 1)) "a")
 # => @["a"]

 (peg-match ~(capture (any 1)) "abc")
 # => @["abc"]

 (peg-match ~(capture (any 1)) "")
 # => @[""]

 (peg-match ~(capture :d*) "123")
 # => @["123"]

 (peg-match ~(capture (any (range "09"))) "123")
 # => @["123"]

 )

# XXX: hack for better naming
(def match peg-match)
