(import ../../../margaret/meg :as peg)

(comment

  (def re-peg
    ~{:p (drop (cmt ($)
                    ,(fn [n]
                       (print "AT: " n) n)))
      :l :a
      :letters (<- (some :l))
      :sym (set "<>|")
      :wild (* "[" (cmt :letters
                        ,(fn [ls]
                           (tuple 'set ls))) "]")
      :squish (cmt (* (<- :sym) "[^" 
                      (? (* (<- :sym) "]" "[^"))
                      (<- :sym :1) "]*" (backmatch :1) )
                   ,(fn [& ss]
                      (match ss
                        @[a b c]
                        (tuple '* a (tuple 'if-not b 1) (tuple 'thru c))
                        @[a b]
                        (tuple '* a (tuple 'thru b)))))
      :sub (+ :letters :wild :squish)
      :word (cmt (some :sub) ,(fn [& ss]
                                (if (= 1 (length ss))
                                  (in ss 0)
                                  (tuple '* ;ss))))
      :words (cmt (* :word (any (* "|" :word)))
                  ,(fn [& wds]
                     (if (= 1 (length wds)) (in wds 0)
                       (tuple '+ ;wds))))
      :main (+ :words :word)})

  (peg/match re-peg "a")
  # => @["a"]

  (peg/match re-peg "a|b")
  # => '@[(+ "a" "b")]

  (peg/match re-peg "[xyz]")
  # => '@[(set "xyz")]

)
