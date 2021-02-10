(import ./args :fresh true)
(import ./input :fresh true)
(import ./rewrite :fresh true)
(import ./segments :fresh true)

# XXX: consider `(break false)` instead of just `assert`?
(defn handle-one
  [opts]
  (def {:format format
        :input input
        :line line
        :output output
        :prepend prepend
        :single single
        :version version} opts)
  # XXX: review
  (when version
    (break true))
  # read in the code, determining the byte offset of line with cursor
  (var [buf position]
       (input/slurp-input input line))
  (assert buf (string "Failed to read input for:" input))
  (when (dyn :debug) (eprint "byte position for line: " position))
  # slice the code up into segments
  (var segments (segments/parse-buffer buf))
  (assert segments (string "Failed to parse input:" input))
  (var at nil)
  (when (< 0 line)
    # find segment relevant to cursor location
    (set at (segments/find-segment segments position)))
  # find an appropriate comment block
  (def comment-blocks (segments/find-comment-blocks segments at single))
  (when (dyn :debug)
    (eprint "first comment block found was: " (first comment-blocks)))
  # output rewritten content if appropriate
  (when (empty? comment-blocks)
    (break false))
  (def out @"")
  (when prepend
    (buffer/blit out buf -1))
  (buffer/blit out (rewrite/rewrite-with-verify comment-blocks format) -1)
  (if (not= "" output)
    (spit output out)
    (print out))
  true)

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (def file-path "./jg.janet")

  (handle-one {:input file-path
               :line 0
               :output ""
               :prepend false
               :single true})

 )

(defn main
  [& args]
  (when (not (handle-one (args/parse)))
    (os/exit 1)))
