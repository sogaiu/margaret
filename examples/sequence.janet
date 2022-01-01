(import ../margaret/meg :as peg)

# `(sequence a b c ...)`

# Tries to match a, b, c and so on in sequence.

# If any of these arguments fail to match the text, the whole pattern fails.

# `(* a b c ...)` is an alias for `(sequence a b c ...)`

(comment

  (peg/match ~(sequence) "a")
  # =>
  @[]

  (peg/match ~(sequence "a" "b" "c")
             "abc")
  # =>
  @[]

  (peg/match ~(sequence "a" "b" "c")
             "abcd")
  # =>
  @[]

  (peg/match ~(sequence "a" "b" "c")
             "abx")
  # =>
  nil

  (peg/match ~(sequence (capture 1 :a)
                        (capture 1)
                        (capture 1 :c))
             "abc")
  # =>
  @["a" "b" "c"]

  (peg/match ~(* "a" "b" "c")
             "abc")
  # =>
  @[]

  (peg/match
    ~(sequence (capture "a"))
    "a")
  # =>
  @["a"]

  (peg/match
    ~(capture "a")
    "a")
  # =>
  (peg/match
    ~(sequence (capture "a"))
    "a")

  (peg/match
    ~(sequence (capture (choice "a" "b")))
    "a")
  # =>
  @["a"]

  (peg/match
    ~(capture (+ "GET" "POST" "PATCH" "DELETE"))
    "PATCH")
  # =>
  @["PATCH"]

  # thanks pepe
  (peg/match
    ~(capture (choice "GET" "POST" "PATCH" "DELETE"))
    "PATCH")
  # =>
  (peg/match
    ~(sequence (capture (choice "GET" "POST" "PATCH" "DELETE")))
    "PATCH")

  )
