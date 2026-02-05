(import ../margaret/meg :as peg)

# `(debug)`

# Print capture stack (sometimes partial) to stdout.

# `(??)` is an alias for `(debug)`

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (let [buf @""]
    (with-dyns [:out buf]
      [(peg/match ~(sequence (capture "a") (??))
                  "a")
       buf]))
  # =>
  [@["a"]
   (buffer eol
           "?? at []" eol
           "stack [1]:" eol
           "  [0]: \e[35m" `"a"` "\e[0m" eol)]

  (let [buf @""]
    (with-dyns [:out buf]
      [(peg/match ~(sequence (debug) "abc")
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer eol
           "?? at [abc]" eol
           "stack [0]:" eol)]

  (let [buf @""]
    (with-dyns [:out buf]
      [(peg/match ~(sequence (??) "abc")
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer eol
           "?? at [abc]" eol
           "stack [0]:" eol)]

  (let [buf @""]
    (with-dyns [:out buf]
      [(peg/match ~(sequence "abc" (??))
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer eol
           "?? at []" eol
           "stack [0]:" eol)]

  (let [buf @""]
    (with-dyns [:out buf]
      [(peg/match ~(sequence "a" (??) "bc")
                  "abc")
       buf]))
  # =>
  [@[]
   (buffer eol
           "?? at [bc]" eol
           "stack [0]:" eol)]

  (let [buf @""]
    (with-dyns [:out buf]
      [(peg/match ~(sequence (capture "a") (??) "bc")
                  "abc")
       buf]))
  # =>
  [@["a"]
   (buffer eol
           "?? at [bc]" eol
           "stack [1]:" eol
           "  [0]: \e[35m" `"a"` "\e[0m" eol)]

  (let [buf @""]
    (with-dyns [:out buf]
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
   (buffer eol
           "?? at [bc]" eol
           "stack [5]:" eol
           "  [0]: \e[35m" `"a"` "\e[0m" eol
           "  [1]: \e[32m" "1" "\e[0m" eol
           "  [2]: \e[36m" "true" "\e[0m" eol
           "  [3]: {}" eol
           "  [4]: @[]" eol)]

  )

