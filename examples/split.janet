(import ../margaret/meg :as peg)

# `(split sep patt)`

# TODO

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

  (peg/match ~(sequence (split "," (capture :w+)) 0)
             "a,b,c")
  # =>
  @["a" "b" "c"]

  )

