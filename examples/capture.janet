(import ../margaret/meg :as peg)

# `(capture patt ?tag)`

# Capture all of the text in `patt` if `patt` matches.

# If `patt` contains any captures, then those captures will be pushed on to
# the capture stack before the total text.

# `(<- patt ?tag)` is an alias for `(capture patt ?tag)`

# `(quote patt ?tag)` is an alias for `(capture patt ?tag)`

# This allows code like `'patt` to capture a pattern

(comment

  (peg/match '(capture 1) "a")
  # => @["a"]

  (peg/match ~(capture "a") "a")
  # => @["a"]

  (peg/match '(capture 1 :a) "a")
  # => @["a"]

  (peg/match ~(capture 2) "hi")
  # => @["hi"]

  (peg/match ~(capture -1) "")
  # => @[""]

  (peg/match ~(sequence (capture :d+ :a)
                        (backref :a))
             "78")
  # => @["78" "78"]

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

  )
