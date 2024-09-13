(import ../margaret/meg :as peg)

# `(only-tags patt)`

# Ignores all captures from `patt`, while making tagged captures
# within `patt` available for future back-referencing.

(comment

  (peg/match ~(sequence (only-tags (sequence (capture 1 :a)
                                             (capture 2 :b)))
                        (backref :a))
             "xyz")
  # =>
  @["x"]

  (peg/match
    ~{:main (some (sequence (only-tags (sequence :prefix ":" :word))
                            (backref :target)))
      :prefix (number :d+ nil :n)
      :word (capture (lenprefix (backref :n) :w)
                     :target)}
    "3:ant3:bee6:flower")
  # =>
  @["ant" "bee" "flower"]

  )

