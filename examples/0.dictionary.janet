(import ../margaret/meg :as peg)

# `{:main <rule> ...}`

# or

# `@{:main <rule> ...}`

# where <rule> is a peg (see below for ...)

# The feature that makes PEGs so much more powerful than pattern
# matching solutions like (vanilla) regex is mutual recursion.

# To do recursion in a PEG, you can wrap multiple patterns in a
# grammar, which is a Janet dictionary (i.e. a struct or a table).

# The patterns must be named by keywords, which can then be used in
# all sub-patterns in the grammar.

# Each grammar, defined by a dictionary, must also have a main rule,
# called `:main`, that is the pattern that the entire grammar is
# defined by.

(comment

  (peg/match '{:main 1} "a")
  # =>
  @[]

  (peg/match '{:main :fun
               :fun 1}
             "a")
  # =>
  @[]

  (peg/match ~{:main (some :fun)
               :fun (choice :play :relax)
               :play "1"
               :relax "0"}
             "0110111001")
  # =>
  @[]

  )

(comment

  (def my-grammar
    '{:a (* "a" :b "a")
      :b (* "b" (+ :a 0) "b")
      :main (* "(" :b ")")})

  # alternative expression of `my-grammar`
  (def my-grammar-alt
    '@{# :b wrapped in parens
       :main (sequence "("
                       :b
                       ")")
       # :a or nothing wrapped in lowercase b's
       :b (sequence "b"
                    (choice :a 0)
                    "b")
       # :b wrapped in lowercase a's
       :a (sequence "a"
                    :b
                    "a")})

  # simplest match
  (peg/match my-grammar-alt "(bb)")
  # =>
  @[]

  # next simplest match
  (peg/match my-grammar-alt "(babbab)")
  # =>
  @[]

  # non-match
  (peg/match my-grammar-alt "(baab)")
  # =>
  nil

  (all |(deep= (peg/match my-grammar $)
               (peg/match my-grammar-alt $))
       ["(bb)" "(babbab)" "(baab)"])
  # =>
  true

  )

