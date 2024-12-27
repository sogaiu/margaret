(import ../margaret/meg :as peg)

# `(split separator-patt patt)`

# Split the remaining input by `separator-patt`, and execute `patt` on
# each substring.

# `patt` will execute with its input constrained to the next instance of
# `separator-patt`, as if narrowed by `(sub (to separator-patt) ...)`.

# `split` will continue to match separators and patterns until it reaches
# the end of the input; if you don't want to match to the end of the
# input you should first narrow it with `(sub ... (split ...))`.

(comment

  (peg/match ~(split "," (capture 1))
             "a,b,c")
  # =>
  @["a" "b" "c"]

  # drops captures from separator pattern
  (peg/match ~(split (capture ",") (capture 1))
             "a,b,c")
  # =>
  @["a" "b" "c"]

  # can match empty subpatterns
  (peg/match ~(split "," (capture :w*))
             ",a,,bar,,,c,,")
  # =>
  @["" "a" "" "bar" "" "" "c" "" ""]

  # subpattern is limited to only text before the separator
  (peg/match ~(split "," (capture (to -1)))
             "a,,bar,c")
  # =>
  @["a" "" "bar" "c"]

  # fails if any subpattern fails
  (peg/match ~(split "," (capture "a"))
             "a,a,b")
  # =>
  nil

  # separator does not have to match anything
  (peg/match ~(split "x" (capture (to -1)))
             "a,a,b")
  # =>
  @["a,a,b"]

  # always consumes entire input
  (peg/match ~(split 1 (capture ""))
             "abc")
  # =>
  @["" "" "" ""]

  # separator can be an arbitrary PEG
  (peg/match ~(split :s+ (capture (to -1)))
             "a   b      c")
  # =>
  @["a" "b" "c"]

  # does not advance past the end of the input
  (peg/match ~(sequence (split "," (capture :w+)) 0)
             "a,b,c")
  # =>
  @["a" "b" "c"]

  )

