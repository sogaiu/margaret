(import ../margaret/meg)

# `(capture patt ?tag)`

# Capture all of the text in `patt` if `patt` matches.

# If `patt` contains any captures, then those captures will be pushed on to
# the capture stack before the total text.

# `(<- patt ?tag)` is an alias for `(capture patt ?tag)`

# `(quote patt ?tag)` is an alias for `(capture patt ?tag)`

# This allows code like `'patt` to capture a pattern

(comment

  (meg/match '(capture 1) "a")
  # => @["a"]

  (meg/match ~(capture "a") "a")
  # => @["a"]

  (meg/match '(capture 1 :a) "a")
  # => @["a"]

  (meg/match ~(capture 2) "hi")
  # => @["hi"]

  (meg/match ~(capture -1) "")
  # => @[""]

  (meg/match ~(capture (range "ac")) "b")
  # => @["b"]

  (let [text (if (< (math/random) 0.5)
               "b"
               "y")
        [cap] (meg/match ~(capture (range "ac" "xz"))
                         text)]
    (or (= cap "b")
        (= cap "y")))
  # => true

  (meg/match ~(capture (set "cat")) "cat")
  # => @["c"]

  (meg/match ~(<- "a") "a")
  # => @["a"]

  (meg/match ~(<- 2) "hi")
  # => @["hi"]

  (meg/match ~(<- -1) "")
  # => @[""]

  (meg/match ~(<- (range "ac")) "b")
  # => @["b"]

  (let [text (if (< (math/random) 0.5)
               "b"
               "y")
        [cap] (meg/match ~(<- (range "ac" "xz"))
                         text)]
    (or (= cap "b")
        (= cap "y")))
  # => true

  (meg/match ~(<- (set "cat")) "cat")
  # => @["c"]

  (meg/match ~(quote "a") "a")
  # => @["a"]

  (meg/match ~'"a" "a")
  # => @["a"]

  (meg/match ~(quote 2) "hi")
  # => @["hi"]

  (meg/match ~'2 "hi")
  # => @["hi"]

  (meg/match ~(quote -1) "")
  # => @[""]

  (meg/match ~'-1 "")
  # => @[""]

  (meg/match ~(quote (range "ac")) "b")
  # => @["b"]

  (meg/match ~'(range "ac") "b")
  # => @["b"]

  (let [text (if (< (math/random) 0.5)
               "b"
               "y")
        [cap] (meg/match ~(quote (range "ac" "xz"))
                         text)]
    (or (= cap "b")
        (= cap "y")))
  # => true

  (let [text (if (< (math/random) 0.5)
               "b"
               "y")
        [cap] (meg/match ~'(range "ac" "xz")
                         text)]
    (or (= cap "b")
        (= cap "y")))
  # => true

  (meg/match ~(quote (set "cat")) "cat")
  # => @["c"]

  (meg/match ~'(set "cat") "cat")
  # => @["c"]

  )
