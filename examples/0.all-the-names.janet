#
# Primitive Patterns
#   Integer Patterns
#   Range Patterns
#   Set Patterns
#   String Patterns
#
# Combining Patterns
#   `any`
#   `at-least`
#   `at-most`
#   `backmatch`
#   `between` aka `opt` or `?`
#   `choice` aka `+`
#   `if`
#   `if-not`
#   `look` aka `>`
#   `not` aka `!`
#   `repeat` aka `n` (actual number)
#   `sequence` aka `*`
#   `some`
#   `thru`
#   `to`
#   `unref`
#
# Captures
#   `accumulate` aka `%`
#   `argument`
#   `backref` aka `->`
#   `capture` aka `<-` or `quote`
#   `cmt`
#   `column`
#   `constant`
#   `drop`
#   `error`
#   `group`
#   `int`
#   `int-be`
#   `lenprefix`
#   `line`
#   `number`
#   `position` aka `$`
#   `replace` aka `/`
#   `uint`
#   `uint-be`
#
# Aliases
#   `(! patt)`               =  `(not patt)`
#   `($ ?tag)`               =  `(position ?tag)`
#   `(% patt ?tag)`          =  `(accumulate patt ?tag)`
#   `(* patt-1 ... patt-n)`  =  `(sequence patt-1 ... patt-n)`
#   `(+ patt-1 ... patt-n)`  =  `(choice patt-1 ... patt-n)`
#   `(-> prev-tag ?tag)`     =  `(backref prev-tag ?tag)`
#   `(/ patt subst ?tag)`    =  `(replace patt subst ?tag)`
#   `(<- patt ?tag)`         =  `(capture patt ?tag)`
#   `(<- patt ?tag)`         =  `(quote patt ?tag)`
#   `(<- patt)`              =  `'patt`
#   `(> offset patt)`        =  `(look offset patt)`
#   `(? patt)`               =  `(between 0 1 patt)`
#   `(1 patt)`               =  `(repeat 1 patt)`
#   `(2 patt)`               =  `(repeat 2 patt)`
#   `(3 patt)`               =  `(repeat 3 patt)`
#   ...
#   `(opt patt)`             =  `(between 0 1 patt)`
#
