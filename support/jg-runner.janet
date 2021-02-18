(import ./utils)
(import ./jg)
(import ./args-runner)
(import ./vendor/jpm)
(import ./vendor/path)

(defn make-judges
  [dir subdirs judge-root judge-file-prefix]
  (each path (os/dir dir)
    (def fpath (path/join dir path))
    (case (os/stat fpath :mode)
      :directory (do
                   (make-judges fpath (array/push subdirs path)
                                judge-root judge-file-prefix)
                   (array/pop subdirs))
      :file (when (= (path/ext fpath) ".janet")
              (jg/handle-one {:input fpath
                              :line 0
                              :output (path/join judge-root
                                                 ;subdirs
                                                 (string
                                                   judge-file-prefix path))
                              :prepend true})))))

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (def proj-root
    (path/join (os/getenv "HOME")
               "src" "judge-gen"))

  (def judge-root
    (path/join proj-root "judge"))

  (def src-root
    (path/join proj-root "judge-gen"))

  (os/mkdir judge-root)

  (make-judges src-root @[] judge-root "judge-")

  )

(defn judge
  [dir results judge-root judge-file-prefix]
  (var count 0)
  (def results-dir
    # XXX: what about windows...
    (path/join "/tmp"
               (string "judge-gen-"
                       (os/time) "-"
                       (utils/rand-string 8))))
  (defn make-results-fpath
    [fname i]
    (let [fpath (path/join results-dir
                           (string i "-" fname))]
      # note: create-dirs expects a path ending in a filename
      (try
        (jpm/create-dirs fpath)
        ([err]
          (errorf "failed to create dir for path: " fpath)))
      fpath))
  (each path (os/dir dir)
    (def fpath (path/join dir path))
    (case (os/stat fpath :mode)
      :directory (judge fpath results judge-root judge-file-prefix)
      :file (when (and (string/has-prefix? judge-file-prefix path)
                       (string/has-suffix? ".janet" fpath))
              (print "  " path)
              (def results-fpath
                (make-results-fpath path count))
              # XXX
              #(eprintf "results path: %s" results-fpath)
              (def command (string/join
                             [(dyn :executable "janet")
                              "-e"
                              (string "'(os/cd \"" judge-root "\")'")
                              "-e"
                              (string "'"
                                      "(do "
                                      "  (setdyn :judge-gen/test-out "
                                      "          \"" results-fpath "\") "
                                      "  (dofile \"" fpath "\") "
                                      ")"
                                      "'")] # avoid `main`
                             " "))
              # XXX
              #(eprintf "command: %s" command)
              (let [output (try
                             (jpm/pslurp command)
                             ([err]
                               (eprint err)
                               (errorf "command failed: %s" command)))]
                (when (not= output "")
                  (spit (path/join results-dir
                                   (string "stdout-" count "-" path ".txt"))
                        output)))
              (def marshalled-results
                (try
                  (slurp results-fpath)
                  ([err]
                    (eprint err)
                    (errorf "failed to read in marshalled results from: %s"
                            results-fpath))))
              (def results-for-path
                (try
                  (unmarshal (buffer marshalled-results))
                  ([err]
                    (eprintf err)
                    (errorf "failed to unmarshal content from: %s"
                            results-fpath))))
              (put results
                   fpath results-for-path)
              (++ count)))))

(defn summarize
  [results]
  (when (empty? results)
    # XXX: somehow messes things up?
    #(print "No test results")
    (break))
  (var total-tests 0)
  (var total-passed 0)
  (def failures @{})
  (eachp [fpath test-results] results
    (def name (path/basename fpath))
    (when test-results
      (var passed 0)
      (var num-tests (length test-results))
      (var fails @[])
      (each test-result test-results
        (++ total-tests)
        (def {:passed test-passed} test-result)
        (if test-passed
          (do
            (++ passed)
            (++ total-passed))
          (array/push fails test-result)))
      (when (not (empty? fails))
        (put failures fpath fails))))
  (eachp [fpath failed-tests] failures
    (print fpath)
    (each fail failed-tests
      (def {:test-value test-value
            :expected-value expected-value
            :name test-name
            :passed test-passed
            :test-form test-form} fail)
      (utils/print-color "  failed" :red)
      (print ": " test-name)
      (utils/print-color "    form" :red)
      (printf ": %M" test-form)
      (utils/print-color "expected" :red)
      # XXX: this could use some work...
      (if (< 30 (length (describe expected-value)))
        (print ":")
        (prin ": "))
      (printf "%M" expected-value)
      (utils/print-color "  actual" :red)
      # XXX: this could use some work...
      (if (< 30 (length (describe test-value)))
        (print ":")
        (prin ": "))
      (printf "%M" test-value)))
  (when (= 0 total-tests)
    (print "No tests found, so no judgements made.")
    (break))
  (if (not= total-passed total-tests)
    (do
      (utils/print-dashes)
      (utils/print-color total-passed :red))
    (utils/print-color total-passed :green))
  (prin " of ")
  (utils/print-color total-tests :green)
  (print " passed")
  (utils/print-dashes)
  (print "all judgements made."))

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (summarize @{})

  )

# XXX: consider `(break false)` instead of just `assert`?
(defn handle-one
  [opts]
  (def {:judge-dir-name judge-dir-name
        :judge-file-prefix judge-file-prefix
        :proj-root proj-root
        :src-root src-root} opts)
  (def judge-root
    (path/join proj-root judge-dir-name))
  # remove old judge directory
  (print (string "cleaning out: " judge-root))
  (jpm/rm judge-root)
  # XXX
  (print "removed judge dir")
  # copy source files
  (jpm/copy src-root judge-root)
  (utils/print-dashes)
  # create judge files
  (make-judges src-root @[] judge-root judge-file-prefix)
  # judge
  (print "judging...")
  (var results @{})
  (judge judge-root results judge-root judge-file-prefix)
  (utils/print-dashes)
  (print)
  # summarize results
  (summarize results))

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (def proj-root
    (path/join (os/getenv "HOME")
               "src" "judge-gen"))

  (def src-root
    (path/join proj-root "judge-gen"))

  (handle-one {:judge-dir-name "judge"
               :judge-file-prefix "judge-"
               :proj-root proj-root
               :src-root src-root})

  )

(defn main
  [& args]
  (def opts (args-runner/parse))
  (unless opts
    (os/exit 1))
  (cond
    (opts :version)
    (print "jg-runner alpha")
    #
    (handle-one opts)
    true))
