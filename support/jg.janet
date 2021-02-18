(import ./args)
(import ./input)
(import ./rewrite)
(import ./segments)

# XXX: consider `(break false)` instead of just `assert`?
(defn handle-one
  [opts]
  (def {:format format
        :input input
        :output output
        :version version} opts)
  # XXX: review
  (when version
    (break true))
  # read in the code
  (def buf (input/slurp-input input))
  (assert buf (string "Failed to read input for:" input))
  # slice the code up into segments
  (def segments (segments/parse-buffer buf))
  (assert segments (string "Failed to parse input:" input))
  # find comment blocks
  (def comment-blocks (segments/find-comment-blocks segments))
  (when (empty? comment-blocks)
    (break false))
  (when (dyn :debug)
    (eprint "first comment block found was: " (first comment-blocks)))
  # output rewritten content if appropriate
  (def out @"")
  (buffer/blit out buf -1)
  (buffer/blit out (rewrite/rewrite-with-verify comment-blocks format) -1)
  (if (not= "" output)
    (spit output out)
    (print out))
  true)

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (def file-path "./jg.janet")

  (handle-one {:input file-path
               :output ""
               :single true})

  )

(defn main
  [& args]
  (def opts (args/parse))
  (unless opts
    (os/exit 1))
  (cond
    (opts :version)
    (print "judge-gen alpha")
    #
    (handle-one opts)
    true))
