(import ./location :as l)
(import ./zipper :as j)
(import ./loc-jipper :as j)

# ti == test indicator, which can look like any of:
#
# # =>
# # before =>
# # => after
# # before => after

(defn find-test-indicator
  [zloc]
  (var label-left nil)
  (var label-right nil)
  [(j/right-until zloc
                  |(match (j/node $)
                     [:comment _ content]
                     (if-let [[l r]
                              (peg/match ~(sequence "#"
                                                    (capture (to "=>"))
                                                    "=>"
                                                    (capture (thru -1)))
                                         content)]
                       (do
                         (set label-left (string/trim l))
                         (set label-right (string/trim r))
                         true)
                       false)))
   label-left
   label-right])

(comment

  (def eol
    (if (= :windows (os/which))
      "\r\n"
      "\n"))

  (def src
    (string "(+ 1 1)" eol
            "# =>"    eol
            "2"))

  (let [[zloc l r]
        (find-test-indicator (-> (l/par src)
                                 j/zip-down))]
    (and zloc
         (empty? l)
         (empty? r)))
  # =>
  true

  (def src
    (string "(+ 1 1)"     eol
            "# before =>" eol
            "2"))

  (let [[zloc l r]
        (find-test-indicator (-> (l/par src)
                                 j/zip-down))]
    (and zloc
         (= "before" l)
         (empty? r)))
  # =>
  true

  (def src
    (string "(+ 1 1)"    eol
            "# => after" eol
            "2"))

  (let [[zloc l r]
        (find-test-indicator (-> (l/par src)
                                 j/zip-down))]
    (and zloc
         (empty? l)
         (= "after" r)))
  # =>
  true

  )

(defn find-test-expr
  [ti-zloc]
  # check for appropriate conditions "before"
  (def before-zlocs @[])
  (var curr-zloc ti-zloc)
  (var found-before nil)
  (while curr-zloc
    (set curr-zloc
         (j/left curr-zloc))
    (when (nil? curr-zloc)
      (break))
    (match (j/node curr-zloc)
      [:comment]
      (array/push before-zlocs curr-zloc)
      #
      [:whitespace]
      (array/push before-zlocs curr-zloc)
      #
      (do
        (set found-before true)
        (array/push before-zlocs curr-zloc)
        (break))))
  #
  (cond
    (nil? curr-zloc)
    :no-test-expression
    #
    (and found-before
         (->> (slice before-zlocs 0 -2)
              (filter |(not (match (j/node $)
                              [:whitespace]
                              true)))
              length
              zero?))
    curr-zloc
    #
    :unexpected-result))

(comment

  (def src
    (string "(comment"         eol
                               eol
            "  (def a 1)"      eol
                               eol
            "  (put @{} :a 2)" eol
            "  # =>"           eol
            "  @{:a 2}"        eol
                               eol
            "  )"))

  (def [ti-zloc _ _]
    (find-test-indicator (-> (l/par src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  '(:comment @{:bc 3 :bl 6 :ec 7 :el 6} "# =>")

  (def test-expr-zloc
    (find-test-expr ti-zloc))

  (j/node test-expr-zloc)
  # =>
  '(:tuple @{:bc 3 :bl 5 :ec 17 :el 5}
           (:symbol @{:bc 4 :bl 5 :ec 7 :el 5} "put")
           (:whitespace @{:bc 7 :bl 5 :ec 8 :el 5} " ")
           (:table @{:bc 8 :bl 5 :ec 11 :el 5})
           (:whitespace @{:bc 11 :bl 5 :ec 12 :el 5} " ")
           (:keyword @{:bc 12 :bl 5 :ec 14 :el 5} ":a")
           (:whitespace @{:bc 14 :bl 5 :ec 15 :el 5} " ")
           (:number @{:bc 15 :bl 5 :ec 16 :el 5} "2"))

  (-> (j/left test-expr-zloc)
      j/node)
  # =>
  '(:whitespace @{:bc 1 :bl 5 :ec 3 :el 5} "  ")

  )

(defn find-expected-expr
  [ti-zloc]
  (def after-zlocs @[])
  (var curr-zloc ti-zloc)
  (var found-comment nil)
  (var found-after nil)
  #
  (while curr-zloc
    (set curr-zloc
         (j/right curr-zloc))
    (when (nil? curr-zloc)
      (break))
    (match (j/node curr-zloc)
      [:comment]
      (do
        (set found-comment true)
        (break))
      #
      [:whitespace]
      (array/push after-zlocs curr-zloc)
      #
      (do
        (set found-after true)
        (array/push after-zlocs curr-zloc)
        (break))))
  #
  (cond
    (or (nil? curr-zloc)
        found-comment)
    :no-expected-expression
    #
    (and found-after
         (match (j/node (first after-zlocs))
           [:whitespace _ "\n"]
           true
           [:whitespace _ "\r\n"]
           true))
    (if-let [from-next-line (drop 1 after-zlocs)
             next-line (take-until |(match (j/node $)
                                      [:whitespace _ "\n"]
                                      true
                                      [:whitespace _ "\r\n"]
                                      true)
                                   from-next-line)
             target (->> next-line
                         (filter |(match (j/node $)
                                    [:whitespace]
                                    false
                                    #
                                    true))
                         first)]
      target
      :no-expected-expression)
    #
    :unexpected-result))

(comment

  (def src
    (string "(comment"         eol
                               eol
            "  (def a 1)"      eol
                               eol
            "  (put @{} :a 2)" eol
            "  # =>"           eol
            "  @{:a 2}"        eol
                               eol
            "  )"))

  (def [ti-zloc _ _]
    (find-test-indicator (-> (l/par src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  '(:comment @{:bc 3 :bl 6 :ec 7 :el 6} "# =>")

  (def expected-expr-zloc
    (find-expected-expr ti-zloc))

  (j/node expected-expr-zloc)
  # =>
  '(:table @{:bc 3 :bl 7 :ec 10 :el 7}
           (:keyword @{:bc 5 :bl 7 :ec 7 :el 7} ":a")
           (:whitespace @{:bc 7 :bl 7 :ec 8 :el 7} " ")
           (:number @{:bc 8 :bl 7 :ec 9 :el 7} "2"))

  (-> (j/left expected-expr-zloc)
      j/node)
  # =>
  '(:whitespace @{:bc 1 :bl 7 :ec 3 :el 7} "  ")

  (def src
    (string "(comment"                eol
                                      eol
            "  (butlast @[:a :b :c])" eol
            "  # => @[:a :b]"         eol
                                      eol
            "  (butlast [:a])"        eol
            "  # => []"               eol
                                      eol
            ")"))

  (def [ti-zloc _ _]
    (find-test-indicator (-> (l/par src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  '(:comment @{:bc 3 :bl 4 :ec 16 :el 4} "# => @[:a :b]")

  (find-expected-expr ti-zloc)
  # =>
  :no-expected-expression

  )

(defn make-label
  [left right]
  (string ""
          (when (not (empty? left))
            (string " " left))
          (when (or (not (empty? left))
                    (not (empty? right)))
            (string " =>"))
          (when (not (empty? right))
            (string " " right))))

(comment

  (make-label "hi" "there")
  # =>
  " hi => there"

  (make-label "hi" "")
  # =>
  " hi =>"

  (make-label "" "there")
  # =>
  " => there"

  (make-label "" "")
  # =>
  ""

  )

(defn find-test-exprs
  [ti-zloc]
  # look for a test expression
  (def test-expr-zloc
    (find-test-expr ti-zloc))
  (case test-expr-zloc
    :no-test-expression
    (break [nil nil])
    #
    :unexpected-result
    (errorf "unexpected result from `find-test-expr`: %p"
            test-expr-zloc))
  # look for an expected value expression
  (def expected-expr-zloc
    (find-expected-expr ti-zloc))
  (case expected-expr-zloc
    :no-expected-expression
    (break [test-expr-zloc nil])
    #
    :unexpected-result
    (errorf "unexpected result from `find-expected-expr`: %p"
            expected-expr-zloc))
  #
  [test-expr-zloc expected-expr-zloc])

(defn wrap-as-test-call
  [start-zloc end-zloc test-label]
  # XXX: hack - not sure if robust enough
  (def eol-str
    (if (= :windows (os/which))
      "\r\n"
      "\n"))
  (-> (j/wrap start-zloc [:tuple @{}] end-zloc)
      # newline important for preserving long strings
      (j/insert-child [:whitespace @{} eol-str])
      # name of test macro
      (j/insert-child [:symbol @{} "_verify/is"])
      # for column zero convention, insert leading whitespace
      # before the beginning of the tuple (_verify/is ...)
      (j/insert-left [:whitespace @{} "  "])
      # add location info argument
      (j/append-child [:whitespace @{} " "])
      (j/append-child [:string @{} test-label])))

(defn rewrite-comment-zloc
  [comment-zloc]
  # move into comment block
  (var curr-zloc (j/down comment-zloc))
  (var found-test nil)
  # process comment block content
  (while (not (j/end? curr-zloc))
    (def [ti-zloc label-left label-right]
      (find-test-indicator curr-zloc))
    (unless ti-zloc
      (break))
    (def [test-expr-zloc expected-expr-zloc]
      (find-test-exprs ti-zloc))
    (set curr-zloc
         (if (or (nil? test-expr-zloc)
                 (nil? expected-expr-zloc))
           (j/right curr-zloc) # next
           # found a complete test, work on rewriting
           (let [left-of-te-zloc (j/left test-expr-zloc)
                 start-zloc (match (j/node left-of-te-zloc)
                              [:whitespace]
                              left-of-te-zloc
                              #
                              test-expr-zloc)
                 end-zloc expected-expr-zloc
                 # XXX: use `attrs` here?
                 ti-line-no ((get (j/node ti-zloc) 1) :bl)
                 test-label (string `"`
                                    `line-` ti-line-no
                                    (make-label label-left label-right)
                                    `"`)]
             (set found-test true)
             (wrap-as-test-call start-zloc end-zloc test-label)))))
  # navigate back out to top of block
  (when found-test
    # morph comment block into plain tuple -- to be unwrapped later
    (-> curr-zloc
        j/up
        j/down
        (j/replace [:whitespace @{} " "])
        # begin hack to prevent trailing whitespace once unwrapping occurs
        j/rightmost
        (j/insert-right [:keyword @{} ":smile"])
        # end of hack
        j/up)))

(comment

  (def src
    (string "(comment"         eol
                               eol
            "  (def a 1)"      eol
                               eol
            "  (put @{} :a 2)" eol
            "  # left =>"      eol
            "  @{:a 2}"        eol
                               eol
            "  (+ 1 1)"        eol
            "  # => right"     eol
            "  2"              eol
                               eol
            "  )"))

  (-> (l/par src)
      j/zip-down
      rewrite-comment-zloc
      j/root
      l/gen)
  # =>
  (string "( "                          eol
                                        eol
          "  (def a 1)"                 eol
                                        eol
          "  (_verify/is"               eol
          "  (put @{} :a 2)"            eol
          "  # left =>"                 eol
          `  @{:a 2} "line-6 left =>")` eol
                                        eol
          "  (_verify/is"               eol
          "  (+ 1 1)"                   eol
          "  # => right"                eol
          `  2 "line-10 => right")`     eol
                                        eol
          "  :smile)")

  )

(defn rewrite-comment-block
  [comment-src]
  (-> (l/par comment-src)
      j/zip-down
      rewrite-comment-zloc
      j/root
      l/gen))

(comment

  (def src
    (string "(comment"          eol
                                eol
            "  (def a 1)"       eol
                                eol
            "  (put @{} :a 2)"  eol
            "  # =>"            eol
            "  @{:a 2}"         eol
                                eol
            "  (+ 1 1)"         eol
            "  # left => right" eol
            "  2"               eol
                                eol
            "  )"))

  (rewrite-comment-block src)
  # =>
  (string "( "                           eol
                                         eol
          "  (def a 1)"                  eol
                                         eol
          "  (_verify/is"                eol
          "  (put @{} :a 2)"             eol
          "  # =>"                       eol
          `  @{:a 2} "line-6")`          eol
                                         eol
          "  (_verify/is"                eol
          "  (+ 1 1)"                    eol
          "  # left => right"            eol
          `  2 "line-10 left => right")` eol
                                         eol
          "  :smile)")

  )

(defn rewrite
  [src]
  (var changed nil)
  # XXX: hack - not sure if robust enough
  (def eol-str
    (if (= :windows (os/which))
      "\r\n"
      "\n"))
  (var curr-zloc
    (-> (l/par src)
        j/zip-down
        # XXX: leading newline is a hack to prevent very first thing
        #      from being a comment block
        (j/insert-left [:whitespace @{} eol-str])
        # XXX: once the newline is inserted, need to move to it
        j/left))
  #
  (while (not (j/end? curr-zloc))
    # try to find a top-level comment block
    (if-let [comment-zloc
             (j/right-until curr-zloc
                            |(match (j/node $)
                               [:tuple _ [:symbol _ "comment"]]
                               true))]
      # may be rewrite the located top-level comment block
      (set curr-zloc
           (if-let [rewritten-zloc
                    (rewrite-comment-zloc comment-zloc)]
             (do
               (set changed true)
               (j/unwrap rewritten-zloc))
             comment-zloc))
      (break)))
  (when changed
    (-> curr-zloc
        j/root
        l/gen)))

(comment

  (def src
    (string "(require \"json\")" eol
                                 eol
            "(defn my-fn"        eol
            "  [x]"              eol
            "  (+ x 1))"         eol
                                 eol
            "(comment"           eol
                                 eol
            "  (def a 1)"        eol
                                 eol
            "  (put @{} :a 2)"   eol
            "  # =>"             eol
            "  @{:a 2}"          eol
                                 eol
            "  (my-fn 1)"        eol
            "  # =>"             eol
            "  2"                eol
                                 eol
            "  )"                eol
                                 eol
            "(defn your-fn"      eol
            "  [y]"              eol
            "  (* y y))"         eol
                                 eol
            "(comment"           eol
                                 eol
            "  (your-fn 3)"      eol
            "  # =>"             eol
            "  9"                eol
                                 eol
            "  (def b 1)"        eol
                                 eol
            "  (+ b 1)"          eol
            "  # =>"             eol
            "  2"                eol
                                 eol
            "  (def c 2)"        eol
                                 eol
            "  )"                eol
            ))

  (rewrite src)
  # =>
  (string                        eol
          `(require "json")`     eol
                                 eol
          "(defn my-fn"          eol
          "  [x]"                eol
          "  (+ x 1))"           eol
                                 eol
          " "                    eol
                                 eol
          "  (def a 1)"          eol
                                 eol
          "  (_verify/is"        eol
          "  (put @{} :a 2)"     eol
          "  # =>"               eol
          `  @{:a 2} "line-12")` eol
                                 eol
          "  (_verify/is"        eol
          "  (my-fn 1)"          eol
          "  # =>"               eol
          `  2 "line-16")`       eol
                                 eol
          "  :smile"             eol
                                 eol
          "(defn your-fn"        eol
          "  [y]"                eol
          "  (* y y))"           eol
                                 eol
          " "                    eol
                                 eol
          "  (_verify/is"        eol
          "  (your-fn 3)"        eol
          "  # =>"               eol
          `  9 "line-28")`       eol
                                 eol
          "  (def b 1)"          eol
                                 eol
          "  (_verify/is"        eol
          "  (+ b 1)"            eol
          "  # =>"               eol
          `  2 "line-34")`       eol
                                 eol
          "  (def c 2)"          eol
                                 eol
          "  :smile"             eol)

  )

(comment

  # https://github.com/sogaiu/judge-gen/issues/1
  (def src
    (string "(comment"        eol
                              eol
            "  (-> ``"        eol
            "      123456789" eol
            "      ``"        eol
            "      length)"   eol
            "  # =>"          eol
            "  9"             eol
                              eol
            "  (->"           eol
            "    ``"          eol
            "    123456789"   eol
            "    ``"          eol
            "    length)"     eol
            "  # =>"          eol
            "  9"             eol
                              eol
            "  )"))

  (rewrite src)
  # =>
  (string                   eol
          " "               eol
                            eol
          "  (_verify/is"   eol
          "  (-> ``"        eol
          "      123456789" eol
          "      ``"        eol
          "      length)"   eol
          "  # =>"          eol
          `  9 "line-7")`   eol
                            eol
          "  (_verify/is"   eol
          "  (->"           eol
          "    ``"          eol
          "    123456789"   eol
          "    ``"          eol
          "    length)"     eol
          "  # =>"          eol
          `  9 "line-15")`  eol
                            eol
          "  :smile")

  )

# XXX: try to put in file?  had trouble originally when working on
#      judge-gen.  may be will have more luck?
(def verify-as-string
  ``
  # influenced by janet's tools/helper.janet

  (var _verify/start-time 0)
  (var _verify/end-time 0)
  (var _verify/test-results @[])

  (defmacro _verify/is
    [t-form e-form &opt name]
    (default name
      (string "test-" (inc (length _verify/test-results))))
    (with-syms [$ts $tr
                $es $er]
      ~(do
         (def [,$ts ,$tr] (protect ,t-form))
         (def [,$es ,$er] (protect ,e-form))
         (array/push _verify/test-results
                     {:expected-form ',e-form
                      :expected-value ,$er
                      :name ,name
                      :passed (if (and ,$ts ,$es)
                                (deep= ,$tr ,$er)
                                nil)
                      :test-form ',t-form
                      :test-value ,$tr
                      :type :is})
         ,name)))

  (defn _verify/start-tests
    []
    (set _verify/start-time (os/clock))
    (set _verify/test-results @[]))

  (defn _verify/end-tests
    []
    (set _verify/end-time (os/clock)))

  (defn _verify/print-color
    [msg color]
    # XXX: what if color doesn't match...
    (let [color-num (match color
                      :black 30
                      :blue 34
                      :cyan 36
                      :green 32
                      :magenta 35
                      :red 31
                      :white 37
                      :yellow 33)]
      (prin (string "\e[" color-num "m"
                    msg
                    "\e[0m"))))

  (defn _verify/dashes
    [&opt n]
    (default n 60)
    (string/repeat "-" n))

  (defn _verify/print-dashes
    [&opt n]
    (print (_verify/dashes n)))

  (defn _verify/print-form
    [form &opt color]
    (def buf @"")
    (with-dyns [:out buf]
      (printf "%m" form))
    (def msg (string/trimr buf))
    (print ":")
    (if color
      (_verify/print-color msg color)
      (prin msg))
    (print))

  (defn _verify/report
    []
    (var total-tests 0)
    (var total-passed 0)
    # analyze results
    (var passed 0)
    (var num-tests (length _verify/test-results))
    (var fails @[])
    (each test-result _verify/test-results
      (++ total-tests)
      (def {:passed test-passed} test-result)
      (if test-passed
        (do
          (++ passed)
          (++ total-passed))
        (array/push fails test-result)))
    # report any failures
    (var i 0)
    (each fail fails
      (def {:test-value test-value
            :expected-value expected-value
            :name test-name
            :passed test-passed
            :test-form test-form} fail)
      (++ i)
      (print)
      (prin "--(")
      (_verify/print-color i :cyan)
      (print ")--")
      (print)
      #
      (_verify/print-color "failed:" :yellow)
      (print)
      (_verify/print-color test-name :red)
      (print)
      #
      (print)
      (_verify/print-color "form" :yellow)
      (_verify/print-form test-form)
      #
      (print)
      (_verify/print-color "expected" :yellow)
      (_verify/print-form expected-value)
      #
      (print)
      (_verify/print-color "actual" :yellow)
      (_verify/print-form test-value :blue))
    (when (zero? (length fails))
      (print)
      (print "No tests failed."))
    # summarize totals
    (print)
    (_verify/print-dashes)
    (when (= 0 total-tests)
      (print "No tests found, so no judgements made.")
      (break true))
    (if (not= total-passed total-tests)
      (_verify/print-color total-passed :red)
      (_verify/print-color total-passed :green))
    (prin " of ")
    (_verify/print-color total-tests :green)
    (print " passed")
    (_verify/print-dashes)
    (when (not= total-passed total-tests)
      (os/exit 1)))
  ``)

(defn rewrite-as-test-file
  [src]
  (when (not (empty? src))
    (when-let [rewritten (rewrite src)]
      # XXX: hack - not sure if robust enough
      (def eol-str
        (if (= :windows (os/which))
          "\r\n"
          "\n"))
      (string verify-as-string
              eol-str
              "(_verify/start-tests)"
              eol-str
              rewritten
              eol-str
              "(_verify/end-tests)"
              eol-str
              "(_verify/report)"
              eol-str))))

# no tests so won't be executed
(comment

  (->> (slurp "./to-test-dogfood.janet")
       rewrite-as-test-file
       (spit "./sample-test-dogfood.janet"))

  )

