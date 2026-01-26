#! /usr/bin/env janet

(comment import ./args :prefix "")
(comment import ./errors :prefix "")
(defn e/makef
  [base fmt & args]
  (merge base {:msg (string/format fmt ;args)}))

(defn e/emf
  [base fmt & args]
  (error (e/makef base fmt ;args)))

# XXX: use l/note?
(defn e/show
  [err]
  (assertf (dictionary? err) "expected dictionary but got: %n" err)
  #
  (eprintf "%s: %s" (get err :in) (get err :msg))
  (when (os/getenv "VERBOSE")
    (when-let [args (get err :args)]
      (eprint "  args:")
      (eachp [n v] args
        (eprintf "    %s: %n" n v)))
    (when-let [locals (get err :locals)]
      (eprint "  locals:")
      (eachp [n v] locals
        (eprintf "    %s: %n" n v)))
    (when-let [e (get err :e-via-try)]
      (eprintf "  e via try: %n" e))))


(comment import ./files :prefix "")
(comment import ./paths :prefix "")
(def p/sep
  (let [tos (os/which)]
    (if (or (= :windows tos) (= :mingw tos)) `\` "/")))

(defn p/clean-end-of-path
  [path a-sep]
  (when (one? (length path))
    (break path))
  (if (string/has-suffix? a-sep path)
    (string/slice path 0 -2)
    path))

(comment

  (p/clean-end-of-path "hello/" "/")
  # =>
  "hello"

  (p/clean-end-of-path "/" "/")
  # =>
  "/"

  )

(defn p/parse-path
  [path]
  (def revcap-peg
    ~(sequence (capture (sequence (choice (to (choice "/" `\`))
                                          (thru -1))))
               (capture (thru -1))))
  (when-let [[rev-name rev-dir]
             (-?>> (string/reverse path)
                   (peg/match revcap-peg)
                   (map string/reverse))]
    [(or rev-dir "") rev-name]))

(comment

  (p/parse-path "/tmp/fun/my.fnl")
  # =>
  ["/tmp/fun/" "my.fnl"]

  (p/parse-path "/my.janet")
  # =>
  ["/" "my.janet"]

  (p/parse-path "pp.el")
  # =>
  ["" "pp.el"]

  (p/parse-path "/etc/init.d")
  # =>
  ["/etc/" "init.d"]

  (p/parse-path "/")
  # =>
  ["/" ""]

  (p/parse-path "")
  # =>
  ["" ""]

  )



(defn f/is-file?
  [path]
  #
  (= :file (os/stat path :mode)))

(defn f/find-files
  [dir &opt pred]
  (default pred identity)
  (def paths @[])
  (defn helper
    [a-dir]
    (each path (os/dir a-dir)
      (def sub-path (string a-dir p/sep path))
      (case (os/stat sub-path :mode)
        :directory
        (when (not= path ".git")
          (helper sub-path))
        #
        :file
        (when (pred sub-path)
          (array/push paths sub-path)))))
  (helper dir)
  paths)

(comment

  (f/find-files "." |(string/has-suffix? ".janet" $))

  )

(defn f/has-janet-shebang?
  [path]
  (with [f (file/open path)]
    (def first-line (file/read f :line))
    (when first-line
      (and (string/find "env" first-line)
           (string/find "janet" first-line)))))

(defn f/collect-paths
  [includes &opt pred]
  (default pred identity)
  (def filepaths @[])
  # collect file and directory paths
  (each thing includes
    (def apath (p/clean-end-of-path thing p/sep))
    (def mode (os/stat apath :mode))
    # XXX: should :link be supported?
    (cond
      (= :file mode)
      (array/push filepaths apath)
      #
      (= :directory mode)
      (array/concat filepaths (f/find-files apath pred))))
  #
  filepaths)


(comment import ./settings :prefix "")
(comment import ./errors :prefix "")


(def s/conf-file ".niche.jdn")

(defn s/parse-conf-file
  [s/conf-file]
  (def b {:in "parse-conf-file" :args {:conf-file s/conf-file}})
  #
  (let [src (try (slurp s/conf-file)
              ([e] (e/emf (merge b {:e-via-try e})
                          "failed to slurp: %s" s/conf-file)))
        cnf (try (parse src)
              ([e] (e/emf (merge b {:e-via-try e})
                          "failed to parse: %s" s/conf-file)))]
    (when (not cnf)
      (e/emf b "failed to load: %s" s/conf-file))
    #
    (when (not (dictionary? cnf))
      (e/emf b "expected dictionary in conf, got: %s" (type cnf)))
    #
    [(array ;(get cnf :includes @[]))
     (array ;(get cnf :excludes @[]))]))



(defn a/parse-args
  [args]
  (def b {:in "parse-args" :args {:args args}})
  #
  (def the-args (array ;args))
  #
  (def head (get the-args 0))
  #
  (when (or (= head "-h") (= head "--help")
            # might have been invoked with no paths in repository root
            (and (not head) (not (f/is-file? s/conf-file))))
    (break @{:show-help true}))
  #
  (when (or (= head "-v") (= head "--version")
            # might have been invoked with no paths in repository root
            (and (not head) (not (f/is-file? s/conf-file))))
    (break @{:show-version true}))
  #
  (def opts
    (if head
      (if-not (and (string/has-prefix? "{" head)
                   (string/has-suffix? "}" head))
        @{}
        (let [parsed
              (try (parse (string "@" head))
                ([e] (e/emf (merge b {:e-via-try e})
                            "failed to parse options: %n" head)))]
          (when (not (and parsed (table? parsed)))
            (e/emf b "expected table but found: %s" (type parsed)))
          #
          (array/remove the-args 0)
          parsed))
      @{}))
  #
  (def [includes excludes]
    (cond
      # paths on command line take precedence over conf file
      (not (empty? the-args))
      [the-args @[]]
      # conf file
      (f/is-file? s/conf-file)
      (s/parse-conf-file s/conf-file)
      #
      (e/emf b "unexpected result parsing args: %n" args)))
  #
  (setdyn :test/color?
          (not (or (os/getenv "NO_COLOR") (get opts :no-color))))
  #
  (defn merge-indexed
    [left right]
    (default left [])
    (default right [])
    (distinct [;left ;right]))
  #
  (merge opts
         {:includes (merge-indexed includes (get opts :includes))
          :excludes (merge-indexed excludes (get opts :excludes))}))

(comment

  (def old-value (dyn :test/color?))

  (setdyn :test/color? false)

  (a/parse-args ["src/main.janet"])
  # =>
  @{:excludes @[]
    :includes @["src/main.janet"]}

  (a/parse-args ["-h"])
  # =>
  @{:show-help true}

  (a/parse-args ["{:overwrite true}" "src/main.janet"])
  # =>
  @{:excludes @[]
    :includes @["src/main.janet"]
    :overwrite true}

  (a/parse-args [`{:excludes ["src/args.janet"]}` "src/main.janet"])
  # =>
  @{:excludes @["src/args.janet"]
    :includes @["src/main.janet"]}

  (setdyn :test/color? old-value)

  )


(comment import ./commands :prefix "")
(comment import ./errors :prefix "")

(comment import ./files :prefix "")

(comment import ./log :prefix "")
# :w - warn
# :e - error
# :i - info
# :o - output

(def l/d-table
  {:w eprin
   :e eprin
   :i eprin
   :o prin})

(defn l/note
  [flavor & args]
  (def disp-table (dyn :d-table l/d-table))
  (def dispatch-fn (get disp-table flavor))
  (assertf dispatch-fn "unknown flavor: %n" flavor)
  #
  (dispatch-fn ;args))

(def l/df-table
  {:w eprinf
   :e eprinf
   :i eprinf
   :o prinf})

(defn l/notef
  [flavor & args]
  (def disp-table (dyn :df-table l/df-table))
  (def dispatch-fn (get disp-table flavor))
  (assertf dispatch-fn "unknown flavor: %n" flavor)
  #
  (dispatch-fn ;args))

(def l/dn-table
  {:w eprint
   :e eprint
   :i eprint
   :o print})

(defn l/noten
  [flavor & args]
  (def disp-table (dyn :dn-table l/dn-table))
  (def dispatch-fn (get disp-table flavor))
  (assertf dispatch-fn "unknown flavor: %n" flavor)
  #
  (dispatch-fn ;args))

(def l/dnf-table
  {:w eprintf
   :e eprintf
   :i eprintf
   :o printf})

(defn l/notenf
  [flavor & args]
  (def disp-table (dyn :dnf-table l/dnf-table))
  (def dispatch-fn (get disp-table flavor))
  (assertf dispatch-fn "unknown flavor: %n" flavor)
  #
  (dispatch-fn ;args))

########################################################################

(def l/ignore-table
  {:w (fn :w [& _] nil)
   :e (fn :e [& _] nil)
   :i (fn :i [& _] nil)
   :o (fn :o [& _] nil)})

(defn l/set-d-tables!
  [{:d d :df df :dn dn :dnf dnf}]
  (default d l/d-table)
  (default df l/df-table)
  (default dn l/dn-table)
  (default dnf l/dnf-table)
  (setdyn :d-table d)
  (setdyn :df-table df)
  (setdyn :dn-table dn)
  (setdyn :dnf-table dnf))

(defn l/clear-d-tables!
  []
  (l/set-d-tables! {:d l/ignore-table
                  :df l/ignore-table
                  :dn l/ignore-table
                  :dnf l/ignore-table}))

(defn l/reset-d-tables!
  []
  (l/set-d-tables! {}))


(comment import ./output :prefix "")
(comment import ./log :prefix "")


(def o/color-table
  {:black 30
   :blue 34
   :cyan 36
   :green 32
   :magenta 35
   :red 31
   :white 37
   :yellow 33})

(defn o/color-msg
  [msg color]
  (def color-num (get o/color-table color))
  (assertf color-num "unknown color: %n" color)
  #
  (if (dyn :test/color?)
    (string "\e[" color-num "m" msg "\e[0m")
    msg))

(defn o/prin-color
  [msg color]
  (l/note :o (o/color-msg msg color)))

(comment

  (def [ok? result] (protect (o/prin-color "hey" :chartreuse)))
  # =>
  [false "unknown color: :chartreuse"]

  )

(defn o/separator
  [&opt str n]
  (default str "-")
  (default n 60)
  (string/repeat str n))

(defn o/prin-sep
  [&opt str n]
  (default str "-")
  (default n 60)
  (l/note :o (o/separator str n)))

(defn o/prin-form
  [form &opt color]
  (def buf @"")
  (with-dyns [:out buf]
    (printf "%m" form))
  (def msg (string/trimr buf))
  (def m-buf
    (buffer ":\n"
            (if color (o/color-msg msg color) msg)))
  (l/note :o m-buf))

(defn o/color-form
  [form]
  (def leader
    (if (or (array? form) (table? form) (buffer? form))
      "@" ""))
  (def fmt-str
    (if (dyn :test/color?) "%M" "%m"))
  (def buf @"")
  (cond
    (indexed? form)
    (do
      (buffer/push buf leader "[\n")
      (each f form
        (with-dyns [:out buf] (printf fmt-str f)))
      (buffer/push buf "]"))
    #
    (dictionary? form)
    (do
      (buffer/push buf leader "{\n")
      (eachp [k v] form
        (with-dyns [:out buf]
          (printf fmt-str k)
          (printf fmt-str v)))
      (buffer/push buf "}"))
    #
    (with-dyns [:out buf] (printf fmt-str form)))
  #
  buf)

(defn o/color-ratio
  [num denom]
  (buffer (if (not= num denom)
            (o/color-msg num :red)
            (o/color-msg num :green))
          "/"
          (o/color-msg denom :green)))

(defn o/report-fails
  [{:num-tests total-tests :fails fails}]
  (var i 0)
  (each f fails
    (def {:test-value test-value
          :expected-value expected-value
          :line-no line-no
          :test-form test-form} f)
    (++ i)
    #
    (l/noten :o)
    (l/note :o "[")
    (o/prin-color i :cyan)
    (l/note :o "]")
    (l/noten :o)
    #
    (l/noten :o)
    (o/prin-color "failed:" :yellow)
    (l/noten :o)
    (o/prin-color (string/format "line %d" line-no) :red)
    (l/noten :o)
    #
    (l/noten :o)
    (o/prin-color "form" :yellow)
    (o/prin-form test-form)
    (l/noten :o)
    #
    (l/noten :o)
    (o/prin-color "expected" :yellow)
    (o/prin-form expected-value)
    (l/noten :o)
    #
    (l/noten :o)
    (o/prin-color "actual" :yellow)
    (o/prin-form test-value :blue)
    (l/noten :o)))

(defn o/report-std
  [content title]
  (when (and content (pos? (length content)))
    (def sepa (o/separator "-" (length title)))
    (l/noten :o sepa)
    (l/noten :o title)
    (l/noten :o sepa)
    (l/noten :o content)))

(defn o/report
  [test-results out err]
  (when (not (empty? (get test-results :fails)))
    (l/noten :o)
    (o/prin-sep)
    #
    (o/report-fails test-results)
    #
    (when (and out (pos? (length out)))
      (l/noten :o)
      (o/report-std out "stdout"))
    #
    (when (and err (pos? (length err)))
      (l/noten :o)
      (o/report-std err "stderr"))
    #
    (when (and (zero? (get test-results :num-tests))
               (empty? out)
               (empty? err))
      (l/noten :o)
      (l/noten :o "no test output...possibly no tests"))
    #
    (o/prin-sep)
    (l/noten :o)))


(comment import ./rewrite :prefix "")
(comment import ./errors :prefix "")

(comment import ./jipper :prefix "")
# bl - begin line
# bc - begin column
# el - end line
# ec - end column
(defn j/make-attrs
  [& items]
  (zipcoll [:bl :bc :el :ec]
           items))

(defn j/atom-node
  [node-type peg-form]
  ~(cmt (capture (sequence (line) (column)
                           ,peg-form
                           (line) (column)))
        ,|[node-type (j/make-attrs ;(slice $& 0 -2)) (last $&)]))

(defn j/reader-macro-node
  [node-type sigil]
  ~(cmt (capture (sequence (line) (column)
                           ,sigil
                           (any :non-form)
                           :form
                           (line) (column)))
        ,|[node-type (j/make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
           ;(slice $& 2 -4)]))

(defn j/collection-node
  [node-type open-delim close-delim]
  # to avoid issues when transforming this file
  (def replace_ (symbol "replace"))
  ~(cmt
     (capture
       (sequence
         (line) (column)
         ,open-delim
         (any :input)
         (choice ,close-delim
                 (error
                   (,replace_ (sequence (line) (column))
                              ,|(string/format
                                  "line: %p column: %p missing %p for %p"
                                  $0 $1 close-delim node-type))))
         (line) (column)))
     ,|[node-type (j/make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
        ;(slice $& 2 -4)]))

(def j/loc-grammar
  ~@{:main (sequence (line) (column)
                     (some :input)
                     (line) (column))
     #
     :input (choice :non-form
                    :form)
     #
     :non-form (choice :whitespace
                       :comment)
     #
     :whitespace ,(j/atom-node :whitespace
                             '(choice (some (set " \0\f\t\v"))
                                      (choice "\r\n"
                                              "\r"
                                              "\n")))
     # :whitespace
     # (cmt (capture (sequence (line) (column)
     #                         (choice (some (set " \0\f\t\v"))
     #                                 (choice "\r\n"
     #                                         "\r"
     #                                         "\n"))
     #                         (line) (column)))
     #      ,|[:whitespace (make-attrs ;(slice $& 0 -2)) (last $&)])
     #
     :comment ,(j/atom-node :comment
                          '(sequence "#"
                                     (any (if-not (set "\r\n") 1))))
     #
     :form (choice # reader macros
                   :fn
                   :quasiquote
                   :quote
                   :splice
                   :unquote
                   # collections
                   :array
                   :bracket-array
                   :tuple
                   :bracket-tuple
                   :table
                   :struct
                   # atoms
                   :number
                   :constant
                   :buffer
                   :string
                   :long-buffer
                   :long-string
                   :keyword
                   :symbol)
     #
     :fn ,(j/reader-macro-node :fn "|")
     # :fn (cmt (capture (sequence (line) (column)
     #                             "|"
     #                             (any :non-form)
     #                             :form
     #                             (line) (column)))
     #          ,|[:fn (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
     #             ;(slice $& 2 -4)])
     #
     :quasiquote ,(j/reader-macro-node :quasiquote "~")
     #
     :quote ,(j/reader-macro-node :quote "'")
     #
     :splice ,(j/reader-macro-node :splice ";")
     #
     :unquote ,(j/reader-macro-node :unquote ",")
     #
     :array ,(j/collection-node :array "@(" ")")
     # :array
     # (cmt
     #   (capture
     #     (sequence
     #       (line) (column)
     #       "@("
     #       (any :input)
     #       (choice ")"
     #               (error
     #                 (replace (sequence (line) (column))
     #                          ,|(string/format
     #                              "line: %p column: %p missing %p for %p"
     #                              $0 $1 ")" :array))))
     #       (line) (column)))
     #   ,|[:array (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
     #      ;(slice $& 2 -4)])
     #
     :tuple ,(j/collection-node :tuple "(" ")")
     #
     :bracket-array ,(j/collection-node :bracket-array "@[" "]")
     #
     :bracket-tuple ,(j/collection-node :bracket-tuple "[" "]")
     #
     :table ,(j/collection-node :table "@{" "}")
     #
     :struct ,(j/collection-node :struct "{" "}")
     #
     :number ,(j/atom-node :number
                         ~(drop (sequence (cmt (capture (some :num-char))
                                               ,scan-number)
                                          (opt (sequence ":" (range "AZ" "az"))))))
     #
     :num-char (choice (range "09" "AZ" "az")
                       (set "&+-._"))
     #
     :constant ,(j/atom-node :constant
                           '(sequence (choice "false" "nil" "true")
                                      (not :name-char)))
     #
     :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                        (set "!$%&*+-./:<?=>@^_"))
     #
     :buffer ,(j/atom-node :buffer
                         '(sequence `@"`
                                    (any (choice :escape
                                                 (if-not "\"" 1)))
                                    `"`))
     #
     :escape (sequence "\\"
                       (choice (set `"'0?\abefnrtvz`)
                               (sequence "x" (2 :h))
                               (sequence "u" (4 :h))
                               (sequence "U" (6 :h))
                               (error (constant "bad escape"))))
     #
     :string ,(j/atom-node :string
                         '(sequence `"`
                                    (any (choice :escape
                                                 (if-not "\"" 1)))
                                    `"`))
     #
     :long-string ,(j/atom-node :long-string
                              :long-bytes)
     #
     :long-bytes {:main (drop (sequence :open
                                        (any (if-not :close 1))
                                        :close))
                  :open (capture :delim :n)
                  :delim (some "`")
                  :close (cmt (sequence (not (look -1 "`"))
                                        (backref :n)
                                        (capture (backmatch :n)))
                              ,=)}
     #
     :long-buffer ,(j/atom-node :long-buffer
                              '(sequence "@" :long-bytes))
     #
     :keyword ,(j/atom-node :keyword
                          '(sequence ":"
                                     (any :name-char)))
     #
     :symbol ,(j/atom-node :symbol
                         '(some :name-char))
     })

(comment

  (get (peg/match j/loc-grammar " ") 2)
  # =>
  '(:whitespace @{:bc 1 :bl 1 :ec 2 :el 1} " ")

  (get (peg/match j/loc-grammar "true?") 2)
  # =>
  '(:symbol @{:bc 1 :bl 1 :ec 6 :el 1} "true?")

  (get (peg/match j/loc-grammar "nil?") 2)
  # =>
  '(:symbol @{:bc 1 :bl 1 :ec 5 :el 1} "nil?")

  (get (peg/match j/loc-grammar "false?") 2)
  # =>
  '(:symbol @{:bc 1 :bl 1 :ec 7 :el 1} "false?")

  (get (peg/match j/loc-grammar "# hi there") 2)
  # =>
  '(:comment @{:bc 1 :bl 1 :ec 11 :el 1} "# hi there")

  (get (peg/match j/loc-grammar "1_000_000") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 10 :el 1} "1_000_000")

  (get (peg/match j/loc-grammar "8.3") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 4 :el 1} "8.3")

  (get (peg/match j/loc-grammar "1e2") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 4 :el 1} "1e2")

  (get (peg/match j/loc-grammar "0xfe") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 5 :el 1} "0xfe")

  (get (peg/match j/loc-grammar "2r01") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 5 :el 1} "2r01")

  (get (peg/match j/loc-grammar "3r101&01") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 9 :el 1} "3r101&01")

  (get (peg/match j/loc-grammar "2:u") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 4 :el 1} "2:u")

  (get (peg/match j/loc-grammar "-8:s") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 5 :el 1} "-8:s")

  (get (peg/match j/loc-grammar "1e2:n") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 6 :el 1} "1e2:n")

  (get (peg/match j/loc-grammar "printf") 2)
  # =>
  '(:symbol @{:bc 1 :bl 1 :ec 7 :el 1} "printf")

  (get (peg/match j/loc-grammar ":smile") 2)
  # =>
  '(:keyword @{:bc 1 :bl 1 :ec 7 :el 1} ":smile")

  (get (peg/match j/loc-grammar `"fun"`) 2)
  # =>
  '(:string @{:bc 1 :bl 1 :ec 6 :el 1} "\"fun\"")

  (get (peg/match j/loc-grammar "``long-fun``") 2)
  # =>
  '(:long-string @{:bc 1 :bl 1 :ec 13 :el 1} "``long-fun``")

  (get (peg/match j/loc-grammar "@``long-buffer-fun``") 2)
  # =>
  '(:long-buffer @{:bc 1 :bl 1 :ec 21 :el 1} "@``long-buffer-fun``")

  (get (peg/match j/loc-grammar `@"a buffer"`) 2)
  # =>
  '(:buffer @{:bc 1 :bl 1 :ec 12 :el 1} "@\"a buffer\"")

  (get (peg/match j/loc-grammar "@[8]") 2)
  # =>
  '(:bracket-array @{:bc 1 :bl 1
                     :ec 5 :el 1}
                   (:number @{:bc 3 :bl 1
                              :ec 4 :el 1} "8"))

  (get (peg/match j/loc-grammar "@{:a 1}") 2)
  # =>
  '(:table @{:bc 1 :bl 1
             :ec 8 :el 1}
           (:keyword @{:bc 3 :bl 1
                       :ec 5 :el 1} ":a")
           (:whitespace @{:bc 5 :bl 1
                          :ec 6 :el 1} " ")
           (:number @{:bc 6 :bl 1
                      :ec 7 :el 1} "1"))

  (get (peg/match j/loc-grammar "~x") 2)
  # =>
  '(:quasiquote @{:bc 1 :bl 1
                  :ec 3 :el 1}
                (:symbol @{:bc 2 :bl 1
                           :ec 3 :el 1} "x"))

  (get (peg/match j/loc-grammar "' '[:a :b]") 2)
  # =>
  '(:quote @{:bc 1 :bl 1
             :ec 11 :el 1}
           (:whitespace @{:bc 2 :bl 1
                          :ec 3 :el 1} " ")
           (:quote @{:bc 3 :bl 1
                     :ec 11 :el 1}
                   (:bracket-tuple @{:bc 4 :bl 1
                                     :ec 11 :el 1}
                                   (:keyword @{:bc 5 :bl 1
                                               :ec 7 :el 1} ":a")
                                   (:whitespace @{:bc 7 :bl 1
                                                  :ec 8 :el 1} " ")
                                   (:keyword @{:bc 8 :bl 1
                                               :ec 10 :el 1} ":b"))))

  )

(def j/loc-top-level-ast
  (put (table ;(kvs j/loc-grammar))
       :main ~(sequence (line) (column)
                        :input
                        (line) (column))))

(defn j/par
  [src &opt start single]
  (default start 0)
  (if single
    (if-let [[bl bc tree el ec]
             (peg/match j/loc-top-level-ast src start)]
      @[:code (j/make-attrs bl bc el ec) tree]
      @[:code])
    (if-let [captures (peg/match j/loc-grammar src start)]
      (let [[bl bc] (slice captures 0 2)
            [el ec] (slice captures -3)
            trees (array/slice captures 2 -3)]
        (array/insert trees 0
                      :code (j/make-attrs bl bc el ec)))
      @[:code])))

# XXX: backward compatibility
(def j/ast j/par)

(comment

  (j/par "(+ 1 1)")
  # =>
  '@[:code @{:bc 1 :bl 1
             :ec 8 :el 1}
     (:tuple @{:bc 1 :bl 1
               :ec 8 :el 1}
             (:symbol @{:bc 2 :bl 1
                        :ec 3 :el 1} "+")
             (:whitespace @{:bc 3 :bl 1
                            :ec 4 :el 1} " ")
             (:number @{:bc 4 :bl 1
                        :ec 5 :el 1} "1")
             (:whitespace @{:bc 5 :bl 1
                            :ec 6 :el 1} " ")
             (:number @{:bc 6 :bl 1
                        :ec 7 :el 1} "1"))]

  )

(defn j/gen*
  [an-ast buf]
  (case (first an-ast)
    :code
    (each elt (drop 2 an-ast)
      (j/gen* elt buf))
    #
    :buffer
    (buffer/push-string buf (in an-ast 2))
    :comment
    (buffer/push-string buf (in an-ast 2))
    :constant
    (buffer/push-string buf (in an-ast 2))
    :keyword
    (buffer/push-string buf (in an-ast 2))
    :long-buffer
    (buffer/push-string buf (in an-ast 2))
    :long-string
    (buffer/push-string buf (in an-ast 2))
    :number
    (buffer/push-string buf (in an-ast 2))
    :string
    (buffer/push-string buf (in an-ast 2))
    :symbol
    (buffer/push-string buf (in an-ast 2))
    :whitespace
    (buffer/push-string buf (in an-ast 2))
    #
    :array
    (do
      (buffer/push-string buf "@(")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf))
      (buffer/push-string buf ")"))
    :bracket-array
    (do
      (buffer/push-string buf "@[")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf))
      (buffer/push-string buf "]"))
    :bracket-tuple
    (do
      (buffer/push-string buf "[")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf))
      (buffer/push-string buf "]"))
    :tuple
    (do
      (buffer/push-string buf "(")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf))
      (buffer/push-string buf ")"))
    :struct
    (do
      (buffer/push-string buf "{")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf))
      (buffer/push-string buf "}"))
    :table
    (do
      (buffer/push-string buf "@{")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf))
      (buffer/push-string buf "}"))
    #
    :fn
    (do
      (buffer/push-string buf "|")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf)))
    :quasiquote
    (do
      (buffer/push-string buf "~")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf)))
    :quote
    (do
      (buffer/push-string buf "'")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf)))
    :splice
    (do
      (buffer/push-string buf ";")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf)))
    :unquote
    (do
      (buffer/push-string buf ",")
      (each elt (drop 2 an-ast)
        (j/gen* elt buf)))
    ))

(defn j/gen
  [an-ast]
  (let [buf @""]
    (j/gen* an-ast buf)
    # XXX: leave as buffer?
    (string buf)))

# XXX: backward compatibility
(def j/code j/gen)

(comment

  (j/gen
    [:code])
  # =>
  ""

  (j/gen
    '(:whitespace @{:bc 1 :bl 1
                    :ec 2 :el 1} " "))
  # =>
  " "

  (j/gen
    '(:buffer @{:bc 1 :bl 1
                :ec 12 :el 1} "@\"a buffer\""))
  # =>
  `@"a buffer"`

  (j/gen
    '@[:code @{:bc 1 :bl 1
               :ec 8 :el 1}
       (:tuple @{:bc 1 :bl 1
                 :ec 8 :el 1}
               (:symbol @{:bc 2 :bl 1
                          :ec 3 :el 1} "+")
               (:whitespace @{:bc 3 :bl 1
                              :ec 4 :el 1} " ")
               (:number @{:bc 4 :bl 1
                          :ec 5 :el 1} "1")
               (:whitespace @{:bc 5 :bl 1
                              :ec 6 :el 1} " ")
               (:number @{:bc 6 :bl 1
                          :ec 7 :el 1} "1"))])
  # =>
  "(+ 1 1)"

  )

(comment

  (def src "{:x  :y \n :z  [:a  :b    :c]}")

  (j/gen (j/par src))
  # =>
  src

  )

(comment

  (comment

    (let [src (slurp (string (os/getenv "HOME")
                             "/src/janet/src/boot/boot.janet"))]
      (= (string src)
         (j/gen (j/par src))))

    )

  )

########################################################################

# based on code by corasaurus-hex

# `slice` doesn't necessarily preserve the input type

# XXX: differs from clojure's behavior
#      e.g. (butlast [:a]) would yield nil(?!) in clojure
(defn j/butlast
  [indexed]
  (if (empty? indexed)
    nil
    (if (tuple? indexed)
      (tuple/slice indexed 0 -2)
      (array/slice indexed 0 -2))))

(comment

  (j/butlast @[:a :b :c])
  # =>
  @[:a :b]

  (j/butlast [:a])
  # =>
  []

  )

(defn j/rest
  [indexed]
  (if (empty? indexed)
    nil
    (if (tuple? indexed)
      (tuple/slice indexed 1 -1)
      (array/slice indexed 1 -1))))

(comment

  (j/rest [:a :b :c])
  # =>
  [:b :c]

  (j/rest @[:a])
  # =>
  @[]

  )

# XXX: can pass in array - will get back tuple
(defn j/tuple-push
  [tup x & xs]
  (if tup
    [;tup x ;xs]
    [x ;xs]))

(comment

  (j/tuple-push [:a :b] :c)
  # =>
  [:a :b :c]

  (j/tuple-push nil :a)
  # =>
  [:a]

  (j/tuple-push @[] :a)
  # =>
  [:a]

  )

(defn j/to-entries
  [val]
  (if (dictionary? val)
    (pairs val)
    val))

(comment

  (sort (j/to-entries {:a 1 :b 2}))
  # =>
  @[[:a 1] [:b 2]]

  (j/to-entries {})
  # =>
  @[]

  (j/to-entries @{:a 1})
  # =>
  @[[:a 1]]

  # XXX: leaving non-dictionaries alone and passing through...
  #      is this desirable over erroring?
  (j/to-entries [:a :b :c])
  # =>
  [:a :b :c]

  )

# XXX: when xs is empty, "all" becomes nil
(defn j/first-rest-maybe-all
  [xs]
  (if (or (nil? xs) (empty? xs))
    [nil nil nil]
    [(first xs) (j/rest xs) xs]))

(comment

  (j/first-rest-maybe-all [:a :b])
  # =>
  [:a [:b] [:a :b]]

  (j/first-rest-maybe-all @[:a])
  # =>
  [:a @[] @[:a]]

  (j/first-rest-maybe-all [])
  # =>
  [nil nil nil]

  # XXX: is this what we want?
  (j/first-rest-maybe-all nil)
  # =>
  [nil nil nil]

  )

########################################################################

(defn j/zipper
  ``
  Returns a new zipper consisting of two elements:

  * `a-root` - the passed in root node.
  * `state` - table of info about node's z-location in the tree with keys:
    * `:ls` - left siblings
    * `:pnodes` - path of nodes from root to current z-location
    * `:pstate` - parent node's state
    * `:rs` - right siblings
    * `:changed?` - indicates whether "editing" has occured

  `state` has a prototype table with four functions:

  * :branch? - fn that tests if a node is a branch (has children)
  * :children - fn that returns the child nodes for the given branch.
  * :make-node - fn that takes a node + children and returns a new branch
    node with the same.
  * :make-state - fn for creating a new state
  ``
  [a-root branch?-fn children-fn make-node-fn]
  #
  (defn make-state_
    [&opt ls_ rs_ pnodes_ pstate_ changed?_]
    (table/setproto @{:ls ls_
                      :pnodes pnodes_
                      :pstate pstate_
                      :rs rs_
                      :changed? changed?_}
                    @{:branch? branch?-fn
                      :children children-fn
                      :make-node make-node-fn
                      :make-state make-state_}))
  #
  [a-root (make-state_)])

(comment

  # XXX

  )

# ds - data structure
(defn j/ds-zip
  ``
  Returns a zipper for nested data structures (tuple/array/table/struct),
  given a root data structure.
  ``
  [ds]
  (j/zipper ds
          |(or (dictionary? $) (indexed? $))
          j/to-entries
          (fn [p xs] xs)))

(comment

  (def a-node
    [:x [:y :z]])

  (def [the-node the-state]
    (j/ds-zip a-node))

  the-node
  # =>
  a-node

  # merge is used to "remove" the prototype table of `st`
  (merge {} the-state)
  # =>
  @{}

  )

(defn j/node
  "Returns the node at `zloc`."
  [zloc]
  (get zloc 0))

(comment

  (j/node (j/ds-zip [:a :b [:x :y]]))
  # =>
  [:a :b [:x :y]]

  )

(defn j/state
  "Returns the state for `zloc`."
  [zloc]
  (get zloc 1))

(comment

  # merge is used to "remove" the prototype table of `st`
  (merge {}
         (-> (j/ds-zip [:a [:b [:x :y]]])
             j/state))
  # =>
  @{}

  )

(defn j/branch?
  ``
  Returns true if the node at `zloc` is a branch.
  Returns false otherwise.
  ``
  [zloc]
  (((j/state zloc) :branch?) (j/node zloc)))

(comment

  (j/branch? (j/ds-zip [:a :b [:x :y]]))
  # =>
  true

  )

(defn j/children
  ``
  Returns children for a branch node at `zloc`.
  Otherwise throws an error.
  ``
  [zloc]
  (if (j/branch? zloc)
    (((j/state zloc) :children) (j/node zloc))
    (error "Called `children` on a non-branch zloc")))

(comment

  (j/children (j/ds-zip [:a :b [:x :y]]))
  # =>
  [:a :b [:x :y]]

  )

(defn j/make-state
  ``
  Convenience function for calling the :make-state function for `zloc`.
  ``
  [zloc &opt ls rs pnodes pstate changed?]
  (((j/state zloc) :make-state) ls rs pnodes pstate changed?))

(comment

  # merge is used to "remove" the prototype table of `st`
  (merge {}
         (j/make-state (j/ds-zip [:a :b [:x :y]])))
  # =>
  @{}

  )

(defn j/down
  ``
  Moves down the tree, returning the leftmost child z-location of
  `zloc`, or nil if there are no children.
  ``
  [zloc]
  (when (j/branch? zloc)
    (let [[z-node st] zloc
          [k rest-kids kids]
          (j/first-rest-maybe-all (j/children zloc))]
      (when kids
        [k
         (j/make-state zloc
                     []
                     rest-kids
                     (if (not (empty? st))
                       (j/tuple-push (get st :pnodes) z-node)
                       [z-node])
                     st
                     (get st :changed?))]))))

(comment

  (j/node (j/down (j/ds-zip [:a :b [:x :y]])))
  # =>
  :a

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/branch?)
  # =>
  false

  (try
    (-> (j/ds-zip [:a])
        j/down
        j/children)
    ([e] e))
  # =>
  "Called `children` on a non-branch zloc"

  (deep=
    #
    (merge {}
           (-> [:a [:b [:x :y]]]
               j/ds-zip
               j/down
               j/state))
    #
    '@{:ls ()
       :pnodes ((:a (:b (:x :y))))
       :pstate @{}
       :rs ((:b (:x :y)))})
  # =>
  true

  )

(defn j/right
  ``
  Returns the z-location of the right sibling of the node
  at `zloc`, or nil if there is no such sibling.
  ``
  [zloc]
  (let [[z-node st] zloc
        {:ls ls :rs rs} st
        [r rest-rs rs] (j/first-rest-maybe-all rs)]
    (when (and (not (empty? st)) rs)
      [r
       (j/make-state zloc
                   (j/tuple-push ls z-node)
                   rest-rs
                   (get st :pnodes)
                   (get st :pstate)
                   (get st :changed?))])))

(comment

  (-> (j/ds-zip [:a :b])
      j/down
      j/right
      j/node)
  # =>
  :b

  (-> (j/ds-zip [:a])
      j/down
      j/right)
  # =>
  nil

  )

(defn j/make-node
  ``
  Returns a branch node, given `zloc`, `a-node` and `kids`.
  ``
  [zloc a-node kids]
  (((j/state zloc) :make-node) a-node kids))

(comment

  (j/make-node (j/ds-zip [:a :b [:x :y]])
             [:a :b] [:x :y])
  # =>
  [:x :y]

  )

(defn j/up
  ``
  Moves up the tree, returning the parent z-location of `zloc`,
  or nil if at the root z-location.
  ``
  [zloc]
  (let [[z-node st] zloc
        {:ls ls
         :pnodes pnodes
         :pstate pstate
         :rs rs
         :changed? changed?} st]
    (when pnodes
      (let [pnode (last pnodes)]
        (if changed?
          [(j/make-node zloc pnode [;ls z-node ;rs])
           (j/make-state zloc
                       (get pstate :ls)
                       (get pstate :rs)
                       (get pstate :pnodes)
                       (get pstate :pstate)
                       true)]
          [pnode pstate])))))

(comment

  (def m-zip
    (j/ds-zip [:a :b [:x :y]]))

  (deep=
    (-> m-zip
        j/down
        j/up)
    m-zip)
  # =>
  true

  (deep=
    (-> m-zip
        j/down
        j/right
        j/right
        j/down
        j/up
        j/up)
    m-zip)
  # =>
  true

  )

# XXX: used by `root` and `df-next`
(defn j/end?
  "Returns true if `zloc` represents the end of a depth-first walk."
  [zloc]
  (= :end (j/state zloc)))

(defn j/root
  ``
  Moves all the way up the tree for `zloc` and returns the node at
  the root z-location.
  ``
  [zloc]
  (if (j/end? zloc)
    (j/node zloc)
    (if-let [p (j/up zloc)]
      (j/root p)
      (j/node zloc))))

(comment

  (def a-zip
    (j/ds-zip [:a :b [:x :y]]))

  (j/node a-zip)
  # =>
  (-> a-zip
      j/down
      j/right
      j/right
      j/down
      j/root)

  )

(defn j/df-next
  ``
  Moves to the next z-location, depth-first.  When the end is
  reached, returns a special z-location detectable via `end?`.
  Does not move if already at the end.
  ``
  [zloc]
  #
  (defn recur
    [a-loc]
    (if (j/up a-loc)
      (or (j/right (j/up a-loc))
          (recur (j/up a-loc)))
      [(j/node a-loc) :end]))
  #
  (if (j/end? zloc)
    zloc
    (or (and (j/branch? zloc) (j/down zloc))
        (j/right zloc)
        (recur zloc))))

(comment

  (def a-zip
    (j/ds-zip [:a :b [:x]]))

  (j/node (j/df-next a-zip))
  # =>
  :a

  (-> a-zip
      j/df-next
      j/df-next
      j/node)
  # =>
  :b

  (-> a-zip
      j/df-next
      j/df-next
      j/df-next
      j/df-next
      j/df-next
      j/end?)
  # =>
  true

  )

(defn j/replace
  "Replaces existing node at `zloc` with `a-node`, without moving."
  [zloc a-node]
  (let [[_ st] zloc]
    [a-node
     (j/make-state zloc
                 (get st :ls)
                 (get st :rs)
                 (get st :pnodes)
                 (get st :pstate)
                 true)]))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      (j/replace :w)
      j/root)
  # =>
  [:w :b [:x :y]]

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/right
      j/right
      j/down
      (j/replace :w)
      j/root)
  # =>
  [:a :b [:w :y]]

  )

(defn j/edit
  ``
  Replaces the node at `zloc` with the value of `(f node args)`,
  where `node` is the node associated with `zloc`.
  ``
  [zloc f & args]
  (j/replace zloc
           (apply f (j/node zloc) args)))

(comment

  (-> (j/ds-zip [1 2 [8 9]])
      j/down
      (j/edit inc)
      j/root)
  # =>
  [2 2 [8 9]]

  (-> (j/ds-zip [1 2 [8 9]])
      j/down
      (j/edit inc)
      j/right
      (j/edit inc)
      j/right
      j/down
      (j/edit dec)
      j/right
      (j/edit dec)
      j/root)
  # =>
  [2 3 [7 8]]

  )

(defn j/insert-child
  ``
  Inserts `child` as the leftmost child of the node at `zloc`,
  without moving.
  ``
  [zloc child]
  (j/replace zloc
           (j/make-node zloc
                      (j/node zloc)
                      [child ;(j/children zloc)])))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      (j/insert-child :c)
      j/root)
  # =>
  [:c :a :b [:x :y]]

  )

(defn j/append-child
  ``
  Appends `child` as the rightmost child of the node at `zloc`,
  without moving.
  ``
  [zloc child]
  (j/replace zloc
           (j/make-node zloc
                      (j/node zloc)
                      [;(j/children zloc) child])))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      (j/append-child :c)
      j/root)
  # =>
  [:a :b [:x :y] :c]

  )

(defn j/rightmost
  ``
  Returns the z-location of the rightmost sibling of the node at
  `zloc`, or the current node's z-location if there are none to the
  right.
  ``
  [zloc]
  (let [[z-node st] zloc
        {:ls ls :rs rs} st]
    (if (and (not (empty? st))
             (indexed? rs)
             (not (empty? rs)))
      [(last rs)
       (j/make-state zloc
                   (j/tuple-push ls z-node ;(j/butlast rs))
                   []
                   (get st :pnodes)
                   (get st :pstate)
                   (get st :changed?))]
      zloc)))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/rightmost
      j/node)
  # =>
  [:x :y]

  )

(defn j/remove
  ``
  Removes the node at `zloc`, returning the z-location that would have
  preceded it in a depth-first walk.
  Throws an error if called at the root z-location.
  ``
  [zloc]
  (let [[z-node st] zloc
        {:ls ls
         :pnodes pnodes
         :pstate pstate
         :rs rs} st]
    #
    (defn recur
      [a-zloc]
      (if-let [child (and (j/branch? a-zloc) (j/down a-zloc))]
        (recur (j/rightmost child))
        a-zloc))
    #
    (if (not (empty? st))
      (if (pos? (length ls))
        (recur [(last ls)
                (j/make-state zloc
                            (j/butlast ls)
                            rs
                            pnodes
                            pstate
                            true)])
        [(j/make-node zloc (last pnodes) rs)
         (j/make-state zloc
                     (get pstate :ls)
                     (get pstate :rs)
                     (get pstate :pnodes)
                     (get pstate :pstate)
                     true)])
      (error "Called `remove` at root"))))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/right
      j/remove
      j/node)
  # =>
  :a

  (try
    (j/remove (j/ds-zip [:a :b [:x :y]]))
    ([e] e))
  # =>
  "Called `remove` at root"

  )

(defn j/left
  ``
  Returns the z-location of the left sibling of the node
  at `zloc`, or nil if there is no such sibling.
  ``
  [zloc]
  (let [[z-node st] zloc
        {:ls ls :rs rs} st]
    (when (and (not (empty? st))
               (indexed? ls)
               (not (empty? ls)))
      [(last ls)
       (j/make-state zloc
                   (j/butlast ls)
                   [z-node ;rs]
                   (get st :pnodes)
                   (get st :pstate)
                   (get st :changed?))])))

(comment

  (-> (j/ds-zip [:a :b :c])
      j/down
      j/right
      j/right
      j/left
      j/node)
  # =>
  :b

  (-> (j/ds-zip [:a])
      j/down
      j/left)
  # =>
  nil

  )

(defn j/df-prev
  ``
  Moves to the previous z-location, depth-first.
  If already at the root, returns nil.
  ``
  [zloc]
  #
  (defn recur
    [a-zloc]
    (if-let [child (and (j/branch? a-zloc)
                        (j/down a-zloc))]
      (recur (j/rightmost child))
      a-zloc))
  #
  (if-let [left-loc (j/left zloc)]
    (recur left-loc)
    (j/up zloc)))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/right
      j/df-prev
      j/node)
  # =>
  :a

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/right
      j/right
      j/down
      j/df-prev
      j/node)
  # =>
  [:x :y]

  )

(defn j/insert-right
  ``
  Inserts `a-node` as the right sibling of the node at `zloc`,
  without moving.
  ``
  [zloc a-node]
  (let [[z-node st] zloc
        {:ls ls :rs rs} st]
    (if (not (empty? st))
      [z-node
       (j/make-state zloc
                   ls
                   [a-node ;rs]
                   (get st :pnodes)
                   (get st :pstate)
                   true)]
      (error "Called `insert-right` at root"))))

(comment

  (def a-zip
    (j/ds-zip [:a :b [:x :y]]))

  (-> a-zip
      j/down
      (j/insert-right :z)
      j/root)
  # =>
  [:a :z :b [:x :y]]

  (try
    (j/insert-right a-zip :e)
    ([e] e))
  # =>
  "Called `insert-right` at root"

  )

(defn j/insert-left
  ``
  Inserts `a-node` as the left sibling of the node at `zloc`,
  without moving.
  ``
  [zloc a-node]
  (let [[z-node st] zloc
        {:ls ls :rs rs} st]
    (if (not (empty? st))
      [z-node
       (j/make-state zloc
                   (j/tuple-push ls a-node)
                   rs
                   (get st :pnodes)
                   (get st :pstate)
                   true)]
      (error "Called `insert-left` at root"))))

(comment

  (def a-zip
    (j/ds-zip [:a :b [:x :y]]))

  (-> a-zip
      j/down
      (j/insert-left :z)
      j/root)
  # =>
  [:z :a :b [:x :y]]

  (try
    (j/insert-left a-zip :e)
    ([e] e))
  # =>
  "Called `insert-left` at root"

  )

(defn j/rights
  "Returns siblings to the right of `zloc`."
  [zloc]
  (when-let [st (j/state zloc)]
    (get st :rs)))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/rights)
  # =>
  [:b [:x :y]]

  )

(defn j/lefts
  "Returns siblings to the left of `zloc`."
  [zloc]
  (if-let [st (j/state zloc)
           ls (get st :ls)]
    ls
    []))

(comment

  (-> (j/ds-zip [:a :b])
      j/down
      j/lefts)
  # =>
  []

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/right
      j/right
      j/lefts)
  # =>
  [:a :b]

  )

(defn j/leftmost
  ``
  Returns the z-location of the leftmost sibling of the node at `zloc`,
  or the current node's z-location if there are no siblings to the left.
  ``
  [zloc]
  (let [[z-node st] zloc
        {:ls ls :rs rs} st]
    (if (and (not (empty? st))
             (indexed? ls)
             (not (empty? ls)))
      [(first ls)
       (j/make-state zloc
                   []
                   [;(j/rest ls) z-node ;rs]
                   (get st :pnodes)
                   (get st :pstate)
                   (get st :changed?))]
      zloc)))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/leftmost
      j/node)
  # =>
  :a

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/rightmost
      j/leftmost
      j/node)
  # =>
  :a

  )

(defn j/path
  "Returns the path of nodes that lead to `zloc` from the root node."
  [zloc]
  (when-let [st (j/state zloc)]
    (get st :pnodes)))

(comment

  (j/path (j/ds-zip [:a :b [:x :y]]))
  # =>
  nil

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/path)
  # =>
  [[:a :b [:x :y]]]

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/right
      j/right
      j/down
      j/path)
  # =>
  [[:a :b [:x :y]] [:x :y]]

  )

(defn j/right-until
  ``
  Try to move right from `zloc`, calling `pred` for each
  right sibling.  If the `pred` call has a truthy result,
  return the corresponding right sibling.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when-let [right-sib (j/right zloc)]
    (if (pred right-sib)
      right-sib
      (j/right-until right-sib pred))))

(comment

  (-> [:code
       [:tuple
        [:comment "# hi there"] [:whitespace "\n"]
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      j/ds-zip
      j/down
      j/right
      j/down
      (j/right-until |(match (j/node $)
                      [:comment]
                      false
                      #
                      [:whitespace]
                      false
                      #
                      true))
      j/node)
  # =>
  [:symbol "+"]

  )

(defn j/left-until
  ``
  Try to move left from `zloc`, calling `pred` for each
  left sibling.  If the `pred` call has a truthy result,
  return the corresponding left sibling.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when-let [left-sib (j/left zloc)]
    (if (pred left-sib)
      left-sib
      (j/left-until left-sib pred))))

(comment

  (-> [:code
       [:tuple
        [:comment "# hi there"] [:whitespace "\n"]
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      j/ds-zip
      j/down
      j/right
      j/down
      j/rightmost
      (j/left-until |(match (j/node $)
                     [:comment]
                     false
                     #
                     [:whitespace]
                     false
                     #
                     true))
      j/node)
  # =>
  [:number "1"]

  )

(defn j/search-from
  ``
  Successively call `pred` on z-locations starting at `zloc`
  in depth-first order.  If a call to `pred` returns a
  truthy value, return the corresponding z-location.
  Otherwise, return nil.
  ``
  [zloc pred]
  (if (pred zloc)
    zloc
    (when-let [next-zloc (j/df-next zloc)]
      (when (j/end? next-zloc)
        (break nil))
      (j/search-from next-zloc pred))))

(comment

  (-> (j/ds-zip [:a :b :c])
      j/down
      (j/search-from |(match (j/node $)
                      :b
                      true))
      j/node)
  # =>
  :b

  (-> (j/ds-zip [:a :b :c])
      j/down
      (j/search-from |(match (j/node $)
                      :d
                      true)))
  # =>
  nil

  (-> (j/ds-zip [:a :b :c])
      j/down
      (j/search-from |(match (j/node $)
                      :a
                      true))
      j/node)
  # =>
  :a

  )

(defn j/search-after
  ``
  Successively call `pred` on z-locations starting after
  `zloc` in depth-first order.  If a call to `pred` returns a
  truthy value, return the corresponding z-location.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when (j/end? zloc)
    (break nil))
  (when-let [next-zloc (j/df-next zloc)]
    (if (pred next-zloc)
      next-zloc
      (j/search-after next-zloc pred))))

(comment

  (-> (j/ds-zip [:b :a :b])
      j/down
      (j/search-after |(match (j/node $)
                       :b
                       true))
      j/left
      j/node)
  # =>
  :a

  (-> (j/ds-zip [:b :a :b])
      j/down
      (j/search-after |(match (j/node $)
                       :d
                       true)))
  # =>
  nil

  (-> (j/ds-zip [:a [:b :c [2 [3 :smile] 5]]])
      (j/search-after |(match (j/node $)
                       [_ :smile]
                       true))
      j/down
      j/node)
  # =>
  3

  )

(defn j/unwrap
  ``
  If the node at `zloc` is a branch node, "unwrap" its children in
  place.  If `zloc`'s node is not a branch node, do nothing.

  Throws an error if `zloc` corresponds to a top-most container.
  ``
  [zloc]
  (unless (j/branch? zloc)
    (break zloc))
  #
  (when (empty? (j/state zloc))
    (error "Called `unwrap` at root"))
  #
  (def kids (j/children zloc))
  (var i (dec (length kids)))
  (var curr-zloc zloc)
  (while (<= 0 i) # right to left
    (set curr-zloc
         (j/insert-right curr-zloc (get kids i)))
    (-- i))
  # try to end up at a sensible spot
  (set curr-zloc
       (j/remove curr-zloc))
  (if-let [ret-zloc (j/right curr-zloc)]
    ret-zloc
    curr-zloc))

(comment

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/right
      j/right
      j/unwrap
      j/root)
  # =>
  [:a :b :x :y]

  (-> (j/ds-zip [:a :b [:x :y]])
      j/down
      j/unwrap
      j/root)
  # =>
  [:a :b [:x :y]]

  (-> (j/ds-zip [[:a]])
      j/down
      j/unwrap
      j/root)
  # =>
  [:a]

  (-> (j/ds-zip [[:a :b] [:x :y]])
      j/down
      j/down
      j/remove
      j/unwrap
      j/root)
  # =>
  [:b [:x :y]]

  (try
    (-> (j/ds-zip [:a :b [:x :y]])
        j/unwrap)
    ([e] e))
  # =>
  "Called `unwrap` at root"

  )

(defn j/wrap
  ``
  Replace nodes from `start-zloc` through `end-zloc` with a single
  node of the same type as `wrap-node` containing the nodes from
  `start-zloc` through `end-zloc`.

  If `end-zloc` is not specified, just wrap `start-zloc`.

  The caller is responsible for ensuring the value of `end-zloc`
  is somewhere to the right of `start-zloc`.  Throws an error if
  an inappropriate value is specified for `end-zloc`.
  ``
  [start-zloc wrap-node &opt end-zloc]
  (default end-zloc start-zloc)
  #
  # 1. collect all nodes to wrap
  #
  (def kids @[])
  (var cur-zloc start-zloc)
  (while (and cur-zloc
              # XXX: expensive?
              (not (deep= (j/node cur-zloc)
                          (j/node end-zloc)))) # left to right
    (array/push kids (j/node cur-zloc))
    (set cur-zloc (j/right cur-zloc)))
  (when (nil? cur-zloc)
    (error "Called `wrap` with invalid value for `end-zloc`."))
  # also collect the last node
  (array/push kids (j/node end-zloc))
  #
  # 2. replace locations that will be removed with non-container nodes
  #
  (def dummy-node
    (j/make-node start-zloc wrap-node (tuple)))
  (set cur-zloc start-zloc)
  # trying to do this together in step 1 is not straight-forward
  # because the desired exiting condition for the while loop depends
  # on cur-zloc becoming end-zloc -- if `replace` were to be used
  # there, the termination condition never gets fulfilled properly.
  (for i 0 (dec (length kids)) # left to right again
    (set cur-zloc
         (-> (j/replace cur-zloc dummy-node)
             j/right)))
  (set cur-zloc
       (j/replace cur-zloc dummy-node))
  #
  # 3. remove all relevant locations
  #
  (def new-node
    (j/make-node start-zloc wrap-node (tuple ;kids)))
  (for i 0 (dec (length kids)) # right to left
    (set cur-zloc
         (j/remove cur-zloc)))
  # 4. put the new container node into place
  (j/replace cur-zloc new-node))

(comment

  (def start-zloc
    (-> (j/ds-zip [:a [:b] :c :x])
        j/down
        j/right))

  (j/node start-zloc)
  # =>
  [:b]

  (-> (j/wrap start-zloc [])
      j/root)
  # =>
  [:a [[:b]] :c :x]

  (def end-zloc
    (j/right start-zloc))

  (j/node end-zloc)
  # =>
  :c

  (-> (j/wrap start-zloc [] end-zloc)
      j/root)
  # =>
  [:a [[:b] :c] :x]

  (try
    (-> (j/wrap end-zloc [] start-zloc)
        j/root)
    ([e] e))
  # =>
  "Called `wrap` with invalid value for `end-zloc`."

  )

########################################################################

(defn j/has-children?
  ``
  Returns true if `a-node` can have children.
  Returns false if `a-node` cannot have children.
  ``
  [a-node]
  (when-let [[head] a-node]
    (truthy? (get {:code true
                   :fn true
                   :quasiquote true
                   :quote true
                   :splice true
                   :unquote true
                   :array true
                   :tuple true
                   :bracket-array true
                   :bracket-tuple true
                   :table true
                   :struct true}
                  head))))

(comment

  (j/has-children?
    [:tuple @{}
     [:symbol @{} "+"] [:whitespace @{} " "]
     [:number @{} "1"] [:whitespace @{} " "]
     [:number @{} "2"]])
  # =>
  true

  (j/has-children? [:number @{} "8"])
  # =>
  false

  )

(defn j/zip
  ``
  Returns a zipper location (zloc or z-location) for a tree
  representing Janet code.
  ``
  [a-tree]
  (defn branch?_
    [a-node]
    (truthy? (and (indexed? a-node)
                  (not (empty? a-node))
                  (j/has-children? a-node))))
  #
  (defn children_
    [a-node]
    (if (branch?_ a-node)
      (slice a-node 2)
      (error "Called `children` on a non-branch node")))
  #
  (defn make-node_
    [a-node kids]
    [(first a-node) (get a-node 1) ;kids])
  #
  (j/zipper a-tree branch?_ children_ make-node_))

(comment

  (def root-node
    @[:code @{} [:number @{} "8"]])

  (def [the-node the-state]
    (j/zip root-node))

  the-node
  # =>
  root-node

  # merge is used to "remove" the prototype table of `st`
  (merge {} the-state)
  # =>
  @{}

  )

(defn j/attrs
  ``
  Return the attributes table for the node of a z-location.  The
  attributes table contains at least bounds of the node by 1-based line
  and column numbers.
  ``
  [zloc]
  (get (j/node zloc) 1))

(comment

  (-> (j/par "(+ 1 3)")
      j/zip
      j/down
      j/attrs)
  # =>
  @{:bc 1 :bl 1 :ec 8 :el 1}

  )

(defn j/zip-down
  ``
  Convenience function that returns a zipper which has
  already had `down` called on it.
  ``
  [a-tree]
  (-> (j/zip a-tree)
      j/down))

(comment

  (-> (j/par "(+ 1 3)")
      j/zip-down
      j/node)
  # =>
  [:tuple @{:bc 1 :bl 1 :ec 8 :el 1}
   [:symbol @{:bc 2 :bl 1 :ec 3 :el 1} "+"]
   [:whitespace @{:bc 3 :bl 1 :ec 4 :el 1} " "]
   [:number @{:bc 4 :bl 1 :ec 5 :el 1} "1"]
   [:whitespace @{:bc 5 :bl 1 :ec 6 :el 1} " "]
   [:number @{:bc 6 :bl 1 :ec 7 :el 1} "3"]]

  (-> (j/par "(/ 1 8)")
      j/zip-down
      j/root)
  # =>
  @[:code @{:bc 1 :bl 1 :ec 8 :el 1}
    [:tuple @{:bc 1 :bl 1 :ec 8 :el 1}
            [:symbol @{:bc 2 :bl 1 :ec 3 :el 1} "/"]
            [:whitespace @{:bc 3 :bl 1 :ec 4 :el 1} " "]
            [:number @{:bc 4 :bl 1 :ec 5 :el 1} "1"]
            [:whitespace @{:bc 5 :bl 1 :ec 6 :el 1} " "]
            [:number @{:bc 6 :bl 1 :ec 7 :el 1} "8"]]]

  )

# wsc == whitespace, comment
(defn j/right-skip-wsc
  ``
  Try to move right from `zloc`, skipping over whitespace
  and comment nodes.

  When at least one right move succeeds, return the z-location
  for the last successful right move destination.  Otherwise,
  return nil.
  ``
  [zloc]
  (j/right-until zloc
               |(match (j/node $)
                  [:whitespace]
                  false
                  #
                  [:comment]
                  false
                  #
                  true)))

(comment

  (-> (j/par (string "(# hi there\n"
                   "+ 1 2)"))
      j/zip-down
      j/down
      j/right-skip-wsc
      j/node)
  # =>
  [:symbol @{:bc 1 :bl 2 :ec 2 :el 2} "+"]

  (-> (j/par "(:a)")
      j/zip-down
      j/down
      j/right-skip-wsc)
  # =>
  nil

  )

(defn j/left-skip-wsc
  ``
  Try to move left from `zloc`, skipping over whitespace
  and comment nodes.

  When at least one left move succeeds, return the z-location
  for the last successful left move destination.  Otherwise,
  return nil.
  ``
  [zloc]
  (j/left-until zloc
              |(match (j/node $)
                 [:whitespace]
                 false
                 #
                 [:comment]
                 false
                 #
                 true)))

(comment

  (-> (j/par (string "(# hi there\n"
                   "+ 1 2)"))
      j/zip-down
      j/down
      j/right-skip-wsc
      j/right-skip-wsc
      j/left-skip-wsc
      j/node)
  # =>
  [:symbol @{:bc 1 :bl 2 :ec 2 :el 2} "+"]

  (-> (j/par "(:a)")
      j/zip-down
      j/down
      j/left-skip-wsc)
  # =>
  nil

  )

# ws == whitespace
(defn j/right-skip-ws
  ``
  Try to move right from `zloc`, skipping over whitespace
  nodes.

  When at least one right move succeeds, return the z-location
  for the last successful right move destination.  Otherwise,
  return nil.
  ``
  [zloc]
  (j/right-until zloc
               |(match (j/node $)
                  [:whitespace]
                  false
                  #
                  true)))

(comment

  (-> (j/par (string "( # hi there\n"
                   "+ 1 2)"))
      j/zip-down
      j/down
      j/right-skip-ws
      j/node)
  # =>
  [:comment @{:bc 3 :bl 1 :ec 13 :el 1} "# hi there"]

  (-> (j/par "(:a)")
      j/zip-down
      j/down
      j/right-skip-ws)
  # =>
  nil

  )

(defn j/left-skip-ws
  ``
  Try to move left from `zloc`, skipping over whitespace
  nodes.

  When at least one left move succeeds, return the z-location
  for the last successful left move destination.  Otherwise,
  return nil.
  ``
  [zloc]
  (j/left-until zloc
              |(match (j/node $)
                 [:whitespace]
                 false
                 #
                 true)))

(comment

  (-> (j/par (string "(# hi there\n"
                   "+ 1 2)"))
      j/zip-down
      j/down
      j/right
      j/right
      j/left-skip-ws
      j/node)
  # =>
  [:comment @{:bc 2 :bl 1 :ec 12 :el 1} "# hi there"]

  (-> (j/par "(:a)")
      j/zip-down
      j/down
      j/left-skip-ws)
  # =>
  nil

  )


(comment import ./verify :prefix "")
# XXX: try to put in file?  had trouble originally when working on
#      judge-gen.  may be will have more luck?
(def v/as-string
  ``
  # influenced by janet's tools/helper.janet

  (var _verify/start-time 0)
  (var _verify/end-time 0)
  (var _verify/test-results @[])

  (defmacro _verify/is
    [t-form e-form line-no name]
    (with-syms [$ts $tr
                $es $er]
      ~(do
         (def [,$ts ,$tr] (protect (eval ',t-form)))
         (def [,$es ,$er] (protect (eval ',e-form)))
         (array/push _verify/test-results
                     @{:test-form ',t-form
                       :test-status ,$ts
                       :test-value ,$tr
                       #
                       :expected-form ',e-form
                       :expected-status ,$es
                       :expected-value ,$er
                       #
                       :line-no ,line-no
                       :name ,name
                       :passed (if (and ,$ts ,$es)
                                 (deep= ,$tr ,$er)
                                 nil)})
         ,name)))

  (defn _verify/start-tests
    []
    (set _verify/start-time (os/clock))
    (set _verify/test-results @[]))

  (defn _verify/end-tests
    []
    (set _verify/end-time (os/clock)))

  (defn _verify/report
    []
    # find and massage failures
    (def fails
      (keep (fn [r]
              (when (not (get r :passed))
                (def t-value (get r :test-value))
                (def [tr ts] (protect (string/format "%j" t-value)))
                (when (not tr)
                  (-> r
                      (put :test-value (string/format "%m" t-value))
                      (put :test-unreadable true)))
                (def e-value (get r :expected-value))
                (def [er es] (protect (string/format "%j" e-value)))
                (when (not er)
                  (-> r
                      (put :expected-value (string/format "%m" e-value))
                      (put :expected-unreadable true)))
                #
                r))
            _verify/test-results))
    # prepare test results
    (def test-results
      @{:num-tests (length _verify/test-results)
        :fails fails})
    # output a separator before the test output
    (print (string/repeat "#" 72) "\n")
    # report test results
    (printf "%j" test-results)
    # signal if there were any failures
    (when (not (empty? fails))
      (os/exit 1)))
  ``)



# at its simplest, a test is expressed like:
#
# (comment
#
#   (+ 1 1)
#   # =>
#   2
#
#   )
#
# i.e. inside a comment form, a single test consists of:
#
# * a test expression        - `(+ 1 1)`
# * a test indicator         - `# =>`
# * an expected expression   - `2`
#
# there can be one or more tests within a comment form.

# ti == test indicator, which can look like any of:
#
# # =>
# # before =>
# # => after
# # before => after
#
# further constraint that neither `before` nor `after` should contain
# a hash character (#)

(defn r/find-test-indicator
  [zloc]
  (var label-left nil)
  (var label-right nil)
  [(j/right-until zloc
                  |(match (j/node $)
                     [:comment _ content]
                     (if-let [[l r]
                              (peg/match ~(sequence "#"
                                                    (capture (to "=>"))
                                                    "=>"
                                                    (capture (thru -1)))
                                         content)
                              no-hash-left (nil? (string/find "#" l))
                              no-hash-right (nil? (string/find "#" r))]
                       (do
                         (set label-left (string/trim l))
                         (set label-right (string/trim r))
                         true)
                       false)))
   label-left
   label-right])

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(+ 1 1)" eol
            "# =>"    eol
            "2"))

  (let [[zloc l r]
        (r/find-test-indicator (-> (j/par src)
                                 j/zip-down))]
    (and zloc
         (empty? l)
         (empty? r)))
  # =>
  true

  (def src
    (string "(+ 1 1)"     eol
            "# before =>" eol
            "2"))

  (let [[zloc l r]
        (r/find-test-indicator (-> (j/par src)
                                 j/zip-down))]
    (and zloc
         (= "before" l)
         (empty? r)))
  # =>
  true

  (def src
    (string "(+ 1 1)"    eol
            "# => after" eol
            "2"))

  (let [[zloc l r]
        (r/find-test-indicator (-> (j/par src)
                                 j/zip-down))]
    (and zloc
         (empty? l)
         (= "after" r)))
  # =>
  true

  )

(defn r/find-test-expr
  [ti-zloc]
  # check for appropriate conditions "before"
  (def before-zlocs @[])
  (var curr-zloc ti-zloc)
  (var found-before nil)
  # collect zlocs to the left of the test indicator up through the
  # first non-whitespace/comment one.  if there is a
  # non-whitespace/comment one, that is the test expression.
  (while curr-zloc
    (set curr-zloc (j/left curr-zloc))
    (when (nil? curr-zloc)
      (break))
    #
    (match (j/node curr-zloc)
      [:comment]
      (array/push before-zlocs curr-zloc)
      #
      [:whitespace]
      (array/push before-zlocs curr-zloc)
      #
      (do
        (set found-before true)
        (array/push before-zlocs curr-zloc)
        (break))))
  #
  (cond
    (nil? curr-zloc)
    :no-test-expression
    # if all collected zlocs (except the last one) are whitespace,
    # then the test expression has been located
    (and found-before
         (->> (slice before-zlocs 0 -2)
              (filter |(not (match (j/node $)
                              [:whitespace]
                              true)))
              length
              zero?))
    curr-zloc
    #
    :unexpected-result))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(comment"         eol
            eol
            "  (def a 1)"      eol
            eol
            "  (put @{} :a 2)" eol
            "  # =>"           eol
            "  @{:a 2}"        eol
            eol
            "  )"))

  (def [ti-zloc _ _]
    (r/find-test-indicator (-> (j/par src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  [:comment @{:bc 3 :bl 6 :ec 7 :el 6} "# =>"]

  (def test-expr-zloc (r/find-test-expr ti-zloc))

  (j/node test-expr-zloc)
  # =>
  [:tuple @{:bc 3 :bl 5 :ec 17 :el 5}
   [:symbol @{:bc 4 :bl 5 :ec 7 :el 5} "put"]
   [:whitespace @{:bc 7 :bl 5 :ec 8 :el 5} " "]
   [:table @{:bc 8 :bl 5 :ec 11 :el 5}]
   [:whitespace @{:bc 11 :bl 5 :ec 12 :el 5} " "]
   [:keyword @{:bc 12 :bl 5 :ec 14 :el 5} ":a"]
   [:whitespace @{:bc 14 :bl 5 :ec 15 :el 5} " "]
   [:number @{:bc 15 :bl 5 :ec 16 :el 5} "2"]]

  (-> (j/left test-expr-zloc)
      j/node)
  # =>
  [:whitespace @{:bc 1 :bl 5 :ec 3 :el 5} "  "]

  )

(defn r/find-expected-expr
  [ti-zloc]
  (def after-zlocs @[])
  (var curr-zloc ti-zloc)
  (var found-comment nil)
  (var found-after nil)
  # collect zlocs to the right of the test indicator up through the
  # first non-whitespace/comment one.  if there is a
  # non-whitespace/comment one, that is the expression used to compute
  # the expected value.
  (while curr-zloc
    (set curr-zloc (j/right curr-zloc))
    (when (nil? curr-zloc)
      (break))
    #
    (match (j/node curr-zloc)
      [:comment]
      (do
        (set found-comment true)
        (break))
      #
      [:whitespace]
      (array/push after-zlocs curr-zloc)
      #
      (do
        (set found-after true)
        (array/push after-zlocs curr-zloc)
        (break))))
  #
  (cond
    (or (nil? curr-zloc)
        found-comment)
    :no-expected-expression
    # if there was a non-whitespace/comment zloc and the first zloc
    # "captured" represents eol (i.e. the first zloc to the right of
    # the test indicator), then there might be a an "expected
    # expression" that follows...
    (and found-after
         (match (j/node (first after-zlocs))
           [:whitespace _ "\n"]
           true
           [:whitespace _ "\r\n"]
           true))
    # starting on the line after the eol zloc, keep collected zlocs up
    # to (but not including) another eol zloc.  the first
    # non-whitespace zloc of the kept zlocs represents the "expected
    # expression".
    (if-let [from-next-line (drop 1 after-zlocs)
             before-eol-zloc (take-until |(match (j/node $)
                                            [:whitespace _ "\n"]
                                            true
                                            [:whitespace _ "\r\n"]
                                            true)
                                         from-next-line)
             target (->> before-eol-zloc
                         (filter |(match (j/node $)
                                    [:whitespace]
                                    false
                                    #
                                    true))
                         first)]
      target
      :no-expected-expression)
    #
    :unexpected-result))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(comment"         eol
            eol
            "  (def a 1)"      eol
            eol
            "  (put @{} :a 2)" eol
            "  # =>"           eol
            "  @{:a 1"         eol
            "    :b 2}"        eol
            eol
            "  )"))

  (def [ti-zloc _ _]
    (r/find-test-indicator (-> (j/par src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  [:comment @{:bc 3 :bl 6 :ec 7 :el 6} "# =>"]

  (def expected-expr-zloc (r/find-expected-expr ti-zloc))

  (j/node expected-expr-zloc)
  # =>
  [:table @{:bc 3 :bl 7 :ec 10 :el 8}
   [:keyword @{:bc 5 :bl 7 :ec 7 :el 7} ":a"]
   [:whitespace @{:bc 7 :bl 7 :ec 8 :el 7} " "]
   [:number @{:bc 8 :bl 7 :ec 9 :el 7} "1"]
   [:whitespace @{:bc 9 :bl 7 :ec 1 :el 8} "\n"]
   [:whitespace @{:bc 1 :bl 8 :ec 5 :el 8} "    "]
   [:keyword @{:bc 5 :bl 8 :ec 7 :el 8} ":b"]
   [:whitespace @{:bc 7 :bl 8 :ec 8 :el 8} " "]
   [:number @{:bc 8 :bl 8 :ec 9 :el 8} "2"]]

  (-> (j/left expected-expr-zloc)
      j/node)
  # =>
  [:whitespace @{:bc 1 :bl 7 :ec 3 :el 7} "  "]

  (def src
    (string "(comment"                eol
            eol
            "  (butlast @[:a :b :c])" eol
            "  # => @[:a :b]"         eol
            eol
            "  (butlast [:a])"        eol
            "  # => []"               eol
            eol
            ")"))

  (def [ti-zloc _ _]
    (r/find-test-indicator (-> (j/par src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  [:comment @{:bc 3 :bl 4 :ec 16 :el 4} "# => @[:a :b]"]

  (r/find-expected-expr ti-zloc)
  # =>
  :no-expected-expression

  )

(defn r/make-label
  [left right]
  (string ""
          (when (not (empty? left))
            left)
          (cond
            (not (empty? left))
            " =>"
            #
            (not (empty? right))
            "=>"
            #
            "")
          (when (not (empty? right))
            (string " " right))))

(comment

  (r/make-label "hi" "there")
  # =>
  "hi => there"

  (r/make-label "hi" "")
  # =>
  "hi =>"

  (r/make-label "" "there")
  # =>
  "=> there"

  (r/make-label "" "")
  # =>
  ""

  )

(defn r/find-exprs
  [ti-zloc]
  (def b {:in "find-exprs" :args {:ti-zloc ti-zloc}})
  # look for a test expression
  (def test-expr-zloc (r/find-test-expr ti-zloc))
  (case test-expr-zloc
    :no-test-expression
    (break [nil nil])
    #
    :unexpected-result
    (e/emf b "unexpected result from `find-test-expr`: %p"
           test-expr-zloc))
  # look for an expected value expression
  (def expected-expr-zloc (r/find-expected-expr ti-zloc))
  (case expected-expr-zloc
    :no-expected-expression
    (break [test-expr-zloc nil])
    #
    :unexpected-result
    (e/emf b "unexpected result from `find-expected-expr`: %p"
           expected-expr-zloc))
  #
  [test-expr-zloc expected-expr-zloc])

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(+ 1 1)" eol
            "# =>"    eol
            "2"))

  (def [ti-zloc _ _]
    (r/find-test-indicator (-> (j/par src)
                             j/zip-down)))

  (def [t-zloc e-zloc] (r/find-exprs ti-zloc))

  (j/gen (j/node t-zloc))
  # =>
  "(+ 1 1)"

  (j/gen (j/node e-zloc))
  # =>
  "2"

  )

(defn r/wrap-as-test-call
  [start-zloc end-zloc ti-line-no test-label]
  # XXX: hack - not sure if robust enough
  (def eol-str (if (= :windows (os/which)) "\r\n" "\n"))
  (-> (j/wrap start-zloc [:tuple @{}] end-zloc)
      # newline important for preserving long strings
      (j/insert-child [:whitespace @{} eol-str])
      # name of test macro
      (j/insert-child [:symbol @{} "_verify/is"])
      # for column zero convention, insert leading whitespace
      # before the beginning of the tuple (_verify/is ...)
      (j/insert-left [:whitespace @{} "  "])
      # add location info argument
      (j/append-child [:whitespace @{} " "])
      (j/append-child [:number @{} (string ti-line-no)])
      #
      (j/append-child [:whitespace @{} " "])
      (j/append-child [:string @{} test-label])))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(+ 1 1)" eol
            "# =>"    eol
            "2"))

  (def [ti-zloc _ _]
    (r/find-test-indicator (-> (j/par src)
                             j/zip-down)))

  (def [t-zloc e-zloc] (r/find-exprs ti-zloc))

  (let [left-of-t-zloc (j/left t-zloc)
        start-zloc (match (j/node left-of-t-zloc)
                     [:whitespace]
                     left-of-t-zloc
                     #
                     t-zloc)
        w-zloc (r/wrap-as-test-call start-zloc e-zloc "3" `""`)]
    (j/gen (j/node w-zloc)))
  # =>
  (string "(_verify/is\n"
          "(+ 1 1)\n"
          "# =>\n"
          "2 "
          "3 "
          `""`
          ")")

  )

(defn r/rewrite-with-tests
  [comment-zloc]
  # move into comment block
  (var curr-zloc (j/down comment-zloc))
  (var found-test nil)
  # process comment block content
  (while (not (j/end? curr-zloc))
    (def [ti-zloc label-left label-right] (r/find-test-indicator curr-zloc))
    (when (not ti-zloc)
      (break))
    #
    (def [test-expr-zloc expected-expr-zloc] (r/find-exprs ti-zloc))
    (set curr-zloc
         (if (or (nil? test-expr-zloc)
                 (nil? expected-expr-zloc))
           (j/right curr-zloc) # next
           # found a complete test, work on rewriting
           (let [left-of-te-zloc (j/left test-expr-zloc)
                 start-zloc (match (j/node left-of-te-zloc)
                              [:whitespace]
                              left-of-te-zloc
                              #
                              test-expr-zloc)
                 end-zloc expected-expr-zloc
                 # XXX: use `attrs` here?
                 ti-line-no ((get (j/node ti-zloc) 1) :bl)
                 test-label
                 (string/format `"%s"`
                                (r/make-label label-left label-right))]
             (set found-test true)
             (r/wrap-as-test-call start-zloc end-zloc
                                ti-line-no test-label)))))
  # navigate back out to top of block
  (when found-test
    # morph comment block into plain tuple -- to be unwrapped later
    (-> curr-zloc
        j/up
        j/down
        (j/replace [:whitespace @{} " "])
        # begin hack to prevent trailing whitespace once unwrapping occurs
        j/rightmost
        (j/insert-right [:keyword @{} ":smile"])
        # end of hack
        j/up)))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(comment"         eol
            eol
            "  (def a 1)"      eol
            eol
            "  (put @{} :a 2)" eol
            "  # left =>"      eol
            "  @{:a 2}"        eol
            eol
            "  (+ 1 1)"        eol
            "  # => right"     eol
            "  2"              eol
            eol
            "  )"))

  (-> (j/par src)
      j/zip-down
      r/rewrite-with-tests
      j/root
      j/gen)
  # =>
  (string "( "                     eol
          eol
          "  (def a 1)"            eol
          eol
          "  (_verify/is"          eol
          "  (put @{} :a 2)"       eol
          "  # left =>"            eol
          `  @{:a 2} 6 "left =>")` eol
          eol
          "  (_verify/is"          eol
          "  (+ 1 1)"              eol
          "  # => right"           eol
          `  2 10 "=> right")`     eol
          eol
          "  :smile)")

  )

(defn r/rewrite-comment-block
  [comment-src]
  (-> (j/par comment-src)
      j/zip-down
      r/rewrite-with-tests
      j/root
      j/gen))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(comment"          eol
            eol
            "  (def a 1)"       eol
            eol
            "  (put @{} :a 2)"  eol
            "  # =>"            eol
            "  @{:a 2}"         eol
            eol
            "  (+ 1 1)"         eol
            "  # left => right" eol
            "  2"               eol
            eol
            "  )"))

  (r/rewrite-comment-block src)
  # =>
  (string "( "                      eol
          eol
          "  (def a 1)"             eol
          eol
          "  (_verify/is"           eol
          "  (put @{} :a 2)"        eol
          "  # =>"                  eol
          `  @{:a 2} 6 "")`         eol
          eol
          "  (_verify/is"           eol
          "  (+ 1 1)"               eol
          "  # left => right"       eol
          `  2 10 "left => right")` eol
          eol
          "  :smile)")

  )

(defn r/rewrite-comments-with
  [src xform-fn]
  (var changed nil)
  # XXX: hack - not sure if robust enough
  (def eol-str (if (= :windows (os/which)) "\r\n" "\n"))
  (var curr-zloc
    (-> (j/par src)
        j/zip-down
        # XXX: leading newline is a hack to prevent very first thing
        #      from being a comment block
        (j/insert-left [:whitespace @{} eol-str])
        # XXX: once the newline is inserted, need to move to it
        j/left))
  #
  (while (not (j/end? curr-zloc))
    # try to find a top-level comment block
    (if-let [comment-zloc
             (j/right-until curr-zloc
                            |(match (j/node $)
                               [:tuple _ [:symbol _ "comment"]]
                               true))]
      # may be rewrite the located top-level comment block
      (set curr-zloc
           (if-let [rewritten-zloc
                    (xform-fn comment-zloc)]
             (do
               (set changed true)
               (j/unwrap rewritten-zloc))
             comment-zloc))
      (break)))
  #
  (when changed
    (-> curr-zloc
        j/root
        j/gen)))

(defn r/rewrite
  [src]
  (r/rewrite-comments-with src r/rewrite-with-tests))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string `(require "json")` eol
            eol
            "(defn my-fn"      eol
            "  [x]"            eol
            "  (+ x 1))"       eol
            eol
            "(comment"         eol
            eol
            "  (def a 1)"      eol
            eol
            "  (put @{} :a 2)" eol
            "  # =>"           eol
            "  @{:a 2}"        eol
            eol
            "  (my-fn 1)"      eol
            "  # =>"           eol
            "  2"              eol
            eol
            "  )"              eol
            eol
            "(defn your-fn"    eol
            "  [y]"            eol
            "  (* y y))"       eol
            eol
            "(comment"         eol
            eol
            "  (your-fn 3)"    eol
            "  # =>"           eol
            "  9"              eol
            eol
            "  (def b 1)"      eol
            eol
            "  (+ b 1)"        eol
            "  # =>"           eol
            "  2"              eol
            eol
            "  (def c 2)"      eol
            eol
            "  )"              eol
            ))

  (r/rewrite src)
  # =>
  (string eol
          `(require "json")`     eol
          eol
          "(defn my-fn"          eol
          "  [x]"                eol
          "  (+ x 1))"           eol
          eol
          " "                    eol
          eol
          "  (def a 1)"          eol
          eol
          "  (_verify/is"        eol
          "  (put @{} :a 2)"     eol
          "  # =>"               eol
          `  @{:a 2} 12 "")`     eol
          eol
          "  (_verify/is"        eol
          "  (my-fn 1)"          eol
          "  # =>"               eol
          `  2 16 "")`           eol
          eol
          "  :smile"             eol
          eol
          "(defn your-fn"        eol
          "  [y]"                eol
          "  (* y y))"           eol
          eol
          " "                    eol
          eol
          "  (_verify/is"        eol
          "  (your-fn 3)"        eol
          "  # =>"               eol
          `  9 28 "")`           eol
          eol
          "  (def b 1)"          eol
          eol
          "  (_verify/is"        eol
          "  (+ b 1)"            eol
          "  # =>"               eol
          `  2 34 "")`           eol
          eol
          "  (def c 2)"          eol
          eol
          "  :smile"             eol)

  )

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  # https://github.com/sogaiu/judge-gen/issues/1
  (def src
    (string "(comment"        eol
            eol
            "  (-> ``"        eol
            "      123456789" eol
            "      ``"        eol
            "      length)"   eol
            "  # =>"          eol
            "  9"             eol
            eol
            "  (->"           eol
            "    ``"          eol
            "    123456789"   eol
            "    ``"          eol
            "    length)"     eol
            "  # =>"          eol
            "  9"             eol
            eol
            "  )"))

  (r/rewrite src)
  # =>
  (string eol
          " "               eol
          eol
          "  (_verify/is"   eol
          "  (-> ``"        eol
          "      123456789" eol
          "      ``"        eol
          "      length)"   eol
          "  # =>"          eol
          `  9 7 "")`       eol
          eol
          "  (_verify/is"   eol
          "  (->"           eol
          "    ``"          eol
          "    123456789"   eol
          "    ``"          eol
          "    length)"     eol
          "  # =>"          eol
          `  9 15 "")`      eol
          eol
          "  :smile")

  )

(defn r/rewrite-as-test-file
  [src]
  (when (not (empty? src))
    (when-let [rewritten (r/rewrite src)]
      # XXX: hack - not sure if robust enough
      (def eol-str (if (= :windows (os/which)) "\r\n" "\n"))
      (string v/as-string
              eol-str
              "(_verify/start-tests)"
              eol-str
              rewritten
              eol-str
              "(_verify/end-tests)"
              eol-str
              "(_verify/report)"
              eol-str))))

(defn r/rewrite-with-only-test-exprs
  [comment-zloc]
  # move into comment block
  (var curr-zloc (j/down comment-zloc))
  (var found-test nil)
  # process comment block content
  (while (not (j/end? curr-zloc))
    (def [ti-zloc label-left label-right] (r/find-test-indicator curr-zloc))
    (when (not ti-zloc)
      (break))
    #
    (def [test-expr-zloc expected-expr-zloc] (r/find-exprs ti-zloc))
    (set curr-zloc
         (if (or (nil? test-expr-zloc)
                 (nil? expected-expr-zloc))
           (j/right curr-zloc) # next
           # found a complete test, work on rewriting
           (let [eol-str (if (= :windows (os/which)) "\r\n" "\n")]
             (set found-test true)
             (-> (j/wrap expected-expr-zloc [:tuple @{}])
                 (j/insert-child [:whitespace @{} " "])
                 (j/insert-child [:symbol @{} "comment"]))))))
  # navigate back out to top of block
  (when found-test
    # morph comment block into plain tuple -- to be unwrapped later
    (-> curr-zloc
        j/up
        j/down
        (j/replace [:whitespace @{} " "])
        # begin hack to prevent trailing whitespace once unwrapping occurs
        j/rightmost
        (j/insert-right [:keyword @{} ":smile"])
        # end of hack
        j/up)))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(comment"         eol
            eol
            "  (def a 1)"      eol
            eol
            "  (put @{} :a 2)" eol
            "  # left =>"      eol
            "  @{:a 2}"        eol
            eol
            "  (+ 1 1)"        eol
            "  # => right"     eol
            "  2"              eol
            eol
            "  )"))

  (-> (j/par src)
      j/zip-down
      r/rewrite-with-only-test-exprs
      j/root
      j/gen)
  # =>
  (string "( "                     eol
          eol
          "  (def a 1)"            eol
          eol
          "  (put @{} :a 2)"       eol
          "  # left =>"            eol
          "  (comment @{:a 2})"    eol
          eol
          "  (+ 1 1)"              eol
          "  # => right"           eol
          "  (comment 2)"          eol
          eol
          "  :smile)")

  )

(defn r/rewrite-to-lint
  [src]
  (r/rewrite-comments-with src r/rewrite-with-only-test-exprs))

# XXX: rewrite-comments-with adds a leading newline for processing
#      purposes (see its source), but this causes all line numbers to
#      be off by one.  to make the line numbers match up, the leading
#      newline is removed.  it's nicer for the line numbers in the
#      rewritten source to match up with the original source because
#      linting messages can mention specific line numbers.
(defn r/rewrite-as-file-to-lint
  [src]
  (when (not (empty? src))
    (when-let [to-lint-src (r/rewrite-to-lint src)
               nl-idx (string/find "\n" to-lint-src)]
      # to make the line numbers match the original source
      (string/slice to-lint-src (inc nl-idx)))))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(comment"         eol
            eol
            "  (def a 1)"      eol
            eol
            "  (put @{} :a 2)" eol
            "  # left =>"      eol
            "  @{:a 2}"        eol
            eol
            "  (+ 1 1)"        eol
            "  # => right"     eol
            "  2"              eol
            eol
            "  )"))

  (r/rewrite-as-file-to-lint src)
  # =>
  (string " " eol
          eol
          "  (def a 1)"         eol
          eol
          "  (put @{} :a 2)"    eol
          "  # left =>"         eol
          "  (comment @{:a 2})" eol
          eol
          "  (+ 1 1)"           eol
          "  # => right"        eol
          "  (comment 2)"       eol
          eol
          "  :smile")

  )

(defn r/patch-zloc
  [a-zloc update-info]
  (def b {:in "patch-zloc" :args {:a-zloc a-zloc :update-info update-info}})
  (var zloc a-zloc)
  (var ok? true)
  (each [line value] update-info
    (when (not zloc)
      (break))
    #
    (def ti-zloc
      (j/search-from zloc
                     |(when-let [node (j/node $)
                                 [n-type {:bl bl} _] node]
                        (and (= :comment n-type)
                             (= bl line)))))
    (when (not ti-zloc)
      (e/emf b "failed to find test indicator at line: %d" line))
    #
    (def ee-zloc (r/find-expected-expr ti-zloc))
    (def new-node
      (try (-> (j/par value)
               j/zip-down
               j/node)
        ([e] (e/emf (merge b {:e-via-try e})
                    "failed to create node for value: %n" value))))
    # patch with value
    (def new-zloc (j/replace ee-zloc new-node))
    (when (not new-zloc)
      (e/emf b "failed to replace with new node: %n" new-node))
    #
    (set zloc new-zloc))
  #
  (when ok? zloc))

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (string "(comment"  eol
            eol
            "  (+ 1 2)" eol
            "  # =>"    eol
            "  0"       eol
            eol
            "  )"))

  (def zloc (-> src j/par j/zip-down))

  (-> (r/patch-zloc zloc @[[4 "3"]])
      j/root
      j/gen)
  # =>
  (string "(comment"  eol
          eol
          "  (+ 1 2)" eol
          "  # =>"    eol
          "  3"       eol
          eol
          "  )")

  )

(defn r/patch
  [input update-info &opt output]
  (def b {:in "patch" :args {:input input :update-info update-info
                             :output output}})
  (default output (if (string? input) input @""))
  (def src (cond (string? input)
                 (slurp input)
                 #
                 (buffer? input)
                 input
                 #
                 (e/emf b "unexpected type for input: %n" input)))
  (when (empty? src)
    (e/emf b "no content for input: %n" input))
  # prepare and patch
  (def zloc
    (try (-> src j/par j/zip-down)
      ([e] (e/emf (merge b {:e-via-try e})
                  "failed to create zipper for: %n" input))))
  (def new-zloc (r/patch-zloc zloc update-info))
  (when (not new-zloc)
    (break nil))
  #
  (def new-src
    (try
      (-> new-zloc j/root j/gen)
      ([e]
        (e/emf (merge b {:e-via-try e})
               "failed to create src from: %n" (j/node new-zloc)))))
  (when (not new-src)
    (e/emf b "unexpected falsy value for new-src"))
  #
  (cond (buffer? output)
        (buffer/blit output new-src)
        #
        (string? output)
        (spit output new-src)
        #
        (e/emf b "unexpected value for output: %n" output))
  #
  output)

(comment

  (def eol (if (= :windows (os/which)) "\r\n" "\n"))

  (def src
    (buffer "(comment"             eol
            eol
            "  (+ 1 (- 2"          eol
            "          (+ 1 2))) " eol
            "  # =>"               eol
            "  3"                  eol
            eol
            "  )"))

  (r/patch src @[[5 "0"]] @"")
  # =>
  (buffer "(comment"             eol
          eol
          "  (+ 1 (- 2"          eol
          "          (+ 1 2))) " eol
          "  # =>"               eol
          "  0"                  eol
          eol
          "  )")

  )


(comment import ./tests :prefix "")
(comment import ./errors :prefix "")

(comment import ./rewrite :prefix "")

(comment import ./paths :prefix "")


(def t/test-file-ext ".niche")

(defn t/make-test-path
  [in-path]
  (def [fdir fname] (p/parse-path in-path))
  #
  (string fdir "_" fname t/test-file-ext))

(comment

  (t/make-test-path "tmp/hello.janet")
  # =>
  "tmp/_hello.janet.niche"

  )

(defn t/make-tests
  [in-path &opt opts]
  (def b {:in "make-tests" :args {:in-path in-path :opts opts}})
  #
  (def src (slurp in-path))
  (def [ok? _] (protect (parse-all src)))
  (when (not ok?)
    (break :parse-error))
  #
  (def test-src (r/rewrite-as-test-file src))
  (when (not test-src)
    (break nil))
  #
  (def test-path (t/make-test-path in-path))
  (when (and (not (get opts :overwrite))
             (os/stat test-path :mode))
    (e/emf (merge b {:locals {:test-path test-path}})
           "test file already exists for: %s" in-path))
  #
  (spit test-path test-src)
  #
  test-path)

(defn t/run-tests
  [test-path]
  (def b {:in "run-tests" :args {:test-path test-path}})
  #
  (try
    (with [of (file/temp)]
      (with [ef (file/temp)]
        (let [# prevents any contained `main` functions from executing
              cmd
              ["janet" "-e" (string "(dofile `" test-path "`)")]
              ecode
              (os/execute cmd :p {:out of :err ef})]
          #
          (file/flush of)
          (file/flush ef)
          (file/seek of :set 0)
          (file/seek ef :set 0)
          # XXX: iiuc ecode cannot be nil
          [ecode
           (file/read of :all)
           (file/read ef :all)])))
    ([e]
      (e/emf (merge b {:e-via-try e})
             "problem running tests in: %s" test-path))))

(defn t/parse-output
  [out]
  (def b {:in "parse-output" :args {:out out}})
  # see verify.janet
  (def boundary (buffer/new-filled 72 (chr "#")))
  (def b-idx (last (string/find-all boundary out)))
  (when (not b-idx)
    (e/emf b "failed to find boundary in output: %n" out))
  #
  (def [test-out results] (string/split boundary out b-idx))
  #
  [(parse results) test-out])

(comment

  (def data
    {:test-form '(+ 1 1)
     :test-status true
     :test-value 2
     :expected-form 3
     :expected-status true
     :expected-value 3
     :line-no 4
     :passed true
     :name ""})

  (def separator (buffer/new-filled 72 (chr "#")))

  (def out
    (string
      "hello this is a line\n"
      "and so is this\n"
      separator "\n"
      (string/format "%j" data)))

  (t/parse-output out)
  # =>
  [{:expected-form 3
    :expected-status true
    :expected-value 3
    :line-no 4
    :name ""
    :passed true
    :test-form '(+ 1 1)
    :test-status true
    :test-value 2}
   "hello this is a line\nand so is this\n"]

  )

(defn t/make-lint-path
  [in-path]
  #
  (string (t/make-test-path in-path) "-lint"))

(comment

  (t/make-lint-path "tmp/hello.janet")
  # =>
  "tmp/_hello.janet.niche-lint"

  )

(defn t/lint-and-get-error
  [input]
  (def lint-path (t/make-lint-path input))
  (defer (os/rm lint-path)
    (def lint-src (r/rewrite-as-file-to-lint (slurp input)))
    (spit lint-path lint-src)
    (def lint-buf @"")
    (with-dyns [:err lint-buf] (flycheck lint-path))
    # XXX: peg may need work
    (peg/match ~(sequence "error: " (to ":") (capture (to "\n")))
               lint-buf)))

(defn t/has-unreadable?
  [test-results]
  (var unreadable? nil)
  (each f (get test-results :fails)
    (when (get f :test-unreadable)
      (set unreadable? f)
      (break))
    #
    (when (get f :expected-unreadable)
      (set unreadable? f)
      (break)))
  #
  unreadable?)

(defn t/make-and-run
  [input &opt opts]
  (def b @{:in "make-and-run" :args {:input input :opts opts}})
  #
  (default opts @{})
  # create test source
  (def result (t/make-tests input opts))
  (cond
    (not result)
    (break [:no-tests nil nil nil])
    #
    (= :parse-error result)
    (break [:parse-error nil nil nil]))
  #
  (def test-path result)
  # run tests and collect output
  (def [exit-code out err] (t/run-tests test-path))
  (os/rm test-path)
  #
  (when (empty? out)
    (if (t/lint-and-get-error input)
      (break [:lint-error nil nil nil])
      (break [:test-run-error nil nil nil])))
  #
  (def [test-results test-out] (t/parse-output out))
  (when-let [unreadable (t/has-unreadable? test-results)]
    (e/emf b (string/format "unreadable value in:\n%s"
                            (if (dyn :test/color?) "%M" "%m"))
           unreadable))
  #
  [exit-code test-results test-out err])



########################################################################

(defn c/summarize
  [noted-paths]
  # pass / fail
  (def ps-paths (get noted-paths :pass))
  (def fl-paths (get noted-paths :fail))
  #
  (when fl-paths
    (def n-ps-paths (length ps-paths))
    (def n-fl-paths (length fl-paths))
    (when (empty? fl-paths)
      (l/notenf :i "All tests successful in %d file(s)."
                n-ps-paths))
    (when (not (empty? fl-paths))
      (l/notenf :i "Test failures in %d of %d file(s)."
                n-fl-paths (+ n-fl-paths n-ps-paths))))
  # errors
  (def p-paths (get noted-paths :parse))
  (def l-paths (get noted-paths :lint))
  (def r-paths (get noted-paths :run))
  (def err-paths [p-paths l-paths r-paths])
  #
  (when (some |(not (empty? $)) err-paths)
    (def num-skipped (sum (map length err-paths)))
    (l/notenf :w "Skipped %d files(s)." num-skipped))
  (when (not (empty? p-paths))
    (l/notenf :w "%s: parse error(s) detected in %d file(s)."
              (o/color-msg "WARNING" :red) (length p-paths)))
  (when (not (empty? l-paths))
    (l/notenf :w "%s: linting error(s) detected in %d file(s)."
              (o/color-msg "WARNING" :yellow) (length l-paths)))
  (when (not (empty? r-paths))
    (l/notenf :w "%s: runtime error(s) detected for %d file(s)."
              (o/color-msg "WARNING" :yellow) (length r-paths))))

########################################################################

(defn c/mrr-single
  [input &opt opts]
  # try to make and run tests, then collect output
  (def [exit-code test-results test-out test-err]
    (t/make-and-run input opts))
  (when (get (invert [:no-tests
                      :parse-error :lint-error :test-run-error])
             exit-code)
    (break [exit-code nil nil]))
  #
  (def {:report report} opts)
  (default report o/report)
  # print out results
  (report test-results test-out test-err)
  #
  (when (not= 0 exit-code)
    (break [:exit-code test-results]))
  #
  [:no-fails test-results])

(defn c/tally-mrr-result
  [path [desc tr] noted-paths]
  (def b @{:in "tally-mrr-result"
           :args {:path path :single-result [desc tr]
                  :noted-paths noted-paths}})
  #
  (case desc
    :no-tests
    (l/noten :i " - no tests found")
    #
    :parse-error
    (let [msg (o/color-msg "detected parse errors" :red)]
      (l/notenf :w " - %s" msg)
      (array/push (get noted-paths :parse) path))
    #
    :lint-error
    (let [msg (o/color-msg "detected lint errors" :yellow)]
      (l/notenf :w " - %s" msg)
      (array/push (get noted-paths :lint) path))
    #
    :test-run-error
    (let [msg (o/color-msg "test file had runtime errors" :yellow)]
      (l/notenf :w " - %s" msg)
      (array/push (get noted-paths :run) path))
    #
    :no-fails
    (let [n-tests (get tr :num-tests)
          ratio (o/color-ratio n-tests n-tests)]
      (l/notenf :i " - [%s]" ratio)
      (array/push (get noted-paths :pass) path))
    #
    :exit-code
    (let [n-tests (get tr :num-tests)
          n-passes (- n-tests (length (get tr :fails)))
          ratio (o/color-ratio n-passes n-tests)]
      (l/notenf :i "[%s]" ratio)
      (array/push (get noted-paths :fail) path))
    #
    (e/emf b "unexpected result %p for: %s" desc path)))

(defn c/make-run-report
  [src-paths opts]
  (def excludes (get opts :excludes))
  (def noted-paths @{:parse @[] :lint @[] :run @[]
                     :pass @[] :fail @[]})
  (def test-results @[])
  # generate tests, run tests, and report
  (each path src-paths
    (when (and (not (has-value? excludes path)) (f/is-file? path))
      (l/note :i path)
      (def single-result (c/mrr-single path opts))
      (def [_ tr] single-result)
      (array/push test-results [path tr])
      (c/tally-mrr-result path single-result noted-paths)))
  #
  (l/notenf :i (o/separator "="))
  (c/summarize noted-paths)
  #
  (def exit-code (if (empty? (get noted-paths :fail)) 0 1))
  #
  [exit-code test-results])


(comment import ./errors :prefix "")

(comment import ./files :prefix "")

(comment import ./log :prefix "")

(comment import ./output :prefix "")


###########################################################################

(def version "2026-01-13_03-50-18")

(def usage
  ``
  Usage: niche [<file-or-dir>...]
         niche [-h|--help] [-v|--version]

  Nimbly Inspect Comment-Hidden Expressions

  Parameters:

    <file-or-dir>          path to file or directory

  Options:

    -h, --help             show this output
    -v, --version          show version information

  Configuration:

    .niche.jdn             configuration file

  Examples:

    Create and run tests in `src/` directory:

    $ niche src

    `niche` can be used via `jpm`, `jeep`, etc. with
    some one-time setup.  Create a suitable `.niche.jdn`
    file in a project's root directory and a runner
    file in a project's `test/` subdirectory (see below
    for further details).

    Run via `jeep test`:

    $ jeep test

    Run via `jpm test`:

    $ jpm test

    Run using the configuration file via direct
    invocation:

    $ niche

  Example `.niche.jdn` content:

    {# what to work on - file and dir paths
     :includes ["src" "bin/my-script"]
     # what to skip - file paths only
     :excludes ["src/sample.janet"]}

  Example runner file `test/trigger-niche.janet`:

    (import ../niche)

    (niche/main)
  ``)

########################################################################

(defn main
  [& args]
  (def start-time (os/clock))
  #
  (def opts (a/parse-args (drop 1 args)))
  #
  (when (get opts :show-help)
    (l/noten :o usage)
    (os/exit 0))
  #
  (when (get opts :show-version)
    (l/noten :o version)
    (os/exit 0))
  #
  (def src-paths
    (f/collect-paths (get opts :includes)
                     |(or (string/has-suffix? ".janet" $)
                          (f/has-janet-shebang? $))))
  (when (get opts :raw)
    (l/clear-d-tables!))
  # 0 - successful testing
  # 1 - at least one test failure
  # 2 - caught error
  (def [exit-code test-results]
    (try
      (c/make-run-report src-paths opts)
      ([e f]
        (l/noten :e)
        (if (dictionary? e)
          (e/show e)
          (debug/stacktrace f e "internal "))
        (l/noten :e "Processing halted.")
        [2 @[]])))
  #
  (if (get opts :raw)
    (print (o/color-form test-results))
    (l/notenf :i "Total processing time was %.02f secs."
              (- (os/clock) start-time)))
  #
  (when (not (get opts :no-exit))
    (os/exit exit-code)))

