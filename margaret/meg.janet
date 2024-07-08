# XXX: perhaps janet's `scan-number` will eventually support a base
(defn- scan-number-base
  [num-str base]
  (assert (or (<= 2 base 36)
              (nil? base))
          (string/format "`%s` is not nil or between 2 and 36 inclusive"
                         base))
  (if (nil? base)
    (scan-number num-str)
    (scan-number (string base "r" num-str))))

# turn peg into table if needed
(defn tablify-peg
  [peg]
  (def peg-tbl
    (case (type peg)
      :boolean
      @{:main (if (true? peg)
                0
                '(not 0))}
      #
      :string
      @{:main peg}
      #
      :number
      (do
        (assert (int? peg)
                (string "number must be an integer: " peg))
        @{:main peg})
      #
      :keyword
      (do
        (assert (in default-peg-grammar peg)
                (string "default-peg-grammar does not have :" peg))
        @{:main peg})
      #
      :tuple
      @{:main peg}
      #
      :struct
      (do
        (assert (get peg :main)
                (string/format "missing :main in grammar: %p" peg))
        (struct/to-table peg))
      #
      :table
      (do
        (assert (get peg :main)
                (string/format "missing :main in grammar: %p" peg))
        peg)
      #
      (errorf "Unexpected type for peg %n: %n" peg (type peg))))
    #
    (table/setproto peg-tbl default-peg-grammar)
    #
    peg-tbl)

(comment

  (tablify-peg true)
  # =>
  @{:main 0}

  (tablify-peg "hello")
  # =>
  @{:main "hello"}

  (tablify-peg 3)
  # =>
  @{:main 3}

  (tablify-peg :s+)
  # =>
  @{:main :s+}

  (tablify-peg '(some 1))
  # =>
  @{:main '(some 1)}

  (tablify-peg {:main 1})
  # =>
  @{:main 1}

  (tablify-peg @{:main :sub
                 :sub "hello"})
  # =>
  @{:main :sub
    :sub "hello"}

  (get (tablify-peg 1) :a)
  # =>
  '(range "az" "AZ")

  (protect (tablify-peg 1.5))
  # =>
  [false "number must be an integer: 1.5"]

  (protect (tablify-peg :x))
  # =>
  [false "default-peg-grammar does not have :x"]

  (protect (tablify-peg {}))
  # =>
  [false "missing :main in grammar: {}"]

  (protect (tablify-peg @"hello"))
  # =>
  [false "Unexpected type for peg @\"hello\": :buffer"]

  (protect (tablify-peg +))
  # =>
  [false "Unexpected type for peg <function +>: :function"]

  )

(defn analyze
  [peg]
  (defn visit-peg
    [a-peg a-state]
    (defn assert-arity
      [argv n &opt limit]
      (def args (drop 1 argv))
      (default limit -1)
      (when (not (neg? limit))
        (assert (<= n limit)
                (string/format "n: %d not <= limit: %d" n limit)))
      (def num-args (length args))
      (if (neg? limit)
        (assert (>= num-args n)
                {:peg argv
                 :msg (string/format "needs >= %d arg(s)" n)})
        (assert (<= n num-args limit)
                {:peg argv
                 :msg (if (= n limit)
                        (string/format "needs exactly %d arg(s)" n)
                        (string/format "needs between %d and %d args"
                                       n limit))})))
    (defn check-range
      [the-peg the-state]
      (assert-arity the-peg 1)
      (assert (all |(and (string? $)
                         (= 2 (length $)))
                   (drop 1 the-peg))
              {:peg the-peg
               :msg "args should be length 2 strings"})
      (assert (all |(<= (get $ 0) (get $ 1))
                   (drop 1 the-peg))
              {:peg the-peg
               :msg "empty range detected"})
      the-state)
    (defn check-set
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (assert (string? (get the-peg 1))
              {:peg the-peg
               :msg "arg should be a string"})
      the-state)
    (defn check-look
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (assert (int? (get the-peg 1))
              {:peg the-peg
               :msg "1st arg should be an integer"})
      (if (= (length the-peg) 3)
        (merge the-state
               (visit-peg (get the-peg 2) the-state))
        the-state))
    (defn check-choice
      [the-peg the-state]
      # can have zero args
      # if any args exist, they should be pegs
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-sequence
      [the-peg the-state]
      # can have zero args
      # if any args exist, they should be pegs
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-if
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-if-not
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-not
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-thru
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-to
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-between
      [the-peg the-state]
      (assert-arity the-peg 3 3)
      (assert (nat? (get the-peg 1))
              {:peg the-peg
               :msg "1st arg should be a non-neg integer"})
      (assert (nat? (get the-peg 2))
              {:peg the-peg
               :msg "2nd arg should be a non-neg integer"})
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-opt
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-any
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-some
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-at-least
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (assert (nat? (get the-peg 1))
              {:peg the-peg
               :msg "1st arg should be a non-neg integer"})
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-at-most
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (assert (nat? (get the-peg 1))
              {:peg the-peg
               :msg "1st arg should be a non-neg integer"})
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-repeat
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (assert (nat? (get the-peg 1))
              {:peg the-peg
               :msg "1st arg should be a non-neg integer"})
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-backref
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (assert (all |(keyword? $) (drop 1 the-peg))
              {:peg the-peg
               :msg "args should be keywords"})
      (merge the-state {:has-backref true}))
    (defn check-position
      [the-peg the-state]
      (assert-arity the-peg 0 1)
      (assert (all |(keyword? $) (drop 1 the-peg))
              {:peg the-peg
               :msg "args should be keywords"})
      the-state)
    (defn check-line
      [the-peg the-state]
      (assert-arity the-peg 0 1)
      (assert (all |(keyword? $) (drop 1 the-peg))
              {:peg the-peg
               :msg "args should be keywords"})
      the-state)
    (defn check-column
      [the-peg the-state]
      (assert-arity the-peg 0 1)
      (assert (all |(keyword? $) (drop 1 the-peg))
              {:peg the-peg
               :msg "args should be keywords"})
      the-state)
    (defn check-argument
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (assert (and (nat? (get the-peg 1)))
              {:peg the-peg
               :msg "1st arg should be a non-neg integer"})
      (when (> (length the-peg) 2)
        (assert (keyword? (get the-peg 2))
                {:peg the-peg
                 :msg "2nd arg should be a keyword"}))
      the-state)
    (defn check-constant
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (when (> (length the-peg) 2)
        (assert (keyword? (get the-peg 2))
                {:peg the-peg
                 :msg "2nd arg should be a keyword"}))
      the-state)
    (defn check-capture
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (when (> (length the-peg) 2)
        (assert (keyword? (get the-peg 2))
                {:peg the-peg
                 :msg "2nd arg should be a keyword"}))
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-number
      [the-peg the-state]
      (assert-arity the-peg 1 3)
      (when (> (length the-peg) 2)
        (assert (or (nil? (get the-peg 2))
                    (and (int? (get the-peg 2))
                         (<= 2 (get the-peg 2) 36)))
                {:peg the-peg
                 :msg "2nd arg should be nil or an int between 2 and 36"}))
      (when (> (length the-peg) 3)
        (assert (keyword? (get the-peg 3))
                {:peg the-peg
                 :msg "third arg should be a keyword"}))
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-accumulate
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (when (> (length the-peg) 2)
        (assert (keyword? (get the-peg 2))
                {:peg the-peg
                 :msg "2nd arg should be a keyword"}))
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-drop
      [the-peg the-state]
      (assert-arity the-peg 1 1)
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-group
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (when (> (length the-peg) 2)
        (assert (keyword? (get the-peg 2))
                {:peg the-peg
                 :msg "2nd arg should be a keyword"}))
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-sub
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-split
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-replace
      [the-peg the-state]
      (assert-arity the-peg 2 3)
      (when (> (length the-peg) 3)
        (assert (keyword? (get the-peg 3))
                {:peg the-peg
                 :msg "3rd arg should be a keyword"}))
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-cmt
      [the-peg the-state]
      (assert-arity the-peg 2 3)
      (assert (get {:function true :cfunction true}
                   (type (get the-peg 2)))
              {:peg the-peg
               :msg "2nd arg should be a function"})
      (when (> (length the-peg) 3)
        (assert (keyword? (get the-peg 3))
                {:peg the-peg
                 :msg "3rd arg should be a keyword"}))
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    (defn check-error
      [the-peg the-state]
      (assert-arity the-peg 0 1)
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-backmatch
      [the-peg the-state]
      (assert-arity the-peg 0 1)
      (assert (all |(keyword? $) (drop 1 the-peg))
              {:peg the-peg
               :msg "args should be keywords"})
      (merge the-state {:has-backref true}))
    (defn check-lenprefix
      [the-peg the-state]
      (assert-arity the-peg 2 2)
      (merge the-state ;(map |(visit-peg $ the-state)
                             (drop 1 the-peg))))
    (defn check-readint
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (assert (and (int? (get the-peg 1))
                   (<= 0 (get the-peg 1) 8))
              {:peg the-peg
               :msg "1st arg should be an integer between 0 and 8"})
      (when (> (length the-peg) 2)
        (assert (keyword? (get the-peg 2))
                {:peg the-peg
                 :msg "2nd arg should be a keyword"}))
      the-state)
    (defn check-unref
      [the-peg the-state]
      (assert-arity the-peg 1 2)
      (when (> (length the-peg) 2)
        (assert (keyword? (get the-peg 2))
                {:peg the-peg
                 :msg "2nd arg should be a keyword"}))
      (merge the-state
             (visit-peg (get the-peg 1) the-state)))
    #
    (case (type a-peg)
      :boolean
      a-state
      #
      :string
      a-state
      #
      :number
      a-state
      #
      :keyword
      a-state
      #
      :tuple
      (let [op (first a-peg)]
        (assert (not (empty? a-peg))
                @{:peg a-peg
                  :msg "peg tuple must be non-empty"})
        (cond
          (int? op)
          (do
            (assert-arity a-peg 1 1)
            (assert (nat? op)
                    @{:peg a-peg
                      :msg "1st arg should be non-neg integer"})
            (merge a-state
                   (visit-peg (get a-peg 1) a-state)))
          (case op
            'range (check-range a-peg a-state)
            'set (check-set a-peg a-state)
            'look (check-look a-peg a-state)
            '> (check-look a-peg a-state)
            'choice (check-choice a-peg a-state)
            '+ (check-choice a-peg a-state)
            'sequence (check-sequence a-peg a-state)
            '* (check-sequence a-peg a-state)
            'if (check-if a-peg a-state)
            'if-not (check-if-not a-peg a-state)
            'not (check-not a-peg a-state)
            '! (check-not a-peg a-state)
            'thru (check-thru a-peg a-state)
            'to (check-to a-peg a-state)
            'between (check-between a-peg a-state)
            'opt (check-opt a-peg a-state)
            '? (check-opt a-peg a-state)
            'any (check-any a-peg a-state)
            'some (check-some a-peg a-state)
            'at-least (check-at-least a-peg a-state)
            'at-most (check-at-most a-peg a-state)
            'repeat (check-repeat a-peg a-state)
            'backref (check-backref a-peg a-state)
            '-> (check-backref a-peg a-state)
            'position (check-position a-peg a-state)
            '$ (check-position a-peg a-state)
            'line (check-line a-peg a-state)
            'column (check-column a-peg a-state)
            'argument (check-argument a-peg a-state)
            'constant (check-constant a-peg a-state)
            'capture (check-capture a-peg a-state)
            'quote (check-capture a-peg a-state)
            '<- (check-capture a-peg a-state)
            'number (check-number a-peg a-state)
            'accumulate (check-accumulate a-peg a-state)
            '% (check-accumulate a-peg a-state)
            'drop (check-drop a-peg a-state)
            'group (check-group a-peg a-state)
            'sub (check-sub a-peg a-state)
            'split (check-split a-peg a-state)
            'replace (check-replace a-peg a-state)
            '/ (check-replace a-peg a-state)
            'cmt (check-cmt a-peg a-state)
            'error (check-error a-peg a-state)
            'backmatch (check-backmatch a-peg a-state)
            'lenprefix (check-lenprefix a-peg a-state)
            'int (check-readint a-peg a-state)
            'int-be (check-readint a-peg a-state)
            'uint (check-readint a-peg a-state)
            'uint-be (check-readint a-peg a-state)
            'unref (check-unref a-peg a-state)
            (errorf "Unexpected tuple: %n" a-peg))))
      :struct
      (do
        (assert (get a-peg :main)
                {:peg a-peg
                 :msg "missing :main key"})
        (merge a-state ;(map |(visit-peg $ a-state)
                             (values a-peg))))
      :table
      (do
        (assert (get a-peg :main)
                {:peg a-peg
                 :msg "missing :main key"})
        (merge a-state ;(map |(visit-peg $ a-state)
                             (values a-peg))))
      # XXX: not sure if this is correct...
      (errorf "Unexpected type for peg %n: %n" a-peg (type a-peg))))
  #
  (try
    (let [results (visit-peg peg @{})]
      (if (get results :has-backref)
        results
        (put results :has-backref false)))
    ([e]
      @{:error e})))

(comment

  (analyze [])
  # =>
  '@{:error @{:msg "peg tuple must be non-empty"
              :peg ()}}

  (analyze 1)
  # =>
  @{:has-backref false}

  (analyze true)
  # =>
  @{:has-backref false}

  (analyze "hello")
  # =>
  @{:has-backref false}

  (analyze '[1 1])
  # =>
  @{:has-backref false}

  (analyze '[-1 :a])
  # =>
  '@{:error @{:msg "1st arg should be non-neg integer"
              :peg [-1 :a]}}

  (analyze '(range "az"))
  # =>
  @{:has-backref false}

  (analyze '(range "ba"))
  # =>
  '@{:error {:msg "empty range detected"
             :peg (range "ba")}}

  (analyze '(range))
  # =>
  '@{:error {:msg "needs >= 1 arg(s)"
             :peg (range)}}

  (analyze '(range "az" 1))
  # =>
  '@{:error {:msg "args should be length 2 strings"
             :peg (range "az" 1)}}

  (analyze '(range "az" "!"))
  # =>
  '@{:error {:msg "args should be length 2 strings"
             :peg (range "az" "!")}}

  (analyze '(set "a"))
  # =>
  @{:has-backref false}

  (analyze '(set))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (set)}}

  (analyze '(set 1))
  # =>
  '@{:error {:msg "arg should be a string"
             :peg (set 1)}}

  (analyze '(look -1 "a"))
  # =>
  @{:has-backref false}

  (analyze '(look -1 (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(look 1))
  # =>
  @{:has-backref false}

  (analyze '(look))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (look)}}

  (analyze '(look :a "a"))
  # =>
  '@{:error {:msg "1st arg should be an integer"
             :peg (look :a "a")}}

  (analyze '(choice))
  # =>
  @{:has-backref false}

  (analyze '(choice 2 1))
  # =>
  @{:has-backref false}

  (analyze '(choice 2 (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(sequence))
  # =>
  @{:has-backref false}

  (analyze '(sequence :a "i" 1))
  # =>
  @{:has-backref false}

  (analyze '(sequence "hello" (backref :a)))
  # =>
  @{:has-backref true}

  (analyze '(if 1 "a"))
  # =>
  @{:has-backref false}

  (analyze '(if 1 (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(if 2))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (if 2)}}

  (analyze '(if 2 "x" 1))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (if 2 "x" 1)}}

  (analyze '(if-not "a" 3))
  # =>
  @{:has-backref false}

  (analyze '(if-not 1 (backref :a)))
  # =>
  @{:has-backref true}

  (analyze '(if-not :x))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (if-not :x)}}

  (analyze '(not "a"))
  # =>
  @{:has-backref false}

  (analyze '(not (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(not))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (not)}}

  (analyze '(not :a :b))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (not :a :b)}}

  (analyze '(thru -1))
  # =>
  @{:has-backref false}

  (analyze '(thru (backref :2)))
  # =>
  @{:has-backref true}

  (analyze '(thru))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (thru)}}

  (analyze '(to 3))
  # =>
  @{:has-backref false}

  (analyze '(to (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(to))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (to)}}

  (analyze '(between 1 2 "x"))
  # =>
  @{:has-backref false}

  (analyze '(between 2 7 (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(between -1 2 "x"))
  # =>
  '@{:error {:msg "1st arg should be a non-neg integer"
             :peg (between -1 2 "x")}}

  (analyze '(between 2 -3 "y"))
  # =>
  '@{:error {:msg "2nd arg should be a non-neg integer"
             :peg (between 2 -3 "y")}}

  (analyze '(between))
  # =>
  '@{:error {:msg "needs exactly 3 arg(s)"
             :peg (between)}}

  (analyze '(opt 1))
  # =>
  @{:has-backref false}

  (analyze '(opt (backmatch :x)))
  # =>
  @{:has-backref true}

  (analyze '(opt))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (opt)}}

  (analyze '(some 2))
  # =>
  @{:has-backref false}

  (analyze '(some (backref :x :y)))
  # =>
  @{:has-backref true}

  (analyze '(some))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (some)}}

  (analyze '(at-least 2 :a))
  # =>
  @{:has-backref false}

  (analyze '(at-least 2 (-> :z)))
  # =>
  @{:has-backref true}

  (analyze '(at-least -3 "a"))
  # =>
  '@{:error {:msg "1st arg should be a non-neg integer"
             :peg (at-least -3 "a")}}

  (analyze '(at-least))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (at-least)}}

  (analyze '(at-most 1 "hi"))
  # =>
  @{:has-backref false}

  (analyze '(at-most 9 (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(at-most -8 1))
  # =>
  '@{:error {:msg "1st arg should be a non-neg integer"
             :peg (at-most -8 1)}}

  (analyze '(at-most))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (at-most)}}

  (analyze '(repeat 7 :a))
  # =>
  @{:has-backref false}

  (analyze '(repeat 2 (backref :x :y)))
  # =>
  @{:has-backref true}

  (analyze '(repeat -7 (capture 1)))
  # =>
  '@{:error {:msg "1st arg should be a non-neg integer"
             :peg (repeat -7 (capture 1))}}

  (analyze '(repeat))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (repeat)}}

  (analyze '(-> :a))
  # =>
  @{:has-backref true}

  (analyze '(backref :xyz))
  # =>
  @{:has-backref true}

  (analyze '(backref :a :b))
  # =>
  @{:has-backref true}

  (analyze '(backref :a :b :c))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (backref :a :b :c)}}

  (analyze '(position))
  # =>
  @{:has-backref false}

  (analyze '(position :c))
  # =>
  @{:has-backref false}

  (analyze '(position :i :j))
  # =>
  '@{:error {:msg "needs between 0 and 1 args"
             :peg (position :i :j)}}

  (analyze '(line))
  # =>
  @{:has-backref false}

  (analyze '(line :p))
  # =>
  @{:has-backref false}

  (analyze '(line :x :y :z))
  # =>
  '@{:error {:msg "needs between 0 and 1 args"
             :peg (line :x :y :z)}}

  (analyze '(column))
  # =>
  @{:has-backref false}

  (analyze '(column :mark))
  # =>
  @{:has-backref false}

  (analyze '(column :one :two :three))
  # =>
  '@{:error {:msg "needs between 0 and 1 args"
             :peg (column :one :two :three)}}

  (analyze '(argument 0))
  # =>
  @{:has-backref false}

  (analyze '(argument 0 :joseph))
  # =>
  @{:has-backref false}

  (analyze '(argument 1 :x :fun))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (argument 1 :x :fun)}}

  (analyze '(constant [:a :b :b]))
  # =>
  @{:has-backref false}

  (analyze '(constant {} :my-tag))
  # =>
  @{:has-backref false}

  # trick question
  (analyze '(constant (backmatch) :a))
  # =>
  @{:has-backref false}

  (analyze '(constant :jump 1))
  # =>
  '@{:error {:msg "2nd arg should be a keyword"
             :peg (constant :jump 1)}}

  (analyze '(constant @[:x :y] :a :b))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (constant @[:x :y] :a :b)}}

  (analyze '(capture :a))
  # =>
  @{:has-backref false}

  (analyze '(capture "abc" :a-tag))
  # =>
  @{:has-backref false}

  (analyze '(capture (backmatch) :woah))
  # =>
  @{:has-backref true}

  (analyze '(capture 1 :mark :tom))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (capture 1 :mark :tom)}}

  (analyze '(number :d))
  # =>
  @{:has-backref false}

  (analyze '(number :d 2))
  # =>
  @{:has-backref false}

  (analyze '(number :d+ 3 :tag))
  # =>
  @{:has-backref false}

  (analyze '(number :d+ nil :mark))
  # =>
  @{:has-backref false}

  (analyze '(number :d+ 0))
  # =>
  '@{:error {:msg "2nd arg should be nil or an int between 2 and 36"
             :peg (number :d+ 0)}}

  (analyze '(number :d nil 1))
  # =>
  '@{:error {:msg "third arg should be a keyword"
             :peg (number :d nil 1)}}

  (analyze '(number :d+ nil :jack :jill))
  # =>
  '@{:error {:msg "needs between 1 and 3 args"
             :peg (number :d+ nil :jack :jill)}}

  (analyze '(accumulate (sequence (capture 1)
                                  (capture 1))))
  # =>
  @{:has-backref false}

  (analyze ~(sequence (accumulate (sequence (capture "x")
                                            (capture "y"))
                                  :mark)
                      (backref :mark)))
  # =>
  @{:has-backref true}

  (analyze '(accumulate (sequence (capture 1)
                                  (capture 1))
                        :a
                        :b))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (accumulate (sequence (capture 1) (capture 1)) :a :b)}}

  (analyze '(drop (capture "a")))
  # =>
  @{:has-backref false}

  (analyze '(drop (backmatch)))
  # =>
  @{:has-backref true}

  (analyze '(drop))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (drop)}}

  (analyze '(drop :alice :bob))
  # =>
  '@{:error {:msg "needs exactly 1 arg(s)"
             :peg (drop :alice :bob)}}

  (analyze '(group (sequence (capture 1)
                             (capture 1))))
  # =>
  @{:has-backref false}

  (analyze ~(sequence (group (sequence (capture "x")
                                       (capture "y"))
                             :mark)
                      (backref :mark)))
  # =>
  @{:has-backref true}

  (analyze '(group (sequence (capture 1)
                             (capture 1))
                   :mark
                   :extra))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (group (sequence (capture 1) (capture 1)) :mark :extra)}}

  (analyze '(sub "xyz0" "xyz"))
  # =>
  @{:has-backref false}

  (analyze '(sub (capture 1 :x) (backref :x)))
  # =>
  @{:has-backref true}

  (analyze '(sub))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (sub)}}

  (analyze '(split "," (capture 1)))
  # =>
  @{:has-backref false}

  (analyze '(split (capture ";" :x) (backref :x)))
  # =>
  @{:has-backref true}

  (analyze '(split :alice :bob :carol))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (split :alice :bob :carol)}}

  (analyze '(replace (capture "turtle")
                     {"turtle" "tortoise"}))
  # =>
  '@{:has-backref false}

  (analyze '(replace (sequence (capture "turtle" :a)
                               (backref :a))
                     {"turtle" "tortoise"}))
  # =>
  @{:has-backref true}

  (analyze '(replace))
  # =>
  '@{:error {:msg "needs between 2 and 3 args"
             :peg (replace)}}

  (analyze '(replace (capture 1) :x))
  # =>
  @{:has-backref false}

  (analyze '(replace (capture "bat")
                     {"bat" "rodent"}
                     1))
  # =>
  '@{:error {:msg "3rd arg should be a keyword"
             :peg (replace (capture "bat") {"bat" "rodent"} 1)}}

  (analyze ~(cmt (capture 1) ,string?))
  # =>
  '@{:has-backref false}

  (analyze ~(cmt (sequence (capture "turtle" :a)
                           (backref :a))
                 ,buffer))
  # =>
  @{:has-backref true}

  (analyze '(cmt))
  # =>
  '@{:error {:msg "needs between 2 and 3 args"
             :peg (cmt)}}

  (analyze '(cmt (capture 1) :eve))
  '@{:error {:msg "2nd arg should be a function"
             :peg (cmt (capture 1) :eve)}}

  (analyze '(cmt (capture "the flag")
                 ,tuple
                 2r0010))
  # =>
  '@{:error {:msg "2nd arg should be a function"
             :peg (cmt (capture "the flag") (unquote tuple) 2)}}

  (analyze '(error))
  # =>
  @{:has-backref false}

  (analyze '(error (backmatch :a)))
  # =>
  @{:has-backref true}

  (analyze '(error :heckle :jeckle))
  # =>
  '@{:error {:msg "needs between 0 and 1 args"
             :peg (error :heckle :jeckle)}}

  (analyze '(backmatch))
  # =>
  @{:has-backref true}

  (analyze '(backmatch :a))
  # =>
  @{:has-backref true}

  (analyze '(backmatch :e :f))
  # =>
  '@{:error {:msg "needs between 0 and 1 args"
             :peg (backmatch :e :f)}}

  (analyze ~(lenprefix
              (replace (sequence (capture (any (if-not ":" 1)))
                                 ":")
                       ,scan-number)
              1))
  # =>
  @{:has-backref false}

  (analyze ~(sequence (number :d nil :tag)
                      (capture (lenprefix (backref :tag)
                                          1))))
  # =>
  @{:has-backref true}

  (analyze ~(lenprefix))
  # =>
  '@{:error {:msg "needs exactly 2 arg(s)"
             :peg (lenprefix)}}

  (analyze '(int 1))
  # =>
  @{:has-backref false}

  (analyze '(int 2 :a-tag))
  # =>
  @{:has-backref false}

  (analyze '(int))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (int)}}

  (analyze '(int 9))
  # =>
  '@{:error {:msg "1st arg should be an integer between 0 and 8"
             :peg (int 9)}}

  (analyze '(int-be 2))
  # =>
  @{:has-backref false}

  (analyze '(int-be 3 :x))
  # =>
  @{:has-backref false}

  (analyze '(int-be :a))
  # =>
  '@{:error {:msg "1st arg should be an integer between 0 and 8"
             :peg (int-be :a)}}

  (analyze '(int-be 10))
  # =>
  '@{:error {:msg "1st arg should be an integer between 0 and 8"
             :peg (int-be 10)}}

  (analyze '(uint 1))
  # =>
  @{:has-backref false}

  (analyze '(uint 5 :mark))
  # =>
  @{:has-backref false}

  (analyze '(uint 1 2))
  # =>
  '@{:error {:msg "2nd arg should be a keyword"
             :peg (uint 1 2)}}

  (analyze '(uint -1))
  # =>
  '@{:error {:msg "1st arg should be an integer between 0 and 8"
             :peg (uint -1)}}

  (analyze '(uint-be 3))
  # =>
  @{:has-backref false}

  (analyze '(uint 2 (backmatch)))
  # =>
  '@{:error {:msg "2nd arg should be a keyword"
             :peg (uint 2 (backmatch))}}

  (analyze '(uint-be math/inf))
  # =>
  '@{:error {:msg "1st arg should be an integer between 0 and 8"
             :peg (uint-be math/inf)}}

  (analyze ~{:main (sequence :thing -1)
             :thing (choice (unref (sequence :open :thing :close))
                            (capture (any (if-not "[" 1))))
             :open (capture (sequence "[" (some "_") "]")
                            :delim)
             :close (capture (backmatch :delim))})
  # =>
  @{:has-backref true}

  (analyze '(unref))
  # =>
  '@{:error {:msg "needs between 1 and 2 args"
             :peg (unref)}}

  (analyze '(unref :a 1))
  # =>
  '@{:error {:msg "2nd arg should be a keyword"
             :peg (unref :a 1)}}

  (analyze '{:main (some :sub)
             :sub (-> :b)})
  # =>
  @{:has-backref true}

  (analyze '@{:main (any :hello)
              :hello (backmatch)})
  # =>
  @{:has-backref true}

  (analyze {:a 1})
  # =>
  @{:error {:msg "missing :main key"
            :peg {:a 1}}}

  (analyze ~{:main (some :sub)
             :sub {:main :inner
                   :inner (choice "a"
                                  (sequence (choice :s
                                                    (backmatch :x)))
                                  1)}})
  # =>
  @{:has-backref true}

  (analyze '(split ":"
                   (sequence (backmatch :a) "b")))
  # =>
  @{:has-backref true}

  (analyze ~(sequence (number :d nil :tag)
                      (capture (lenprefix (backref :tag) 1))))
  # =>
  @{:has-backref true}

  )

(defn peg-init
  [argv &opt get-replace]
  (default get-replace false)
  (def ret @{})
  #
  (def argc (length argv))
  (assert (>= argc 2)
          (string/format "argv contains %n items, need at least 2" argc))
  (def min_ (if get-replace 3 2))
  (def arg-0 (get argv 0))
  # unwrap peg if wrapped in function
  (def non-fn-peg
    (if (function? arg-0)
      (arg-0)
      arg-0))
  (put-in ret [:state :grammar] non-fn-peg)
  (put ret :peg (tablify-peg non-fn-peg))
  #
  (def results (analyze non-fn-peg))
  (def err (get results :error))
  (assert (nil? err)
          (string/format "analysis error: %n" err))
  (def backref? (get results :has-backref))
  #
  (if get-replace
    (do
      (put ret :subst (get argv 1))
      (put ret :bytes (get argv 2)))
    (put ret :bytes (get argv 1)))
  #
  (if (> argc min_)
    (do
      # XXX: if more than min # of args, the arg after the min # is a
      #      starting offset
      (put-in ret [:state :start] (get argv min_))
      (put-in ret [:state :extrav] (slice argv (inc min_))))
    (do
      (put-in ret [:state :start] 0)
      (put-in ret [:state :extrav] @[])))
  #
  (-> ret
      # the text passed as an argument originally, e.g. to peg-match
      (put-in [:state :original-text] (get ret :bytes))
      # affects capturing behavior; :peg-mode-accumulate means use :scratch
      (put-in [:state :mode] :peg-mode-normal)
      # index position of the start of :original-text
      (put-in [:state :text-start] 0)
      # index position of the end of what's considered the current text;
      # this makes a difference when sub or split is being processed
      (put-in [:state :text-end] (length (get ret :bytes)))
      # index position of the end of :original-text
      (put-in [:state :outer-text-end] (get-in ret [:state :text-end]))
      # array of captures
      (put-in [:state :captures] @[])
      # array of captures corresponding to :tags
      (put-in [:state :tagged-captures] @[])
      # buffer for capturing context in mode :peg-mode-accumulate
      (put-in [:state :scratch] @"")
      # array of capture tags (keywords)
      (put-in [:state :tags] @[])
      # array of positions of newlines in :original-text
      (put-in [:state :linemap] @[])
      # number of newlines in :original-text
      (put-in [:state :linemaplen] -1)
      # whether the grammar uses certain ref constructs, see `analyze`
      (put-in [:state :has-backref] backref?))
  #
  ret)

(comment

  (def peg ~(some :d))

  (peg-init [peg "123"])
  # =>
  @{:bytes "123"
    :peg @{:main peg}
    :state @{:captures @[]
             :extrav @[]
             :grammar peg
             :has-backref false
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "123"
             :outer-text-end 3
             :scratch @""
             :start 0
             :tagged-captures @[]
             :tags @[]
             :text-end 3
             :text-start 0}}

  (peg-init [peg "123" 1 :hello :there])
  # =>
  @{:bytes "123"
    :peg @{:main '(some :d)}
    :state @{:captures @[]
             :extrav [:hello :there]
             :grammar peg
             :has-backref false
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "123"
             :outer-text-end 3
             :scratch @""
             :start 1
             :tagged-captures @[]
             :tags @[]
             :text-end 3
             :text-start 0}}

  (def peg-with-backref ~(backref :a))

  (peg-init [peg-with-backref "123"])
  # =>
  @{:bytes "123"
    :peg @{:main '(backref :a)}
    :state @{:captures @[]
             :extrav @[]
             :grammar peg-with-backref
             :has-backref true
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "123"
             :outer-text-end 3
             :scratch @""
             :start 0
             :tagged-captures @[]
             :tags @[]
             :text-end 3
             :text-start 0}}

  )

(defn state?
  [cand]
  (and (dictionary? cand)
       (has-key? cand :captures)
       (has-key? cand :extrav)
       (has-key? cand :grammar)
       (has-key? cand :has-backref)
       (has-key? cand :linemap)
       (has-key? cand :linemaplen)
       (has-key? cand :mode)
       (has-key? cand :original-text)
       (has-key? cand :outer-text-end)
       (has-key? cand :scratch)
       (has-key? cand :start)
       (has-key? cand :tagged-captures)
       (has-key? cand :tags)
       (has-key? cand :text-end)
       (has-key? cand :text-start)))

(comment

  (state? @{:captures @[]
             :extrav @[]
             :grammar ~(capture "a" :x)
             :has-backref true
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "123"
             :outer-text-end 3
             :scratch @""
             :start 0
             :tagged-captures @[]
             :tags @[]
             :text-end 3
             :text-start 0})
  # =>
  true

  (state? (get (peg-init [~(sequence "a" "b") "abc"])
               :state))
  # =>
  true

  )

########################################################################

(defn fake-readable
  [ds]
  (def readables
    (invert [:nil :boolean :number :symbol :keyword :string :buffer]))
  (defn helper
    [a-ds]
    (def the-type (type a-ds))
    (cond
      (get readables the-type)
      a-ds
      #
      (= :tuple the-type)
      (tuple ;(map helper a-ds))
      #
      (= :array the-type)
      (array ;(map helper a-ds))
      #
      (= :struct the-type)
      (table/to-struct (tabseq [[k v] :pairs a-ds]
                         (helper k) (helper v)))
      #
      (= :table the-type)
      (tabseq [[k v] :pairs a-ds]
        (helper k) (helper v))
      # otherwise use `describe`
      (describe a-ds)))
  #
  (helper ds))

(comment

  (fake-readable 1)
  # =>
  1

  (fake-readable {:a 1 :b 2})
  # =>
  {:a 1 :b 2}

  (fake-readable [:a :b :c])
  # =>
  [:a :b :c]

  (->> (fake-readable [(peg/compile "a") :b :c])
       first
       (string/has-prefix? "<core/peg "))
  # =>
  true

  (fake-readable '{:entry 0
                   :index 0
                   :peg (capture "a")
                   :grammar @{:main (capture "a")}
                   :state @{:captures @[]
                            :extrav ()
                            :has-backref false
                            :linemap @[]
                            :linemaplen -1
                            :mode :peg-mode-normal
                            :original-text "a"
                            :outer-text-end 1
                            :scratch @""
                            :tagged-captures @[]
                            :tags @[]
                            :text-end 1
                            :text-start 0}})
  # =>
  '{:entry 0
    :grammar @{:main (capture "a")}
    :index 0
    :peg (capture "a")
    :state @{:captures @[]
             :extrav ()
             :has-backref false
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "a"
             :outer-text-end 1
             :scratch @""
             :tagged-captures @[]
             :tags @[]
             :text-end 1
             :text-start 0}}

  (->> (get-in (fake-readable {:entry 0
                               :index 0
                               :peg '(capture "a")
                               :grammar '@{:main (capture "a")}
                               :state @{:captures @[]
                                        :extrav [(peg/compile "1")]
                                        #        ^^^^^^^^^^^^^^^^^
                                        :has-backref false
                                        :linemap @[]
                                        :linemaplen -1
                                        :mode :peg-mode-normal
                                        :original-text "a"
                                        :outer-text-end 1
                                        :scratch @""
                                        :tagged-captures @[]
                                        :tags @[]
                                        :text-end 1
                                        :text-start 0}})
               [:state :extrav 0])
       (string/has-prefix? "<core/peg "))
  # =>
  true

  )

(var step nil)
(def steps @[])
(var event-idx nil)

(defn reset-steps
  []
  (set step -1)
  (set event-idx -1)
  (array/clear steps)
  (array/push steps step))

(defn log-edge
  [this-step this-idx the-type & args]
  (when (os/getenv "VERBOSE")
    (def mt (dyn :meg-trace (file/temp)))
    (def spec
      (if (dyn :meg-color) "N" "n"))
    (xprin mt "{")
    (xprint mt ":idx" " " this-idx " ")
    (xprinf mt (string the-type " %" spec " ")
            this-step)
    (each arg args
      (if (and (tuple? arg) (= 2 (length arg)))
        (xprinf mt (string "%" spec " %" spec " ")
                ;(fake-readable arg))
        (xprinf mt (string "%" spec " ")
                arg)))
    (xprint mt "}")))

(defn log-entry
  [& args]
  (def this-step (++ step))
  (def this-idx (++ event-idx))
  (array/push steps this-step)
  (log-edge this-step this-idx ":entry" ;args))

(defn log-exit
  [& args]
  (def this-step (array/pop steps))
  (def this-idx (++ event-idx))
  (log-edge this-step this-idx ":exit" ;args))

(defn log
  [msg & args]
  (when (os/getenv "VERBOSE")
    (def mt (dyn :meg-trace (file/temp)))
    (xprintf mt msg ;args)))

(defmacro log-in
  []
  ~(log-entry [:index index] [:peg peg]
              [:grammar grammar] [:state state]))

(defmacro log-out
  []
  ~(log-exit [:ret (or ret :nil)]
             [:index index] [:peg peg]
             [:grammar grammar] [:state state]))

########################################################################

(defn cap-save
  [state]
  {:scratch (length (get state :scratch))
   :captures (length (get state :captures))
   :tagged-captures (length (get state :tagged-captures))})

(defn cap-load
  [state cs]
  (put state :scratch
       (buffer/slice (get state :scratch)
                     0 (get cs :scratch)))
  (put state :captures
       (array/slice (get state :captures)
                    0 (get cs :captures)))
  (put state :tags
       (array/slice (get state :tags)
                    0 (get cs :tagged-captures)))
  (put state :tagged-captures
       (array/slice (get state :tagged-captures)
                    0 (get cs :tagged-captures))))

(defn cap-load-keept
  [state cs]
  (put state :scratch
       (buffer/slice (get state :scratch)
                     0 (get cs :scratch)))
  (put state :captures
       (array/slice (get state :captures)
                    0 (cs :captures))))

(defn pushcap
  [state capture tag]
  (case (get state :mode)
    :peg-mode-accumulate
    (buffer/push (get state :scratch) (string capture))
    #
    :peg-mode-normal
    (array/push (get state :captures) capture)
    #
    (error (string "unrecognized mode: " (get state :mode))))
  #
  (when (get state :has-backref)
    (array/push (get state :tagged-captures) capture)
    (array/push (get state :tags) tag)))

(defn get-linecol-from-position
  [state position]
  (when (neg? (get state :linemaplen))
    (var nl-count 0)
    (def original-text (get state :original-text))
    (forv i (get state :text-start) (get state :outer-text-end)
      (let [ch (in original-text i)]
        (when (= ch (chr "\n"))
          (array/push (get state :linemap) i)
          (++ nl-count))))
    (put state :linemaplen nl-count))
  #
  (var hi (get state :linemaplen))
  (var lo 0)
  (while (< (inc lo) hi)
    (def mid
      (math/floor (+ lo (/ (- hi lo) 2))))
    (if (>= (get-in state [:linemap mid]) position)
      (set hi mid)
      (set lo mid)))
  (if (or (zero? (get state :linemaplen))
          (and (zero? lo)
               (>= (get-in state [:linemap 0]) position)))
    [1 (inc position)]
    [(+ lo 2) (- position (get-in state [:linemap lo]))]))

(defn check-params
  [state peg index grammar]
  (assert (state? state)
          (string/format "invalid state: %n" state))
  (assert (analyze peg) "analysis of peg failed")
  (assert (number? index) "index was not a number")
  (assert (analyze grammar) "analysis of grammar failed"))

(defn peg-rule
  [state peg index grammar]

  (when (dyn :meg-debug)
    (check-params state peg index grammar))

  (defn get-text
    [index]
    (string/slice (get state :original-text)
                  index (get state :text-end)))

  (cond
    # true / false
    (boolean? peg)
    (do
      (log-in)
      (def ret
        (if (true? peg)
          (peg-rule state 0 index grammar)
          (peg-rule state '(not 0) index grammar)))
      (log-out)
      ret)

    # keyword leads to a lookup in the grammar
    (keyword? peg)
    (do
      (log-in)
      (def ret
        (peg-rule state (get grammar peg) index grammar))
      (log-out)
      ret)

    # struct looks up the peg associated with :main
    (struct? peg)
    (do
      (log-in)
      (def ret
        (peg-rule state (get peg :main) index peg))
      (log-out)
      ret)

    # table looks up the peg associated with :main
    (table? peg)
    (do
      (log-in)
      (def ret
        (peg-rule state (get peg :main) index peg))
      (log-out)
      ret)

    # string is RULE_LITERAL
    (string? peg)
    (do
      (log-in)
      (def ret
        (when (string/has-prefix? peg (get-text index))
          (+ index (length peg))))
      (log-out)
      ret)

    # non-negative integer is RULE_NCHAR
    (nat? peg)
    (do
      (log-in)
      (def ret
        (when (<= peg (length (get-text index)))
          (+ index peg)))
      (log-out)
      ret)

    # negative integer is RULE_NOTNCHAR
    (and (int? peg) (neg? peg))
    (do
      (log-in)
      (def ret
        (when (not (<= (math/abs peg)
                       (length (get-text index))))
          index))
      (log-out)
      ret)

    #
    (tuple? peg)
    (do
      (def op (get peg 0))
      (def args (drop 1 peg))
      (cond
        # RULE_RANGE
        (= 'range op)
        (do
          (log-in)
          (def text (get-text index))
          (def ret
            (when (pos? (length text))
              (let [target-bytes
                    # if more than one thing in args, c version compiles
                    # as a set.  equivalent not done here.
                    (reduce (fn [acc elt]
                              (let [left (get elt 0)
                                    right (get elt 1)]
                                (array/concat acc
                                              (range left (inc right)))))
                            @[]
                            args)
                    target-set (string/from-bytes ;target-bytes)]
                (when (string/check-set target-set
                                        (string/slice text 0 1))
                  (+ index 1)))))
          (log-out)
          ret)

        # RULE_SET
        (= 'set op)
        (do
          (log-in)
          (def text (get-text index))
          (def patt (in args 0))
          (def ret
            (when (and (pos? (length text))
                       (string/check-set patt
                                         (string/slice text 0 1)))
              (+ index 1)))
          (log-out)
          ret)

        # RULE_LOOK
        (or (= 'look op)
            (= '> op))
        (do
          (log-in)
          (def offset (in args 0))
          (def ret
            (label result
              (let [text-start (get state :text-start)
                    text-end (get state :text-end)
                    new-start (+ index offset)]
                (when (or (< new-start text-start)
                          (> new-start text-end))
                  (return result nil))
                (if-let [patt (get args 1)]
                  (when (peg-rule state patt new-start grammar)
                    index)
                  (when (peg-rule state 0 offset grammar)
                    index)))))
          (log-out)
          ret)

        # RULE_CHOICE
        (or (= 'choice op)
            (= '+ op))
        (do
          (log-in)
          (def len (length args))
          (def ret
            (label result
              (when (zero? len)
                (return result nil))
              (def cs (cap-save state))
              (forv i 0 (dec len)
                (def sub-peg (get args i))
                (def res-idx (peg-rule state sub-peg index grammar))
                # XXX: should be ok?
                (when res-idx
                  (return result res-idx))
                (cap-load state cs))
              # instead of goto :args, make a call
              (peg-rule state (get args (dec len))
                        index grammar)))
          (log-out)
          ret)

        # RULE_SEQUENCE
        (or (= '* op)
            (= 'sequence op))
        (do
          (log-in)
          (def len (length args))
          (def ret
            (label result
              (when (zero? len)
                (return result index))
              (var cur-idx index)
              (var i 0)
              (while (and cur-idx
                          (< i (dec len)))
                (def sub-peg (get args i))
                (set cur-idx (peg-rule state sub-peg cur-idx grammar))
                (++ i))
              (when (not cur-idx)
                (return result nil))
              # instead of goto :args, make a call
              (when-let [last-idx
                         (peg-rule state (get args (dec len))
                                   cur-idx grammar)]
                last-idx)))
          (log-out)
          ret)

        # RULE_IF
        (= 'if op)
        (do
          (log-in)
          (def patt-a (in args 0))
          (def patt-b (in args 1))
          (def res-idx (peg-rule state patt-a index grammar))
          (def ret
            (when res-idx
              # instead of goto :args, make a call
              (peg-rule state patt-b index grammar)))
          (log-out)
          ret)

        # RULE_IFNOT
        (= 'if-not op)
        (do
          (log-in)
          (def patt-a (in args 0))
          (def patt-b (in args 1))
          (def cs (cap-save state))
          (def res-idx (peg-rule state patt-a index grammar))
          (def ret
            (when (not res-idx)
              (cap-load state cs)
              # instead of goto :args, make a call
              (peg-rule state patt-b index grammar)))
          (log-out)
          ret)

        # RULE_NOT
        (or (= 'not op)
            (= '! op))
        (do
          (log-in)
          (def patt (in args 0))
          (def cs (cap-save state))
          (def res-idx (peg-rule state patt index grammar))
          (def ret
            (when (not res-idx)
              (cap-load state cs)
              index))
          (log-out)
          ret)

        # RULE_THRU
        (= 'thru op)
        (do
          (log-in)
          (def patt (in args 0))
          (def cs (cap-save state))
          (def ret
            (label result
              (var next-idx nil)
              (var cur-idx index)
              (while (<= cur-idx (get state :text-end))
                (def cs2 (cap-save state))
                (set next-idx (peg-rule state patt cur-idx grammar))
                (when next-idx
                  (break))
                (cap-load state cs2)
                (++ cur-idx))
              (when (> cur-idx (get state :text-end))
                (cap-load state cs)
                (return result nil))
              (when next-idx
                next-idx)))
          (log-out)
          ret)

        # RULE_TO
        (= 'to op)
        (do
          (log-in)
          (def patt (in args 0))
          (def cs (cap-save state))
          (def ret
            (label result
              (var next-idx nil)
              (var cur-idx index)
              (while (<= cur-idx (get state :text-end))
                (def cs2 (cap-save state))
                (set next-idx (peg-rule state patt cur-idx grammar))
                (when next-idx
                  (cap-load state cs2)
                  (break))
                (cap-load state cs2)
                (++ cur-idx))
              (when (> cur-idx (get state :text-end))
                (cap-load state cs)
                (return result nil))
              (when next-idx
                cur-idx)))
          (log-out)
          ret)

        # RULE_BETWEEN
        (or (= 'between op)
            # XXX: might remove if analysis / rewrite path is taken
            (= 'opt op)
            (= '? op)
            (= 'any op)
            (= 'some op)
            (= 'at-least op)
            (= 'at-most op)
            (= 'repeat op)
            (int? op))
        (do
          (log-in)
          (var lo 0)
          (var hi 1)
          (var patt nil)
          (cond
            (= 'between op)
            (do
              (set lo (in args 0))
              (set hi (in args 1))
              (set patt (in args 2)))
            #
            (or (= 'opt op)
                (= '? op))
            (set patt (in args 0))
            #
            (= 'any op)
            (do
              (set patt (in args 0))
              # XXX: 2 ^ 32 - 1 not an integer...
              (set hi (math/pow 2 30)))
            #
            (= 'some op)
            (do
              (set patt (in args 0))
              (set lo 1)
              # XXX: 2 ^ 32 - 1 not an integer...
              (set hi (math/pow 2 30)))
            #
            (= 'at-least op)
            (do
              (set lo (in args 0))
              (set patt (in args 1))
              # XXX: 2 ^ 32 - 1 not an integer...
              (set hi (math/pow 2 30)))
            #
            (= 'at-most op)
            (do
              (set hi (in args 0))
              (set patt (in args 1)))
            #
            (= 'repeat op)
            (do
              (def arg (in args 0))
              (set patt (in args 1))
              (set lo arg)
              (set hi arg))
            #
            (int? op)
            (do
              (set patt (in args 0))
              (set lo op)
              (set hi op)))
          #
          (def cs (cap-save state))
          (def ret
            (label result
              (var captured 0)
              (var cur-idx index)
              (var next-idx nil)
              (while (< captured hi)
                (def cs2 (cap-save state))
                (set next-idx (peg-rule state patt cur-idx grammar))
                # match fail or no change in position
                (when (or (nil? next-idx)
                          (= next-idx cur-idx))
                  (cap-load state cs2)
                  (break))
                (++ captured)
                (set cur-idx next-idx))
              (when (< captured lo)
                (cap-load state cs)
                (return result nil))
              cur-idx))
          (log-out)
          ret)

        # RULE_GETTAG
        (or (= 'backref op)
            (= '-> op))
        (do
          (log-in)
          (def tag (in args 0))
          (def ret
            (label result
              (loop [i :down-to [(dec (length (get state :tags))) 0]]
                (let [cur-tag (get-in state [:tags i])]
                  (when (= cur-tag tag)
                    (pushcap state
                             (get-in state [:tagged-captures i]) tag)
                    (return result index))))
              # just being explicit
              nil))
          (log-out)
          ret)

        # RULE_POSITION
        (or (= 'position op)
            (= '$ op))
        (do
          (log-in)
          (def tag (when (next args) (in args 0)))
          (pushcap state
                   (- index (get state :text-start))
                   tag)
          (def ret index)
          (log-out)
          ret)

        # RULE_LINE
        (= 'line op)
        (do
          (log-in)
          (def tag (when (next args) (in args 0)))
          (def [line _]
            (get-linecol-from-position
              state
              (- index (get state :text-start))))
          (pushcap state line tag)
          (def ret index)
          (log-out)
          ret)

        # RULE_COLUMN
        (= 'column op)
        (do
          (log-in)
          (def tag (when (next args) (in args 0)))
          (def [_ col]
            (get-linecol-from-position
              state
              (- index (get state :text-start))))
          (pushcap state col tag)
          (def ret index)
          (log-out)
          ret)

        # RULE_ARGUMENT
        (= 'argument op)
        (do
          (log-in)
          (def patt (in args 0))
          (assert (< patt (length (get state :extrav)))
                  (string "expected smaller integer, got: " patt))
          (def tag (when (< 1 (length args)) (in args 1)))
          (def arg-n (in (get state :extrav) patt))
          (pushcap state arg-n tag)
          (def ret index)
          (log-out)
          ret)

        # RULE_CONSTANT
        (= 'constant op)
        (do
          (log-in)
          (def patt (in args 0))
          (def tag (when (< 1 (length args)) (in args 1)))
          (pushcap state patt tag)
          (def ret index)
          (log-out)
          ret)

        # RULE_CAPTURE
        (or (= 'capture op)
            (= 'quote op)
            (= '<- op))
        (do
          (log-in)
          (def patt (in args 0))
          (def tag (when (< 1 (length args)) (in args 1)))
          (def res-idx (peg-rule state patt index grammar))
          (def ret
            (when res-idx
              (let [cap (string/slice (get state :original-text)
                                      index res-idx)]
                (if (and (not (get state :has-backref))
                         (= (get state :mode) :peg-mode-accumulate))
                  (buffer/push (get state :scratch) cap)
                  (pushcap state cap tag)))
              res-idx))
          (log-out)
          ret)

        # RULE_CAPTURE_NUM
        (= 'number op)
        (do
          (log-in)
          (def patt (in args 0))
          (def base (when (< 1 (length args)) (in args 1)))
          (def tag (when (< 2 (length args)) (in args 2)))
          (def res-idx (peg-rule state patt index grammar))
          (def ret
            (when res-idx
              (let [cap (string/slice (get state :original-text)
                                      index res-idx)]
                (when-let [num (scan-number-base cap base)]
                  (if (and (not (get state :has-backref))
                           (= (get state :mode) :peg-mode-accumulate))
                    (buffer/push (get state :scratch) cap)
                    (pushcap state num tag))))
              res-idx))
          (log-out)
          ret)

        # RULE_ACCUMULATE
        (or (= 'accumulate op)
            (= '% op))
        (do
          (log-in)
          (def patt (in args 0))
          (def tag (when (< 1 (length args)) (in args 1)))
          (def old-mode (get state :mode))
          (when (and (not tag)
                     (= old-mode :peg-mode-accumulate))
            # instead of goto :args, make a call
            (peg-rule state patt index grammar))
          (def cs (cap-save state))
          (put state :mode :peg-mode-accumulate)
          (def res-idx (peg-rule state patt index grammar))
          (put state :mode old-mode)
          (def ret
            (when res-idx
              (def cap (string (get state :scratch)))
              (cap-load-keept state cs)
              (pushcap state cap tag)
              res-idx))
          (log-out)
          ret)

        # RULE_DROP
        (= 'drop op)
        (do
          (log-in)
          (def patt (in args 0))
          (def cs (cap-save state))
          (def res-idx (peg-rule state patt index grammar))
          (def ret
            (when res-idx
              (cap-load state cs)
              res-idx))
          (log-out)
          ret)

        # RULE_GROUP
        (= 'group op)
        (do
          (log-in)
          (def patt (in args 0))
          (def tag (when (< 1 (length args)) (in args 1)))
          (def old-mode (get state :mode))
          (def cs (cap-save state))
          (put state :mode :peg-mode-normal)
          (def res-idx (peg-rule state patt index grammar))
          (put state  :mode old-mode)
          (def ret
            (when res-idx
              (def cap
                # use only the new captures
                (array/slice (get state :captures)
                             (get cs :captures)))
              (cap-load-keept state cs)
              (pushcap state cap tag)
              res-idx))
          (log-out)
          ret)

        # RULE_SUB
        (= 'sub op)
        (do
          (log-in)
          (def text-start-index index)
          (def win-patt (in args 0))
          (def sub-patt (in args 1))
          (def ret
            (when-let [win-end
                       (peg-rule state win-patt index grammar)]
              (def saved-end (get state :text-end))
              (put state :text-end win-end)
              (def next-text
                (peg-rule state sub-patt text-start-index grammar))
              (put state :text-end saved-end)
              (when next-text
                win-end)))
          (log-out)
          ret)

        # RULE_SPLIT
        (= 'split op)
        (do
          (log-in)
          (def saved-end (get state :text-end))
          (def sep-patt (in args 0))
          (def sub-patt (in args 1))
          (var cur-idx index)
          (var sep-end nil)
          (def ret
            (label result
              (forever # not really
                (def text-start cur-idx)
                (def cs (cap-save state))
                (while (<= cur-idx (get state :text-end))
                  (set sep-end
                       (peg-rule state sep-patt cur-idx grammar))
                  (cap-load state cs)
                  (when sep-end
                    (break))
                  (++ cur-idx))
                #
                (when sep-end
                  (put state :text-end cur-idx)
                  (set cur-idx sep-end))
                #
                (def subpatt-end
                  (peg-rule state sub-patt text-start grammar))
                #
                (put state :text-end saved-end)
                #
                (when (nil? subpatt-end)
                  (return result nil))
                #
                (when (nil? sep-end)
                  (break)))
              # when loop broken out of via break...
              (get state :text-end)))
          (log-out)
          ret)

        # RULE_REPLACE
        (or (= 'replace op)
            (= '/ op))
        (do
          (log-in)
          (def patt (in args 0))
          (def subst (in args 1))
          (def tag (when (> (length args) 2) (in args 2)))
          (def old-mode (get state :mode))
          (def cs (cap-save state))
          (put state :mode :peg-mode-normal)
          (def res-idx (peg-rule state patt index grammar))
          (put state :mode old-mode)
          (def ret
            (when res-idx
              (def cap
                (cond
                  (dictionary? subst)
                  (get subst (last (get state :captures)))
                  #
                  (or (function? subst)
                      (cfunction? subst))
                  # use only the new captures
                  (subst ;(array/slice (get state :captures)
                                       (get cs :captures)))
                  #
                  subst))
              (cap-load-keept state cs)
              (pushcap state cap tag)
              res-idx))
          (log-out)
          ret)

        # RULE_MATCHTIME
        (= 'cmt op)
        (do
          (log-in)
          (def patt (in args 0))
          (def subst (in args 1))
          (def tag (when (> (length args) 2) (in args 2)))
          (def old-mode (get state :mode))
          (def cs (cap-save state))
          (put state :mode :peg-mode-normal)
          (def res-idx (peg-rule state patt index grammar))
          (put state :mode old-mode)
          (def ret
            (label result
              (when res-idx
                (def cap
                  # use only the new captures
                  (subst ;(array/slice (get state :captures)
                                       (get cs :captures))))
                (cap-load-keept state cs)
                (when (not (truthy? cap))
                  (return result nil))
                (pushcap state cap tag)
                res-idx)))
          (log-out)
          ret)

        # RULE_ERROR
        (= 'error op)
        (do
          (log-in)
          (def patt
            (if (empty? args)
              0 # determined via gdb
              (in args 0)))
          (def old-mode (get state :mode))
          (put state :mode :peg-mode-normal)
          (def old-cap (length (get state :captures)))
          (def res-idx (peg-rule state patt index grammar))
          (put state :mode old-mode)
          (def ret
            (when res-idx
              (if (> (length (get state :captures)) old-cap)
                (error (string (last (get state :captures))))
                (let [[line col]
                      (get-linecol-from-position
                        state
                        (- index (get state :text-start)))]
                  (errorf "match error at line %d, column %d" line col)))
              # XXX: should not get here
              nil))
          (log-out)
          ret)

        # RULE_BACKMATCH
        (= 'backmatch op)
        (do
          (log-in)
          (def text (get-text index))
          (def tag (when (next args) (in args 0)))
          (def ret
            (label result
              (loop [i :down-to [(dec (length (get state :tags))) 0]]
                (let [cur-tag (get-in state [:tags i])]
                  (when (= cur-tag tag)
                    (def cap
                      (get-in state [:tagged-captures i]))
                    (when (not (string? cap))
                      (return result nil))
                    #
                    (let [caplen (length cap)]
                      (when (> (+ (length text) caplen)
                               (get state :text-end))
                        (return result nil))
                      (return result
                              (when (string/has-prefix? cap text)
                                (+ index caplen)))))))
              # just being explicit
              nil))
          (log-out)
          ret)

        # RULE_LENPREFIX
        (= 'lenprefix op)
        (do
          (log-in)
          (def n-patt (in args 0))
          (def patt (in args 1))
          (def old-mode (get state :mode))
          (put state :mode :peg-mode-normal)
          (def cs (cap-save state))
          (def ret
            (label result
              (var next-idx (peg-rule state n-patt index grammar))
              (when (nil? next-idx)
                (return result nil))
              #
              (put state :mode old-mode)
              (def num-sub-caps
                (- (length (get state :captures))
                   (get cs :captures)))
              (var lencap nil)
              # XXX: is the condition below incomplete?
              (when (<= num-sub-caps 0)
                (cap-load state cs)
                (return result nil))
              # above and below here somewhat different from c
              (set lencap (get-in state
                                  [:captures (get cs :captures)]))
              (when (not (int? lencap))
                (cap-load state cs)
                (return result nil))
              #
              (def nrep lencap)
              (cap-load state cs)
              (forv i 0 nrep
                (set next-idx
                     (peg-rule state patt next-idx grammar))
                (when (nil? next-idx)
                  (cap-load state cs)
                  (return result nil)))
              next-idx))
          (log-out)
          ret)

        # RULE_READINT
        (or (= 'int op)
            (= 'int-be op)
            (= 'uint op)
            (= 'uint-be op))
        (do
          (log-in)
          (def text (get-text index))
          (def width (in args 0))
          (def tag (when (> (length args) 1) (in args 1)))
          (def ret
            (label result
              (when (> (+ index width)
                       (get state :text-end))
                (return result nil))
              (var accum nil)
              (cond
                (= 'int op)
                (do
                  (set accum
                       (if (> width 6) (int/s64 0) 0))
                  (loop [i :down-to [(dec width) 0]]
                    (set accum
                         (bor (blshift accum 8)
                              (get text i)))))
                #
                (= 'int-be op)
                (do
                  (set accum
                       (if (> width 6) (int/s64 0) 0))
                  (forv i 0 width
                    (set accum
                         (bor (blshift accum 8)
                              (get text i)))))
                #
                (= 'uint op)
                (do
                  (set accum
                       (if (> width 6) (int/u64 0) 0))
                  (loop [i :down-to [(dec width) 0]]
                    (set accum
                         (bor (blshift accum 8)
                              (get text i)))))
                #
                (= 'uint-be op)
                (do
                  (set accum
                       (if (> width 6) (int/u64 0) 0))
                  (forv i 0 width
                    (set accum
                         (bor (blshift accum 8)
                              (get text i))))))
              #
              (when (or (= 'int op)
                        (= 'int-be op))
                (def shift (* 8 (- 8 width)))
                (set accum
                     (brshift (blshift accum shift) shift)))
              (var capture-value accum)
              (pushcap state capture-value tag)
              width))
          (log-out)
          ret)

        # RULE_UNREF
        (= 'unref op)
        (do
          (log-in)
          (def rule (in args 0))
          (def tag (when (> (length args) 1) (in args 1)))
          (def tcap (length (get state :tags)))
          (def res-idx (peg-rule state rule index grammar))
          (def ret
            (label result
              (when (nil? res-idx)
                (return result nil))
              (def final-tcap (length (get state :tags)))
              (var w tcap)
              (when tag
                (forv i tcap final-tcap
                  (when (= tag (get-in state [:tags i]))
                    (put-in state [:tags w]
                            (get-in state [:tags i]))
                    (put-in state [:tagged-captures w]
                            (get-in state [:tagged-captures i]))
                    (++ w))))
              (put state :tags
                   (array/slice (get state :tags) 0 w))
              (put state :tagged-captures
                   (array/slice (get state :tagged-captures) 0 w))
              res-idx))
          (log-out)
          ret)

        #
        (errorf "unknown tuple op: %n" op)))
    #
    (errorf "unknown peg: %n" peg)))

(defn peg-match
  [peg text &opt start & args]
  (default start 0)
  (default args [])
  #
  (def peg-call (peg-init [peg text start ;args]))
  (def state (get peg-call :state))
  (def new-peg (get peg-call :peg))
  (def start-peg (get new-peg :main))
  #
  (setdyn :meg-trace (dyn :meg-trace stderr))
  (setdyn :meg-color (dyn :meg-color true))
  (reset-steps)
  (def result (peg-rule state start-peg start new-peg))
  #
  (when result (get state :captures)))

(comment

  (defn make-attrs
    [& items]
    (zipcoll [:bl :bc :el :ec]
             items))

  (defn atom-node
    [node-type peg-form]
    ~(cmt (capture (sequence (line) (column)
                             ,peg-form
                             (line) (column)))
          ,|[node-type (make-attrs ;(slice $& 0 -2)) (last $&)]))

  (defn reader-macro-node
    [node-type sigil]
    ~(cmt (capture (sequence (line) (column)
                             ,sigil
                             (any :non-form)
                             :form
                             (line) (column)))
          ,|[node-type (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
             ;(slice $& 2 -4)]))

  (defn collection-node
    [node-type open-delim close-delim]
    ~(cmt
       (capture
         (sequence
           (line) (column)
           ,open-delim
           (any :input)
           (choice ,close-delim
                   (error
                     (replace (sequence (line) (column))
                              ,|(string/format
                                  "line: %p column: %p missing %p for %p"
                                  $0 $1 close-delim node-type))))
           (line) (column)))
       ,|[node-type (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
          ;(slice $& 2 -4)]))

  (def loc-grammar
    ~@{:main (sequence (line) (column)
                       (some :input)
                       (line) (column))
       #
       :input (choice :non-form
                      :form)
       #
       :non-form (choice :whitespace
                         :comment
                         :discard)
       #
       :whitespace ,(atom-node :whitespace
                               '(choice (some (set " \0\f\t\v"))
                                        (choice "\r\n"
                                                "\r"
                                                "\n")))
       #
       :comment ,(atom-node :comment
                            '(sequence "#"
                                       (any (if-not (set "\r\n") 1))))
       #
       :discard
       (cmt (capture (sequence (line) (column)
                               "\\#"
                               (opt (sequence (any (choice :comment
                                                           :whitespace))
                                              :discard))
                               (any (choice :comment
                                            :whitespace))
                               :form
                               (line) (column)))
            ,|[:discard (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
               ;(slice $& 2 -4)])
       #
       :form (choice # reader macros
                     :fn
                     :quasiquote
                     :quote
                     :splice
                     :unquote
                     # collections
                     :array
                     :bracket-array
                     :tuple
                     :bracket-tuple
                     :table
                     :struct
                     # atoms
                     :number
                     :constant
                     :buffer
                     :string
                     :long-buffer
                     :long-string
                     :keyword
                     :symbol)
       #
       :fn ,(reader-macro-node :fn "|")
       #
       :quasiquote ,(reader-macro-node :quasiquote "~")
       #
       :quote ,(reader-macro-node :quote "'")
       #
       :splice ,(reader-macro-node :splice ";")
       #
       :unquote ,(reader-macro-node :unquote ",")
       #
       :array ,(collection-node :array "@(" ")")
       #
       :tuple ,(collection-node :tuple "(" ")")
       #
       :bracket-array ,(collection-node :bracket-array "@[" "]")
       #
       :bracket-tuple ,(collection-node :bracket-tuple "[" "]")
       #
       :table ,(collection-node :table "@{" "}")
       #
       :struct ,(collection-node :struct "{" "}")
       #
       :number ,(atom-node :number
                           ~(drop (cmt
                                    (capture (some :name-char))
                                    ,scan-number)))
       #
       :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                          (set "!$%&*+-./:<?=>@^_"))
       #
       :constant ,(atom-node :constant
                             '(sequence (choice "false" "nil" "true")
                                        (not :name-char)))
       #
       :buffer ,(atom-node :buffer
                           '(sequence `@"`
                                      (any (choice :escape
                                                   (if-not "\"" 1)))
                                      `"`))
       #
       :escape (sequence "\\"
                         (choice (set `"'0?\abefnrtvz`)
                                 (sequence "x" (2 :h))
                                 (sequence "u" (4 :h))
                                 (sequence "U" (6 :h))
                                 (error (constant "bad escape"))))
       #
       :string ,(atom-node :string
                           '(sequence `"`
                                      (any (choice :escape
                                                   (if-not "\"" 1)))
                                      `"`))
       #
       :long-string ,(atom-node :long-string
                                :long-bytes)
       #
       :long-bytes {:main (drop (sequence :open
                                          (any (if-not :close 1))
                                          :close))
                    :open (capture :delim :n)
                    :delim (some "`")
                    :close (cmt (sequence (not (look -1 "`"))
                                          (backref :n)
                                          (capture (backmatch :n)))
                                ,=)}
       #
       :long-buffer ,(atom-node :long-buffer
                                '(sequence "@" :long-bytes))
       #
       :keyword ,(atom-node :keyword
                            '(sequence ":"
                                       (any :name-char)))
       #
       :symbol ,(atom-node :symbol
                           '(some :name-char))
       })

  (peg-match loc-grammar
             (string "(defn my-fn\n"
                     "  [x]\n"
                     "  (math/pow x x))"))
  # =>
  @[1 1
    [:tuple
     @{:bc 1 :bl 1 :ec 18 :el 3}
     [:symbol @{:bc 2 :bl 1 :ec 6 :el 1} "defn"]
     [:whitespace @{:bc 6 :bl 1 :ec 7 :el 1} " "]
     [:symbol @{:bc 7 :bl 1 :ec 12 :el 1} "my-fn"]
     [:whitespace @{:bc 12 :bl 1 :ec 1 :el 2} "\n"]
     [:whitespace @{:bc 1 :bl 2 :ec 3 :el 2} "  "]
     [:bracket-tuple @{:bc 3 :bl 2 :ec 6 :el 2}
      [:symbol @{:bc 4 :bl 2 :ec 5 :el 2} "x"]]
     [:whitespace @{:bc 6 :bl 2 :ec 1 :el 3} "\n"]
     [:whitespace @{:bc 1 :bl 3 :ec 3 :el 3} "  "]
     [:tuple @{:bc 3 :bl 3 :ec 17 :el 3}
      [:symbol @{:bc 4 :bl 3 :ec 12 :el 3} "math/pow"]
      [:whitespace @{:bc 12 :bl 3 :ec 13 :el 3} " "]
      [:symbol @{:bc 13 :bl 3 :ec 14 :el 3} "x"]
      [:whitespace @{:bc 14 :bl 3 :ec 15 :el 3} " "]
      [:symbol @{:bc 15 :bl 3 :ec 16 :el 3} "x"]]]
    3 18]

  )

(defn peg-compile
  [peg]
  (fn [] peg))

(comment

  (peg-match (peg-compile ~(capture 1))
             "a")
  # =>
  @["a"]

  )

# XXX: hack for better naming

(def match peg-match)

(def compile peg-compile)
