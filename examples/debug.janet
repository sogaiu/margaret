(import ../margaret/meg :as peg)

# `(debug)`

# Print capture stack (sometimes partial) to stdout.

# `(??)` is an alias for `(debug)`

(comment

  (def err-color (dyn :err-color))

  (setdyn :err-color nil)

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence (capture "a") (??))
                  "a")
       buf]))
  # =>
  [@["a"]
   (buffer "?? at [] (index 1)" eol
           "stack [1]:" eol
           "  [0]: " `"a"` eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence (debug) "abc")
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer "?? at [abc] (index 0)" eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence (??) "abc")
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer "?? at [abc] (index 0)" eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence "abc" (??))
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer "?? at [] (index 3)" eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence "a" (??) "bc")
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer "?? at [bc] (index 1)" eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence (capture "a") (??) "bc")
                  "abc")
       buf]))
  # =>
  [@["a"]
   (buffer "?? at [bc] (index 1)" eol
           "stack [1]:" eol
           "  [0]: " `"a"` eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence (capture "a" :a) (??)
                             (backref :a) (??))
                  "abc")
       buf]))
  # =>
  [@["a" "a"]
   (buffer "?? at [bc] (index 1)" eol
           "stack [1]:" eol
           "  [0]: " `"a"` eol
           "tag stack [1]:" eol
           "  [0] tag=:a: \"a\"" eol
           "?? at [bc] (index 1)" eol
           "stack [2]:" eol
           "  [0]: \"a\"" eol
           "  [1]: \"a\"" eol
           "tag stack [2]:" eol
           "  [0] tag=:a: \"a\"" eol
           "  [1] tag=:a: \"a\"" eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(accumulate (sequence (capture 1)
                                         (capture 1)
                                         (??)
                                         (capture 1)))
                  "abc")
       buf]))
  # =>
  [@["abc"]
   (buffer "?? at [c] (index 2)" eol
           "accumulate buffer: @\"ab\"" eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence (capture "a")
                             (number :d)
                             (constant true)
                             (constant {})
                             (constant @[])
                             (??)
                             "bc")
                  "a1bc")
       buf]))
  # =>
  [@["a" 1 true {} @[]]
   (buffer "?? at [bc] (index 2)" eol
           "stack [5]:" eol
           "  [0]: " `"a"` eol
           "  [1]: " "1" eol
           "  [2]: " "true" eol
           "  [3]: {}" eol
           "  [4]: @[]" eol)]

  # regression test for change in janet's %m / %M behavior
  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match ~(sequence (constant @[]) (??))
                  "a")
       buf]))
  # =>
  [@[@[]]
   (buffer "?? at [a] (index 0)" eol
           "stack [1]:" eol
           "  [0]: @[]" eol)]

  (let [buf @""]
    (with-dyns [:err buf]
      [(peg/match
         ~(sequence (capture 1)
                    (capture 2)
                    (accumulate (sequence (capture 1) (??)
                                          (capture 2 :tag)
                                          (capture 3)
                                          (backref :tag) (??))))
         "aksjndkajsnd")
       buf]))
  # =>
  [@["a" "ks" "jndkajnd"]
   (buffer "?? at [ndkajsnd] (index 4)" eol
           "accumulate buffer: @\"j\"" eol
           "stack [2]:" eol
           "  [0]: \"a\"" eol
           "  [1]: \"ks\"" eol
           "tag stack [3]:" eol
           "  [0] tag=nil: \"a\"" eol
           "  [1] tag=nil: \"ks\"" eol
           "  [2] tag=nil: \"j\"" eol
           "?? at [snd] (index 9)" eol
           "accumulate buffer: @\"jndkajnd\"" eol
           "stack [2]:" eol
           "  [0]: \"a\"" eol
           "  [1]: \"ks\"" eol
           "tag stack [6]:" eol
           "  [0] tag=nil: \"a\"" eol
           "  [1] tag=nil: \"ks\"" eol
           "  [2] tag=nil: \"j\"" eol
           "  [3] tag=:tag: \"nd\"" eol
           "  [4] tag=nil: \"kaj\"" eol
           "  [5] tag=:tag: \"nd\"" eol)]

  (setdyn :err-color err-color)

  )

