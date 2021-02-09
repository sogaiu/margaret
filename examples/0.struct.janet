(import ../margaret/meg)

# `{:main <rule> ...}` -- where <rule> is a peg (see below for ...)

# The feature that makes PEGs so much more powerful than pattern matching
# solutions like (vanilla) regex is mutual recursion.

# To do recursion in a PEG, you can wrap multiple patterns in a grammar,
# which is a Janet struct.

# The patterns must be named by keywords, which can then be used in all
# sub-patterns in the grammar.

# Each grammar, defined by a struct, must also have a main rule, called
# `:main`, that is the pattern that the entire grammar is defined by.

(comment

  (meg/match '{:main 1} "a")
  # => @[]

  (meg/match '{:main :fun
               :fun 1}
             "a")
  # => @[]

  (def my-grammar
    '{:a (* "a" :b "a")
      :b (* "b" (+ :a 0) "b")
      :main (* "(" :b ")")})

  # alternative expression of `my-grammar`
  (def my-grammar-alt
    '{# :b wrapped in parens
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
  (meg/match my-grammar-alt "(bb)")
  # => @[]

  # next simplest match
  (meg/match my-grammar-alt "(babbab)")
  # => @[]

  # non-match
  (meg/match my-grammar-alt "(baab)")
  # => nil

)
