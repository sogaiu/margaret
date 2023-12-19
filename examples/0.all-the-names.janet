#
# Primitive Patterns
#   Boolean Patterns
#   Integer Patterns
#   Range Patterns
#   Set Patterns
#   String Patterns
#
# Combining Patterns
#   any
#   at-least
#   at-most
#   backmatch
#   between aka opt or ?
#   choice aka +
#   if
#   if-not
#   look aka >
#   not aka !
#   repeat aka n (actual number)
#   sequence aka *
#   some
#   thru
#   to
#   unref
#
# Captures
#   accumulate aka %
#   argument
#   backref aka ->
#   capture aka <- or quote
#   cmt
#   column
#   constant
#   drop
#   error
#   group
#   int
#   int-be
#   lenprefix
#   line
#   number
#   position aka $
#   replace aka /
#   uint
#   uint-be
#
# Built-ins
#   :a                     =  (range "AZ" "az")
#   :d                     =  (range "09")
#   :h                     =  (range "09" "AF" "af")
#   :s                     =  (set " \0\f\n\r\t\v")
#   :w                     =  (range "09" "AZ" "az")
#   :A                     =  (if-not :a 1)
#   :D                     =  (if-not :d 1)
#   :H                     =  (if-not :h 1)
#   :S                     =  (if-not :s 1)
#   :W                     =  (if-not :w 1)
#   :a+                    =  (some :a)
#   :d+                    =  (some :d)
#   :h+                    =  (some :h)
#   :s+                    =  (some :s)
#   :w+                    =  (some :w)
#   :A+                    =  (some :A)
#   :D+                    =  (some :D)
#   :H+                    =  (some :H)
#   :S+                    =  (some :S)
#   :W+                    =  (some :W)
#   :a*                    =  (any :a)
#   :d*                    =  (any :d)
#   :h*                    =  (any :h)
#   :s*                    =  (any :s)
#   :w*                    =  (any :w)
#   :A*                    =  (any :A)
#   :D*                    =  (any :D)
#   :H*                    =  (any :H)
#   :S*                    =  (any :S)
#   :W*                    =  (any :W)
#
# Aliases
#   (! patt)               =  (not patt)
#   ($ ?tag)               =  (position ?tag)
#   (% patt ?tag)          =  (accumulate patt ?tag)
#   (* patt-1 ... patt-n)  =  (sequence patt-1 ... patt-n)
#   (+ patt-1 ... patt-n)  =  (choice patt-1 ... patt-n)
#   (-> prev-tag ?tag)     =  (backref prev-tag ?tag)
#   (/ patt subst ?tag)    =  (replace patt subst ?tag)
#   (<- patt ?tag)         =  (capture patt ?tag)
#   (> offset patt)        =  (look offset patt)
#   (? patt)               =  (between 0 1 patt)
#   (1 patt)               =  (repeat 1 patt)
#   (2 patt)               =  (repeat 2 patt)
#   (3 patt)               =  (repeat 3 patt)
#   ...
#   (opt patt)             =  (between 0 1 patt)
#   (quote patt ?tag)      =  (capture patt ?tag)
#   'patt                  =  (capture patt)
#
