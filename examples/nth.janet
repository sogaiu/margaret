(import ../margaret/meg :as peg)

# `(nth index patt ?tag)`

# Capture one of the captures in `patt` at `index`.  If no such
# capture exists, then the match fails.

(comment

  (peg/match ~(nth 2 (sequence (capture 1)
                               (capture 1)
                               (capture 1)))
             "xyz")
  # =>
  @["z"]

  (peg/match ~{:main (some (nth 1 (* :prefix ":" :word)))
               :prefix (number :d+ nil :n)
               :word (capture (lenprefix (backref :n) :w))}
             "3:fox8:elephant")
  # =>
  @["fox" "elephant"]

  )

