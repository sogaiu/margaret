# XXX: consider using portions of the janet grammar peg in the
#      examples below

# XXX: also consider a series of posts similar in spirit to pyrmont's post,
#      subject can be the janet grammar peg, but start simple and build it
#      up gradually

# XXX: more tag examples?

# XXX: after a single pass through, study examples and consider
#      additional / changes.  then consider rearranging
#      material to introduce things like `capture` and/or `position` earlier.
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

# Introduction
# ------------

# This is a tutorial for becoming familiar with some
# essential characteristics and constructs of Janet's PEG
# system.

# Specifically, the `peg/match` function, Janet PEG grammars,
# and a select set of specials will be covered in an incremental
# fashion.

# The following is meant to give an overview of coverage, but not
# the presentation order.

# * Mental Model of Janet's PEG system
#   * Grammar
#     * string literal
#     * integer
#     * keyword
#     * tuple
#     * struct
#   * State
#     * Current Index
#     * Capture Stack
#     * Tags Table

# * Familiarity with Useful Specials
#   * Primitive Patterns
#     * string literals
#     * integers
#     * `set` and `range`
#   * Combinators
#     * `choice` / `+`
#     * `sequence` / `+`
#     * `any` and `some`
#     * `if-not` and `not`
#     * `repeat` / "n"
#   * Captures
#     * `capture` / `<-` / `quote`
#     * `backref` / `->`
#     * `look`/ `>`
#     * `cmt` and `replace` / `/`
#     * `drop`
#     * `constant`
#     * `error`

# * Default PEG Grammar

# * Extra coverage # XXX: different document?  but mentioning existence
#                         above seems sensible

#   * Combinators
#     * `at-least`, `at-most`
#     * `between`, `opt` / `?`
#     * `if`
#     * `to` and `thru`
#     * `backmatch`

#   * Captures
#     * `accumulate` and `group`
#     * `argument`
#     * `int`, `int-be`, `uint`, `uint-be`
#     * `line` and `column`
#     * `lenprefix`
#     * `position` / `$`

# The `peg` module
# ----------------

# The `peg` module uses the concept of a capture stack to extract
# data from text.

# As the PEG is trying to match a piece of text, some forms may
# push Janet values onto the capture stack as a side effect.

# If the text matches the PEG, `peg/match` will return the final
# capture stack as an array.

# The `peg/match` function
# ------------------------

# `(peg/match peg text
#             &opt start
#             & args)`

# Match a PEG against some text.

# Returns an array of captured data if the text matches.

(peg/match "cat" "cat")
# =>
@[]

# N.B. 1. matching succeeded and the returned array is the
#         capture stack

# N.B. 2. array is empty because there was a match, but no
#         capture

(peg/match ~(capture "cat") "cat")
# =>
@["cat"]

# N.B. matching succeeded and there was a capture, so the
#      returned array (capture stack) is not empty

# `peg/match` returns nil if there is no match.

(peg/match "cat" "ca")
# =>
nil

# N.B. matching was not successful so the return value is nil

# The caller of `peg/match` can provide an optional start index
# to begin matching, otherwise the PEG starts on the first
# character of text.

(peg/match "cat" "cat" 0)
# =>
@[]

(peg/match "cat" "cat")
# =>
@[]

(peg/match "cat" "notcat" 3)
# =>
@[]

(peg/match "cat" "notcat" 2)
# =>
nil

# A PEG can either be a compiled PEG object or PEG source.

# N.B. examples before this point have been using "PEG source"

(type (peg/compile "cat"))
# =>
:core/peg

(let [cat-peg (peg/compile "cat")]
  [(peg/match cat-peg "cat")
   (peg/match cat-peg "category")])
# =>
[@[] @[]]

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
# =>
@[]

(peg/match "cat" "cat1")
# =>
@[]

(peg/match "" "")
# =>
@[]

(peg/match "" "a")
# =>
@[]

(peg/match "cat" "dog")
# =>
nil

# Integer Patterns
# ----------------

# Matches a number of characters, and advances that many characters.

(peg/match 3 "cat")
# =>
@[]

(peg/match 2 "cat")
# =>
@[]

(peg/match 4 "cat")
# =>
nil

# If negative, matches if not that many characters and does not advance.

# For example, -1 will match the end of a string because the length of
# the empty string is 0, which is less than 1 (i.e. "not that many
# characters").

(peg/match -1 "cat")
# =>
nil

(peg/match -1 "")
# =>
@[]

(peg/match -2 "")
# =>
@[]

(peg/match -2 "o")
# =>
@[]

# Range Patterns
# --------------

# Matches characters in a range and advances 1 character.

(peg/match '(range "ac") "b")
# =>
@[]

# N.B. in this case the grammar needs to be quoted

(peg/match ~(range "ac") "b")
# =>
@[]

# N.B. using quasiquoting (~) means unquoting can be used within
#      the grammar expression

(let [a-range "ac"]
  (peg/match ~(range ,a-range) "b"))
# =>
@[]

# Multiple ranges can be combined together.

(let [text (if (< (math/random) 0.5)
               "b"
               "y")]
  (peg/match ~(range "ac" "xz") text))
# =>
@[]

# Set Patterns
# ------------

# Match any character in the argument string. Advances 1 character.

(peg/match ~(set "cat") "cat")
# =>
@[]

(peg/match ~(set "act!") "cat!")
# =>
@[]

(peg/match ~(set "bo") "bob")
# =>
@[]

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
# =>
@[]

(peg/match ~(choice "a" "b") "b")
# =>
@[]

# and fails if none of the arguments match the text.

(peg/match ~(choice "a" "b") "c")
# =>
nil

# `(+ a b c ...)` is an alias for `(choice a b c ...)`

(peg/match ~(+ "a" "b") "a")
# =>
@[]

# `sequence` aka `*`
# ------------------

# `(sequence a b c ...)`

# Tries to match a, b, c and so on in sequence.

(peg/match ~(sequence "a" "b" "c") "abc")
# =>
@[]

(peg/match ~(sequence "a" "b" "c") "abcd")
# =>
@[]

# If any of these arguments fail to match the text, the whole pattern fails.

(peg/match ~(sequence "a" "b" "c") "abx")
# =>
nil

# `(* a b c ...)` is an alias for `(sequence a b c ...)`

(peg/match ~(* "a" "b" "c") "abc")
# =>
@[]

# `any`
# -----

# `(any patt)`

# Matches 0 or more repetitions of `patt`

(peg/match ~(any "a") "aaa")
# =>
@[]

(peg/match ~(any "bo") "")
# =>
@[]

# `some`
# ------

# `(some patt)`

# Matches 1 or more repetitions of `patt`

(peg/match ~(some "a") "aa")
# =>
@[]

(peg/match ~(some "a") "")
# =>
nil

# `if`
# ----

# `(if cond patt)`

# Tries to match `patt` only if `cond` matches as well.

# `cond` will not produce any captures. [*]

(peg/match ~(if 5 (set "eilms"))
           "smile")
# =>
@[]

(peg/match ~(if 5 (set "eilms"))
           "wink")
# =>
nil

# `if-not`
# --------

# `(if-not cond patt)`

# Tries to match only if `cond` does not match.

# `cond` will not produce any captures. [*]

(peg/match ~(if-not 5 (set "iknw"))
           "wink")
# =>
@[]

# `not` aka `!`
# -------------

# `(not patt)`

# Matches only if `patt` does not match.

# Will not produce captures or advance any characters.

(peg/match ~(not "cat") "dog")
# =>
@[]

(peg/match ~(sequence (not "cat")
                      (set "dgo"))
           "dog")
# =>
@[]

# `(! patt)` is an alias for `(not patt)`

(peg/match ~(! "cat") "dog")
# =>
@[]

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
# =>
@["a"]

(peg/match ~(capture 2) "hi")
# =>
@["hi"]

(peg/match ~(capture -1) "")
# =>
@[""]

(peg/match ~(capture (range "ac")) "b")
# =>
@["b"]

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~(capture (range "ac" "xz"))
                       text)]
  (or (= cap "b")
      (= cap "y")))
# =>
true

(peg/match ~(capture (set "cat")) "cat")
# =>
@["c"]

# `(<- patt ?tag)` is an alias for `(capture patt ?tag)`

(peg/match ~(<- "a") "a")
# =>
@["a"]

(peg/match ~(<- 2) "hi")
# =>
@["hi"]

(peg/match ~(<- -1) "")
# =>
@[""]

(peg/match ~(<- (range "ac")) "b")
# =>
@["b"]

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~(<- (range "ac" "xz"))
                       text)]
  (or (= cap "b")
      (= cap "y")))
# =>
true

(peg/match ~(<- (set "cat")) "cat")
# =>
@["c"]

# `(quote patt ?tag)` is an alias for `(capture patt ?tag)`

# This allows code like `'patt` to capture a pattern

(peg/match ~(quote "a") "a")
# =>
@["a"]

(peg/match ~'"a" "a")
# =>
@["a"]

(peg/match ~(quote 2) "hi")
# =>
@["hi"]

(peg/match ~'2 "hi")
# =>
@["hi"]

(peg/match ~(quote -1) "")
# =>
@[""]

(peg/match ~'-1 "")
# =>
@[""]

(peg/match ~(quote (range "ac")) "b")
# =>
@["b"]

(peg/match ~'(range "ac") "b")
# =>
@["b"]

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~(quote (range "ac" "xz"))
                       text)]
  (or (= cap "b")
      (= cap "y")))
# =>
true

(let [text (if (< (math/random) 0.5)
               "b"
               "y")
      [cap] (peg/match ~'(range "ac" "xz")
                       text)]
  (or (= cap "b")
      (= cap "y")))
# =>
true

(peg/match ~(quote (set "cat")) "cat")
# =>
@["c"]

(peg/match ~'(set "cat") "cat")
# =>
@["c"]

# `group`
# -------

# `(group patt ?tag)`

# Captures an array of all of the captures in `patt`

(first
  (peg/match ~(group (sequence (capture "(")
                               (capture (any (if-not ")" 1)))
                               (capture ")")))
             "(defn hi [] 1)"))
# =>
@["(" "defn hi [] 1" ")"]

# `constant`
# ----------

# `(constant k ?tag)`

# Captures a constant value and advances no characters.

(peg/match ~(constant "smile")
           "whatever")
# =>
@["smile"]

(peg/match ~(constant {:fun :value})
           "whatever")
# =>
@[{:fun :value}]

(peg/match ~(sequence (constant :relax)
                      (position))
            "whatever")
# =>
@[:relax 0]

# `position` aka `$`
# ------------------

# `(position ?tag)`

# Captures the current index into the text and advances no input.

(peg/match ~(position) "a")
# =>
@[0]

(peg/match ~(sequence "a"
                      (position))
           "ab")
# =>
@[1]

# `($ ?tag)` is an alias for `(position ?tag)`

(peg/match ~($) "a")
# =>
@[0]

(peg/match ~(sequence "a"
                      ($))
           "ab")
# =>
@[1]

# `accumulate` aka `%`
# --------------------

# `(accumulate patt ?tag)`

# Capture a string that is the concatenation of all captures in `patt`.

# This will try to be efficient and not create intermediate string if possible.

(peg/match ~(accumulate (sequence (capture "a")
                                  (capture "b")
                                  (capture "c")))
           "abc")
# =>
@["abc"]

(peg/match ~(accumulate (sequence (capture "a")
                                  (position)
                                  (capture "b")
                                  (position)
                                  (capture "c")
                                  (position)))
           "abc")
# =>
@["a1b2c3"]

# `(% ?tag)` is an alias for `(accumulate ?tag)`

(peg/match ~(% (sequence (capture "a")
                         (capture "b")
                         (capture "c")))
           "abc")
# =>
@["abc"]

(peg/match ~(% (sequence (capture "a")
                         (position)
                         (capture "b")
                         (position)
                         (capture "c")
                         (position)))
           "abc")
# =>
@["a1b2c3"]

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
# =>
@["hello!"]

(peg/match ~(cmt (sequence (capture "hello")
                           (some (set " ,"))
                           (capture "world"))
                 ,(fn [cap1 cap2]
                    (string cap2 ": yes, " cap1 "!")))
           "hello, world")
# =>
@["world: yes, hello!"]

# `backref` aka `->`
# ------------------

# `(backref prev-tag ?tag)`

# Duplicates the last capture with tag `prev-tag`.

# If no such capture exists then the match fails.

(peg/match ~(sequence (capture "a" :target)
                      (backref :target))
           "a")
# =>
@["a" "a"]

(peg/match ~(sequence (capture "a" :target)
                      (backref :target))
           "b")
# =>
nil

(peg/match ~(sequence (capture "a" :target)
                      (capture "b" :target-2)
                      (backref :target-2)
                      (backref :target))
           "ab")
# =>
@["a" "b" "b" "a"]

# `(-> prev-tag ?tag)` is an alias for `(backref prev-tag ?tag)`

(peg/match ~(sequence (capture "a" :target)
                      (-> :target))
           "a")
# =>
@["a" "a"]

(peg/match ~(sequence (capture "a" :target)
                      (capture "b" :target-2)
                      (-> :target-2)
                      (-> :target))
           "ab")
# =>
@["a" "b" "b" "a"]

(peg/match ~(sequence (capture "a" :target)
                      (-> :target))
           "b")
# =>
nil

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
# =>
"c"

(try
  (peg/match ~(choice "a"
                      "b"
                      (error ""))
             "c")
  ([err]
   err))
# =>
"match error at line 1, column 1"

(try
  (peg/match ~(choice "a"
                      "b"
                      (error))
             "c")
  ([err]
   :match-error))
# =>
:match-error

# `drop`
# ------

# `(drop patt)`

# Ignores (drops) all captures from `patt`.

(peg/match ~(drop (capture "a"))
           "a")
# =>
@[]

# /* Hold captured patterns and match state */
# typedef struct {
#     const uint8_t *text_start;
#     const uint8_t *text_end;     // check for moved beyond end of string
#     const uint32_t *bytecode;    // accessing subsequent bytecode
#     const Janet *constants;      // lookup for `constant`, `replace`, `cmt`
#     JanetArray *captures;        // capture stack
#     JanetBuffer *scratch;        // for `capture` and `accumulate`
#     JanetBuffer *tags;           // for tagged capture and retrieval
#     JanetArray *tagged_captures; //
#     const Janet *extrav;         // for `argument`
#     int32_t *linemap;            // for `line`, `column`, and `error`
#     int32_t extrac;              // for `argument`
#     int32_t depth;               // "stack" overflow protection
#     int32_t linemaplen;          // for `line`, `column`, and `error`
#     int32_t has_backref;         //
#     enum {
#         PEG_MODE_NORMAL,         // `group`, `replace`, `cmt`, `error`, etc.
#         PEG_MODE_ACCUMULATE      // `accumulate` and `capture` (but see below)
#     } mode;
# } PegState;

# candidate order
#
# RULE_NCHAR - text_end
# RULE_CAPTURE - captures (add scratch, mode later) - cover tag too
# RULE_GETTAG - tags, tagged_captures
# RULE_MATCHTIME - constants, captures + scratch -> cap_save, tags -> cap_load
# RULE_ERROR - linemap and linemaplen
# RULE_ARGUMENT - extrav and extrac

# text_start
#   RULE_LOOK
#   RULE_POSITION
#   RULE_LINE
#   RULE_COLUMN
#   RULE_ERROR

# text_end
#   RULE_LOOK
#   RULE_LITERAL
#   RULE_NCHAR
#   RULE_NOTNCHAR
#   RULE_RANGE
#   RULE_SET
#   RULE_THRU
#   RULE_TO
#   RULE_BACKMATCH
#   RULE_READINT

# bytecode
#   RULE_LOOK
#   RULE_CHOICE
#   RULE_SEQUENCE
#   RULE_IF
#   RULE_IFNOT
#   RULE_NOT
#   RULE_THRU
#   RULE_TO
#   RULE_BETWEEN
#   RULE_CAPTURE
#   RULE_ACCUMULATE
#   RULE_DROP
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_ERROR
#   RULE_LENPREFIX

# constants
#   RULE_ACCUMULATE
#   RULE_REPLACE
#   RULE_MATCHTIME

# captures
#   RULE_GETTAG
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_ERROR
#   RULE_BACKMATCH
#   RULE_LENPREFIX

# scratch
#   RULE_CAPTURE
#   RULE_ACCUMULATE

# tags
#   RULE_GETTAG
#   RULE_BACKMATCH

# tag
#   RULE_GETTAG
#   RULE_CAPTURE
#   RULE_ACCUMULATE
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_READINT

# tagged_captures
#   RULE_GETTAG
#   RULE_BACKMATCH

# extrav
#   RULE_ARGUMENT

# linemap (via get_linecol_from_position)
#   RULE_LINE
#   RULE_COLUMN
#   RULE_ERROR

# extrac
#   RULE_ARGUMENT

# depth (via up1 / down1)
#   RULE_LOOK
#   RULE_CHOICE
#   RULE_SEQUENCE
#   RULE_IF
#   RULE_IFNOT
#   RULE_NOT
#   RULE_THRU
#   RULE_TO
#   RULE_BETWEEN
#   RULE_CAPTURE
#   RULE_ACCUMULATE
#   RULE_DROP
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_ERROR
#   RULE_LENPREFIX

# linemaplen (via get_linecol_from_position)
#   RULE_LINE
#   RULE_COLUMN
#   RULE_ERROR

# has_backref
#   RULE_CAPTURE

# has_backref (via pushcap)
#   RULE_CAPTURE
#   anything that calls pushcap if has_backref == 1
#     RULE_GETTAG
#     RULE_POSITION
#     RULE_LINE
#     RULE_COLUMN
#     RULE_ARGUMENT
#     RULE_CONSTANT
#     RULE_CAPTURE (a repeat, see above)
#     RULE_ACCUMULATE
#     RULE_GROUP
#     RULE_REPLACE
#     RULE_MATCHTIME
#     RULE_READINT

# mode
#   RULE_CAPTURE
#   RULE_ACCUMULATE
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_ERROR
#   RULE_LENPREFIX

# PEG_MODE_ACCUMULATE
#   RULE_CAPTURE
#   RULE_ACCUMULATE

# PEG_MODE_NORMAL
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_ERROR
#   RULE_LENPREFIX

# PEG_MODE_ACCUMULATE / PEG_MODE_NORMAL (via pushcap)
#   RULE_GETTAG
#   RULE_POSITION
#   RULE_LINE
#   RULE_COLUMN
#   RULE_ARGUMENT
#   RULE_CONSTANT
#   RULE_CAPTURE
#   RULE_ACCUMULATE
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_READINT

# cap_save
#   RULE_CHOICE
#   RULE_THRU
#   RULE_TO
#   RULE_BETWEEN
#   RULE_ACCUMULATE
#   RULE_DROP
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_LENPREFIX

# cap_load
#   RULE_CHOICE
#   RULE_THRU
#   RULE_TO
#   RULE_BETWEEN
#   RULE_ACCUMULATE
#   RULE_DROP
#   RULE_GROUP
#   RULE_REPLACE
#   RULE_MATCHTIME
#   RULE_LENPREFIX

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

)
