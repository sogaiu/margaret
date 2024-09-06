(import ../../../margaret/meg :as peg)

(comment

  (def csv-lang
    (peg/compile
      '{:comma ","
        :space " "
        :space? (any :space)
        :cr "\r"
        :lf "\n"
        :nl (+ (* :cr :lf)
               :cr :lf)
        :dquote "\""
        :dquote? (? "\"")
        :d_dquote (* :dquote :dquote)
        :textdata (+ (<- (some (if-not (+ :dquote :comma :nl) 1)))
                     (* :dquote
                        (<- (some (+ (if :d_dquote 2)
                                     (if-not :dquote 1))))
                        :dquote))
        :empty_field 0
        :field (accumulate (+ (* :space? :textdata :space?)
                              :empty_field))
        :row (* (any (+ (* :field :comma)
                        :field))
                (+ :nl 0))
        :main (some (group :row))}))

  (peg/match csv-lang "great,scott,tiger,woods")
  # =>
  @[@["great" "scott" "tiger" "woods"]]

  (peg/match csv-lang
             (string "header1,header2,header3\n"
                     "this,is,nice\n"
                     ",,,"))
  #
  @[@["header1" "header2" "header3"]
    @["this" "is" "nice"]
    @["" "" ""]]

  )
