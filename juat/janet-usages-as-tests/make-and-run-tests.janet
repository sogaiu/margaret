(import ./to-test :as t)

###########################################################################

(def file-ext
  ".janet")

(def test-file-ext
  ".juat")

(defn make-execute-command
  [filepath]
  ["janet"
   # this prevents any contained `main` functions from executing
   "-e" (string "(dofile `" filepath "`)")])

###########################################################################

(def sep
  (if (= :windows (os/which))
    "\\"
    "/"))

(defn parse-path
  [path sep]
  (def revcap-peg
    ~(sequence (capture (sequence (choice (to ,sep)
                                          (thru -1))))
               (capture (thru -1))))
  (when-let [[rev-name rev-dir]
             (-?>> (string/reverse path)
                   (peg/match revcap-peg)
                   (map string/reverse))]
    [(or rev-dir "") rev-name]))

(comment

  (parse-path "/tmp/fun/my.fnl" "/")
  # =>
  ["/tmp/fun/" "my.fnl"]

  (parse-path "/my.janet" "/")
  # =>
  ["/" "my.janet"]

  (parse-path "pp.el" "/")
  # =>
  ["" "pp.el"]

  (parse-path "/" "/")
  # =>
  ["/" ""]

  (parse-path "" "/")
  # =>
  ["" ""]

  )

(defn make-tests
  [filepath]
  (def src
    (slurp filepath))
  (def test-src
    (t/rewrite-as-test-file src))
  (unless test-src
    (break :no-tests))
  (def [fdir fname]
    (parse-path filepath sep))
  (def test-filepath
    (string fdir "_" fname test-file-ext))
  (unless test-filepath
    (eprintf "test file already exists for: %p" filepath)
    (break nil))
  (spit test-filepath test-src)
  test-filepath)

(defn run-tests
  [test-filepath]
  (try
    (with [of (file/temp)]
      (with [ef (file/temp)]
        (let [ecode (os/execute (make-execute-command test-filepath)
                                :p
                                {:out of :err ef})]
          (when (not (zero? ecode))
            (eprintf "non-zero exit code: %p" ecode))
          #
          (file/flush of)
          (file/flush ef)
          (file/seek of :set 0)
          (file/seek ef :set 0)
          #
          [(file/read of :all)
           (file/read ef :all)
           ecode])))
    ([e]
      (eprintf "problem executing tests: %p" e)
      [nil nil nil])))

(defn report
  [out err]
  (when (and out
             (pos? (length out)))
    (print out)
    (print))
  (when (and err
             (pos? (length err)))
    (print "------")
    (print "stderr")
    (print "------")
    (print err)
    (print))
  # XXX: kind of awkward
  (when (and (empty? out) (empty? err))
    (print "no test output...possibly no tests")
    (print)))

(defn make-run-report
  [filepath]
  # create test source
  (def result
    (make-tests filepath))
  (unless result
    (eprintf "failed to create test file for: %p" filepath)
    (break nil))
  (when (= :no-tests result)
    (break :no-tests))
  (def test-filepath result)
  # run tests and collect output
  (def [out err ecode]
    (run-tests test-filepath))
  # print out results
  (report out err)
  # finish off
  (when (zero? ecode)
    (os/rm test-filepath)
    true))

(defn find-files-with-ext
  [dir ext]
  (def paths @[])
  (defn helper
    [a-dir]
    (each path (os/dir a-dir)
      (def sub-path
        (string a-dir sep path))
      (case (os/stat sub-path :mode)
        :directory
        (when (not= path ".git")
          (when (not (os/stat (string sub-path sep ".gitrepo")))
            (helper sub-path)))
        #
        :file
        (when (string/has-suffix? ext sub-path)
          (array/push paths sub-path)))))
  (helper dir)
  paths)

(comment

  (find-files-with-ext "." file-ext)

  )

(defn clean-end-of-path
  [path sep]
  (when (one? (length path))
    (break path))
  (if (string/has-suffix? sep path)
    (string/slice path 0 -2)
    path))

(comment

  (clean-end-of-path "hello/" "/")
  # =>
  "hello"

  (clean-end-of-path "/" "/")
  # =>
  "/"

  )

(defn main
  [& args]
  (def src-filepaths @[])
  # collect file and directory paths from args
  (each thing (slice args 1)
    (def apath
      (clean-end-of-path thing sep))
    (def stat
      (os/stat apath :mode))
    # XXX: should :link be supported?
    (cond
      (= :file stat)
      (if (string/has-suffix? file-ext apath)
        (array/push src-filepaths apath)
        (do
          (eprintf "File does not have extension: %p" file-ext)
          (os/exit 1)))
      #
      (= :directory stat)
      (array/concat src-filepaths (find-files-with-ext apath file-ext))
      #
      (do
        (eprintf "Not an ordinary file or directory: %p" apath)
        (os/exit 1))))
  # generate tests, run tests, and report
  (each path src-filepaths
    (when (= :file (os/stat path :mode))
      (print path)
      (def result (make-run-report path))
      (cond
        (= :no-tests result)
        # XXX: the 2 newlines here are cosmetic
        (eprintf "* no tests detected for: %p\n\n" path)
        #
        (nil? result)
        (do
          (eprintf "failure in: %p" path)
          (os/exit 1))
        #
        (true? result)
        true
        #
        (do
          (eprintf "Unexpected result %p for: %p" result path)
          (os/exit 1)))))
  (printf "All tests completed successfully in %d file(s)."
          (length src-filepaths)))

