(import ../margaret/meg)

# `(error ?patt)`

# Throws a Janet error.

# The error thrown will be the last capture of `patt`, or a generic error if
# `patt` produces no captures or `patt` is not specified.

(comment

  # error with line and column values
  (meg/match ~(sequence "a"
                        "\n"
                        "b"
                        "\n"
                        "c"
                        (error))
             "a\nb\nc")
  # !

  # error match failure
  (meg/match ~(error "ho")
             "")
  # => nil

  # error with captured result in message
  (meg/match ~(error (capture "a"))
             "a")
  # !

  (try
    (meg/match ~(sequence "a"
                          (error (sequence (capture "b")
                                           (capture "c"))))
               "abc")
    ([err]
      err))
  # => "c"

  (try
    (meg/match ~(choice "a"
                        "b"
                        (error ""))
               "c")
    ([err]
      err))
  # => "match error at line 1, column 1"

  (try
    (meg/match ~(choice "a"
                        "b"
                        (error))
               "c")
    ([err]
      :match-error))
  # => :match-error

  )
