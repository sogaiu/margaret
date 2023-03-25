(import ../margaret/meg :as peg)

# `(unref rule ?tag)`

# The `unref` combinator lets a user "scope" tagged captures.

# After the rule has matched, all captures with `tag` can no longer be
# referred to by their tag. However, such captures from outside the
# rule are kept as is.

# If no tag is given, all tagged captures from rule are
# unreferenced.

# Note that this doesn't `drop` the captures, merely removes their
# association with the tag. This means subsequent calls to `backref`
# and `backmatch` will no longer "see" these tagged captures.

(comment

  # try removing the unref to see what happens
  (peg/match ~{:main (sequence :thing -1)
               :thing (choice (unref (sequence :open :thing :close))
                              (capture (any (if-not "[" 1))))
               :open (capture (sequence "[" (some "_") "]")
                              :delim)
               :close (capture (backmatch :delim))}
             "[__][_]a[_][__]")
  # =>
  @["[__]" "[_]" "a" "[_]" "[__]"]

  )

(comment

  (def grammar
    ~{:main (sequence :tagged -1)
      :tagged (unref (replace (sequence :open-tag :value :close-tag)
                              ,struct))
      :open-tag (sequence (constant :tag)
                          "<"
                          (capture :w+ :tag-name)
                          ">")
      :value (sequence (constant :value)
                       (group (any (choice :tagged :untagged))))
      :close-tag (sequence "</"
                           (backmatch :tag-name)
                           ">")
      :untagged (capture (any (if-not "<" 1)))})

  (peg/match grammar "<p>Hello</p>")
  # =>
  @[{:tag "p"
     :value @["Hello"]}]

  (peg/match grammar "<p><p>Hello</p></p>")
  # =>
  @[{:tag "p"
     :value @[{:tag "p"
               :value @["Hello"]}]}]

  (peg/match grammar "<p><em>Hello</em></p>")
  # =>
  @[{:tag "p"
     :value @[{:tag "em"
               :value @["Hello"]}]}]

  )

