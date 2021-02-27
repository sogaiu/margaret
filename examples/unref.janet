(import ../margaret/meg :as peg)

# `(undef rule ?tag)`

# The `undef` combinator lets a user "scope" tagged captures.

# After the rule has matched, all captures with `tag` can no longer be
# referred to by their tag. However, such captures from outside the
# rule are kept as is.

# If no tag is given, all tagged captures from rule are
# unreferenced.

# Note that this doesn't `drop` the captures, merely removes their
# association with the tag. This means subsequent calls to `backref`
# and `backmatch` will no longer "see" these tagged captures.

(comment

  (def grammar
    ~{:main (* :tagged -1)
      :tagged (unref (replace (* :open-tag :value :close-tag)
                              ,struct))
      :open-tag (* (constant :tag)
                   "<"
                   (capture :w+ :tag-name)
                   ">")
      :value (* (constant :value)
                (group (any (+ :tagged :untagged))))
      :close-tag (* "</"
                    (backmatch :tag-name)
                    ">")
      :untagged (capture (any (if-not "<" 1)))})

  (deep=
    (peg/match grammar "<p>Hello</p>")
    #
    @[{:tag "p"
       :value @["Hello"]}]
    ) # => true

  (deep=
    (peg/match grammar "<p><p>Hello</p></p>")
    #
    @[{:tag "p"
       :value @[{:tag "p"
                 :value @["Hello"]}]}]
    ) # => true

  (deep=
    (peg/match grammar "<p><em>Hello</em></p>")
    #
    @[{:tag "p"
       :value @[{:tag "em"
                 :value @["Hello"]}]}]
    ) # => true

)
