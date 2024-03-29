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

(defn- peg-match
  [the-peg the-text &opt the-start & the-args]
  #
  (defn peg-match**
    [opeg otext]
    #
    (def peg-table
      (case (type opeg)
        :boolean
        (if (true? opeg)
          @{:main 0}
          @{:main '(not 0)})
        #
        :string
        @{:main opeg}
        #
        :number
        (do (assert (int? opeg)
                    (string "number must be an integer: " opeg))
          @{:main opeg})
        #
        :keyword
        (do (assert (in default-peg-grammar opeg)
                    (string "default-peg-grammar does not have :" opeg))
          @{:main opeg})
        #
        :tuple
        @{:main opeg}
        #
        :struct
        (do (assert (get opeg :main)
                    (string "missing :main in grammar: %p" opeg))
          (table ;(kvs opeg)))
        #
        :table
        (do (assert (get opeg :main)
                    (string "missing :main in grammar: %p" opeg))
          opeg)))
    (assert (peg-table :main)
            "peg needs a :main key")
    (table/setproto peg-table default-peg-grammar)
    #
    (def tot-len (length otext))
    #
    (var indent 0)
    (def nws 1)
    #
    (var captures @[])
    (var scratch @"")
    (var tags @[])
    (var tagged_captures @[])
    (var mode :peg_mode_normal)
    (def linemap @[])
    (var linemaplen -1)
    # allow overriding via :meg-debug
    (def has_backref
      (if-let [md (dyn :meg-debug)]
        (if-let [setting (get md :disable_tagged_captures)]
          (not setting)
          true)
        true))
    #
    (defn log-entry
      [op peg text grammar]
      (++ indent)
      (when-let [md (dyn :meg-debug)]
        (let [ind (string/repeat " " (* nws indent))]
          (print ind op " >")
          (when (struct? md)
            (when (in md :captures)
              (printf "%s captures: %j" ind captures))
            (when (in md :scratch)
              (printf "%s scratch: %j" ind scratch))
            (when (in md :tags)
              (printf "%s tags: %j" ind tags))
            (when (in md :tagged_captures)
              (printf "%s tagged_captures: %j" ind tagged_captures))
            (when (in md :mode)
              (printf "%s mode: %j" ind mode))
            (when (in md :has_backref)
              (printf "%s has_backref: %j" ind has_backref))
            (when (in md :peg)
              (printf "%s peg: %p" ind peg))
            (when (in md :text)
              (printf "%s text: %j" ind text))))))
    #
    (defn log-exit
      [op ret &opt dict]
      (default dict {})
      (when-let [md (dyn :meg-debug)]
        (let [ind (string/repeat " " (* nws indent))]
          (print ind op " <")
          (when (struct? md)
            (when (in md :captures)
              (printf "%s captures: %j" ind captures))
            (when (in md :scratch)
              (printf "%s scratch: %j" ind scratch))
            (when (in md :tags)
              (printf "%s tags: %j" ind tags))
            (when (in md :tagged_captures)
              (printf "%s tagged_captures: %j" ind tagged_captures))
            (when (in md :mode)
              (printf "%s mode: %j" ind mode))
            (when (in md :has_backref)
              (printf "%s has_backref: %j" ind has_backref))
            (when (in md :peg)
              (when-let [peg (in dict :peg)]
                (printf "%s peg: %p" ind peg)))
            (when (in md :text)
              (when-let [text (in dict :text)]
                (printf "%s text: %j" ind text))))
          (printf "%s ret: %j" ind ret)))
      (-- indent))
    #
    (defn cap_save
      []
      {:scratch (length scratch)
       :captures (length captures)
       :tagged_captures (length tagged_captures)})
    #
    (defn cap_load
      [cs]
      (set scratch
           (buffer/slice scratch 0 (cs :scratch)))
      (set captures
           (array/slice captures 0 (cs :captures)))
      (set tags
           (array/slice tags 0 (cs :tagged_captures)))
      (set tagged_captures
           (array/slice tagged_captures 0 (cs :tagged_captures))))
    #
    (defn cap_load_keept
      [cs]
      (set scratch
           (buffer/slice scratch 0 (cs :scratch)))
      (set captures
           (array/slice captures 0 (cs :captures))))
    #
    (defn pushcap
      [capture tag]
      (case mode
        :peg_mode_accumulate
        (buffer/push scratch (string capture))
        #
        :peg_mode_normal
        (array/push captures capture)
        #
        (error (string "unrecognized mode: " mode)))
      #
      (when has_backref
        (array/push tagged_captures capture)
        (array/push tags tag)))
    #
    (defn get_linecol_from_position
      [position]
      (when (neg? linemaplen)
        (var nl-count 0)
        (def nl-char (chr "\n"))
        (forv i 0 (length otext)
          (let [ch (in otext i)]
            (when (= ch nl-char)
              (array/push linemap i)
              (++ nl-count))))
        (set linemaplen nl-count))
      #
      (var hi linemaplen)
      (var lo 0)
      (while (< (inc lo) hi)
        (def mid
          (math/floor (+ lo (/ (- hi lo) 2))))
        (if (>= (get linemap mid) position)
          (set hi mid)
          (set lo mid)))
      (if (or (= linemaplen 0)
              (and (= lo 0)
                   (>= (get linemap 0) position)))
        [1 (inc position)]
        [(+ lo 2) (- position (get linemap lo))]))
    #
    (defn peg-match*
      # when match succeeds, return number of bytes to advance
      # otherwise return nil
      [peg text grammar &opt state]
      #
      (cond
        # true / false
        (boolean? peg)
        (do
          (log-entry "BOOLEAN" peg text grammar)
          (def ret
            (if (true? peg)
              (peg-match* 0 text grammar state)
              (peg-match* '(not 0) text grammar state)))
          (log-exit "BOOLEAN" ret {:peg peg :text text})
          ret)
        # keyword leads to a lookup in the grammar
        (keyword? peg)
        (do
          (log-entry "KEYWORD" peg text grammar)
          (def ret
            (peg-match* (grammar peg) text grammar state))
          (log-exit "KEYWORD" ret {:peg peg :text text})
          ret)
        # string is RULE_LITERAL
        (string? peg)
        (do
          (log-entry "RULE_LITERAL" peg text grammar)
          (def ret
            (when (string/has-prefix? peg text)
              (length peg)))
          (log-exit "RULE_LITERAL" ret {:peg peg :text text})
          ret)
        # non-negative integer is RULE_NCHAR
        (nat? peg)
        (do
          (log-entry "RULE_NCHAR" peg text grammar)
          (def ret
            (when (<= peg (length text))
              peg))
          (log-exit "RULE_NCHAR" ret {:peg peg :text text})
          ret)
        # negative integer is RULE_NOTNCHAR
        (and (int? peg)
             (neg? peg))
        (do
          (log-entry "RULE_NOTNCHAR" peg text grammar)
          (def ret
            (when (not (<= (math/abs peg)
                           (length text)))
              0))
          (log-exit "RULE_NOTNCHAR" ret {:peg peg :text text})
          ret)
        # struct looks up the peg associated with :main
        (struct? peg)
        (do
          (log-entry "STRUCT" peg text grammar)
          (assert (peg :main)
                  "peg does not have :main")
          (def ret
            (peg-match* (peg :main) text peg state))
          (log-exit "STRUCT" ret {:peg peg :text text})
          ret)
        #
        (tuple? peg)
        (do
          (assert (pos? (length peg))
                  "peg must have non-zero length")
          (def op (get peg 0))
          (def tail (drop 1 peg))
          #
          (cond
            # RULE_RANGE
            (= 'range op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def ret
                (when (> (length text) 0)
                  (let [target-bytes
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
                      1))))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_SET
            (= 'set op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def ret
                (when (and (> (length text) 0)
                           (string/check-set patt
                                             (string/slice text 0 1)))
                  1))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_LOOK
            (or (= 'look op)
                (= '> op))
            (do
              (log-entry op peg text grammar)
              (assert (>= (length tail) 2)
                      (string/format "`%s` requires at least 2 arguments"
                                     (string op)))
              (def offset (in tail 0))
              (assert (int? offset)
                      "offset argument should be an integer")
              (def ret
                (label result
                  (let [text-len
                        # RULE_SUB needs this
                        (length (get state :text text))
                        cur-idx (- tot-len text-len)
                        new-start (+ cur-idx offset)]
                    (when (or (< new-start 0)
                              (> new-start text-len))
                      (return result nil))
                    (def patt (in tail 1))
                    (when (peg-match* patt
                                      (string/slice otext new-start)
                                      grammar
                                      state)
                      0))))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_CHOICE
            (or (= 'choice op)
                (= '+ op))
            (do
              (log-entry op peg text grammar)
              (def len (length tail))
              (def ret
                (label result
                  (when (= len 0)
                    (return result nil))
                  (def cs (cap_save))
                  (forv i 0 (dec len)
                    (def sub-peg (get tail i))
                    (def res-idx (peg-match* sub-peg text grammar state))
                    # XXX: should be ok?
                    (when res-idx
                      (return result res-idx))
                    (cap_load cs))
                  (peg-match* (get tail (dec len))
                              text grammar state)))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_SEQUENCE
            (or (= '* op)
                (= 'sequence op))
            (do
              (log-entry op peg text grammar)
              (def len (length tail))
              (def ret
                (label result
                  (when (= len 0)
                    (return result 0))
                  (var cur-text text)
                  (var res-idx nil)
                  (var acc-idx 0)
                  (var i 0)
                  (while (and cur-text
                              (< i (dec len)))
                    (def sub-peg (get tail i))
                    (set res-idx (peg-match* sub-peg cur-text grammar state))
                    # looks weird but makes it more similar to peg.c
                    (if res-idx
                      (do
                        (set cur-text (string/slice cur-text res-idx))
                        (+= acc-idx res-idx))
                      (set cur-text nil))
                    (++ i))
                  (when (nil? cur-text)
                    (return result nil))
                  (when-let [last-idx
                             (peg-match* (get tail (dec len))
                                         cur-text grammar state)]
                    (+ acc-idx last-idx))))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_IF
            (= 'if op)
            (do
              (log-entry op peg text grammar)
              (assert (>= (length tail) 2)
                      (string/format "`%s` requires at least 2 arguments"
                                     (string op)))
              (def patt-a (in tail 0))
              (def patt-b (in tail 1))
              (def res-idx (peg-match* patt-a text grammar state))
              (def ret
                (if res-idx
                  (peg-match* patt-b text grammar state)
                  nil))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_IFNOT
            (= 'if-not op)
            (do
              (log-entry op peg text grammar)
              (assert (>= (length tail) 2)
                      (string/format "`%s` requires at least 2 arguments"
                                     (string op)))
              (def patt-a (in tail 0))
              (def patt-b (in tail 1))
              (def cs (cap_save))
              (def res-idx (peg-match* patt-a text grammar state))
              (def ret
                (if res-idx
                  nil
                  (do
                    (cap_load cs)
                    (peg-match* patt-b text grammar state))))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_NOT
            (or (= 'not op)
                (= '! op))
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def cs (cap_save))
              (def res-idx (peg-match* patt text grammar state))
              (def ret
                (if res-idx
                  nil
                  (do
                    (cap_load cs)
                    0)))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_THRU
            (= 'thru op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def cs (cap_save))
              (def ret
                (label result
                  (var cur-text text)
                  (def text-len (length text))
                  (var next-idx nil)
                  (var cur-idx 0)
                  (while (<= cur-idx text-len)
                    (def cs2 (cap_save))
                    (set next-idx (peg-match* patt cur-text grammar state))
                    (when next-idx
                      (break))
                    (when (pos? (length cur-text))
                      (set cur-text (string/slice cur-text 1)))
                    (cap_load cs2)
                    (++ cur-idx))
                  (when (> cur-idx text-len)
                    (cap_load cs)
                    (return result nil))
                  (when next-idx
                    (+= cur-idx next-idx))))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_TO
            (= 'to op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def cs (cap_save))
              (def ret
                (label result
                  (var cur-text text)
                  (def text-len (length text))
                  (var next-idx nil)
                  (var cur-idx 0)
                  (while (<= cur-idx text-len)
                    (def cs2 (cap_save))
                    (set next-idx (peg-match* patt cur-text grammar state))
                    (when next-idx
                      (cap_load cs2)
                      (break))
                    (when (pos? (length cur-text))
                      (set cur-text (string/slice cur-text 1)))
                    (cap_load cs2)
                    (++ cur-idx))
                  (when (> cur-idx text-len)
                    (cap_load cs)
                    (return result nil))
                  (when next-idx
                    cur-idx)))
              (log-exit op ret {:peg peg :text text})
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
              (log-entry op peg text grammar)
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
              (def cs (cap_save))
              (def ret
                (label result
                  (var captured 0)
                  (var cur-text text)
                  (var next-idx nil)
                  (var acc-idx 0)
                  (while (< captured hi)
                    (def cs2 (cap_save))
                    (set next-idx (peg-match* patt cur-text grammar state))
                    # match fail or no change in position
                    (when (or (nil? next-idx)
                              (= next-idx 0))
                      (cap_load cs2)
                      (break))
                    (++ captured)
                    (set cur-text (string/slice cur-text next-idx))
                    (+= acc-idx next-idx))
                  (when (< captured lo)
                    (cap_load cs)
                    (return result nil))
                  acc-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_GETTAG
            (or (= 'backref op)
                (= '-> op))
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def tag (in tail 0))
              (def ret
                (label result
                  (loop [i :down-to [(dec (length tags)) 0]]
                    (let [cur-tag (get tags i)]
                      (when (= cur-tag tag)
                        (pushcap (get tagged_captures i) tag)
                        (return result 0))))
                  nil))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_POSITION
            (or (= 'position op)
                (= '$ op))
            (do
              (log-entry op peg text grammar)
              (def tag (when (next tail) (in tail 0)))
              (pushcap (- tot-len
                          # RULE_SUB needs this
                          (length (get state :text text)))
                       tag)
              (def ret 0)
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_LINE
            (= 'line op)
            (do
              (log-entry op peg text grammar)
              (def tag (when (next tail) (in tail 0)))
              (def [line _]
                (get_linecol_from_position
                  (- tot-len
                     # RULE_SUB needs this
                     (length (get state :text text)))))
              (pushcap line tag)
              (def ret 0)
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_COLUMN
            (= 'column op)
            (do
              (log-entry op peg text grammar)
              (def tag (when (next tail) (in tail 0)))
              (def [_ col]
                (get_linecol_from_position
                  (- tot-len
                     # RULE_SUB needs this
                     (length (get state :text text)))))
              (pushcap col tag)
              (def ret 0)
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_ARGUMENT
            (= 'argument op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (assert (nat? patt)
                      (string "expected non-negative integer, got: " patt))
              (assert (< patt (length the-args))
                      (string "expected smaller integer, got: " patt))
              (def tag (when (< 1 (length tail))
                         (in tail 1)))
              (def arg-n (in the-args patt))
              (pushcap arg-n tag)
              (def ret 0)
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_CONSTANT
            (= 'constant op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def tag (when (< 1 (length tail)) (in tail 1)))
              (pushcap patt tag)
              (def ret 0)
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_CAPTURE
            (or (= 'capture op)
                (= 'quote op)
                (= '<- op))
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def tag (when (< 1 (length tail)) (in tail 1)))
              (def res-idx (peg-match* patt text grammar state))
              (def ret
                (when res-idx
                  (let [cap (string/slice text 0 res-idx)]
                    (if (and (not has_backref)
                             (= mode :peg_mode_accumulate))
                      (buffer/push scratch cap)
                      (pushcap cap tag)))
                  res-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_CAPTURE_NUM
            (= 'number op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def base (when (< 1 (length tail)) (in tail 1)))
              (def tag (when (< 2 (length tail)) (in tail 2)))
              (def res-idx (peg-match* patt text grammar state))
              (def ret
                (when res-idx
                  (let [cap (string/slice text 0 res-idx)]
                    (when-let [num (scan-number-base cap base)]
                      (if (and (not has_backref)
                               (= mode :peg_mode_accumulate))
                        (buffer/push scratch cap)
                        (pushcap num tag))))
                  res-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_ACCUMULATE
            (or (= 'accumulate op)
                (= '% op))
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def tag (when (< 1 (length tail)) (in tail 1)))
              (def old-mode mode)
              (when (and (not tag)
                         (= old-mode :peg_mode_accumulate))
                (peg-match* patt text grammar state))
              (def cs (cap_save))
              (set mode :peg_mode_accumulate)
              (def res-idx (peg-match* patt text grammar state))
              (set mode old-mode)
              (def ret
                (when res-idx
                  (def cap (string scratch))
                  (cap_load_keept cs)
                  (pushcap cap tag)
                  res-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_DROP
            (= 'drop op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def cs (cap_save))
              (def res-idx (peg-match* patt text grammar state))
              (def ret
                (when res-idx
                  (cap_load cs)
                  res-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_GROUP
            (= 'group op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def patt (in tail 0))
              (def tag (when (< 1 (length tail))
                         (in tail 1)))
              (def old-mode mode)
              (def cs (cap_save))
              (set mode :peg_mode_normal)
              (def res-idx (peg-match* patt text grammar state))
              (set mode old-mode)
              (def ret
                (when res-idx
                  (def cap
                    # use only the new captures
                    (array/slice captures
                                 (cs :captures)))
                  (cap_load_keept cs)
                  (pushcap cap tag)
                  res-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_SUB
            (= 'sub op)
            (do
              (log-entry op peg text grammar)
              (assert (not (< (length tail) 2))
                      (string/format "`%s` requires at least 2 arguments"
                                     (string op)))
              (def win-patt (in tail 0))
              (def patt (in tail 1))
              (def ret
                (when-let [win-end-offset
                           (peg-match* win-patt text grammar state)]
                  (when (peg-match* patt
                                    (string/slice text 0 win-end-offset)
                                    grammar
                                    (merge state {:text text}))
                    win-end-offset)))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_REPLACE
            (or (= 'replace op)
                (= '/ op))
            (do
              (log-entry op peg text grammar)
              (assert (not (< (length tail) 2))
                      (string/format "`%s` requires at least 2 arguments"
                                     (string op)))
              (def patt (in tail 0))
              (def subst (in tail 1))
              (def tag (when (> (length tail) 2)
                         (in tail 2)))
              (def old-mode mode)
              (def cs (cap_save))
              (set mode :peg_mode_normal)
              (def res-idx (peg-match* patt text grammar state))
              (set mode old-mode)
              (def ret
                (when res-idx
                  (def cap
                    (cond
                      (dictionary? subst)
                      (get subst (last captures))
                      #
                      (or (function? subst)
                          (cfunction? subst))
                      # use only the new captures
                      (subst ;(array/slice captures
                                           (cs :captures)))
                      #
                      subst))
                  (cap_load_keept cs)
                  (pushcap cap tag)
                  res-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_MATCHTIME
            (= 'cmt op)
            (do
              (log-entry op peg text grammar)
              (assert (not (< (length tail) 2))
                      (string/format "`%s` requires at least 2 arguments"
                                     (string op)))
              (def patt (in tail 0))
              (def subst (in tail 1))
              (assert (or (function? subst)
                          (cfunction? subst))
                      (string "expected a function, got: " (type subst)))
              (def tag (when (> (length tail) 2)
                         (in tail 2)))
              (def old-mode mode)
              (def cs (cap_save))
              (set mode :peg_mode_normal)
              (def res-idx (peg-match* patt text grammar state))
              (set mode old-mode)
              (def ret
                (label result
                  (when res-idx
                    (def cap
                      # use only the new captures
                      (subst ;(array/slice captures
                                           (cs :captures))))
                    (cap_load_keept cs)
                    (when (not (truthy? cap))
                      (return result nil))
                    (pushcap cap tag)
                    res-idx)))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_ERROR
            (= 'error op)
            (do
              (log-entry op peg text grammar)
              (def patt (if (empty? tail)
                          0 # determined via gdb
                          (in tail 0)))
              (def old-mode mode)
              (set mode :peg_mode_normal)
              (def old-cap (length captures))
              (def res-idx (peg-match* patt text grammar state))
              (set mode old-mode)
              (def ret
                (when res-idx
                  (if (> (length captures) old-cap)
                    (error (string (last captures)))
                    (let [[line col]
                          (get_linecol_from_position
                            (- tot-len
                               # RULE_SUB needs this
                               (length (get state :text text))))]
                      (errorf "match error at line %d, column %d" line col)))
                  # XXX: should not get here
                  nil))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_BACKMATCH
            (= 'backmatch op)
            (do
              (log-entry op peg text grammar)
              (def tag (when (next tail) (in tail 0)))
              (def ret
                (label result
                  (loop [i :down-to [(dec (length tags)) 0]]
                    (let [cur-tag (get tags i)]
                      (when (= cur-tag tag)
                        (def cap
                          (get tagged_captures i))
                        (when (not (string? cap))
                          (return result nil))
                        #
                        (let [caplen (length cap)]
                          (when (> (+ (length text) caplen)
                                   tot-len)
                            (return result nil))
                          (return result
                                  (when (string/has-prefix? cap text)
                                    caplen))))))
                  nil))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_LENPREFIX
            (= 'lenprefix op)
            (do
              (log-entry op peg text grammar)
              (assert (not (< (length tail) 2))
                      (string/format "`%s` requires at least 2 arguments"
                                     (string op)))
              (def n-patt (in tail 0))
              (def patt (in tail 1))
              (def old-mode mode)
              (set mode :peg_mode_normal)
              (def cs (cap_save))
              (def ret
                (label result
                  (def idx (peg-match* n-patt text grammar state))
                  (when (nil? idx)
                    (return result nil))
                  #
                  (set mode old-mode)
                  (def num-sub-caps
                    (- (length captures) (cs :captures)))
                  (var lencap nil)
                  (when (<= num-sub-caps 0)
                    (cap_load cs)
                    (return result nil))
                  #
                  (set lencap (get captures (cs :captures)))
                  (when (not (int? lencap))
                    (cap_load cs)
                    (return result nil))
                  #
                  (def nrep lencap)
                  (cap_load cs)
                  (var next-idx nil)
                  (var next-text (string/slice text idx))
                  (var acc-idx idx)
                  (forv i 0 nrep
                    (set next-idx
                         (peg-match* patt next-text grammar state))
                    (when (nil? next-idx)
                      (cap_load cs)
                      (return result nil))
                    (+= acc-idx next-idx)
                    (set next-text
                         (string/slice next-text next-idx)))
                  acc-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_READINT
            (or (= 'int op)
                (= 'int-be op)
                (= 'uint op)
                (= 'uint-be op))
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def width (in tail 0))
              (def tag (when (> (length tail) 1) (in tail 1)))
              (def ret
                (label result
                  (when (> width (length text))
                    (return result nil))
                  (var accum nil)
                  (cond
                    (= 'int op)
                    (do
                      (set accum (if (> width 6)
                                   (int/s64 0)
                                   0))
                      (loop [i :down-to [(dec width) 0]]
                        (set accum
                             (bor (blshift accum 8)
                                  (get text i)))))
                    #
                    (= 'int-be op)
                    (do
                      (set accum (if (> width 6)
                                   (int/s64 0)
                                   0))
                      (forv i 0 width
                        (set accum
                             (bor (blshift accum 8)
                                  (get text i)))))
                    #
                    (= 'uint op)
                    (do
                      (set accum (if (> width 6)
                                   (int/u64 0)
                                   0))
                      (loop [i :down-to [(dec width) 0]]
                        (set accum
                             (bor (blshift accum 8)
                                  (get text i)))))
                    #
                    (= 'uint-be op)
                    (do
                      (set accum (if (> width 6)
                                   (int/u64 0)
                                   0))
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
                  (pushcap capture-value tag)
                  width))
              (log-exit op ret {:peg peg :text text})
              ret)
            # RULE_UNREF
            (= 'unref op)
            (do
              (log-entry op peg text grammar)
              (assert (next tail)
                      (string/format "`%s` requires at least 1 argument"
                                     (string op)))
              (def rule (in tail 0))
              (def tag (when (> (length tail) 1) (in tail 1)))
              (def tcap (length tags))
              (def res-idx (peg-match* rule text grammar state))
              (def ret
                (label result
                  (when (nil? res-idx)
                    (return result nil))
                  (def final-tcap (length tags))
                  (var w tcap)
                  (when tag
                    (forv i tcap final-tcap
                      (when (= tag (get tags i))
                        (put tags
                             w (get tags i))
                        (put tagged_captures
                             w (get tagged_captures i))
                        (++ w))))
                  (set tags
                       (array/slice tags 0 w))
                  (set tagged_captures
                       (array/slice tagged_captures 0 w))
                  res-idx))
              (log-exit op ret {:peg peg :text text})
              ret)
            #
            (error (string "unknown tuple op: " op))))
        #
        (error (string "unknown peg: " peg))))
    # XXX: for aesthetic purposes
    (when (dyn :meg-debug)
      (print))
    #
    (def index
      (peg-match* (peg-table :main) otext peg-table @{}))
    [captures index tags])
  #
  (when the-start
    (let [text-len (length the-text)]
      (assert (and (<= the-start text-len)
                   (<= (* -1 (inc text-len)) the-start))
              "start argument out of range")))
  (default the-start 0)
  (def [captures index tags]
    (peg-match** (if (= :function (type the-peg))
                   (the-peg)
                   the-peg)
                 (if (not= 0 the-start)
                   (string/slice the-text the-start)
                   the-text)))
  (when (dyn :meg-debug)
    (print "--------")
    (prin "tags: ")
    (pp tags)
    (prin "captures: ")
    (pp captures))
  (when index
    (when (dyn :meg-debug)
      (print "index: " index)
      (print "--------"))
    captures))

(comment

  (setdyn :meg-debug {:captures true
                      #:scratch true
                      :tags true
                      :tagged_captures true
                      :mode true
                      :has_backref true
                      :text true})

  (setdyn :meg-debug {:captures true
                      #:scratch true
                      #:tags true
                      :tagged_captures true
                      #:mode true
                      :has_backref true
                      #:disable_tagged_captures true
                      :peg true
                      :text true})

  (import ./meg :fresh true)

  (meg/match ~(cmt (sequence (capture "hello")
                             (some (set " ,"))
                             (capture "world"))
                   ,(fn [cap1 cap2]
                      (string cap2 ": yes, " cap1 "!")))
             "hello, world")
  # =>
  @["world: yes, hello!"]

  )

(defn- peg-compile
  [peg]
  (fn [] peg))

# XXX: hack for better naming

(def match peg-match)

(def compile peg-compile)
