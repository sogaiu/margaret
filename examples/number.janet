(import ../margaret/meg :as peg)

# `(number patt ?base ?tag)`

# Capture a number if `patt` matches and the matched text scans as a number.

# If specified, `base` should be a number between 2 and 36 inclusive or nil.
# If `base` is not nil, interpreting the string will be done according to
# radix `base`.  If `base` is nil,  interpreting the string will be done
# via `scan-number` as-is.

# Note that if the capture is tagged, the captured content available via
# the tag (e.g. using `backref`) is a number and not a string.

(comment

  (peg/match '(number :d+) "18")
  # => @[18]

  (peg/match ~(number :w+) "0xab")
  # => @[171]

  (peg/match '(number (sequence (some (choice :d "_"))))
             "60_000 ganges rivers")
  # => @[60000]

  (peg/match ~(number :d+ nil :my-tag) "18")
  # => @[18]

  (peg/match '(number :w+ nil :your-tag) "0xab")
  # => @[171]

  (peg/match ~(sequence (number :d+ nil :a)
                        (backref :a))
             "28")
  # => @[28 28]

  (let [chunked
        (string "4\r\n"
                "Wiki\r\n"
                "6\r\n"
                "pedia \r\n"
                "E\r\n"
                "in \r\n"
                "\r\n"
                "chunks.\r\n"
                "0\r\n"
                "\r\n")]
    (peg/match ~(some (sequence
                        (number :h+ 16 :length)
                        "\r\n"
                        (capture
                          (lenprefix (backref :length)
                                     1))
                        "\r\n"))
               chunked))
  # => @[4 "Wiki" 6 "pedia " 14 "in \r\n\r\nchunks." 0 ""]

  )
