# note: expression-by-expression evaluation may lead to better retention

(comment

  #########################################################################

  # step 1

  (peg/match "Content-Length:"
             "Content-Type:")
  # => nil

  # the second argument, "Content-Type:", is a string (or buffer) to
  # match against

  # the first argument, "Content-Length:", describes the desired
  # "matching" (somewhat analogous to a "regular expression" for
  # string matching in many other programming languages).

  # here the string literal "Content-Length:" results in an attempt to
  # match "Content-Length:" against the string "Content-Type:".  this
  # doesn't succeed because the strings differ after the "-":
  #
  #   "Content-Type:"
  #   "Content-Length:"
  #            ^
  #            |
  #            strings differ from here

  # when matching "fails", the return value of `peg/match` is `nil`

  #########################################################################

  # step 2

  (peg/match "Content-Type:"
             "Content-Type:")
  # => @[]

  # in this case the strings are equal and matching succeeds:

  #   "Content-Type:"
  #   "Content-Type:"
  #                ^
  #                |
  #                strings equal up through the end

  # when matching "succeeds", the return value of `peg/match` is an
  # array.  (the array is empty in this case because nothing was
  # captured.)

  # (in the examples so far, the first argument has been a string, but
  # it can be other things too (examples coming up).)

  # the first argument is sometimes referred to as a "peg" (short for
  # "parsing expression grammar").
  #
  # a simplified signature of `peg/match` is thus:
  #
  #   (peg/match peg str)
  #
  # where:
  #
  #   `peg` is a parsing expression grammar     (describes matching)
  #   `str` is a string                         (to match against)

  #########################################################################

  # step 3

  (peg/match "Content"
             "Content-Type:")
  # => @[]

  # in this case, the first argument is a substring of the second
  # argument and matching succeeds.  (this is referred to as an
  # "anchored match" in other contexts.)

  #   str: "Content-Type:"
  #   peg: "Content"
  #               ^
  #               |
  #               the part of the string "Content-Type:" that was examined
  #               was equal to the peg ("Content")

  # still, the returned array is empty because there were no captures.

  #########################################################################

  # step 4

  (peg/match ~(capture "Content-Type:")
             "Content-Type:")
  # => @["Content-Type:"]

  # the peg is not a string in this case, but rather a tuple:

  #   str: "Content-Type:"
  #   peg: (capture "Content-Type:)

  # ~ is used to prevent the tuple from being interpreted as a "call".
  # this could have also been written in any of the following ways:
  #
  #   '(capture "Content-Type:")
  #   '[capture "Content-Type:"]
  #   ['capture "Content-Type:"]
  #
  # ~ is used because sometimes unquoting is desired, and it's seen by
  # some as easier to just always use ~.  (imagine one started with
  # a single quote and then edited a peg later but then needed to use
  # unquoting -- the single quote would need to be changed...)

  # to capture content, use `capture`.  wrap an existing peg with
  # `(capture ...)`:

  #   old peg: "Content-Type:"
  #   new peg: ~(capture "Content-Type:")

  # finally the returned array is not empty -- it contains what was
  # captured.  in this case that is the string "Content-Type:"

  #########################################################################

  # step 5

  (peg/match ~(capture "Content")
             "Content-Type:")
  # => @["Content"]

  # here the captured content is "Content" -- "advancing" through the
  # "string to match", only occured up through the end of the word
  # "Content":

  #   str: "Content-Type:"
  #   peg: "Content"
  #               ^
  #               |
  #               "advanced" up through this position

  # wondering how we can match against things other than literal
  # strings?

  #########################################################################

  # step 6

  (peg/match ~(set "ABC")
             "Content-Type:")
  # => @[]

  # here only the initial "C" was matched.  `set` enables one to match
  # choosing from some number of characters.

  # in this example, the set has three characters, "A", "B", and "C".
  # since "Content-Type:" begins with "C", the peg matches.

  # note that the returned array is empty because no capturing happened.

  # to obtain matched content, recall one can use `capture`:

  (peg/match ~(capture (set "ABC"))
             "Content-Type:")
  # => @["C"]

  # if one wanted to match against the capital letters "A" through
  # "Z", that seems like it could be a lot of typing...

  #########################################################################

  # step 7

  (peg/match ~(range "AZ")
             "Content-Type:")
  # => @[]

  # somewhat similar to `set` is `range`.

  # in this example, one character of the string is tested against the
  # capital letters "A" through "Z".  since "C" (the first character
  # in "Content-Type:") is in that range, the match succeeds.

  # again, the returned array is empty.

  # probably it's clear what to do to capture what was matched:

  (peg/match ~(capture (range "AZ"))
             "Content-Type:")
  # => @["C"]

  # how are we going to match beyond the first character without
  # using a literal string?

  #########################################################################

  # step 8

  (peg/match ~(sequence (range "AZ")
                        (range "az"))
             "Content-Type:")
  # => @[]

  # wrapping multiple pegs with `(sequence ...)` expresses the idea
  # that all of the pegs should match.  further, they should match in
  # the order they are expressed in.

  # in this example, the first two characters of "Content-Type:" are
  # matched.

  # one way to see what was matched is to wrap the whole peg with
  # `capture`:

  (peg/match ~(capture (sequence (range "AZ")
                                 (range "az")))
             "Content-Type:")
  # => @["Co"]

  # another way is to wrap some of the individual pegs with `capture`:

  (peg/match ~(sequence (capture (range "AZ"))
                        (capture (range "az")))
             "Content-Type:")
  # => @["C" "o"]

  # note that the returned array now has more than one element.

  # also note the order in which the captures end up in the array.

  # the returned array is also referred to as "the capture stack",
  # presumably because captures are added on at one end as they are
  # "captured".

  # we can capture additional characters by adding more `range`
  # pegs:

  (peg/match ~(capture (sequence (range "AZ")
                                 (range "az")
                                 (range "az")))
             "Content-Type:")
  # => @["Con"]

  # but this has its limits :)

  #########################################################################

  # step 9

  (peg/match ~(capture (sequence (range "AZ")
                                 (some (range "az"))))
             "Content-Type:")
  # => @["Content"]

  # `some` expresses the idea of "1 or more".

  # in this example, the matching succeeded because:
  #
  # * the first character was a capital letter
  # * the second character and some subsequent characters
  #   were lower case letters

  # the matched content was "Content" and not "Content-Type:" because
  # "-" is not a lower case letter.

  # one way "-" and other non letters (such as ":") can be matched is
  # by using literal strings:

  (peg/match ~(capture (sequence (range "AZ")
                                 (some (range "az"))
                                 "-"
                                 (range "AZ")
                                 (some (range "az"))
                                 ":"))
             "Content-Type:")
  # => @["Content-Type:"]

  # is there a way to match a lower case or upper case letter?

  #########################################################################

  # step 10

  (peg/match ~(capture (sequence (some (range "az" "AZ"))
                                 "-"
                                 (some (range "az" "AZ"))
                                 ":"))
             "Content-Type:")
  # => @["Content-Type:"]

  # it turns out that `range` can be given more than one argument,
  # where each argument describes a range.

  # in this example, `(range "az" "AZ")` means to match a character in
  # the range of lower case letters OR in the range of upper case
  # letters.

  # that sounds like a rather common thing one might want to do...

  #########################################################################

  # step 11

  (peg/match ~(capture (sequence (some :a)
                                 "-"
                                 (some :a)
                                 ":"))
             "Content-Type:")
  # => @["Content-Type:"]

  # `:a` is shorthand for `(range "az" "AZ")`

  # this is defined in the table named `default-peg-grammar` in
  # `boot.janet`.

  # to see what `:a` stands for, try:

  (get default-peg-grammar :a)
  # => '(range "az" "AZ")

  # which other conveniences exist can be seen by examining the keys
  # of `default-peg-grammar`:

  (deep=
    #
    (sort (keys default-peg-grammar))
    #
    @[:A :D :H :S :W
      :a :a* :a+
      :d :d* :d+
      :h :h* :h+
      :s :s* :s+
      :w :w* :w+])
  # => true

  # the `*` and `+` versions refer to "0 or more" and "1 or more", so
  # the example above could also be expressed as:

  (peg/match ~(capture (sequence :a+
                                 "-"
                                 :a+
                                 ":"))
             "Content-Type:")
  # => @["Content-Type:"]

  # once again, to see what something stands for:

  (get default-peg-grammar :a+)
  # => '(some :a)

  #############################################################
  ### BEGIN ASIDE ABOUT *, +, PEG SPECIALS, AND SHORT NAMES ###
  #############################################################

  # WARNING: `*` and `+` are used elsewhere in janet's pegs with
  # meanings that do not correspond to "X or more".

  # for example, it turns out that `*` is another name for `sequence`.
  # thus, the most recent `peg/match` could also be expressed as:

  (peg/match ~(capture (* :a+
                          "-"
                          :a+
                          ":"))
             "Content-Type:")
  # => @["Content-Type:"]

  # a number of the peg-related constructs (sometimes called "peg
  # specials") have short names.  one place they can be looked up is:

  #   https://github.com/sogaiu/margaret#specials-implementation-status

  # to reduce confusion, this tutorial will not use these.  though you
  # can avoid them in your own code, it may be helpful to become
  # familiar with them in order to read code by others as well as for
  # communication purposes.

  ###########################################################
  ### END ASIDE ABOUT *, +, PEG SPECIALS, AND SHORT NAMES ###
  ###########################################################

  #########################################################################

  # step 12

  (peg/match ~(capture (sequence :a+
                                 :A
                                 :a+
                                 :A))
             "Content-Type:")
  # => @["Content-Type:"]

  # the capital letter versions (such as `:A`) of the convenient
  # shorthands in `default-peg-grammar` are negated versions of the
  # lower case versions.  so for example, `:A` means NOT `:a`, or
  # "neither a lower case nor an upper case letter".

  # in the above example, the call doesn't mean exactly the same thing
  # as a similar one in the previous example as it is looser about
  # matching "-" and ":".

  ##################################################
  ### BEGIN ASIDE ABOUT :A+, :A*, :D+, :D*, etc. ###
  ##################################################

  # note that there is no `:A+` nor `:A*`.  in `default-peg-grammar`,
  # `*` and `+` are just the third characters in literal keywords
  # (e.g. `:a*` and `:a+`).  there is no "magic" that arranges for the
  # `*` or `+` version of something to come into existence.  there are
  # no `*` or `+` versions of `:A`, `:D`, `:H`, `:S`, or `:W`.

  ################################################
  ### END ASIDE ABOUT :A+, :A*, :D+, :D*, etc. ###
  ################################################

  # `:A` is shorthand for:

  (get default-peg-grammar :A)
  # => '(if-not :a 1)

  # there are two constructs that are new here -- `if-not` and `1` --
  # which will be examine in the reverse order :)

  # the peg special `1` means to unconditionally "advance" by one
  # character, i.e. matching isn't affected by the specific character
  # at the current position under consideration.

  # thus, another way to express an earlier example is:

  (peg/match ~(capture (sequence :a+
                                 1
                                 :a+
                                 1))
             "Content-Type:")
  # => @["Content-Type:"]

  # `if-not` works by trying to match based on its first argument, and
  # if that FAILS, it proceeds to attempt a match using the second
  # argument (starting at the same position of the string used for the
  # first argument match attempt).

  # it is noteworthy that although an attempt to match is made with
  # the first argument, it doesn't lead to anything being captured,
  # nor is there any "advancing" (i.e. the next character to be
  # considered is not further along the string):

  (peg/match ~(sequence (capture (if-not "a" 1)))
             "bz")
  # => @["b"]

  # in this example, after `if-not`'s first argument "a" fails to
  # match "b", a match attempt is made with `1` starting at "b" rather
  # than "z" (because there was no "advancing" associated with the
  # attempt at matching with the first argument).

  #########################################################################

  # step 13

  (peg/match ~(sequence "Content" (position))
             "Content-Type:")
  # => @[7]

  # `position` can be used to obtain the current position or index
  # within the string being matched.

  # in this example, 7 represents index position 7.  counting starts
  # at 0, so this actually means the 8th spot.

  # janet's `string/slice` can be used to examine "what's left" of
  # the string that was the target of matching:

  (string/slice "Content-Type:" 7)
  # => "-Type:"

  # `position` can be put in various locations:

  (peg/match ~(sequence (position) "Content" (position))
             "Content-Type:")
  # => @[0 7]

  # so one way to determine what part of the string matched is to
  # use these indeces:

  (string/slice "Content-Type:" 0 7)
  # => "Content"

  # there are also the peg specials `line` and `column` (1-based
  # instead of 0-based) which can be convenient when working with
  # editor-like situations:

  (peg/match ~(sequence (line) (column)
                        "Content\nType"
                        (line) (column))
             "Content\nType")
  # => @[1 1 2 5]

  # in this example `1 1` refers to line 1 and column 1 -- the first
  # character -- while `2 5` refers to line 2 and column 5 -- the
  # character after the last character matched

  #########################################################################

  # step 14

  (peg/match ~(capture (to ":"))
             "Content-Type:")
  # => @["Content-Type"]

  # the `to` peg special is equivalent to `(some (if-not ... 1))`.
  # put another way, keep matching "to" (up until but not including)
  # something.

  # in this example, `(to ":")` matches characters from the beginning
  # of the string up until (but not including) ":".  thus the captured
  # value does not end in ":".

  # `thru` is a conceptually similar peg special which matches up
  # through (i.e. including) something:

  (peg/match ~(capture (thru ":"))
             "Content-Type:")
  # => @["Content-Type:"]

  # in this example, `(thru ":")` matches characters from the
  # beginning of the string up through (and including) ":".  thus the
  # captured value ends in ":".

  #########################################################################

  # step 15

  (peg/match ~(sequence (capture (to ":")) ":"
                        :s+
                        (capture (to "\r\n")) "\r\n")
             "Content-Type: text/plain\r\n")
  # => @["Content-Type" "text/plain"]

  # `:s+` is the `+` form of `:s`:

  (get default-peg-grammar :s+)
  # => '(some :s)

  # `:s` is shorthand for matching whitespace (note that the zero byte
  # is included):

  (get default-peg-grammar :s)
  # => '(set " \t\r\n\0\f\v")

  # in this example, a header line (perhaps from HTTP) is matched, and
  # the header name ("Content-Type") and header value ("text/plain")
  # are captured.  note that the ":", intermediate space, and "\r\n"
  # were not captured.

  # what if we wanted the header name and value to be contained in a
  # table?

  #########################################################################

  # step 16

  (peg/match ~(replace (sequence (capture (to ":")) ":"
                                 :s+
                                 (capture (to "\r\n")) "\r\n")
                       ,(fn [& captures]
                          (table ;captures)))
             "Content-Type: text/plain\r\n")
  # => @[@{"Content-Type" "text/plain"}]

  # the `replace` peg special can be used to capture the results of
  # running a janet function.  the function is passed initially
  # captured values and is free to produce some other value (which is
  # what ends up being captured instead).

  # in this example, the initally captured values are "Content-Type"
  # and "text/plain".  the janet function is:

  #   (fn [& captures]
  #     (table ;captures))

  # the call to `table` ends up being:

  #   (table "Content-Type" "text/plain")

  # which results in:

  #   @{"Content-Type" "text/plain"}

  # note that in the `peg/match` call, there is a comma before the
  # `(fn [& captures] ...)` form.  this is a case where unquoting
  # is necessary (recall the use of ~ described earlier).

  # since `peg/match` returns an array that holds the table in this
  # case, one can get at the table via `first` or other means:

  (->> "Content-Type: text/plain\r\n"
       (peg/match ~(replace (sequence (capture (to ":")) ":"
                                      :s+
                                      (capture (to "\r\n")) "\r\n")
                            ,(fn [& captures]
                               (table ;captures))))
       first)
  # => @{"Content-Type" "text/plain"}

  #########################################################################

  # step 17

  (peg/match ~{:main (some :line)
               :line (sequence (capture (to "\r\n"))
                               "\r\n")}
             (string "Content-Type: text/plain\r\n"
                     "Content-Length: 1024\r\n"))
  # => @["Content-Type: text/plain" "Content-Length: 1024"]

  # it's possible to compose pegs using a struct or a table where the
  # keys are keywords and the values are pegs.  further, the keywords
  # can be used within the other pegs in the struct / table to refer
  # to their corresponding pegs.

  # an additional requirement is that there is a `:main` key.  this is
  # considered the "top" or "start" of the overall peg.

  # in the example above, the peg associated with `:main` is `(some
  # :line)`.  `:line` refers to `(sequence (capture ...))`.  so the
  # call could have been written as follows instead:

  (peg/match ~(some (sequence (capture (to "\r\n"))
                              "\r\n"))
             (string "Content-Type: text/plain\r\n"
                     "Content-Length: 1024\r\n"))
  # => @["Content-Type: text/plain" "Content-Length: 1024"]

  # as pegs grow in size though, they might benefit from making use of
  # the struct / table arrangement.

  #########################################################################

  # step 18

  (deep=
    #
    (->> (string "Content-Type: text/plain\r\n"
                 "Content-Length: 1024\r\n")
         (peg/match ~{:main (cmt (some :header-line)
                                 ,(fn [& captures]
                                    (table ;captures)))
                      :header-line (sequence (capture :header-name) ":"
                                             :s+
                                             (capture :header-value) :crlf)
                      :header-name (to ":")
                      :header-value (to "\r\n")
                      :crlf "\r\n"})
         first)
    #
    @{"Content-Length" "1024"
      "Content-Type" "text/plain"})
  # => true

  # bringing many of the examples so far together, this example takes
  # a string consisting of several lines and produces a table of
  # header, value pairs

  # one could turn this into a function like:

  (defn parse-header-from-buffer
    [lines-as-buffer]
    (def header-peg
      (peg/compile ~{:main (cmt (some :header-line)
                                ,(fn [& captures]
                                   (table ;captures)))
                     :header-line (sequence (capture :header-name) ":"
                                            :s+
                                            (capture :header-value) :crlf)
                     :header-name (to ":")
                     :header-value (to "\r\n")
                     :crlf "\r\n"}))
    #
    (->> lines-as-buffer
         (peg/match header-peg)
         first))

  # here `peg/compile` has been used to produce a compiled form of the
  # peg.  taking this approach means that the peg is compiled when the
  # function is defined.  so the peg is not compiled each time
  # `parse-header-from-buffer` is called.

  # note that this approach is not always feasible if the peg contains
  # some kind of "parameterization".

  # here's the function in action:

  (deep=
    #
    (parse-header-from-buffer
      (buffer/push-string
        @""
        "Content-Type: text/plain\r\n"
        "Content-Length: 1024\r\n"))
    #
    @{"Content-Length" "1024"
      "Content-Type" "text/plain"})
  # => true

  #########################################################################

  # step X

  # in this step we'll mention some things that were not covered
  # earlier.

  # some peg specials allow "tagging" a match for later use:

  (peg/match ~(sequence (capture :d+ :number)
                        :a+
                        (backmatch :number))
             "123abc123")
  # => @["123"]

  # in this example, a numeric prefix string "123" is captured for
  # reference later.  the capture is "tagged" with the keyword
  # `:number`.  after the prefix a sequence of letters is matched
  # "abc".  finally, the numeric prefix string that was captured
  # earlier "123" is matched via its tag using the `backmatch` peg
  # special.

  # to avoid having the capture stack end up with the tagged capture,
  # in this case one could use `drop` to remove from the capture
  # stack:

  (peg/match ~(drop (sequence (capture :d+ :number)
                              :a+
                              (backmatch :number)))
             "123abc123")
  # => @[]

  # one important peg special not covered earlier is `choice`.  as the
  # name suggests, this one allows multiple pegs to be attempted in
  # the order of listing:

  (peg/match ~(choice "cat"
                      "dog")
             (if (< (math/random) 0.5)
               "cat"
               "dog"))
  # => @[]

  # to match the end of a string, use `-1`.

  # compare the following:

  (peg/match ~(sequence "Hello!" -1)
             "Hello!")
  # => @[]

  (peg/match ~(sequence "Hello!" -1)
             "Hello!There")
  # => nil

  # the second call returned `nil` because the string didn't end after
  # the "!", whereas the first call yielded a match (but no capture)
  # because the string matched and had no further characters.

  # `peg/match` has optional arguments:

  #   (peg/match peg text &opt start & args)

  # `start` is an index position within `text` to start matching at.
  # the default value for this is 0.

  # `args` is used by the `argument` peg special as a source of
  # "things to put on the capture stack":

  (peg/match ~(sequence "{{expression}}"
                        (argument 0)
                        :s+
                        "{{action}}"
                        (argument 1))
             "{{expression}}  {{action}}"
             0
             :smile :breathe)
  # => @[:smile :breathe]

  # there are more peg specials that are not covered here, but
  # see the following for a grouped listing that includes the short
  # names as well as links to examples:

  #   https://github.com/sogaiu/margaret#user-content-specials-implementation-status

  # incidentally, peg specials can be classified into 3 types:

  # * primitive
  # * combinators
  # * captures

  # the primitive peg specials were all touched on:

  # * integer (e.g. 1, 2, -1, etc.)
  # * `range`
  # * `set`
  # * string literal (e.g. "Content-Type:", "Hello!", etc.)

  # combinator peg specials that were covered include:

  # * `backmatch`
  # * `choice`
  # * `if-not`
  # * `sequence`
  # * `some`
  # * `thru`
  # * `to`

  # not covered were:

  # * `any`
  # * `at-least`
  # * `at-most`
  # * `between`
  # * `if`
  # * `look`
  # * `opt`
  # * `repeat`
  # * `unref`

  # capture peg specials are those that influence the capture stack in
  # some fashion.  those that were covered include:

  # * `argument`
  # * `capture`
  # * `column`
  # * `drop`
  # * `line`
  # * `position`
  # * `replace`

  # not covered were:

  # * `accumulate`
  # * `backref`
  # * `cmt`
  # * `constant`
  # * `error`
  # * `group`
  # * `int`
  # * `int-be`
  # * `lenprefix`
  # * `number`
  # * `uint`
  # * `uint-be`

  )
