# XXX: more tag examples?

# XXX: after a single pass through, study examples and consider
#      additional / changes.  then consider rearranging
#      material to introduce things like `capture` earlier.
#      the current arrangement feels more like a reference and
#      is not so good for learning the material for the first
#      time.

# based on https://janet-lang.org/docs/peg.html

(comment

# Parsing Expression Grammars
#   The `peg` module
#   The `peg/match` function
#   Primitive Patterns
#     String Patterns
#     Integer Patterns
#     Range Patterns
#     Set Patterns
#   Combining Patterns
#     `choice` aka `+`
#     `sequence` aka `*`
#     `any`
#     `some`
#     `between` aka `opt` or `?`
#     `at-least`
#     `at-most`
#     `repeat` aka `n` (actual number)
#     `if`
#     `if-not`
#     `not` aka `!`
#     `look` aka `>`
#     `to`
#     `thru`
#     `backmatch`
#   Greediness and Backtracking
#   Captures
#     `capture` aka `<-` or `quote`
#     `group`
#     `replace` aka `/`
#     `constant`
#     `argument`
#     `position` aka `$`
#     `line`
#     `column`
#     `accumulate` aka `%`
#     `cmt`
#     `backref` aka `->`
#     `error`
#     `drop`
#     `lenprefix`
#     `int`
#     `int-be`
#     `uint`
#     `uint-be`
#   Grammars and Recursion
#   Recursion and Stack Limit
#   Built-in Patterns
#   String Searching and Other Idioms
#     `peg/find`
#     `peg/find-all`
#     `peg/replace`
#     `peg/replace-all`
# More Examples
# Real World Code Samples
# References

# Parsing Expression Grammars
# ---------------------------

# PEGs, or Parsing Expression Grammars, are another formalism
# for recognizing languages.

# PEGs are easier to write than a custom parser and more
# powerful than regular expressions. They also can produce
# grammars that are easily understandable and fast.

# PEGs can also be compiled to a bytecode format that can be
# reused.

# Janet offers the `peg` module for writing and evaluating PEGs.

# (Janet's `peg` module borrows syntax and ideas from both LPeg
# and REBOL/Red parse module. Janet has no built-in regex module
# because PEGs offer a superset of the functionality of regular
# expressions.)

(keep (fn [sym]
        (when (string/has-prefix? "peg/" (string sym))
          (string sym)))
      (all-bindings))
``
@["peg/compile"
  "peg/find"
  "peg/find-all"
  "peg/match"
  "peg/replace"
  "peg/replace-all"]
``

# The `peg` module
# ----------------

# The `peg` module uses the concept of a capture stack to extract
# data from text.

# As the PEG is trying to match a piece of text, some forms may
# push Janet values onto the capture stack as a side effect.

# If the text matches the PEG, `peg/match` will return the final
# capture stack as an array.

(type peg/match)
# => :cfunction

# The `peg/match` function
# ------------------------

# `(peg/match peg text
#             &opt start
#             & args)`

# Match a PEG against some text.

# Returns an array of captured data if the text matches.

(peg/match "cat" "cat")
# => @[]

# N.B. 1. matching succeeded and the returned array is the 
#         capture stack

# N.B. 2. array is empty because there was a match, but no 
#         capture

(peg/match ~(capture "cat") "cat")
# => @["cat"]

# N.B. matching succeeded and there was a capture, so the 
#      returned array (capture stack) is not empty

# `peg/match` returns nil if there is no match.

(peg/match "cat" "ca")
# => nil

# N.B. matching was not successful so the return value is nil

# The caller of `peg/match` can provide an optional start index 
# to begin matching, otherwise the PEG starts on the first 
# character of text.

(peg/match "cat" "cat" 0)
# => @[]

(peg/match "cat" "cat")
# => @[]

(peg/match "cat" "notcat" 3)
# => @[]

(peg/match "cat" "notcat" 2)
# => nil

# A PEG can either be a compiled PEG object or PEG source.

# N.B. examples before this point have been using "PEG source"

(type (peg/compile "cat"))
# => :core/peg

(let [cat-peg (peg/compile "cat")]
  [(peg/match cat-peg "cat")
   (peg/match cat-peg "category")])
# => [@[] @[]]

# The variadic `args` argument to `peg/match` is used by the
# as-yet-unintroduced capture form `argument` and will be 
# described later.

# Primitive Patterns
# ------------------

# Larger patterns are built up with primitive patterns, which 
# recognize:

#   * string literals
#   * individual characters
#   * a given number of characters

# A character in Janet is considered a byte, so PEGs will work 
# on any string of bytes.

# No special meaning is given to the 0 byte, or the string 
# terminator as in many languages.

# String Patterns
# ---------------

# Matches a literal string, and advances a corresponding number of characters.

# N.B. "advances" refers to an increase in the value of the current position
#      under consideration of the target text as matching is carried out
#      according to the PEG.

#      The "current position" of the text is relevant because it affects
#      matching.

#      The conditions under which "advancing" occurs vary, but should be
#      described in the documentation.

(peg/match "cat" "cat")
# => @[]

(peg/match "cat" "cat1")
# => @[]

(peg/match "" "")
# => @[]

(peg/match "" "a")
# => @[]

(peg/match "cat" "dog")
# => nil

# Integer Patterns
# ----------------

# Matches a number of characters, and advances that many characters.

(peg/match 3 "cat")
# => @[]

(peg/match 2 "cat")
# => @[]

(peg/match 4 "cat")
# => nil

# If negative, matches if not that many characters and does not advance.

# For example, -1 will match the end of a string because the length of
# the empty string is 0, which is less than 1 (i.e. "not that many
# characters").

(peg/match -1 "cat")
# => nil

(peg/match -1 "")
# => @[]

(peg/match -2 "")
# => @[]

(peg/match -2 "o")
# => @[]

# Range Patterns
# --------------

# Matches characters in a range and advances 1 character.

(peg/match '(range "ac") "b")
# => @[]

# N.B. in this case the grammar needs to be quoted

(peg/match ~(range "ac") "b")
# => @[]

# N.B. using quasiquoting (~) means unquoting can be used within
#      the grammar expression

(let [a-range "ac"]
  (peg/match ~(range ,a-range) "b"))
# => @[]

# Multiple ranges can be combined together.

(let [text (if (< (math/random) 0.5)
               "b"
               "y")]
  (peg/match ~(range "ac" "xz") text))
# => @[]

# Set Patterns
# ------------

# Match any character in the argument string. Advances 1 character.

(peg/match ~(set "cat") "cat")
# => @[]

(peg/match ~(set "act!") "cat!")
# => @[]

(peg/match ~(set "bo") "bob")
# => @[]

# Combining Patterns
# ------------------

# The primitive patterns can be combined with several combinators to match
# a wide number of languages.

# These combinators can be thought of as the looping and branching forms in
# a traditional language (that is how they are implemented when compiled
# to bytecode).

# `choice` aka `+`
# ----------------

# `(choice a b ...)`

# Tries to match a, then b, and so on.

# Will succeed on the first successful match,

(peg/match ~(choice "a" "b") "a")
# => @[]

(peg/match ~(choice "a" "b") "b")
# => @[]

# and fails if none of the arguments match the text.

(peg/match ~(choice "a" "b") "c")
# => nil

# `(+ a b c ...)` is an alias for `(choice a b c ...)`

(peg/match ~(+ "a" "b") "a")
# => @[]

# `sequence` aka `*`
# ------------------

# `(sequence a b c ...)`

# Tries to match a, b, c and so on in sequence.

(peg/match ~(sequence "a" "b" "c") "abc")
# => @[]

(peg/match ~(sequence "a" "b" "c") "abcd")
# => @[]

# If any of these arguments fail to match the text, the whole pattern fails.

(peg/match ~(sequence "a" "b" "c") "abx")
# => nil

# `(* a b c ...)` is an alias for `(sequence a b c ...)`

(peg/match ~(* "a" "b" "c") "abc")
# => @[]

# `any`
# -----

# `(any patt)`

# Matches 0 or more repetitions of `patt`

(peg/match ~(any "a") "aaa")
# => @[]

(peg/match ~(any "bo") "")
# => @[]

# `some`
# ------

# `(some patt)`

# Matches 1 or more repetitions of `patt`

(peg/match ~(some "a") "aa")
# => @[]

(peg/match ~(some "a") "")
# => nil

# `between` aka `opt` or `?`
# --------------------------

# `(between min max patt)`

# Matches between `min` and `max` (inclusive) repetitions of `patt`

(peg/match ~(between 1 3 "a") "aa")
# => @[]

(peg/match ~(between 0 8 "b") "")
# => @[]

(peg/match ~(sequence (between 0 2 "c") "c")
           "ccc")
# => @[]

(peg/match ~(sequence (between 0 3 "c") "c")
           "ccc")
# => nil

# `(opt patt)` and `(? patt)` are aliases for `(between 0 1 patt)`

(peg/match ~(between 0 1 "a") "a")
# => @[]

(peg/match ~(between 0 1 "a") "")
# => @[]

(peg/match ~(opt "a") "a")
# => @[]

(peg/match ~(opt "a") "")
# => @[]

(peg/match ~(? "a") "a")
# => @[]

(peg/match ~(? "a") "")
# => @[]

# `at-least`
# ----------

# `(at-least n patt)`

# Matches at least n repetitions of patt

(peg/match ~(at-least 3 "z") "zz")
# => nil

(peg/match ~(at-least 3 "z") "zzz")
# => @[]

# `at-most`
# ---------

# `(at-most n patt)`

# Matches at most n repetitions of patt
(peg/match ~(at-most 3 "z") "zz")
# => @[]

(peg/match ~(sequence (at-most 3 "z") "z")
           "zzz")
# => nil

# `repeat` aka `n` (actual number)
# --------------------------------

# `(repeat n patt)`

# Matches exactly n repetitions of x

(peg/match ~(repeat 3 "m") "mmm")
# => @[]

(peg/match ~(repeat 2 "m") "m")
# => nil

# `(n patt)` is an alias for `(repeat n patt)`

(peg/match ~(3 "m") "mmm")
# => @[]

(peg/match ~(2 "m") "m")
# => nil

# `if`
# ----

# `(if cond patt)`

# Tries to match `patt` only if `cond` matches as well.

# `cond` will not produce any captures. [*]

(peg/match ~(if 5 (set "eilms"))
           "smile")
# => @[]

(peg/match ~(if 5 (set "eilms"))
           "wink")
# => nil

# `if-not`
# --------

# `(if-not cond patt)`

# Tries to match only if `cond` does not match.

# `cond` will not produce any captures. [*]

(peg/match ~(if-not 5 (set "iknw"))
           "wink")
# => @[]

# `not` aka `!`
# -------------

# `(not patt)`

# Matches only if `patt` does not match.

# Will not produce captures or advance any characters.

(peg/match ~(not "cat") "dog")
# => @[]

(peg/match ~(sequence (not "cat")
                      (set "dgo"))
           "dog")
# => @[]

# `(! patt)` is an alias for `(not patt)`

(peg/match ~(! "cat") "dog")
# => @[]

# `look` aka `>`
# --------------

# `(look offset patt)`

# Matches only if `patt` matches at a fixed offset.

# `offset` can be any integer.

# `patt` will not produce captures [*] and the peg will not advance any
# characters.

(peg/match ~(look 3 "cat")
           "my cat")
# => @[]

(peg/match ~(sequence (look 3 "cat")
                      "my")
           "my cat")
# => @[]

(peg/match ~(capture (look 3 "cat"))
           "my cat")
# => @[""]

# `(> offset patt)` is an alias for `(look offset patt)`

(peg/match ~(> 3 "cat")
           "my cat")
# => @[]

(peg/match ~(sequence (> 3 "cat")
                      "my")
           "my cat")
# => @[]

# `to`
# ----

# `(to patt)`

# Match up to `patt` (but not including it).

# If the end of the input is reached and `patt` is not matched, the entire
# pattern does not match.

(peg/match ~(to "\n")
           "this is a nice line\n")
# => @[]

(peg/match ~(sequence (to "\n")
                      "\n")
           "this is a nice line\n")
# => @[]

# `thru`
# ------

# `(thru patt)`

# Match up through `patt` (thus including it).

# If the end of the input is reached and `patt` is not matched, the entire
# pattern does not match.

(peg/match ~(thru "\n")
           "this is a nice line\n")
# => @[]

(peg/match ~(sequence (thru "\n")
                      "\n")
           "this is a nice line\n")
# => nil

# `backmatch`
# -----------

# `(backmatch ?tag)`

# If `tag` is provided, matches against the tagged capture.

# If no tag is provided, matches against the last capture, but only if that
# capture is untagged.

# The peg advances if there was a match.

# XXX: these examples use `capture` which really hasn't been introduced yet

(peg/match ~(sequence (capture "a" :target)
                      (capture (some "b"))
                      (capture (backmatch :target)))
           "abbba")
# => @["a" "bbb" "a"]

(peg/match ~(sequence (capture "a")
                      (capture (some "b"))
                      (capture (backmatch))) # referring to captured "b"s
           "abbba")
# => nil

(peg/match ~(sequence (capture "a")
                      (some "b")
                      (capture (backmatch))) # referring to captured "a"
           "abbba")
# => @["a" "a"]

# Greediness and Backtracking
# ---------------------------

# PEGs try to match an input text with a pattern in a greedy manner.

# This means that if a rule fails to match, that rule will fail and not try
# again.

# The only backtracking provided in a PEG is provided by the
# `(choice x y z ...)` special, which will try rules in order until one
# succeeds, and the whole pattern succeeds.

# If no sub-pattern succeeds, then the whole pattern fails.

# Note that this means that the order of `x` `y` `z` in `choice` does matter.

# If `y` matches everything that `z` matches, `z` will never succeed.

# Captures
# --------

# Capture specials will only push captures to the capture stack if their
# child pattern matches the text.

# Most captures specials will match the same text as their first argument
# pattern.

# In addition, most specials that produce captures can take an optional
# argument `tag` that applies a keyword tag to the capture.

# These tagged captures can then be recaptured via the `(backref tag)`
# special in subsequent matches.

# Tagged captures, when combined with the `cmt` special, provide a powerful
# form of look-behind that can make many grammars simpler.

# `capture` aka `<-` or `quote`
# -----------------------------

# `(capture patt ?tag)`

# Capture all of the text in `patt` if `patt` matches.

# If `patt` contains any captures, then those captures will be pushed on to
# the capture stack before the total text.

# XXX: if `capture` had been introduced much earlier, certain parts of the
#      docs might have made more sense at the time (e.g. bits that refer
#      to capturing)

(peg/match ~(capture "a") "a")
# => @["a"]

(peg/match ~(capture 2) "hi")
# => @["hi"]

(peg/match ~(capture -1) "")
# => @[""]

(peg/match ~(capture (range "ac")) "b")
# => @["b"]

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~(capture (range "ac" "xz"))
                       text)]
  (or (= cap "b")
      (= cap "y")))
# => true

(peg/match ~(capture (set "cat")) "cat")
# => @["c"]

# `(<- patt ?tag)` is an alias for `(capture patt ?tag)`

(peg/match ~(<- "a") "a")
# => @["a"]

(peg/match ~(<- 2) "hi")
# => @["hi"]

(peg/match ~(<- -1) "")
# => @[""]

(peg/match ~(<- (range "ac")) "b")
# => @["b"]

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~(<- (range "ac" "xz"))
                       text)]
  (or (= cap "b")
      (= cap "y")))
# => true

(peg/match ~(<- (set "cat")) "cat")
# => @["c"]

# `(quote patt ?tag)` is an alias for `(capture patt ?tag)`

# This allows code like `'patt` to capture a pattern

(peg/match ~(quote "a") "a")
# => @["a"]

(peg/match ~'"a" "a")
# => @["a"]

(peg/match ~(quote 2) "hi")
# => @["hi"]

(peg/match ~'2 "hi")
# => @["hi"]

(peg/match ~(quote -1) "")
# => @[""]

(peg/match ~'-1 "")
# => @[""]

(peg/match ~(quote (range "ac")) "b")
# => @["b"]

(peg/match ~'(range "ac") "b")
# => @["b"]

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~(quote (range "ac" "xz"))
                       text)]
  (or (= cap "b")
      (= cap "y")))
# => true

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~'(range "ac" "xz")
                       text)]
  (or (= cap "b")
      (= cap "y")))
# => true

(peg/match ~(quote (set "cat")) "cat")
# => @["c"]

(peg/match ~'(set "cat") "cat")
# => @["c"]

# `group`
# -------

# `(group patt ?tag)`

# Captures an array of all of the captures in `patt`

(first
  (peg/match ~(group (sequence (capture "(")
                               (capture (any (if-not ")" 1)))
                               (capture ")")))
             "(defn hi [] 1)"))
# => @["(" "defn hi [] 1" ")"]

# `replace` aka `/`
# -----------------

# `(replace patt subst ?tag)`

# Replaces the captures produced by `patt` by applying `subst` to them.

# If `subst` is a table or struct, will push `(get subst last-capture)` to
# the capture stack after removing the old captures.

# If `subst` is a function, will call `subst` with the captures of `patt`
# as arguments and push the result to the capture stack.

# Otherwise, will push `subst` literally to the capture stack.

(peg/match ~(replace (capture "cat")
                     {"cat" "tiger"})
           "cat")
# => @["tiger"]

(peg/match ~(replace (capture "cat")
                     ,(fn [original]
                        (string original "alog")))
           "cat")
# => @["catalog"]

(peg/match ~(replace (capture "cat")
                     "dog")
           "cat")
# => @["dog"]

# `(/ patt subst ?tag)` is an alias for `(replace patt subst ?tag)`

(peg/match ~(/ (capture "cat")
               {"cat" "tiger"})
           "cat")
# => @["tiger"]

(peg/match ~(/ (capture "cat")
               ,(fn [original]
                  (string original "alog")))
           "cat")
# => @["catalog"]

(peg/match ~(/ (capture "cat")
               "dog")
           "cat")
# => @["dog"]

# `constant`
# ----------

# `(constant k ?tag)`

# Captures a constant value and advances no characters.

(peg/match ~(constant "smile")
           "whatever")
# => @["smile"]

(peg/match ~(constant {:fun :value})
           "whatever")
# => @[{:fun :value}]

# `argument`
# ----------

# `(argument n ?tag)`

# Captures the nth extra argument to the `match` function and does not advance.

(let [start 0]
  (peg/match ~(argument 2) "whatever"
             start :zero :one :two))
# => @[:two]

(peg/match ~(argument 0) "whatever"
           0 :zero :one :two)
# => @[:zero]

# `position` aka `$`
# ------------------

# `(position ?tag)`

# Captures the current index into the text and advances no input.

(peg/match ~(position) "a")
# => @[0]

(peg/match ~(sequence "a"
                      (position))
           "ab")
# => @[1]

# `($ ?tag)` is an alias for `(position ?tag)`

(peg/match ~($) "a")
# => @[0]

(peg/match ~(sequence "a"
                      ($))
           "ab")
# => @[1]

# `line`
# ------

# `(line)`

# Captures the line of the current index into the text and advances no input.

(peg/match ~(sequence "a"
                      (line))
           "a")
# => @[1]

(peg/match ~(sequence "a"
                      (line)
                      (capture "b"))
           "ab")
# => @[1 "b"]

# `column`
# --------

# `(column)`

# Captures the column of the current index into the text and advances no input.

(peg/match ~(sequence "ab"
                      (column))
           "ab")
# => @[3]

(peg/match ~(sequence "ab"
                      (column)
                      (capture "c"))
           "abc")
# => @[3 "c"]

# `accumulate` aka `%`
# --------------------

# `(accumulate patt ?tag)`

# Capture a string that is the concatenation of all captures in `patt`.

# This will try to be efficient and not create intermediate string if possible.

(peg/match ~(accumulate (sequence (capture "a")
                                  (capture "b")
                                  (capture "c")))
           "abc")
# => @["abc"]

(peg/match ~(accumulate (sequence (capture "a")
                                  (position)
                                  (capture "b")
                                  (position)
                                  (capture "c")
                                  (position)))
           "abc")
# => @["a1b2c3"]

# `(% ?tag)` is an alias for `(accumulate ?tag)`

(peg/match ~(% (sequence (capture "a")
                         (capture "b")
                         (capture "c")))
           "abc")
# => @["abc"]

(peg/match ~(% (sequence (capture "a")
                         (position)
                         (capture "b")
                         (position)
                         (capture "c")
                         (position)))
           "abc")
# => @["a1b2c3"]

# `cmt`
# -----

# `(cmt patt fun ?tag)`

# Invokes `fun` with all of the captures of `patt` as arguments (if `patt`
# matches).

# If the result is truthy, then captures the result.

# The whole expression fails if `fun` returns false or nil.

(peg/match ~(cmt (capture "hello")
                 ,(fn [cap]
                    (string cap "!")))
           "hello")
# => @["hello!"]

(peg/match ~(cmt (sequence (capture "hello")
                           (some (set " ,"))
                           (capture "world"))
                 ,(fn [cap1 cap2]
                    (string cap2 ": yes, " cap1 "!")))
           "hello, world")
# => @["world: yes, hello!"]

# `backref` aka `->`
# ------------------

# `(backref prev-tag ?tag)`

# Duplicates the last capture with tag `prev-tag`.

# If no such capture exists then the match fails.

(peg/match ~(sequence (capture "a" :target)
                      (backref :target))
           "a")
# => @["a" "a"]

(peg/match ~(sequence (capture "a" :target)
                      (backref :target))
           "b")
# => nil

(peg/match ~(sequence (capture "a" :target)
                      (capture "b" :target-2)
                      (backref :target-2)
                      (backref :target))
           "ab")
# => @["a" "b" "b" "a"]


# `(-> prev-tag ?tag)` is an alias for `(backref prev-tag ?tag)`

(peg/match ~(sequence (capture "a" :target)
                      (-> :target))
           "a")
# => @["a" "a"]

(peg/match ~(sequence (capture "a" :target)
                      (capture "b" :target-2)
                      (-> :target-2)
                      (-> :target))
           "ab")
# => @["a" "b" "b" "a"]

(peg/match ~(sequence (capture "a" :target)
                      (-> :target))
           "b")
# => nil

# `error`
# -------

# `(error ?patt)`

# Throws a Janet error.

# The error thrown will be the last capture of `patt`, or a generic error if
# `patt` produces no captures or `patt` is not specified.

(try
  (peg/match ~(sequence "a"
                        (error (sequence (capture "b")
                                         (capture "c"))))
             "abc")
  ([err]
   err))
# => "c"

(try
  (peg/match ~(choice "a"
                      "b"
                      (error ""))
             "c")
  ([err]
   err))
# => "match error at line 1, column 1"

(try
  (peg/match ~(choice "a"
                      "b"
                      (error))
             "c")
  ([err]
   :match-error))
# => :match-error

# `drop`
# ------

# `(drop patt)`

# Ignores (drops) all captures from `patt`.

(peg/match ~(drop (capture "a"))
           "a")
# => @[]

# `lenprefix`
# -----------

# `(lenprefix n patt)`

# Matches `n` repetitions of `patt`, where `n` is supplied from other parsed
# input and is not constant.

# XXX: examples from janet test suite

(peg/match ~(sequence
              (lenprefix
                (replace
                  (sequence
                    (capture (any (if-not ":" 1)))
                    ":")
                  ,scan-number)
                1)
              -1)
           "5:abcde")
# => @[]

# XXX: so does `lenprefix` get `n` from the capture stack?

(peg/match ~(sequence
              (lenprefix
                (replace
                  (sequence
                    (capture (any (if-not ":" 1)))
                    ":")
                  ,scan-number)
                1)
              -1)
           "5:abcdef")
# => nil

# `int`
# -----

# `(int n)`

# Captures `n` bytes interpreted as a little endian integer.

(peg/match ~(int 1) "a")
# => @[97]

(peg/match ~(int 2) "ab")
# => @[25185]

(type
 (first
  (peg/match ~(int 8) "abcdefgh")))
# => :core/s64

# `int-be`
# --------

# `(int-be n)`

# Captures `n` bytes interpreted as a big endian integer.

(peg/match ~(int-be 1) "a")
# => @[97]

(peg/match ~(int-be 2) "ab")
# => @[24930]

(type
 (first
  (peg/match ~(int-be 8) "abcdefgh")))
# => :core/s64

# `uint`
# ------

# `(uint n)`

# Captures `n` bytes interpreted as a little endian unsigned integer.

(peg/match ~(uint 1) "a")
# => @[97]

(type
 (first
  (peg/match ~(uint 8) "abcdefgh")))
# => :core/u64

# `uint-be`
# ---------

# `(uint-be n)`

# Captures `n` bytes interpreted as a big endian unsigned integer.

(peg/match ~(uint-be 1) "a")
# => @[97]

(type
 (first
  (peg/match ~(uint-be 8) "abcdefgh")))
# => :core/u64

# Grammars and Recursion
# ----------------------

# The feature that makes PEGs so much more powerful than pattern matching
# solutions like (vanilla) regex is mutual recursion.

# To do recursion in a PEG, you can wrap multiple patterns in a grammar,
# which is a Janet struct.

# The patterns must be named by keywords, which can then be used in all
# sub-patterns in the grammar.

# Each grammar, defined by a struct, must also have a main rule, called
# `:main`, that is the pattern that the entire grammar is defined by.

(def my-grammar
  '{:a (* "a" :b "a")
    :b (* "b" (+ :a 0) "b")
    :main (* "(" :b ")")})

# alternative expression of `my-grammar`
(def my-grammar-alt
  '{# :b wrapped in parens
    :main (sequence "("
                    :b
                    ")")
    # :a or nothing wrapped in lowercase b's
    :b (sequence "b"
                 (choice :a 0)
                 "b")
    # :b wrapped in lowercase a's
    :a (sequence "a"
                 :b
                 "a")})

# simplest match
(peg/match my-grammar-alt "(bb)")
# => @[]

# next simplest match
(peg/match my-grammar-alt "(babbab)")
# => @[]

# non-match
(peg/match my-grammar-alt "(baab)")
# => nil

# Recursion and Stack Limit
# -------------------------

# Keep in mind that recursion is implemented with a stack, meaning that
# very recursive grammars can overflow the stack.

# The compiler is able to turn some recursion into iteration via tail-call
# optimization, but some patterns may fail on large inputs.

# It is also possible to construct (very poorly written) patterns that will
# result in long loops and be very slow in general.

# Built-in Patterns
# -----------------

# The `peg` module also provides a default grammar with a handful of
# commonly used patterns.

# All of these shorthands can be defined with the combinators above and
# primitive patterns, but you may see these aliases in other grammars and
# they can make grammars simpler and easier to read.

# All of these aliases are defined in `default-peg-grammar`, which is a table
# that maps from the alias name to the expanded form.

# You can even add your own aliases here which are then available for all
# PEGs in the program.

# Modifiying this table will not affect already compiled PEGs.

default-peg-grammar
``
'@{# ascii letter
   :a (range "az" "AZ")
   :a* (any :a)
   :a+ (some :a)
   :A (if-not :a 1)

   # ascii digit
   :d (range "09")
   :d* (any :d)
   :d+ (some :d)
   :D (if-not :d 1)

   # hex
   :h (range "09" "af")
   :h* (any :h)
   :h+ (some :h)
   :H (if-not :h 1)

   # ascii whitespace
   :s (set " \t\r\n\0\f\v")
   :s* (any :s)
   :s+ (some :s)
   :S (if-not :s 1)

   # ascii digits and letters
   :w (range "az" "AZ" "09")
   :w+ (some :w)
   :w* (any :w)
   :W (if-not :w 1)}
``

# String Searching and Other Idioms
# ---------------------------------

# Although all pattern matching is done in anchored mode, operations like
# global substituion and searching can be implemented with the `peg` module.

# A simple Janet function that prodces PEGs that search for strings shows
# how captures and looping specials can be composed, and how quasiquoting
# can be used to embed values in patterns.

# There are also built-ins:

#   `peg/find`
#   `peg/find-all`
#   `peg/replace`
#   `peg/replace-all`

(defn finder
  "Creates a peg that finds all locations of `patt` in the text."
  [patt]
  (peg/compile ~(any (+ (* ($) ,patt)
                        1))))

(def where-are-the-dogs?
  (finder "dog"))

(peg/match where-are-the-dogs?
           "dog dog cat dog")
# => @[0 4 12]

(def find-cats
  (finder '(* "c" (some "a") "t")))

(peg/match find-cats "cat ct caat caaaaat cat")
# => @[0 7 12 20]


# `peg/find`
# ----------

# `(peg/find peg text
#            &opt start
#            & args)`

# Find first index where `peg` matches in `text`.

# Return an integer, or nil if not found.

(peg/find "dog" "dog dog cat dog")
# => 0

# `peg/find-all`
# --------------

# `(peg/find-all peg text
#                &opt start
#                & args)`

# Find all indexes where `peg` matches in `text`.

# Return an array of integers.

(peg/find-all "dog" "dog dog cat dog")
# => @[0 4 12]

(peg/find-all "dog" "do do cat do")
# => @[]

# We can also wrap a PEG to turn it into a global substituion grammar with
# the `accumulate` special (`%`).

(defn replacer
  "Creates a peg that replaces instances of `patt` with `subst`."
  [patt subst]
  (peg/compile ~(% (any (+ (/ (<- ,patt)
                              ,subst)
                           (<- 1))))))

(peg/match (replacer "dog" "cat")
           "a dog passed another dog")
# => @["a cat passed another cat"]

# `peg/replace`
# -------------

# `(peg/replace peg repl text
#               &opt start
#               & args)`

# Replace first match of `peg` in `text` with `repl`, returning a new buffer.

# The peg does not need to make captures to do replacement.

# If no matches are found, returns the input string in a new buffer.

(peg/replace "dog" "cat" "a dog passed another dog")
# => @"a cat passed another dog"

(peg/replace "dog" "cat" "a bee passed another bee")
# => @"a bee passed another bee"

# `peg/replace-all`
# -----------------

# `(peg/replace-all peg repl text
#                   &opt start
#                   & args)`

# Replace all matches of `peg` in `text` with `repl`, returning a new buffer.

# The peg does not need to make captures to do replacement.

# If no matches are found, returns the input string in a new buffer.

(peg/replace-all "dog" "cat" "a dog passed another dog")
# => @"a cat passed another cat"

(peg/replace-all "dog" "cat" "a bee passed another bee")
# => @"a bee passed another bee"

# More Examples
# -------------

# modification of peg docs example
(def ip-address-2
  ~{:main (sequence :byte "." :byte "." :byte "." :byte)
    # byte doesn't start with a zero if there is more than one digit
    :byte (choice (sequence "25" :0-5)
                  (sequence "2" :0-4 :dig)
                  (sequence "1" :dig :dig)
                  (sequence :pos :dig)
                  :dig)
    # pieces to accomodate :byte
    :0-5 (range "05")
    :0-4 (range "04")
    :dig (range "09")
    :pos (range "19")})

(peg/match ip-address-2 "127.0.0.1")
# => @[]

(peg/match ip-address-2 "127.0.00.1")
# => nil

(peg/match ip-address-2 "127.0.000.1")
# => nil

# djb's netstrings
(def peg-netstring
  ~{:main (replace (sequence :digits
                             ":"
                             (capture (lenprefix (backref :digits) 1))
                             ",")
                   ,|$1)
    :digits (replace (capture (choice "0"
                                      (sequence (range "19") :d*)))
                     ,scan-number
                     :digits)})

(peg/match peg-netstring "3:djb,")
# => @["djb"]

(peg/match peg-netstring "0:,")
# => @[""]

# recording a position but not leaving a related trace on the capture stack
(do
  (var where 0)
  (peg/match ~(drop (cmt (sequence (some (if-not "j" 1))
                                   (position))
                         ,(fn [cap]
                            (print cap)
                            (set where cap))))
             "abcdefghij")
  where)
# => 9

# Real World Code Samples
# -----------------------

# * bagatto - https://sr.ht/~subsetpark/bagatto
# * bencode - https://github.com/ikarius/bencode
# * janet-code - https://github.com/ahungry/janet-code
# * janet-uri - https://github.com/andrewchambers/janet-uri
# * janet-utf8 - https://github.com/crocket/janet-utf8
# * janetls - https://github.com/LeviSchuck/janetls
# * joy - https://github.com/joy-framework/joy
# * judge-gen - https://github.com/sogaiu/judge-gen
# * musty - https://github.com/pyrmont/musty
# * neil - https://git.sr.ht/~pepe/neil
# * spork - https://github.com/janet-lang/spork

# Hint: grep for peg/match

# References
# ----------

# * How-To: Using PEGs in Janet
#     https://articles.inqk.net/2020/09/19/how-to-use-pegs-in-janet.html

# * Parsing Expression Grammars
#     https://janet-lang.org/docs/peg.html

# * How Janet's PEG module works
#     https://bakpakin.com/writing/how-janets-peg-works.html

# * src/core/peg.c
#     https://github.com/janet-lang/janet/blob/cae4f1962914e27aba3d40aa650ac1e63c3c5a9b/src/core/peg.c

# Footnotes
# ---------

# [*] The phrase "not produce ... captures" seems misleading as
#     the combinators themselves do not produce captures, but
#     "arguments" (e.g. `cond`, `patt`, etc.) can (e.g. if
#     `patt` is `(capture "a")` and `patt` succeeds).

)
