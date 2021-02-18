(import ./pegs)

# XXX: simplify?
(defn rewrite-tagged
  [tagged-item last-form offset]
  (match tagged-item
    [:returns value line]
    (string "(_verify/is "
            last-form " "
            value " "
            (string "\"" "line-" (dec (+ line offset)) "\"") ")\n\n")
    nil))

(comment

  (rewrite-tagged [:returns true 1] "(= 1 1)" 1)
  # => "(_verify/is (= 1 1) true \"line-1\")\n\n"

  )

# XXX: tried putting the following into a file, but kept having
#      difficulty getting it to work out
# XXX: an advantage of it being in a separate file is that testing
#      the contained code might be easier...
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

  (defn _verify/dump-results
    []
    (if-let [test-out (dyn :judge-gen/test-out)]
      (spit test-out (marshal _verify/test-results))
      # XXX: could this sometimes have problems?
      (printf "%p" _verify/test-results)))

  ``)

(defn has-tests
  [forms]
  (when forms
    (some |(tuple? $)
          forms)))

(comment

  (has-tests @["(+ 1 1)\n  " [:returns "2" 1]])
  # => true

  (has-tests @["(comment \"2\")\n  "])
  # => nil

  )

(defn rewrite-block-with-verify
  [blk]
  (def rewritten-forms @[])
  (def {:value blk-str
        :s-line offset} blk)
  # parse the comment block and rewrite some parts
  (set pegs/in-comment 0)
  (let [parsed (peg/match pegs/inner-forms blk-str)]
    (when (has-tests parsed)
      (each cmt-or-frm parsed
        (when (not= cmt-or-frm "")
          (if (empty? rewritten-forms)
            (array/push rewritten-forms cmt-or-frm)
            # is `cmt-or-frm` an expected value
            (if (= (type cmt-or-frm) :tuple)
              # looks like an expected value, handle rewriting as test
              (let [last-form (array/pop rewritten-forms)
                    rewritten (rewrite-tagged cmt-or-frm last-form offset)]
                (assert rewritten (string "match failed for: " cmt-or-frm))
                (array/push rewritten-forms rewritten))
              # not an expected value, continue
              (array/push rewritten-forms cmt-or-frm))))
        (set pegs/in-comment 0))))
  rewritten-forms)

(comment

  (def comment-str
    ``
    (comment

      (+ 1 1)
      # => 2

    )
    ``)

  (def comment-blk
    {:value comment-str
     :s-line 3})

  (rewrite-block-with-verify comment-blk)
  # => @["(_verify/is (+ 1 1)\n   2 \"line-6\")\n\n"]

  (do
    (set pegs/in-comment 0)
    (peg/match pegs/inner-forms comment-str))
  # => @["(+ 1 1)\n  " [:returns "2" 4]]

  (def comment-with-no-test-str
    ``
    (comment

      (+ 1 1)

    )
    ``)

  (def comment-blk-with-no-test-str
    {:value comment-with-no-test-str
     :s-line 1})

  (rewrite-block-with-verify comment-blk-with-no-test-str)
  # => @[]

  # comment block in comment block shields inner content
  (def comment-in-comment-str
    ``
    (comment

      (comment

         (+ 1 1)
         # => 2

       )
    )
    ``)

  (def comment-blk-in-comment-blk
    {:value comment-in-comment-str
     :s-line 10})

  (do
    (set pegs/in-comment 0)
    (peg/match pegs/inner-forms comment-in-comment-str))
  # => @["" "(comment\n\n     (+ 1 1)\n     # => 2\n\n   )\n"]

  (rewrite-block-with-verify comment-blk-in-comment-blk)
  # => @[]

  )

(defn rewrite-with-verify
  [cmt-blks &opt format]
  (default format "jdn")
  (var rewritten-forms @[])
  # parse comment blocks and rewrite some parts
  (each blk cmt-blks
    (array/concat rewritten-forms (rewrite-block-with-verify blk)))
  # assemble pieces
  (var forms
    (array/concat @[]
                  @["\n\n"
                    "(_verify/start-tests)\n\n"]
                  rewritten-forms
                  @["\n(_verify/end-tests)\n"
                    (cond
                      (= format "jdn")
                      "\n(_verify/dump-results)\n"
                      #
                      (= format "text")
                      "\n(_verify/summarize)\n"
                      # XXX: is this appropriate?
                      (do
                        (eprint "warning: unrecognized format: " format)
                        "\n(_verify/dump-results)\n"))]))
  (string verify-as-string
          (string/join forms "")))

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  # XXX: expected values are all large here -- not testing

  (def sample
    ``
    (comment

      (= 1 1)
      # => true

    )
    ``)

  (rewrite-with-verify [sample] "text")

  (def sample-comment-form
    ``
    (comment

      (def a 1)

      # this is just a comment

      (def b 2)

      (= 1 (- b a))
      # => true

    )
    ``)

  (rewrite-with-verify [sample-comment-form] "jdn")

  (def comment-in-comment
    ``
    (comment

      (comment

        (+ 1 1)
        # => 2

      )

    )
    ``)

  (rewrite-with-verify [comment-in-comment] "jdn")

  )
