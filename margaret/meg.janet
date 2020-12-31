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
#   . test things from default-peg-grammar
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
# . implement rest of combinators
#
#   . look, >
#   . between, opt, ?
#   . at-least
#   . at-most
#   . repeat, "n"
#   . to
#   . thru
#   . backmatch
#
# . implement rest of captures
#
#   . cmt
#   . error
#   . constant
#   . replace, /
# . . position
#   . accumulate, %
#   . lenprefix
#   . group
#   . argument
#   . line
#   . column
#   . int
#   . int-be
#   . uint
#   . uint-be
#
# . capture stack load / save is done for following in c:
#
#   . accumulate, %
#   . between
#   . choice
#   . cmt
#   . drop
#   . group
#   . lenprefix
#   . replace, /
#   . thru
#   . to
#
# . argument 3 -- where to start
#
# . argument 4+ -- things for use with `argument`
#
# . review tag support
#
# . output debugging info as "data" (jdn)
#
# . experimental specials
#
#   . debug - dumps internal state (e.g. capture stack, tags, etc.)
#
# . optimization speculation
#
#   . tco using loop + label as in mal
#   . tuple/slice over drop
#   . consider not using `match`

(defn- peg-match
  [the-peg the-text]
  #
  (defn peg-match**
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
    (def tlen (length otext))
    #
    (defn peg-match*
      [peg text grammar]
      (cond
        # keyword
        (keyword? peg)
        (do (when (dyn :meg-debug) (print "keyword: :" peg))
          (peg-match* (grammar peg) text grammar))
        # string literal
        (string? peg)
        (do (when (dyn :meg-debug) (print "string: \"" peg "\""))
          (when (string/has-prefix? peg text)
            (length peg)))
        # integer
        (int? peg)
        (do (when (dyn :meg-debug) (print "integer: " peg))
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
            #
            (= 'range special)
            (do (print special)
              (assert (not (empty? tail))
                      "`range` requires at least 1 argument")
              (let [target-bytes
                    (reduce (fn [acc elt]
                              (assert (= 2 (length elt))
                                      "range argument must be length 2")
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
                  1)))
            #
            (= 'set special)
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`set` requires at least 1 argument")
              (def patt (first tail))
              (when (string/check-set patt
                                      (string/slice text 0 1))
                1))
            #
            (or (= '! special)
                (= 'not special))
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`not` requires at least 1 argument")
              (def patt (first tail))
              (unless (peg-match* patt text grammar)
                0))
            #
            (or (= '+ special)
                (= 'choice special))
            (do (when (dyn :meg-debug) (print special))
              (def res
                (some (fn [patt]
                        (def [new-caps idx new-tags]
                          (peg-match** (table/to-struct (merge grammar
                                                               {:main patt}))
                                       text))
                        (when idx
                          [new-caps idx new-tags]))
                      (tuple/slice peg 1)))
              (when res
                (def [new-caps idx new-tags] res)
                (array/concat caps new-caps)
                (merge-into tags new-tags)
                idx))
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
              (assert (not (empty? tail)) "`any` requires 1 argument")
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
              (assert (not (empty? tail)) "`some` requires 1 argument")
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
            (= 'if special)
            (do (when (dyn :meg-debug) (print special))
              (assert (>= (length tail) 2)
                      "`if` requires at least 2 arguments")
              (def cond-patt (first tail))
              (def lenx (peg-match* cond-patt text grammar))
              (when lenx
                (def patt (get tail 1))
                (when-let [leny (peg-match* patt text grammar)]
                  leny)))
            #
            (= 'if-not special)
            (do (when (dyn :meg-debug) (print special))
              (assert (>= (length tail) 2)
                      "`if-not` requires at least 2 arguments")
              (def cond-patt (first tail))
              (def lenx (peg-match* cond-patt text grammar))
              (unless lenx
                (def patt (get tail 1))
                (when-let [leny (peg-match* patt text grammar)]
                  leny)))
            #
            (or (= '> special)
                (= 'look special))
            (do (when (dyn :meg-debug) (print special))
              (assert (>= (length tail) 2)
                      "`look` requires at least 2 arguments")
              (def offset (first tail))
              (assert (int? offset)
                      "offset argument should be an integer")
              (def patt (get tail 1))
              (def lenx (peg-match* patt
                                    (string/slice text offset) grammar))
              (when lenx 0))
            #
            (or (= 'opt special)
                (= '? special))
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`opt` requires at least 1 argument")
              (def patt (first tail))
              (if-let [lenx (peg-match* patt text grammar)]
                lenx
                0))
            # XXX: need to be able to restore state if match-cnt < min-arg
            (= 'between special)
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`between` requires at least 3 arguments")
              (def [min-arg max-arg patt] tail)
              (assert (and (int? min-arg) (>= min-arg 0))
                      "min arg should be a non-negative integer")
              (assert (and (int? max-arg) (>= max-arg 0))
                      "max arg should be a non-negative integer")
              (var match-cnt 0)
              (var len 0)
              (var subtext text)
              (while (and (pos? (length subtext))
                          (< match-cnt max-arg))
                (def idx (peg-match* patt subtext grammar))
                (unless idx
                  (break))
                (++ match-cnt)
                (set subtext (string/slice subtext idx))
                (+= len idx))
              (when (<= min-arg match-cnt max-arg)
                len))
            #
            (or (= 'capture special)
                (= 'quote special)
                (= '<- special))
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`capture` requires at least 1 argument")
              (def patt (first tail))
              (def lenx (peg-match* patt text grammar))
              (when lenx
                (let [cap (string/slice text 0 lenx)]
                  (array/push caps cap)
                  (when-let [tag (get tail 1)]
                    (put tags
                         tag cap))
                  lenx)))
            #
            (= 'drop special)
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`drop` requires at least 1 argument")
              (def patt (first tail))
              (def [_ idx _]
                (peg-match** (table/to-struct (merge grammar {:main patt}))
                             text))
              idx)
            #
            (or (= 'backref special)
                (= '-> special))
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`backref` requires at least 1 argument")
              (def tag (first tail))
              (when-let [last-cap (get tags tag)]
                (array/push caps last-cap)
                (when-let [opt-tag (get tail 1)]
                  (put tags
                       opt-tag last-cap))
                0))
            # XXX: line and column info?
            (= 'error special)
            (do (when (dyn :meg-debug) (print special))
              (if-let [patt (first tail)]
                (let [pre-len (length caps) # XXX: hack?
                      lenx (peg-match* patt text grammar)
                      post-len (length caps)]
                  # XXX: hack to assess  "didn't produce captures"
                  (if (not= pre-len post-len)
                    (error (array/peek caps))
                    (error "match error at line X, column Y")))
                (error "match error at line X, column Y")))
            #
            (= 'constant special)
            (do (when (dyn :meg-debug) (print special))
              (assert (not (empty? tail))
                      "`constant` requires at least 1 argument")
              (def k (first tail))
              (array/push caps k)
              (when-let [tag (get tail 1)]
                (put tags
                     tag k))
              0)
            #
            (or (= 'position special)
                (= '$ special))
            (do (when (dyn :meg-debug) (print special))
              (def pos (- tlen (length text)))
              (array/push caps pos)
              0)
            #
            (= 'cmt special)
            (do (when (dyn :meg-debug) (print special))
              (assert (>= (length tail) 2)
                      "`cmt` requires at least 2 arguments")
              (def patt (first tail))
              (def fun (get tail 1))
              (assert (or (function? fun) (cfunction? fun))
                      "fun argument should be a function")
              (def [new-caps idx new-tags]
                (peg-match** (table/to-struct (merge grammar {:main patt}))
                             text))
              (when (and new-caps (not (empty? new-caps)))
                (def res (fun ;new-caps))
                (unless (or (false? res) (nil? res))
                  (array/push caps res)
                  (when-let [tag (get tail 2)]
                    (put (merge-into tags new-tags)
                         tag res))
                  idx)))
            #
            (or (= 'replace special)
                (= '/ special))
            (do (when (dyn :meg-debug) (print special))
              (assert (>= (length tail) 2)
                      "`replace` requires at least 2 arguments")
              (def patt (first tail))
              (def subst (get tail 1))
              (def [new-caps idx new-tags]
                (peg-match** (table/to-struct (merge grammar {:main patt}))
                             text))
              (when idx
                (cond
                  (dictionary? subst)
                  (let [res (get subst (last new-caps))]
                    (array/push caps res)
                    (when-let [tag (get tail 2)]
                      (put (merge-into tags new-tags)
                           tag res)))
                  #
                  (or (function? subst) (cfunction? subst))
                  (let [res (subst ;new-caps)]
                    (array/push caps res)
                    (when-let [tag (get tail 2)]
                      (put (merge-into tags new-tags)
                           tag subst)))
                  #
                  (do
                    (array/push caps subst)
                    (when-let [tag (get tail 2)]
                      (put (merge-into tags new-tags)
                           tag subst))))
                idx))
            #
            (error (string "unknown special: " special))))
        #
        # unknown
        (error (string "unknown construct type: " (type peg)
                       " " (describe peg)))))
    #
    (def index
      (peg-match* (peg-table :main) otext peg-table))
    [caps index tags])
  #
  (def [caps index tags]
    (peg-match** the-peg the-text))
  (when (dyn :meg-debug)
    (print "--------")
    (prin "tags: ")
    (pp tags)
    (prin "capture stack: ")
    (pp caps))
  (when index
    (when (dyn :meg-debug)
      (print "index: " index)
      (print "--------"))
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

 (peg-match ~(capture (if 5 (set "eilms")))
             "smile")
 # => @["s"]

 (peg-match ~(capture (if 5 (set "eilms")))
             "wink")
 # => nil

 (peg-match ~(capture (if-not 5 (set "iknw")))
             "wink")
 # => @["w"]

 (peg-match ~(capture (if-not 4 (set "iknw")))
             "wink")
 # => nil

 (peg-match ~(capture :A) "1")
 # => @["1"]

 (peg-match ~(capture :H) "g")
 # => @["g"]

 (peg-match ~(look 3 "cat")
             "my cat")
 # => @[]

 (peg-match ~(look 3 (capture "cat"))
             "my cat")
 # => @["cat"]

 (peg-match ~(look -4 (capture "cat"))
             "my cat")
 # => @["cat"]

 (peg-match ~(sequence (look 3 "cat")
                       "my")
             "my cat")
 # => @[]

 (peg-match ~(capture (look 3 "cat"))
             "my cat")
 # => @[""]

 (try
   (peg-match ~(sequence "a"
                         (error (sequence (capture "b")
                                          (capture "c"))))
               "abc")
   ([err]
    err))
 # => "c"

 (try
   (peg-match ~(choice "a"
                       "b"
                       (error ""))
               "c")
   ([err]
    err))
 # => "match error at line X, column Y"

 (try
   (peg-match ~(choice "a"
                       "b"
                       (error))
               "c")
   ([err]
    :match-error))
 # => :match-error

 (peg-match ~(constant "smile")
             "whatever")
 # => @["smile"]

 (peg-match ~(constant {:fun :value})
             "whatever")
 # => @[{:fun :value}]

 (peg-match ~(sequence (constant :relax)
                       (position))
             "whatever")
 # => @[:relax 0]

 (peg-match ~(position) "a")
 # => @[0]

 (peg-match ~(sequence "a"
                       (position))
             "ab")
 # => @[1]

 (peg-match ~($) "a")
 # => @[0]

 (peg-match ~(sequence "a"
                       ($))
             "ab")
 # => @[1]

 (peg-match ~(opt "a") "a")
 # => @[]

 (peg-match ~(opt "a") "")
 # => @[]

 (peg-match ~(? "a") "a")
 # => @[]

 (peg-match ~(? "a") "")
 # => @[]

 (peg-match ~(cmt (capture "hello")
                  ,(fn [cap]
                     (string cap "!")))
             "hello")
 # => @["hello!"]

 (peg-match ~(cmt (sequence (capture "hello")
                            (some (set " ,"))
                            (capture "world"))
                  ,(fn [cap1 cap2]
                     (string cap2 ": yes, " cap1 "!")))
             "hello, world")
 # => @["world: yes, hello!"]

 (peg-match ~(replace (capture "cat")
                      {"cat" "tiger"})
             "cat")
 # => @["tiger"]

 (peg-match ~(replace (capture "cat")
                      ,(fn [original]
                         (string original "alog")))
             "cat")
 # => @["catalog"]

 (peg-match ~(replace (capture "cat")
                      "dog")
             "cat")
 # => @["dog"]

 (peg-match ~(/ (capture "cat")
                {"cat" "tiger"})
             "cat")
 # => @["tiger"]

 (peg-match ~(between 1 3 "a") "aa")
 # => @[]

 (peg-match ~(between 1 3 (capture "a")) "aa")
 # => @["a" "a"]

 (peg-match ~(between 3 5 (capture "a")) "aa")
 # => nil

 (peg-match ~(between 0 8 "b") "")
 # => @[]

 (peg-match ~(sequence (between 0 2 "c") "c")
             "ccc")
 # => @[]

 (peg-match ~(sequence (between 0 3 "c") "c")
             "ccc")
 # => nil


 )

(comment

 (peg-match ~{:main :token
              :token (some :symchars)
              :symchars (+ (range "09" "AZ" "az" "\x80\xFF")
                           (set "!$%&*+-./:<?=>@^_"))}
             "18")
 # => @[]

 (peg-match ~(capture {:main :number
                       :number (drop (cmt (<- :token)
                                          ,scan-number))
                       :token (some :symchars)
                       :symchars (+ (range "09" "AZ" "az" "\x80\xFF")
                                    (set "!$%&*+-./:<?=>@^_"))})
             "18")
 # => @["18"]

 # based on:
 #   https://janet-lang.org/docs/syntax.html#Grammar
 (def grammar
   ~{:ws (set " \t\r\f\n\0\v") # XXX: why \0?
     :readermac (set "';~,|")
     :symchars (+ (range "09" "AZ" "az" "\x80\xFF")
                  (set "!$%&*+-./:<?=>@^_"))
     :token (some :symchars)
     :hex (range "09" "af" "AF")
     :escape (* "\\" (+ (set "ntrzfev0\"\\")
                        (* "x" :hex :hex)
                        (* "u" [4 :hex])
                        (* "U" [6 :hex])
                        (error (constant "bad escape"))))
     :comment (* "#" (any (if-not (+ "\n" -1) 1)))
     :symbol :token
     :keyword (* ":" (any :symchars))
     :constant (* (+ "true" "false" "nil")
                  (not :symchars))
     :bytes (* "\""
               (any (+ :escape (if-not "\"" 1)))
               "\"")
     :string :bytes
     :buffer (* "@" :bytes)
     :long-bytes {:delim (some "`")
                  :open (capture :delim :n)
                  :close (cmt (* (not (> -1 "`"))
                                 (-> :n)
                                 ':delim)
                              ,=)
                  :main (drop (* :open
                                 (any (if-not :close 1))
                                 :close))}
     :long-string :long-bytes
     :long-buffer (* "@" :long-bytes)
     :number (drop (cmt (<- :token) ,scan-number))
     :raw-value (+ :comment :constant :number :keyword
                   :string :buffer :long-string :long-buffer
                   :parray :barray :ptuple :btuple :struct :table :symbol)
     :value (* (any (+ :ws :readermac))
               :raw-value
               (any :ws))
     :root (any :value)
     :root2 (any (* :value :value))
     :ptuple (* "(" :root (+ ")" (error "")))
     :btuple (* "[" :root (+ "]" (error "")))
     :struct (* "{" :root2 (+ "}" (error "")))
     :parray (* "@" :ptuple)
     :barray (* "@" :btuple)
     :table (* "@" :struct)
     :main :root})

 (peg-match grammar "1")
 # => @[]

 (peg-match ~(capture ,grammar) "1")
 # => @["1"]

 (peg-match grammar "(+ 1 1)")
 # => @[]

 )

# XXX: hack for better naming
(def match peg-match)
