(import ../margaret/meg :as peg)

# `(error ?patt)`

# Throws a Janet error.

# The error thrown will be the last capture of `patt`, or a generic error if
# `patt` produces no captures or `patt` is not specified.

(comment

  # error with line and column values
  (peg/match ~(sequence "a"
                        "\n"
                        "b"
                        "\n"
                        "c"
                        (error))
             "a\nb\nc")
  # !

  # error match failure
  (peg/match ~(error "ho")
             "")
  # => nil

  # error with captured result in message
  (peg/match ~(error (capture "a"))
             "a")
  # !

  (try
    (peg/match ~(sequence "a"
                          (error (sequence (capture "b")
                                           (capture "c"))))
               "abc")
    ([err]
      err))
  # => "c"

  (try
    (peg/match ~(choice "a"
                        "b"
                        (error ""))
               "c")
    ([err]
      err))
  # => "match error at line 1, column 1"

  (try
    (peg/match ~(choice "a"
                        "b"
                        (error))
               "c")
    ([err]
      :match-error))
  # => :match-error

  )
