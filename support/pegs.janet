(import ./vendor/grammar)

# XXX: any way to avoid this?
(var in-comment 0)

(def jg-comments
  (->
   # jg* from grammar are structs, need something mutable
   (table ;(kvs grammar/jg))
   (put :main '(choice (capture :value)
                       :comment))
   #
   (put :comment-block ~(sequence
                          "("
                          (any :ws)
                          (drop (cmt (capture "comment")
                                     ,|(do
                                         (++ in-comment)
                                         $)))
                          :root
                          (drop (cmt (capture ")")
                                     ,|(do
                                         (-- in-comment)
                                         $)))))
   (put :ptuple ~(choice :comment-block
                         (sequence "("
                                   :root
                                   (choice ")" (error "")))))
   # classify certain comments
   (put :comment ~(sequence
                    (any :ws)
                    (choice
                      (cmt (sequence
                             (line)
                             "#" (any :ws) "=>"
                             (capture (sequence
                                        (any (if-not (choice "\n" -1) 1))
                                        (any "\n"))))
                           ,|(if (zero? in-comment)
                               # record value and line
                               [:returns (string/trim $1) $0]
                               ""))
                      (cmt (capture (sequence
                                      "#"
                                      (any (if-not (+ "\n" -1) 1))
                                      (any "\n")))
                           ,|(identity $))
                      (any :ws))))
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(def inner-forms
  ~{:main :inner-forms
    #
    :inner-forms (sequence
                  "("
                  (any :ws)
                  "comment"
                  (any :ws)
                  (any (choice :ws ,jg-comments))
                  (any :ws)
                  ")")
    #
    :ws (set " \0\f\n\r\t\v")
    })

(comment

  (deep=
    #
    (peg/match
      inner-forms
      ``
      (comment
        (- 1 1)
        # => 0
      )
      ``)
    #
    @["(- 1 1)\n  "
      [:returns "0" 3]])
  # => true

  (deep=
    #
    (peg/match
      inner-forms
      ``
      (comment

        (def a 1)

        # this is just a comment

        (def b 2)

        (= 1 (- b a))
        # => true

      )
      ``)
    #
    @["(def a 1)\n\n  "
      "# this is just a comment\n\n"
      "(def b 2)\n\n  "
      "(= 1 (- b a))\n  "
      [:returns "true" 10]])
  # => true

  )

# recognize next top-level form, returning a map
# modify a copy of jg
(def jg-pos
  (->
   # jg* from grammar are structs, need something mutable
   (table ;(kvs grammar/jg))
   # also record location and type information, instead of just recognizing
   (put :main ~(choice (cmt (sequence
                              (position)
                              (line)
                              (capture :value)
                              (position))
                            ,|(do
                                (def [start s-line value end] $&)
                                {:end end
                                 :start start
                                 :s-line s-line
                                 :type :value
                                 :value value}))
                       (cmt (sequence
                              (position)
                              (line)
                              (capture :comment)
                              (position))
                            ,|(do
                                (def [start s-line value end] $&)
                                {:end end
                                 :start start
                                 :s-line s-line
                                 :type :comment
                                 :value value}))))
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(comment

  (def sample-source
    (string "# \"my test\"\n"
            "(+ 1 1)\n"
            "# => 2\n"))

  (deep=
    #
    (peg/match jg-pos sample-source 0)
    #
    @[{:type :comment
       :value "# \"my test\"\n"
       :start 0
       :s-line 1
       :end 12}]) # => true

  (deep=
    #
    (peg/match jg-pos sample-source 12)
    #
    @[{:type :value
       :value "(+ 1 1)\n"
       :start 12
       :s-line 2
       :end 20}]) # => true

  (string/slice sample-source 12 20)
  # => "(+ 1 1)\n"

  (deep=
    #
    (peg/match jg-pos sample-source 20)
    #
    @[{:type :comment
       :value "# => 2\n"
       :start 20
       :s-line 3
       :end 27}]) # => true

)

(comment

  (def top-level-comments-sample
    ``
    (def a 1)

    (comment

      (+ 1 1)

      # hi there

      (comment :a )

    )

    (def x 0)

    (comment

      (= a (+ x 1))

    )
    ``)

  (deep=
    #
    (peg/match jg-pos top-level-comments-sample)
    #
    @[{:type :value
       :value "(def a 1)\n\n"
       :start 0
       :s-line 1
       :end 11}]
    ) # => true

  (deep=
    #
    (peg/match jg-pos top-level-comments-sample 11)
    #
    @[{:type :value
       :value
       "(comment\n\n  (+ 1 1)\n\n  # hi there\n\n  (comment :a )\n\n)\n\n"
       :start 11
       :s-line 3
       :end 66}]
    ) # => true

  (deep=
    #
    (peg/match jg-pos top-level-comments-sample 66)
    #
    @[{:type :value
       :value "(def x 0)\n\n"
       :start 66
       :s-line 13
       :end 77}]
    ) # => true

  (deep=
    #
    (peg/match jg-pos top-level-comments-sample 77)
    #
    @[{:type :value
       :value "(comment\n\n  (= a (+ x 1))\n\n)"
       :start 77
       :s-line 15
       :end 105}]
    ) # => true

 )

(def comment-block-maybe
  ~{:main (sequence
           (any :ws)
           "("
           (any :ws)
           "comment"
           (any :ws))
    #
    :ws (set " \0\f\n\r\t\v")})

(comment

  (peg/match
    comment-block-maybe
    ``
    (comment

      (= a (+ x 1))

    )
    ``)
  # => @[]

  (peg/match
    comment-block-maybe
    ``

    (comment

      :a
    )
    ``)
  # => @[]

 )
