(import ../../../margaret/meg :as peg)

(comment

  # fmt.janet
  (defn- pnode
    "Make a capture function for a node."
    [tag]
    (fn [x] [tag x]))

  (def- parse-peg
    "Peg to parse Janet with extra information, namely comments."
    (peg/compile
      ~{:ws (+ (set " \t\r\f\0\v") '"\n")
        :readermac (/ '(set "';~,|") ,(pnode :readermac))
        :symchars (+ (range "09" "AZ" "az" "\x80\xFF")
                     (set "!$%&*+-./:<?=>@^_"))
        :token (some :symchars)
        :hex (range "09" "af" "AF")
        :escape (* "\\" (+ (set "ntrzfev0\"\\")
                           (* "x" :hex :hex)
                           (* "u" :hex :hex :hex :hex)
                           (* "U" :hex :hex :hex :hex :hex :hex)
                           (error (constant "bad hex escape"))))
        :comment (/ (* "#" '(any (if-not (+ "\n" -1) 1)) (+ "\n" -1))
                    ,(pnode :comment))
        :spacing (any (* (any :ws) (? :comment)))
        :span (/ ':token ,(pnode :span))
        :bytes '(* "\"" (any (+ :escape (if-not "\"" 1))) "\"")
        :string (/ :bytes ,(pnode :string))
        :buffer (/ (* "@" :bytes) ,(pnode :buffer))
        :long-bytes '{:delim (some "`")
                      :open (capture :delim :n)
                      :close (cmt (* (not (> -1 "`")) (-> :n) ':delim) ,=)
                      :main (drop (* :open (any (if-not :close 1)) :close))}
        :long-string (/ :long-bytes ,(pnode :string))
        :long-buffer (/ (* "@" :long-bytes) ,(pnode :buffer))
        :raw-value (+ :string :buffer :long-string :long-buffer
                      :parray :barray :ptuple :btuple :struct :dict :span)
        :value (* (any (+ :ws :readermac)) :raw-value :spacing)
        :root (* :spacing (any :value))
        :root2 (* :spacing (any (* :value :value)))
        :ptuple (/ (group (* "(" :root (+ ")" (error)))) ,(pnode :ptuple))
        :btuple (/ (group (* "[" :root (+ "]" (error)))) ,(pnode :btuple))
        :struct (/ (group (* "{" :root2 (+ "}" (error)))) ,(pnode :struct))
        :parray (/ (group (* "@(" :root (+ ")" (error)))) ,(pnode :array))
        :barray (/ (group (* "@[" :root (+ "]" (error)))) ,(pnode :array))
        :dict (/ (group (* "@{" :root2 (+ "}" (error)))) ,(pnode :table))
        :main (* :root (+ -1 (error)))
        }))

  (peg/match parse-peg "(defn a [] 1)")
  # =>
  @['(:ptuple @[(:span "defn") (:span "a") (:btuple @[]) (:span "1")])]

  )

(comment

  # regex.janet
  (defn- postfix-modify
    "Apply regex postfix operators to a pattern."
    [cc suffix &opt suf2]
    (case suffix
      "?" ['? cc]
      "*" ['any cc]
      "+" ['some cc]
      (if (empty? suffix)
        cc
        (if suf2
          ['between (scan-number suffix) (scan-number suf2) cc]
          ['repeat (scan-number suffix) cc]))))

  (defn- make-sequence
    "Combine a series of patterns into a sequence combinator, but
  merge string literals together."
    [& ccs]
    (let [res @['*]
          buf @""]
      (each cc ccs
        (if (string? cc)
          (buffer/push-string buf cc)
          (do
            (unless (empty? buf)
              (array/push res (string buf)))
            (array/push res cc)
            (buffer/clear buf))))
      (unless (empty? buf) (array/push res (string buf)))
      (if (= 2 (length res)) (in res 1) (tuple/slice res))))

  (defn- make-choice
    "Combine multiple patterns with the choice combinator, or
  return a the first argument if there is only one argument.
  Will also reduce multiple choices into a single choice operator."
    [l &opt r]
    (if r
      (if (and (tuple? r) (= 'choice (first r)))
        ['choice l ;(tuple/slice r 1)]
        ['choice l r])
      l))

  (def peg
    "Peg used to generate peg source code from a regular expression string."
    (peg/compile
      ~{
        # Custom character classes (bracketed characters)
        # Compiled to a single (range ...) peg combinator
        :hex (range "09" "af" "AF")
        :escapedchar (+ (/ `\n` "\n")
                        (/ `\t` "\t")
                        (/ `\e` "\e")
                        (/ `\v` "\v")
                        (/ `\r` "\r")
                        (/ `\f` "\f")
                        (/ `\0` "\0")
                        (/ `\z` "\z")
                        (/ (* `\x` '(* :hex :hex))
                           ,|(string/from-bytes (scan-number (string "0x" $))))
                        (* `\` '1))
        :namedclass1 (+ (/ `\s` "  \t\n")
                        (/ `\d` "09")
                        (/ `\a` "AZaz")
                        (/ `\w` "AZaz09")
                        (/ `\S` "\0\x08\x0e\x1f\x21\xff")
                        (/ `\D` "\0\x2f\x3a\xff")
                        (/ `\A` "\0\x40\x5b\x60\x7b\xff")
                        (/ `\W` "\0\x2f\x3a\x40\x5b\x60\x7b\xff"))
        :singbyte (+ :escapedchar (if-not (set "-]") '1))
        :singchar (/ :singbyte ,|(string $ $))
        :charspan (* :singbyte "-" :singbyte)
        :make-range (/ (accumulate (any (+ :namedclass1 :charspan :singchar)))
                       ,|['range ;(partition 2 $)])
        :brack (* "[" :make-range "]")
        :invbrack (/ (* "[^" :make-range "]") ,|['if-not $ 1])

        # Other single characters
        :escapedchar2
        (+ (/ `\s` (set "\n\t\r\v\f "))
           (/ `\d` (range "09"))
           (/ `\a` (range "AZ" "az"))
           (/ `\w` (range "AZ" "az" "09"))
           (/ `\S` (range "\0\x08" "\x0e\x1f" "\x21\xff"))
           (/ `\D` (range "\0\x2f" "\x3a\xff"))
           (/ `\A` (range "\0\x40" "\x5b\x60" "\x7b\xff"))
           (/ `\W` (range "\0\x2f" "\x3a\x40" "\x5b\x60" "\x7b\xff"))
           :escapedchar)
        :normalchars (if-not (set `[.+*?()|`) '1)
        :dot (/ "." 1)
        :cc (+ :dot :invbrack :brack :escapedchar2 :normalchars)

        # Postfix modifier
        :postfix (+ '"?" '"*" '"+" (* "{" ':d+ (? (* "," ':d+)) "}") '"")

        # Character modifiers
        :cc-with-mod (/ (* :cc :postfix) ,postfix-modify)

        # Single alteration is a sequence of character classes.
        :span (/ (some :cc-with-mod) ,make-sequence)

        # Captures and groupings
        :grouping (* "(?:" :node ")")
        :capture (/ (* "(" :node ")")
                    ,|['capture $])
        :node1 (/ (* (+ :grouping :capture :span) :postfix)
                  ,postfix-modify)
        :node-span (/ (some :node1)
                      ,make-sequence)
        :node (/ (* :node-span (? (* "|" :node)))
                 ,make-choice)

        :main (* :node (+ -1 (error "")))}))

  (peg/match peg "abc")
  # =>
  @["abc"]

  (peg/match peg "a.c")
  # =>
  @['(* "a" 1 "c")]

  (peg/match peg `a\s+c`)
  # =>
  @['(* "a" (some (set "\n\t\r\v\f ")) "c")]

  (peg/match peg `(?:abc){4}`)
  # =>
  @['(repeat 4 "abc")]

  (peg/match peg `(?:(abc)){4}`)
  # =>
  @['(repeat 4 (capture "abc"))]

  (peg/match peg `\a+`)
  # =>
  @['(some (range "AZ" "az"))]

  (peg/match peg `\w+`)
  # =>
  @['(some (range "AZ" "az" "09"))]

  (peg/match peg `cat|dog`)
  # =>
  @['(choice "cat" "dog")]

  (peg/match peg `cat|dog|mouse`)
  # =>
  @['(choice "cat" "dog" "mouse")]

  (peg/match peg `(cat|dog|mouse)+`)
  # =>
  @['(some (capture (choice "cat" "dog" "mouse")))]

  (peg/match peg `a(cat|dog|mouse)+`)
  # =>
  @['(* "a" (some (capture (choice "cat" "dog" "mouse"))))]

  )

