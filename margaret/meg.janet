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

# janet.h
(def recursion-guard 1024)

# turn peg into table if needed
(defn tablify-peg
  [peg]
  (var peg-tbl @{})
  (case (type peg)
    :boolean
    (if (true? peg)
      (put peg-tbl :main 0)
      (put peg-tbl :main '(not 0)))
    #
    :string
    (put peg-tbl :main peg)
    #
    :number
    (do
      (assert (int? peg)
              (string "number must be an integer: " peg))
      (put peg-tbl :main peg))
    #
    :keyword
    (do
      (assert (in default-peg-grammar peg)
              (string "default-peg-grammar does not have :" peg))
      (put peg-tbl :main peg))
    #
    :tuple
    (put peg-tbl :main peg)
    #
    :struct
    (do
      (assert (get peg :main)
              (string/format "missing :main in grammar: %p" peg))
      (set peg-tbl (table ;(kvs peg))))
    #
    :table
    (do
      (assert (get peg :main)
              (string/format "missing :main in grammar: %p" peg))
      (set peg-tbl peg))
    #
    (errorf "Unexpected type for peg %n: %n" peg (type peg)))
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

(defn has-backref?
  [peg]
  (defn visit-peg
    [a-peg]
    (case (type a-peg)
      :boolean
      false
      #
      :string
      false
      #
      :number
      false
      #
      :keyword
      false
      #
      :tuple
      (let [head (first a-peg)]
        (cond
          (empty? a-peg)
          false
          #
          (get {'-> true
                'backref true
                'backmatch true}
               head)
          true
          #
          (or (get {'any true
                    'not true '! true
                    'some true
                    'thru true
                    'to true
                    'unref true
                    'opt true '? true
                    #
                    'accumulate true '% true
                    'capture true 'quote true '<- true
                    'cmt true
                    'drop true
                    'group true
                    'number true
                    'replace true '/ true}
                   head)
              (int? head))
          (visit-peg (get a-peg 1))
          #
          (get {'at-least true
                'at-most true
                'if true
                'if-not true
                'look true '> true
                'repeat true}
               head)
          (visit-peg (get a-peg 2))
          #
          (get {'between true}
               head)
          (visit-peg (get a-peg 3))
          #
          (get {'choice true '+ true
                'sequence true '* true}
               head)
          (some true? (map visit-peg (drop 1 a-peg)))
          #
          (get {'split true
                'sub true
                #
                'lenprefix true}
               head)
          (or (visit-peg (get a-peg 1))
              (visit-peg (get a-peg 2)))
          #
          (get {'error true}
               head)
          (if (> (length a-peg) 1)
            (visit-peg (get a-peg 1))
            false)
          #
          (get {'range true
                'set true
                #
                'argument true
                'column true
                'constant true
                'int true
                'int-be true
                'line true
                'position true '$ true
                'uint true
                'uint-be true}
               head)
          false
          #
          (errorf "Unexpected tuple: %n" a-peg)))
      #
      :struct
      (some true? (map visit-peg (values a-peg)))
      #
      :table
      (some true? (map visit-peg (values a-peg)))
      # XXX: not sure if this is correct...
      (errorf "Unexpected type for peg %n: %n" a-peg (type a-peg))))
  #
  (visit-peg peg))

(comment

  (has-backref? 1)
  # =>
  false

  (has-backref? true)
  # =>
  false

  (has-backref? "hello")
  # =>
  false

  (has-backref? '(-> :a))
  # =>
  true

  (has-backref? '(backref :xyz))
  # =>
  true

  (has-backref? '{:main (some :sub)
                  :sub (-> :b)})
  # =>
  true

  (has-backref? '@{:main (any :hello)
                   :hello (backmatch)})
  # =>
  true

  (has-backref? ~(some (backref :a)))
  # =>
  true

  (has-backref? ~{:main (some :sub)
                  :sub {:main :inner
                        :inner (choice "a"
                                       (sequence (choice :s
                                                         (backmatch :x)))
                                       1)}})
  # =>
  true

  (has-backref? '(split ":"
                        (sequence (backmatch :a) "b")))
  # =>
  true

  (has-backref? ~(sequence (number :d nil :tag)
                           (capture (lenprefix (backref :tag) 1))))
  # =>
  true

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
  (put ret :peg
       (tablify-peg non-fn-peg))
  (def backref? (has-backref? non-fn-peg))
  #
  (def arg-1 (get argv 1))
  (if get-replace
    (do
      (put ret :subst arg-1)
      (put ret :bytes (get argv 2)))
    (put ret :bytes arg-1))
  (put-in ret [:state :original-text] (get ret :bytes))
  (if (> argc min_)
    (do
      # XXX: if more than min # of args, the arg after the min # is a
      #      starting offset
      (put ret :start (get argv min_))
      (put-in ret [:state :extrav] (slice argv (inc min_))))
    (do
      (put ret :start 0)
      (put-in ret [:state :extrav] @[])))
  (put-in ret [:state :mode] :peg-mode-normal)
  (put-in ret [:state :text-start] 0)
  (put-in ret [:state :text-end] (length (get ret :bytes)))
  (put-in ret [:state :outer-text-end] (get-in ret [:state :text-end]))
  (put-in ret [:state :depth] recursion-guard)
  (put-in ret [:state :captures] @[])
  (put-in ret [:state :tagged-captures] @[])
  (put-in ret [:state :scratch] @"")
  # XXX: use an array for tags instead
  (put-in ret [:state :tags] @[])
  (put-in ret [:state :linemap] @[])
  (put-in ret [:state :linemaplen] -1)
  (put-in ret [:state :has-backref] backref?)
  #
  ret)

(comment

  (def peg ~(some :d))

  (peg-init [peg "123"])
  # =>
  @{:bytes "123"
    :peg @{:main peg}
    :state @{:captures @[]
             :depth 1024
             :extrav @[]
             :has-backref false
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "123"
             :outer-text-end 3
             :scratch @""
             :tagged-captures @[]
             :tags @[]
             :text-end 3
             :text-start 0}
    :start 0}

  (peg-init [peg "123" 1 :hello :there])
  # =>
  @{:bytes "123"
    :peg @{:main '(some :d)}
    :state @{:captures @[]
             :depth 1024
             :extrav [:hello :there]
             :has-backref false
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "123"
             :outer-text-end 3
             :scratch @""
             :tagged-captures @[]
             :tags @[]
             :text-end 3
             :text-start 0}
    :start 1}

  (def peg-with-backref ~(backref :a))

  (peg-init [peg-with-backref "123"])
  # =>
  @{:bytes "123"
    :peg @{:main '(backref :a)}
    :state @{:captures @[]
             :depth 1024
             :extrav @[]
             :has-backref true
             :linemap @[]
             :linemaplen -1
             :mode :peg-mode-normal
             :original-text "123"
             :outer-text-end 3
             :scratch @""
             :tagged-captures @[]
             :tags @[]
             :text-end 3
             :text-start 0}
    :start 0}

  )

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
    (def nl-char (chr "\n"))
    (def original-text (get state :original-text))
    (forv i (get state :text-start) (get state :outer-text-end)
      (let [ch (in original-text i)]
        (when (= ch nl-char)
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

(defn log-entry [& args]
  (when (os/getenv "VERBOSE")
    (eprintf "entry: %n" args)))

(defn log [msg & args]
  (when (os/getenv "VERBOSE")
    (eprintf msg ;args)))

(defn log-exit [& args]
  (when (os/getenv "VERBOSE")
    (eprintf "exit: %n" args)))

(defn peg-rule
  [state peg index grammar]

  # XXX
  (log "")
  (log ":state: %M" state)
  (log ":peg: %n" peg)
  (log ":index: %n" index)
  (log ":grammar: %n" grammar)

  (cond
    # non-negative integer is RULE_NCHAR
    (nat? peg)
    (do
      (log-entry "RULE_NCHAR" peg index grammar)
      (def text
        (string/slice (get state :original-text)
                      index (get state :text-end)))
      (def ret
        (when (<= peg (length text))
          (+ index peg)))
      (log-exit "RULE_NCHAR" ret {:peg peg :index index})
      ret)
    # string is RULE_LITERAL
    (string? peg)
    (do
      (log-entry "RULE_LITERAL" peg index grammar)
      (def text
        (string/slice (get state :original-text)
                      index (get state :text-end)))
      (def ret
        (when (string/has-prefix? peg text)
          (+ index (length peg))))
      (log-exit "RULE_LITERAL" ret {:peg peg :index index})
      ret)
    # true / false
    (boolean? peg)
    (do
      (log-entry "BOOLEAN" peg index grammar)
      (def ret
        (when-let [result (if (true? peg)
                            (peg-rule state 0 index grammar)
                            (peg-rule state '(not 0) index grammar))]
          result))
      (log-exit "BOOLEAN" ret {:peg peg :index index})
      ret)
    # keyword leads to a lookup in the grammar
    (keyword? peg)
    (do
      (log-entry "KEYWORD" peg index grammar)
      (def ret
        (when-let [result
                   (peg-rule state (get grammar peg) index grammar)]
          # XXX
          #(+ index result)
          result
          ))
      (log-exit "KEYWORD" ret {:peg peg :index index})
      ret)
    # negative integer is RULE_NOTNCHAR
    (and (int? peg)
         (neg? peg))
    (do
      (log-entry "RULE_NOTNCHAR" peg index grammar)
      (def text
        (string/slice (get state :original-text)
                      index (get state :text-end)))
      (def ret
        (when (not (<= (math/abs peg)
                       (length text)))
          index))
      (log-exit "RULE_NOTNCHAR" ret {:peg peg :index index})
      ret)
    # struct looks up the peg associated with :main
    (struct? peg)
    (do
      (log-entry "STRUCT" peg index grammar)
      (assert (get peg :main)
              "peg does not have :main")
      (def ret
        (when-let [result (peg-rule state (get peg :main) index peg)]
          #(+ index result)
          result
          ))
      (log-exit "STRUCT" ret {:peg peg :index index})
      ret)
    # table looks up the peg associated with :main
    (table? peg)
    (do
      (log-entry "TABLE" peg index grammar)
      (assert (get peg :main)
              "peg does not have :main")
      (def ret
        (when-let [result (peg-rule state (get peg :main) index peg)]
          #(+ index result)
          result
          ))
      (log-exit "TABLE" ret {:peg peg :index index})
      ret)
    #
    (tuple? peg)
    (do
      (assert (pos? (length peg))
              "peg must have non-zero length")
      (def op (get peg 0))
      (def tail (drop 1 peg))
      # XXX: many more to go
      (cond
        # RULE_SET
        (= 'set op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def text
            (string/slice (get state :original-text)
                          index (get state :text-end)))
          (def patt (in tail 0))
          (def ret
            (when (and (pos? (length text))
                       (string/check-set patt
                                         (string/slice text 0 1)))
              (+ index 1)))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_RANGE
        (= 'range op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def text
            (string/slice (get state :original-text)
                          index (get state :text-end)))
          (def ret
            (when (pos? (length text))
              (let [target-bytes
                    # if more than one thing in tail, c version compiles
                    # as a set.  we're not currently doing that here.
                    (reduce (fn [acc elt]
                              (assert (= 2 (length elt))
                                      "`range` argument must be length 2")
                              (let [left (get elt 0)
                                    right (get elt 1)]
                                (assert (<= left right) "empty range")
                                (array/concat acc
                                              (range left (inc right)))))
                            @[]
                            tail)
                    target-set (string/from-bytes ;target-bytes)]
                (when (string/check-set target-set
                                        (string/slice text 0 1))
                  (+ index 1)))))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_SUB
        (= 'sub op)
        (do
          (log-entry op peg index grammar)
          (assert (not (< (length tail) 2))
                  (string/format "`%s` requires at least 2 arguments"
                                 (string op)))
          (def text-start-index index)
          (def win-patt (in tail 0))
          (def sub-patt (in tail 1))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_CAPTURE
        (or (= 'capture op)
            (= 'quote op)
            (= '<- op))
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (def tag (when (< 1 (length tail)) (in tail 1)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_SEQUENCE
        (or (= '* op)
            (= 'sequence op))
        (do
          (log-entry op peg index grammar)
          (def len (length tail))
          (def ret
            (label result
              (when (zero? len)
                (return result index))
              (var cur-idx index)
              (var i 0)
              (while (and cur-idx
                          (< i (dec len)))
                (def sub-peg (get tail i))
                (set cur-idx (peg-rule state sub-peg cur-idx grammar))
                (++ i))
              (when (not cur-idx)
                (return result nil))
              # instead of goto :tail, make a call
              (when-let [last-idx
                         (peg-rule state (get tail (dec len))
                                   cur-idx grammar)]
                last-idx)))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_CONSTANT
        (= 'constant op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (def tag (when (< 1 (length tail)) (in tail 1)))
          (pushcap state patt tag)
          (def ret index)
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_GETTAG
        (or (= 'backref op)
            (= '-> op))
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def tag (in tail 0))
          (def ret
            (label result
              (loop [i :down-to [(dec (length (get state :tags))) 0]]
                (let [cur-tag (get-in state [:tags i])]
                  (when (= cur-tag tag)
                    (pushcap state
                             (get-in state [:tagged-captures i]) tag)
                    (return result index))))
              nil))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_POSITION
        (or (= 'position op)
            (= '$ op))
        (do
          (log-entry op peg index grammar)
          (def tag (when (next tail) (in tail 0)))
          (pushcap state
                   (- index (get state :text-start))
                   tag)
          (def ret index)
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_LINE
        (= 'line op)
        (do
          (log-entry op peg index grammar)
          (def tag (when (next tail) (in tail 0)))
          (def [line _]
            (get-linecol-from-position
              state
              (- index (get state :text-start))))
          (pushcap state line tag)
          (def ret index)
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_COLUMN
        (= 'column op)
        (do
          (log-entry op peg index grammar)
          (def tag (when (next tail) (in tail 0)))
          (def [_ col]
            (get-linecol-from-position
              state
              (- index (get state :text-start))))
          (pushcap state col tag)
          (def ret index)
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_ERROR
        (= 'error op)
        (do
          (log-entry op peg index grammar)
          (def patt
            (if (empty? tail)
              0 # determined via gdb
              (in tail 0)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_BACKMATCH
        (= 'backmatch op)
        (do
          (log-entry op peg index grammar)
          (def text
            (string/slice (get state :original-text)
                          index (get state :text-end)))
          (def tag (when (next tail) (in tail 0)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_LOOK
        (or (= 'look op)
            (= '> op))
        (do
          (log-entry op peg index grammar)
          (assert (>= (length tail) 2)
                  (string/format "`%s` requires at least 2 arguments"
                                 (string op)))
          (def offset (in tail 0))
          (assert (int? offset)
                  "offset argument should be an integer")
          # XXX: can the call to peg-rule below lead to unwanted
          #      outcomes?  in peg.c, text (effectively an index) is
          #      incremented first, then peg_rule is called, and
          #      finally text is decremented...specifically if
          #      peg_rule calls something with `sub` or `split` in
          #      it, quite unsure if things will be ok...
          (def ret
            (label result
              (let [text-end (get state :text-end)
                    new-start (+ index offset)]
                (when (or (< new-start 0)
                          (> new-start text-end))
                  (return result nil))
                (def patt (in tail 1))
                (when (peg-rule state patt new-start grammar)
                  index))))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_TO
        (= 'to op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_THRU
        (= 'thru op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
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
          (log-exit op ret {:peg peg :index index})
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
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (var lo 0)
          (var hi 1)
          (var patt nil)
          (cond
            (= 'between op)
            (do
              (assert (<= 3 (length tail))
                      "`between` requires at least 3 arguments")
              (set lo (in tail 0))
              (assert (nat? lo)
                      (string "expected non-neg int, got: " lo))
              (set hi (in tail 1))
              (assert (nat? hi)
                      (string "expected non-neg int, got: " hi))
              (set patt (in tail 2)))
            #
            (or (= 'opt op)
                (= '? op))
            (set patt (in tail 0))
            #
            (= 'any op)
            (do
              (set patt (in tail 0))
              # XXX: 2 ^ 32 - 1 not an integer...
              (set hi (math/pow 2 30)))
            #
            (= 'some op)
            (do
              (set patt (in tail 0))
              (set lo 1)
              # XXX: 2 ^ 32 - 1 not an integer...
              (set hi (math/pow 2 30)))
            #
            (= 'at-least op)
            (do
              (assert (<= 2 (length tail))
                      "`at-least` requires at least 2 arguments")
              (set lo (in tail 0))
              (set patt (in tail 1))
              (assert (nat? lo)
                      (string "expected non-neg int, got: " lo))
              # XXX: 2 ^ 32 - 1 not an integer...
              (set hi (math/pow 2 30)))
            #
            (= 'at-most op)
            (do
              (assert (<= 2 (length tail))
                      "`at-most` requires at least 2 arguments")
              (set hi (in tail 0))
              (set patt (in tail 1))
              (assert (nat? hi)
                      (string "expected non-neg int, got: " hi)))
            #
            (= 'repeat op)
            (do
              (assert (<= 2 (length tail))
                      "`repeat` requires at least 2 arguments")
              (def arg (in tail 0))
              (set patt (in tail 1))
              (assert (nat? arg)
                      (string "expected non-neg int, got: " arg))
              (set lo arg)
              (set hi arg))
            #
            (int? op)
            (do
              (assert (next tail)
                      "`n` requires at least 1 argument")
              (set patt (in tail 0))
              (assert (nat? op)
                      (string "expected non-neg int, got: " op))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_READINT
        (or (= 'int op)
            (= 'int-be op)
            (= 'uint op)
            (= 'uint-be op))
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def text
            (string/slice (get state :original-text)
                          index (get state :text-end)))
          (def width (in tail 0))
          (def tag (when (> (length tail) 1) (in tail 1)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_CHOICE
        (or (= 'choice op)
            (= '+ op))
        (do
          (log-entry op peg index grammar)
          (def len (length tail))
          (def ret
            (label result
              (when (zero? len)
                (return result nil))
              (def cs (cap-save state))
              (forv i 0 (dec len)
                (def sub-peg (get tail i))
                (def res-idx (peg-rule state sub-peg index grammar))
                # XXX: should be ok?
                (when res-idx
                  (return result res-idx))
                (cap-load state cs))
              (peg-rule state (get tail (dec len))
                        index grammar)))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_SPLIT
        (= 'split op)
        (do
          (log-entry op peg index grammar)
          (def saved-end (get state :text-end))
          (def sep-patt (in tail 0))
          (def sub-patt (in tail 1))
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

                (when sep-end
                  (put state :text-end cur-idx)
                  (set cur-idx sep-end))

                (def subpatt-end
                  (peg-rule state sub-patt text-start grammar))

                (put state :text-end saved-end)

                (when (nil? subpatt-end)
                  (return result nil))

                (when (nil? sep-end)
                  (break)))
              # when loop broken out of via break...
              (get state :text-end)))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_IF
        (= 'if op)
        (do
          (log-entry op peg index grammar)
          (assert (>= (length tail) 2)
                  (string/format "`%s` requires at least 2 arguments"
                                 (string op)))
          (def patt-a (in tail 0))
          (def patt-b (in tail 1))
          (def res-idx (peg-rule state patt-a index grammar))
          (def ret
            (when res-idx
              (peg-rule state patt-b index grammar)))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_NOT
        (or (= 'not op)
            (= '! op))
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (def cs (cap-save state))
          (def res-idx (peg-rule state patt index grammar))
          (def ret
            (when (not res-idx)
              (cap-load state cs)
              index))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_MATCHTIME
        (= 'cmt op)
        (do
          (log-entry op peg index grammar)
          (assert (not (< (length tail) 2))
                  (string/format "`%s` requires at least 2 arguments"
                                 (string op)))
          (def patt (in tail 0))
          (def subst (in tail 1))
          (assert (or (function? subst)
                      (cfunction? subst))
                  (string "expected a function, got: " (type subst)))
          (def tag (when (> (length tail) 2) (in tail 2)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_DROP
        (= 'drop op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (def cs (cap-save state))
          (def res-idx (peg-rule state patt index grammar))
          (def ret
            (when res-idx
              (cap-load state cs)
              res-idx))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_IFNOT
        (= 'if-not op)
        (do
          (log-entry op peg index grammar)
          (assert (>= (length tail) 2)
                  (string/format "`%s` requires at least 2 arguments"
                                 (string op)))
          (def patt-a (in tail 0))
          (def patt-b (in tail 1))
          (def cs (cap-save state))
          (def res-idx (peg-rule state patt-a index grammar))
          (def ret
            (when (not res-idx)
              (cap-load state cs)
              (peg-rule state patt-b index grammar)))
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_REPLACE
        (or (= 'replace op)
            (= '/ op))
        (do
          (log-entry op peg index grammar)
          (assert (not (< (length tail) 2))
                  (string/format "`%s` requires at least 2 arguments"
                                 (string op)))
          (def patt (in tail 0))
          (def subst (in tail 1))
          (def tag (when (> (length tail) 2) (in tail 2)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_CAPTURE_NUM
        (= 'number op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (def base (when (< 1 (length tail)) (in tail 1)))
          (def tag (when (< 2 (length tail)) (in tail 2)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_LENPREFIX
        (= 'lenprefix op)
        (do
          (log-entry op peg index grammar)
          (assert (not (< (length tail) 2))
                  (string/format "`%s` requires at least 2 arguments"
                                 (string op)))
          (def n-patt (in tail 0))
          (def patt (in tail 1))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_GROUP
        (= 'group op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (def tag (when (< 1 (length tail)) (in tail 1)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_UNREF
        (= 'unref op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def rule (in tail 0))
          (def tag (when (> (length tail) 1) (in tail 1)))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_ACCUMULATE
        (or (= 'accumulate op)
            (= '% op))
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (def tag (when (< 1 (length tail)) (in tail 1)))
          (def old-mode (get state :mode))
          (when (and (not tag)
                     (= old-mode :peg-mode-accumulate))
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
          (log-exit op ret {:peg peg :index index})
          ret)
        # RULE_ARGUMENT
        (= 'argument op)
        (do
          (log-entry op peg index grammar)
          (assert (next tail)
                  (string/format "`%s` requires at least 1 argument"
                                 (string op)))
          (def patt (in tail 0))
          (assert (nat? patt)
                  (string "expected non-negative integer, got: " patt))
          # XXX: could use (get state :extrac)?
          (assert (< patt (length (get state :extrav)))
                  (string "expected smaller integer, got: " patt))
          (def tag (when (< 1 (length tail))
                     (in tail 1)))
          (def arg-n (in (get state :extrav) patt))
          (pushcap state arg-n tag)
          (def ret index)
          (log-exit op ret {:peg peg :index index})
          ret)
        #
        (errorf "unknown tuple op: %n" op)))
    #
    (errorf "unknown peg: %n" peg)))

(defn peg-match
  [peg text &opt start & args]
  (default start 0)
  (default args [])
  (def peg-call (peg-init [peg text start ;args]))
  (def state (get peg-call :state))
  (def new-peg (get peg-call :peg))
  (def start-peg (get new-peg :main))
  #
  (def result (peg-rule state start-peg start new-peg))
  #
  (when result (get state :captures)))

(comment

  (peg-match 1 "abc")
  # =>
  @[]

  (peg-match 1 "abc" 1 :hola)
  # =>
  @[]

  (peg-match "a" "abc")
  # =>
  @[]

  (peg-match '(set "a") "abc")
  # =>
  @[]

  (peg-match '(set "d") "abc")
  # =>
  nil

  (peg-match '{:main :sub
               :sub {:main :inner
                     :inner 1}}
             "abc")
  # =>
  @[]

  (peg-match '(range "ac") "abc")
  # =>
  @[]

  (peg-match :a "abc")
  # =>
  @[]

  (peg-match ~(sub "abcd" "abc")
             "abcdef")
  # =>
  @[]

  (peg-match ~(sub "abcd" "abcde")
             "abcdef")
  # =>
  nil

  (peg-match ~(sub "x" "abc")
             "abcdef")
  # =>
  nil

  (peg-match ~(sub "abc" "x")
             "abcdef")
  # =>
  nil

  (peg-match ~(capture 1) "a")
  # =>
  @["a"]

  (peg-match ~(sub (capture "abcd") (capture "abc"))
             "abcdef")
  # =>
  @["abcd" "abc"]

  (peg-match ~(sequence "a" "b" "c") "abc")
  # =>
  @[]

  (peg-match ~(sequence (capture 1 :a) (capture 1) (capture 1 :c))
             "abc")
  # =>
  @["a" "b" "c"]

  (peg-match ~(constant "smile")
             "whatever")
  # =>
  @["smile"]

  (peg-match ~(sequence (capture 1 :a)
                        (backref :a))
             "a")
  # =>
  @["a" "a"]

  (peg-match ~(sequence (constant 5 :tag)
                        (sub (capture "abc" :tag)
                             (backref :tag)))
             "abcdef")
  # =>
  @[5 "abc" "abc"]

  (peg-match ~(sub "abc" (sequence "abc" -1))
             "abcdef")
  # =>
  @[]

  (peg-match ~(position) "a")
  # =>
  @[0]

  (peg-match ~(line)
             "a")
  # =>
  @[1]

  (peg-match ~(column)
             "a")
  # =>
  @[1]

  (peg-match ~(sequence "one\ntw"
                        (sub "o" (position)))
             "one\ntwo\nthree\n")
  # =>
  @[6]

  (peg-match ~(sequence "one\ntw"
                        (sub "o" (sequence (position) (line) (column))))
             "one\ntwo\nthree\n")
  # =>
  @[6 2 3]

  (peg-match ~(sequence (sub "abc" "ab")
                        "d")
             "abcdef")
  # =>
  @[]

  (try
    (peg-match ~(sequence "a"
                          (sub "bcd" (error "bc")))
               "abcdef")
    ([e] e))
  # =>
  "match error at line 1, column 2"

 (peg-match ~(sequence (sub (capture "abcd" :a)
                            (capture "abc"))
                       (capture (backmatch)))
            "abcdabcd")
  # =>
  @["abcd" "abc" "abc"]

  (peg-match ~(sequence (sub (capture "abcd" :a)
                             (capture "abc"))
                        (capture (backmatch :a)))
             "abcdabcd")
  # =>
  @["abcd" "abc" "abcd"]

  (peg-match ~(sequence (capture "abcd" :a)
                        (sub (capture "abc" :a)
                             (capture (backmatch :a)))
                        (capture (backmatch :a)))
             "abcdabcabcd")
  # =>
  @["abcd" "abc" "abc" "abc"]

  (peg-match ~(sequence (capture "abcd" :a)
                        (sub (capture "abc")
                             (capture (backmatch)))
                        (capture (backmatch :a)))
             "abcdabcabcd")
  # =>
  @["abcd" "abc" "abc" "abcd"]

  (peg-match ~(sub (capture "abcd")
                   (look 3 (capture "d")))
             "abcdcba")
  # =>
  @["abcd" "d"]

  (peg-match ~(sub (capture "abcd")
                   (capture (to "c")))
             "abcdef")
  # =>
  @["abcd" "ab"]

  (peg-match ~(sub (capture (to "d"))
                   (capture "abc"))
             "abcdef")
  # =>
  @["abc" "abc"]

  (peg-match ~(sub (capture (to "d"))
                   (capture (to "c")))
             "abcdef")
  # =>
  @["abc" "ab"]

  (peg-match ~(sequence (sub (capture (to "d"))
                             (capture (to "c")))
                        (capture (to "f")))
             "abcdef")
  # =>
  @["abc" "ab" "de"]

  (peg-match ~(sub (capture "abcd")
                   (capture (thru "c")))
             "abcdef")
  # =>
  @["abcd" "abc"]

  (peg-match ~(sub (capture (thru "d"))
                   (capture "abc"))
             "abcdef")
  # =>
  @["abcd" "abc"]

  (peg-match ~(sub (capture (thru "d"))
                   (capture (thru "c")))
             "abcdef")
  # =>
  @["abcd" "abc"]

  (peg-match ~(sequence (sub (capture (thru "d"))
                             (capture (thru "c")))
                        (capture (thru "f")))
             "abcdef")
  # =>
  @["abcd" "abc" "ef"]

  (peg-match ~(sequence (sub (capture 3)
                             (capture 2))
                        (capture 3))
             "abcdef")
  # =>
  @["abc" "ab" "def"]

  (peg-match ~(sub (capture -7)
                   (capture -1))
             "abcdef")
  # =>
  @["" ""]

  (peg-match ~(sequence (sub (capture -7)
                             (capture -1))
                        (capture 1))
             "abcdef")
  # =>
  @["" "" "a"]

  (peg-match ~(sequence (sub (capture (repeat 3 (range "ac")))
                             (capture (repeat 2 (range "ab"))))
                        (capture (repeat 3 (range "df"))))
             "abcdef")
  # =>
  @["abc" "ab" "def"]

  (peg-match ~(sequence (sub (capture (repeat 3 (set "abc")))
                             (capture (repeat 2 (set "ab"))))
                        (capture (repeat 3 (set "def"))))
             "abcdef")
  # =>
  @["abc" "ab" "def"]

  (peg-match ~(sequence (sub (capture "abcd")
                             (int 1))
                        (int 1))
             "abcdef")
  # =>
  @["abcd" 97 101]

  (peg-match ~(sequence (sub (capture "ab")
                             (int 3)))
             "abcdef")
  # =>
  nil

  (peg-match ~(sub (capture "abcd")
                   (sub (capture "abc")
                        (capture "ab")))
             "abcdef")
  # =>
  @["abcd" "abc" "ab"]

  (peg-match ~(split "," (capture 1))
             "a,b,c")
  # =>
  @["a" "b" "c"]

  # drops captures from separator pattern
  (peg-match ~(split (capture ",") (capture 1))
             "a,b,c")
  # =>
  @["a" "b" "c"]

  # can match empty subpatterns
  (peg-match ~(split "," (capture :w*))
             ",a,,bar,,,c,,")
  # =>
  @["" "a" "" "bar" "" "" "c" "" ""]

  # subpattern is limited to only text before the separator
  (peg-match ~(split "," (capture (to -1)))
             "a,,bar,c")
  # =>
  @["a" "" "bar" "c"]

  # fails if any subpattern fails
  (peg-match ~(split "," (capture "a"))
             "a,a,b")
  # =>
  nil

  # separator does not have to match anything
  (peg-match ~(split "x" (capture (to -1)))
             "a,a,b")
  # =>
  @["a,a,b"]

  # always consumes entire input
  (peg-match ~(split 1 (capture ""))
             "abc")
  # =>
  @["" "" "" ""]

  # separator can be an arbitrary PEG
  (peg-match ~(split :s+ (capture (to -1)))
             "a   b      c")
  # =>
  @["a" "b" "c"]

  (peg-match ~(sequence (number :d nil :tag)
                        (capture (lenprefix (backref :tag) 1)))
             "3abc")
  # =>
  @[3 "abc"]

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
