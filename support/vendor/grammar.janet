# adapted from:
#   https://janet-lang.org/docs/syntax.html

# approximation of janet's grammar
(def jg
  ~{:main :root
    #
    :root (any :root0)
    #
    :root0 (choice :value :comment)
    #
    :value (sequence
            (any (choice :ws :readermac))
            :raw-value
            (any :ws))
    #
    :ws (set " \0\f\n\r\t\v")
    #
    :readermac (set "',;|~")
    #
    :raw-value (choice
                :constant :number
                :symbol :keyword
                :string :buffer
                :long-string :long-buffer
                :parray :barray
                :ptuple :btuple
                :struct :table)
    #
    :comment (sequence (any :ws)
                       "#"
                       (any (if-not (choice "\n" -1) 1))
                       (any :ws))
    #
    :constant (choice "false" "nil" "true")
    #
    :number (drop (cmt
                   (capture :token)
                   ,scan-number))
    #
    :token (some :symchars)
    #
    :symchars (choice
               (range "09" "AZ" "az" "\x80\xFF")
               # XXX: see parse.c's is_symbol_char which mentions:
               #
               #        \, ~, and |
               #
               #      but tools/symcharsgen.c does not...
               (set "!$%&*+-./:<?=>@^_"))
    #
    :keyword (sequence ":" (any :symchars))
    #
    :string :bytes
    #
    :bytes (sequence "\""
                     (any (choice :escape (if-not "\"" 1)))
                     "\"")
    #
    :escape (sequence "\\"
                      (choice (set "0efnrtvz\"\\")
                              (sequence "x" [2 :hex])
                              (sequence "u" [4 :d])
                              (sequence "U" [6 :d])
                              (error (constant "bad escape"))))
    #
    :hex (range "09" "af" "AF")
    #
    :buffer (sequence "@" :bytes)
    #
    :long-string :long-bytes
    #
    :long-bytes {:main (drop (sequence
                              :open
                              (any (if-not :close 1))
                              :close))
                 :open (capture :delim :n)
                 :delim (some "`")
                 :close (cmt (sequence
                              (not (look -1 "`"))
                              (backref :n)
                              (capture :delim))
                             ,=)}
    #
    :long-buffer (sequence "@" :long-bytes)
    #
    :parray (sequence "@" :ptuple)
    #
    :ptuple (sequence "("
                      :root
                      (choice ")" (error "")))
    #
    :barray (sequence "@" :btuple)
    #
    :btuple (sequence "["
                      :root
                      (choice "]" (error "")))
    # XXX: constraining to an even number of values doesn't seem
    #      worth the work when considering that comments can also
    #      appear in a variety of locations...
    :struct (sequence "{"
                      :root
                      (choice "}" (error "")))
    #
    :table (sequence "@" :struct)
    #
    :symbol :token
    })

(comment

  (try
    (peg/match jg "\"\\u001\"")
    ([e] e))
  # => "bad escape"

  (peg/match jg "\"\\u0001\"")
  # => @[]

  (peg/match jg "(def a 1)")
  # => @[]

  (try
    (peg/match jg "[:a :b)")
    ([e] e))
  # => "match error at line 1, column 7"

  (peg/match jg "(def a # hi\n 1)")
  # => @[]

  (try
    (peg/match jg "(def a # hi 1)")
    ([e] e))
  # => "match error at line 1, column 15"

  (peg/match jg "[1]")
  # => @[]

  (peg/match jg "# hello")
  # => @[]

  (peg/match jg "``hello``")
  # => @[]

  (peg/match jg "8")
  # => @[]

  (peg/match jg "[:a :b]")
  # => @[]

  (peg/match jg "[:a :b] 1")
  # => @[]

 )

# make a version of jg that matches a single form
(def jg-one
  (->
   # jg is a struct, need something mutable
   (table ;(kvs jg))
   # just recognize one form
   (put :main :root0)
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(comment

  (try
    (peg/match jg-one "\"\\u001\"")
    ([e] e))
  # => "bad escape"

  (peg/match jg "\"\\u0001\"")
  # => @[]

  (peg/match jg "(def a 1)")
  # => @[]

  (try
    (peg/match jg "[:a :b)")
    ([e] e))
  # => "match error at line 1, column 7"

  (peg/match jg "(def a # hi\n 1)")
  # => @[]

  (try
    (peg/match jg "(def a # hi 1)")
    ([e] e))
  # => "match error at line 1, column 15"

  (peg/match jg "[1]")
  # => @[]

  (peg/match jg "# hello")
  # => @[]

  (peg/match jg "``hello``")
  # => @[]

  (peg/match jg "8")
  # => @[]

  (peg/match jg "[:a :b]")
  # => @[]

  (peg/match jg "[:a :b] 1")
  # => @[]

 )

# make a capturing version of jg
(def jg-capture
  (->
   # jg is a struct, need something mutable
   (table ;(kvs jg))
   # capture recognized bits
   (put :main '(capture :root))
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(comment

  (peg/match jg-capture "nil")
  # => @["nil"]

  (peg/match jg-capture "true")
  # => @["true"]

  (peg/match jg-capture "false")
  # => @["false"]

  (peg/match jg-capture "symbol")
  # => @["symbol"]

  (peg/match jg-capture "kebab-case-symbol")
  # => @["kebab-case-symbol"]

  (peg/match jg-capture "snake_case_symbol")
  # => @["snake_case_symbol"]

  (peg/match jg-capture "my-module/my-function")
  # => @["my-module/my-function"]

  (peg/match jg-capture "*****")
  # => @["*****"]

  (peg/match jg-capture "!%$^*__--__._+++===~-crazy-symbol")
  # => @["!%$^*__--__._+++===~-crazy-symbol"]

  (peg/match jg-capture "*global-var*")
  # => @["*global-var*"]

  (peg/match jg-capture "你好")
  # => @["\xE4\xBD\xA0\xE5\xA5\xBD"]

  (peg/match jg-capture ":keyword")
  # => @[":keyword"]

  (peg/match jg-capture ":range")
  # => @[":range"]

  (peg/match jg-capture ":0x0x0x0")
  # => @[":0x0x0x0"]

  (peg/match jg-capture ":a-keyword")
  # => @[":a-keyword"]

  (peg/match jg-capture "::")
  # => @["::"]

  (peg/match jg-capture ":")
  # => @[":"]

  (peg/match jg-capture "0")
  # => @["0"]

  (peg/match jg-capture "12")
  # => @["12"]

  (peg/match jg-capture "-65912")
  # => @["-65912"]

  (peg/match jg-capture "1.3e18")
  # => @["1.3e18"]

  (peg/match jg-capture "-1.3e18")
  # => @["-1.3e18"]

  (peg/match jg-capture "18r123C")
  # => @["18r123C"]

  (peg/match jg-capture "11raaa&a")
  # => @["11raaa&a"]

  (peg/match jg-capture "1_000_000")
  # => @["1_000_000"]

  (peg/match jg-capture "0xbeef")
  # => @["0xbeef"]

  (try
    (peg/match jg-capture "\"\\u001\"")
    ([e] e))
  # => "bad escape"

  (peg/match jg-capture "\"\\u0001\"")
  # => @["\"\\u0001\""]

  (peg/match jg-capture "\"\\U000008\"")
  # => @["\"\\U000008\""]

  (peg/match jg-capture "(def a 1)")
  # => @["(def a 1)"]

  (try
    (peg/match jg-capture "[:a :b)")
    ([e] e))
  # => "match error at line 1, column 7"

  (peg/match jg-capture "(def a # hi\n 1)")
  # => @["(def a # hi\n 1)"]

  (try
    (peg/match jg-capture "(def a # hi 1)")
    ([e] e))
  # => "match error at line 1, column 15"

  (peg/match jg-capture "[1]")
  # => @["[1]"]

  (peg/match jg-capture "# hello")
  # => @["# hello"]

  (peg/match jg-capture "``hello``")
  # => @["``hello``"]

  (peg/match jg-capture "8")
  # => @["8"]

  (peg/match jg-capture "[:a :b]")
  # => @["[:a :b]"]

  (peg/match jg-capture "[:a :b] 1")
  # => @["[:a :b] 1"]

  (def sample-source
    (string "# \"my test\"\n"
            "(+ 1 1)\n"
            "# => 2\n"))

  (peg/match jg-capture sample-source)
  # => @["# \"my test\"\n(+ 1 1)\n# => 2\n"]

  )

# make a version of jg that captures a single form
(def jg-capture-one
  (->
   # jg is a struct, need something mutable
   (table ;(kvs jg))
   # capture just one form
   (put :main '(capture :root0))
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(comment

  (def sample-source
    (string "# \"my test\"\n"
            "(+ 1 1)\n"
            "# => 2\n"))

  (peg/match jg-capture-one sample-source)
  # => @["# \"my test\"\n"]

  (peg/match jg-capture-one sample-source 11)
  # => @["\n(+ 1 1)\n"]

  (peg/match jg-capture-one sample-source 20)
  # => @["# => 2\n"]

  )
