# configuration

# highly likely will want to tweak this
(def src-dir-name
  "examples")

# only tweak if trying to prevent collision with existing dir
(def judge-dir-name
  "judge")

# only tweak if trying to prevent collision with existing source
(def judge-file-prefix
  "judge-")

# disable "All tests passed." message from `jpm test` if true
(def silence-jpm-test
  false)

# configuration ends here

### path.janet
###
### A library for path manipulation.
###
### Copyright 2019 © Calvin Rose

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#
# Common
#

(def- path/ext-peg
  (peg/compile ~{:back (> -1 (+ (* ($) (set "\\/.")) :back))
                 :main :back}))

(defn path/ext
  "Get the file extension for a path."
  [path]
  (if-let [m (peg/match path/ext-peg path (length path))]
    (let [i (m 0)]
      (if (= (path i) 46)
        (string/slice path (m 0) -1)))))

(defn- path/redef
  "Redef a value, keeping all metadata."
  [from to]
  (setdyn (symbol to) (dyn (symbol from))))

#
# Generating Macros
#

(defmacro- path/decl-sep [pre sep] ~(def ,(symbol pre "/sep") ,sep))
(defmacro- path/decl-delim [pre d] ~(def ,(symbol pre "/delim") ,d))

(defmacro- path/decl-last-sep
  [pre sep]
  ~(def- ,(symbol pre "/last-sep-peg")
    (peg/compile '{:back (> -1 (+ (* ,sep ($)) :back))
                   :main (+ :back (constant 0))})))

(defmacro- path/decl-dirname
  [pre]
  ~(defn ,(symbol pre "/dirname")
     "Gets the directory name of a path."
     [path]
     (if-let [m (peg/match
                  ,(symbol pre "/last-sep-peg")
                  path
                  (length path))]
       (let [[p] m]
         (if (zero? p) "./" (string/slice path 0 p)))
       path)))

(defmacro- path/decl-basename
  [pre]
  ~(defn ,(symbol pre "/basename")
     "Gets the base file name of a path."
     [path]
     (if-let [m (peg/match
                  ,(symbol pre "/last-sep-peg")
                  path
                  (length path))]
       (let [[p] m]
         (string/slice path p -1))
       path)))

(defmacro- path/decl-parts
  [pre sep]
  ~(defn ,(symbol pre "/parts")
     "Split a path into its parts."
     [path]
     (string/split ,sep path)))

(defmacro- path/decl-normalize
  [pre sep sep-pattern lead]
  (defn capture-lead
    [& xs]
    [:lead (xs 0)])
  (def grammar
    ~{:span (some (if-not ,sep-pattern 1))
      :sep (some ,sep-pattern)
      :main (* (? (* (replace ',lead ,capture-lead) (any ,sep-pattern)))
               (? ':span)
               (any (* :sep ':span))
               (? (* :sep (constant ""))))})
  (def peg (peg/compile grammar))
  ~(defn ,(symbol pre "/normalize")
     "Normalize a path. This removes . and .. in the
     path, as well as empty path elements."
     [path]
     (def accum @[])
     (def parts (peg/match ,peg path))
     (var seen 0)
     (var lead nil)
     (each x parts
       (match x
         [:lead what] (set lead what)
         "." nil
         ".." (if (= 0 seen)
                (array/push accum x)
                (do (-- seen) (array/pop accum)))
         (do (++ seen) (array/push accum x))))
     (def ret (string (or lead "") (string/join accum ,sep)))
     (if (= "" ret) "." ret)))

(defmacro- path/decl-join
  [pre sep]
  ~(defn ,(symbol pre "/join")
     "Join path elements together."
     [& els]
     (,(symbol pre "/normalize") (string/join els ,sep))))

(defmacro- path/decl-abspath
  [pre]
  ~(defn ,(symbol pre "/abspath")
     "Coerce a path to be absolute."
     [path]
     (if (,(symbol pre "/abspath?") path)
       (,(symbol pre "/normalize") path)
       (,(symbol pre "/join") (or (dyn :path-cwd) (os/cwd)) path))))

#
# Posix
#

(defn path/posix/abspath?
  "Check if a path is absolute."
  [path]
  (string/has-prefix? "/" path))

(path/redef "path/ext" "path/posix/ext")
(path/decl-sep "path/posix" "/")
(path/decl-delim "path/posix" ":")
(path/decl-last-sep "path/posix" "/")
(path/decl-basename "path/posix")
(path/decl-dirname "path/posix")
(path/decl-parts "path/posix" "/")
(path/decl-normalize "path/posix" "/" "/" "/")
(path/decl-join "path/posix" "/")
(path/decl-abspath "path/posix")

#
# Windows
#

(def- path/abs-pat '(* (? (* (range "AZ" "az") `:`)) `\`))
(def- path/abs-peg (peg/compile path/abs-pat))
(defn path/win32/abspath?
  "Check if a path is absolute."
  [path]
  (not (not (peg/match path/abs-peg path))))

(path/redef "path/ext" "path/win32/ext")
(path/decl-sep "path/win32" "\\")
(path/decl-delim "path/win32" ";")
(path/decl-last-sep "path/win32" "\\")
(path/decl-basename "path/win32")
(path/decl-dirname "path/win32")
(path/decl-parts "path/win32" "\\")
(path/decl-normalize "path/win32" `\` (set `\/`) (* (? (* (range "AZ" "az") `:`)) `\`))
(path/decl-join "path/win32" "\\")
(path/decl-abspath "path/win32")

#
# Satisfy linter
#

(defn path/sep [pre sep] nil)
(defn path/delim [pre d] nil)
(defn path/dirname [pre] nil)
(defn path/basename [pre] nil)
(defn path/parts [pre sep] nil)
(defn path/normalize [pre sep sep-pattern lead] nil)
(defn path/join [pre sep] nil)
(defn path/abspath [pre] nil)
(defn path/abspath? [path] nil)

#
# Specialize for current OS
#

(def- path/syms
  ["ext"
   "sep"
   "delim"
   "basename"
   "dirname"
   "abspath?"
   "abspath"
   "parts"
   "normalize"
   "join"])
(let [pre (if (= :windows (os/which)) "path/win32" "path/posix")]
  (each sym path/syms
    (path/redef (string pre "/" sym) (string "path/" sym))))

# XXX: useful bits from jpm

### Copyright 2019 © Calvin Rose

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

(def- jpm/is-win (= (os/which) :windows))
(def- jpm/is-mac (= (os/which) :macos))
(def- jpm/sep (if jpm/is-win "\\" "/"))

(defn jpm/rm
  "Remove a directory and all sub directories."
  [path]
  (case (os/lstat path :mode)
    :directory (do
      (each subpath (os/dir path)
        (jpm/rm (string path jpm/sep subpath)))
      (os/rmdir path))
    nil nil # do nothing if file does not exist
    # Default, try to remove
    (os/rm path)))

(def- jpm/path-splitter
  "split paths on / and \\."
  (peg/compile ~(any (* '(any (if-not (set `\/`) 1)) (+ (set `\/`) -1)))))

(defn jpm/shell
  "Do a shell command"
  [& args]
  (if (dyn :verbose)
    (print ;(interpose " " args)))
  (def res (os/execute args :p))
  (unless (zero? res)
    (error (string "command exited with status " res))))

(defn jpm/copy
  "Copy a file or directory recursively from one location to another."
  [src dest]
  (print "copying " src " to " dest "...")
  (if jpm/is-win
    (let [end (last (peg/match jpm/path-splitter src))
          isdir (= (os/stat src :mode) :directory)]
      (jpm/shell "C:\\Windows\\System32\\xcopy.exe"
                 (string/replace "/" "\\" src)
                 (string/replace "/" "\\" (if isdir (string dest "\\" end) dest))
                 "/y" "/s" "/e" "/i"))
    (jpm/shell "cp" "-rf" src dest)))

(defn jpm/pslurp
  [cmd]
  (string/trim (with [f (file/popen cmd)]
                     (:read f :all))))

(defn jpm/create-dirs
  "Create all directories needed for a file (mkdir -p)."
  [dest]
  (def segs (peg/match jpm/path-splitter dest))
  (for i 1 (length segs)
    (def path (string/join (slice segs 0 i) jpm/sep))
    (unless (empty? path) (os/mkdir path))))

### argparse.janet
###
### A library for parsing command-line arguments
###
### Copyright 2019 © Calvin Rose

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

(defn- argparse/pad-right
  "Pad a string on the right with some spaces."
  [str n]
  (def len (length str))
  (if (>= len n)
    str
    (string str (string/repeat " " (- n len)))))

(defn argparse/argparse
  "Parse (dyn :args) according to options. If the arguments are incorrect,
  will return nil and print usage information.

  Each option is a table or struct that specifies a flag or option
  for the script. The name of the option should be a string, specified
  via (argparse/argparse \"...\" op1-name {...} op2-name {...} ...). A help option
  and usage text is automatically generated for you.\n\n

  The keys in each option table are as follows:\n\n

  \t:kind - What kind of option is this? One of :flag, :multi, :option, or
  :accumulate. A flag can either be on or off, a multi is a flag that can be provided
  multiple times, each time adding 1 to a returned integer, an option is a key that
  will be set in the returned table, and accumulate means an option can be specified
  0 or more times, each time appending a value to an array.\n
  \t:short - Single letter for shorthand access.\n
  \t:help - Help text for the option, explaining what it is.\n
  \t:default - Default value for the option.\n
  \t:required - Whether or not an option is required.\n
  \t:short-circuit - Whether or not to stop parsing and fail if this option is hit.\n
  \t:action - A function that will be invoked when the option is parsed.\n\n

  There is also a special option :default that will be invoked on arguments
  that do not start with a -- or -. Use this option to collect unnamed
  arguments to your script.\n\n

  Once parsed, values are accessible in the returned table by the name
  of the option. For example (result \"verbose\") will check if the verbose
  flag is enabled."
  [description &keys options]

  # Add default help option
  (def options (merge
                 @{"help" {:kind :flag
                           :short "h"
                           :help "Show this help message."
                           :action :help
                           :short-circuit true}}
                 options))

  # Create shortcodes
  (def shortcodes @{})
  (loop [[k v] :pairs options :when (string? k)]
    (if-let [code (v :short)]
      (put shortcodes (code 0) {:name k :handler v})))

  # Results table and other things
  (def res @{:order @[]})
  (def args (dyn :args))
  (def arglen (length args))
  (var scanning true)
  (var bad false)
  (var i 1)

  # Show usage
  (defn usage
    [& msg]
    # Only show usage once.
    (if bad (break))
    (set bad true)
    (set scanning false)
    (unless (empty? msg)
      (print "usage error: " ;msg))
    (def flags @"")
    (def opdoc @"")
    (def reqdoc @"")
    (loop [[name handler] :in (sort (pairs options))]
      (def short (handler :short))
      (when short (buffer/push-string flags short))
      (when (string? name)
        (def kind (handler :kind))
        (def usage-prefix
          (string
            ;(if short [" -" short ", "] ["     "])
            "--" name
            ;(if (or (= :option kind) (= :accumulate kind))
               [" " (or (handler :value-name) "VALUE")
                ;(if-let [d (handler :default)]
                   ["=" d]
                   [])]
               [])))
        (def usage-fragment
          (string
            (argparse/pad-right (string usage-prefix " ") 45)
            (if-let [h (handler :help)] h "")
            "\n"))
        (buffer/push-string (if (handler :required) reqdoc opdoc)
                            usage-fragment)))
    (print "usage: " (get args 0) " [option] ... ")
    (print)
    (print description)
    (print)
    (unless (empty? reqdoc)
      (print " Required:")
      (print reqdoc))
    (unless (empty? opdoc)
      (print " Optional:")
      (print opdoc)))

  # Handle an option
  (defn handle-option
    [name handler]
    (array/push (res :order) name)
    (case (handler :kind)
      :flag (put res name true)
      :multi (do
               (var count (or (get res name) 0))
               (++ count)
               (put res name count))
      :option (if-let [arg (get args i)]
                (do
                  (put res name arg)
                  (++ i))
                (usage "missing argument for " name))
      :accumulate (if-let [arg (get args i)]
                    (do
                      (def arr (or (get res name) @[]))
                      (array/push arr arg)
                      (++ i)
                      (put res name arr))
                    (usage "missing argument for " name))
      # default
      (usage "unknown option kind: " (handler :kind)))

    # Allow actions to be dispatched while scanning
    (when-let [action (handler :action)]
              (cond
                (= action :help) (usage)
                (function? action) (action)))

    # Early exit for things like help
    (when (handler :short-circuit)
      (set scanning false)))

  # Iterate command line arguments and parse them
  # into the run table.
  (while (and scanning (< i arglen))
    (def arg (get args i))
    (cond

      # long name (--name)
      (string/has-prefix? "--" arg)
      (let [name (string/slice arg 2)
            handler (get options name)]
        (++ i)
        (if handler
          (handle-option name handler)
          (usage "unknown option " name)))

      # short names (-flags)
      (string/has-prefix? "-" arg)
      (let [flags (string/slice arg 1)]
        (++ i)
        (each flag flags
          (if-let [x (get shortcodes flag)]
            (let [{:name name :handler handler} x]
              (handle-option name handler))
            (usage "unknown flag " arg))))

      # default
      (if-let [handler (options :default)]
        (handle-option :default handler)
        (usage "could not handle option " arg))))

  # Handle defaults, required options
  (loop [[name handler] :pairs options]
    (when (nil? (res name))
      (when (handler :required)
        (usage "option " name " is required"))
      (put res name (handler :default))))

  (if-not bad res))


(def args-runner/params
  ["Comment block test runner."
   "debug" {:help "Debug output."
            :kind :flag
            :short "d"}
   "judge-file-prefix" {:default "judge-"
                        :help "Prefix for test files."
                        :kind :option
                        :short "f"}
   "judge-dir-name" {:default "judge"
                     :help "Name of judge directory."
                     :kind :option
                     :short "j"}
   "project-root" {:help "Project root."
                   :kind :option
                   :short "p"}
   "source-root" {:help "Source root."
                  :kind :option
                  :short "s"}
   "version" {:default false
              :help "Version output."
              :kind :flag
              :short "v"}])

(comment

  (deep=
    (do
      (setdyn :args ["jg-verdict"
                     "-p" ".."
                     "-s" "."])
      (argparse/argparse ;args-runner/params))

    @{"version" false
      "judge-file-prefix" "judge-"
      "judge-dir-name" "judge"
      :order @["project-root" "source-root"]
      "project-root" ".."
      "source-root" "."}) # => true

  )

(defn args-runner/parse
  []
  (def res (argparse/argparse ;args-runner/params))
  (unless res
    (break nil))
  (let [judge-dir-name (res "judge-dir-name")
        judge-file-prefix (res "judge-file-prefix")
        proj-root (or (res "project-root") "")
        src-root (or (res "source-root") "")
        version (res "version")]
    # XXX: work on this
    (when version
      (print "jg-verdict pre-release")
      (break nil))
    (setdyn :debug (res "debug"))
    (assert (os/stat proj-root)
            (string "Project root not detected: " proj-root))
    (assert (os/stat src-root)
            (string "Source root not detected: " src-root))
    {:judge-dir-name judge-dir-name
     :judge-file-prefix judge-file-prefix
     :proj-root proj-root
     :src-root src-root
     :version version}))
# adapted from:
#   https://janet-lang.org/docs/syntax.html

# approximation of janet's grammar
(def grammar/jg
  ~{:main :root
    #
    :root (any :root0)
    #
    :root0 (choice :value :comment)
    #
    :value (sequence
            (any (choice :ws :readermac))
            :raw-value
            (any :ws))
    #
    :ws (set " \0\f\n\r\t\v")
    #
    :readermac (set "',;|~")
    #
    :raw-value (choice
                :constant :number
                :symbol :keyword
                :string :buffer
                :long-string :long-buffer
                :parray :barray
                :ptuple :btuple
                :struct :table)
    #
    :comment (sequence (any :ws)
                       "#"
                       (any (if-not (choice "\n" -1) 1))
                       (any :ws))
    #
    :constant (choice "false" "nil" "true")
    #
    :number (drop (cmt
                   (capture :token)
                   ,scan-number))
    #
    :token (some :symchars)
    #
    :symchars (choice
               (range "09" "AZ" "az" "\x80\xFF")
               # XXX: see parse.c's is_symbol_char which mentions:
               #
               #        \, ~, and |
               #
               #      but tools/symcharsgen.c does not...
               (set "!$%&*+-./:<?=>@^_"))
    #
    :keyword (sequence ":" (any :symchars))
    #
    :string :bytes
    #
    :bytes (sequence "\""
                     (any (choice :escape (if-not "\"" 1)))
                     "\"")
    #
    :escape (sequence "\\"
                      (choice (set "0efnrtvz\"\\")
                              (sequence "x" [2 :hex])
                              (sequence "u" [4 :d])
                              (sequence "U" [6 :d])
                              (error (constant "bad escape"))))
    #
    :hex (range "09" "af" "AF")
    #
    :buffer (sequence "@" :bytes)
    #
    :long-string :long-bytes
    #
    :long-bytes {:main (drop (sequence
                              :open
                              (any (if-not :close 1))
                              :close))
                 :open (capture :delim :n)
                 :delim (some "`")
                 :close (cmt (sequence
                              (not (look -1 "`"))
                              (backref :n)
                              (capture :delim))
                             ,=)}
    #
    :long-buffer (sequence "@" :long-bytes)
    #
    :parray (sequence "@" :ptuple)
    #
    :ptuple (sequence "("
                      :root
                      (choice ")" (error "")))
    #
    :barray (sequence "@" :btuple)
    #
    :btuple (sequence "["
                      :root
                      (choice "]" (error "")))
    # XXX: constraining to an even number of values doesn't seem
    #      worth the work when considering that comments can also
    #      appear in a variety of locations...
    :struct (sequence "{"
                      :root
                      (choice "}" (error "")))
    #
    :table (sequence "@" :struct)
    #
    :symbol :token
    })

(comment

  (try
    (peg/match grammar/jg "\"\\u001\"")
    ([e] e))
  # => "bad escape"

  (peg/match grammar/jg "\"\\u0001\"")
  # => @[]

  (peg/match grammar/jg "(def a 1)")
  # => @[]

  (try
    (peg/match grammar/jg "[:a :b)")
    ([e] e))
  # => "match error at line 1, column 7"

  (peg/match grammar/jg "(def a # hi\n 1)")
  # => @[]

  (try
    (peg/match grammar/jg "(def a # hi 1)")
    ([e] e))
  # => "match error at line 1, column 15"

  (peg/match grammar/jg "[1]")
  # => @[]

  (peg/match grammar/jg "# hello")
  # => @[]

  (peg/match grammar/jg "``hello``")
  # => @[]

  (peg/match grammar/jg "8")
  # => @[]

  (peg/match grammar/jg "[:a :b]")
  # => @[]

  (peg/match grammar/jg "[:a :b] 1")
  # => @[]

 )

# make a version of jg that matches a single form
(def grammar/jg-one
  (->
   # jg is a struct, need something mutable
   (table ;(kvs grammar/jg))
   # just recognize one form
   (put :main :root0)
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(comment

  (try
    (peg/match grammar/jg-one "\"\\u001\"")
    ([e] e))
  # => "bad escape"

  (peg/match grammar/jg-one "\"\\u0001\"")
  # => @[]

  (peg/match grammar/jg-one "(def a 1)")
  # => @[]

  (try
    (peg/match grammar/jg-one "[:a :b)")
    ([e] e))
  # => "match error at line 1, column 7"

  (peg/match grammar/jg-one "(def a # hi\n 1)")
  # => @[]

  (try
    (peg/match grammar/jg-one "(def a # hi 1)")
    ([e] e))
  # => "match error at line 1, column 15"

  (peg/match grammar/jg-one "[1]")
  # => @[]

  (peg/match grammar/jg-one "# hello")
  # => @[]

  (peg/match grammar/jg-one "``hello``")
  # => @[]

  (peg/match grammar/jg-one "8")
  # => @[]

  (peg/match grammar/jg-one "[:a :b]")
  # => @[]

  (peg/match grammar/jg-one "[:a :b] 1")
  # => @[]

 )

# make a capturing version of jg
(def grammar/jg-capture
  (->
   # jg is a struct, need something mutable
   (table ;(kvs grammar/jg))
   # capture recognized bits
   (put :main '(capture :root))
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(comment

  (peg/match grammar/jg-capture "nil")
  # => @["nil"]

  (peg/match grammar/jg-capture "true")
  # => @["true"]

  (peg/match grammar/jg-capture "false")
  # => @["false"]

  (peg/match grammar/jg-capture "symbol")
  # => @["symbol"]

  (peg/match grammar/jg-capture "kebab-case-symbol")
  # => @["kebab-case-symbol"]

  (peg/match grammar/jg-capture "snake_case_symbol")
  # => @["snake_case_symbol"]

  (peg/match grammar/jg-capture "my-module/my-function")
  # => @["my-module/my-function"]

  (peg/match grammar/jg-capture "*****")
  # => @["*****"]

  (peg/match grammar/jg-capture "!%$^*__--__._+++===~-crazy-symbol")
  # => @["!%$^*__--__._+++===~-crazy-symbol"]

  (peg/match grammar/jg-capture "*global-var*")
  # => @["*global-var*"]

  (peg/match grammar/jg-capture "你好")
  # => @["\xE4\xBD\xA0\xE5\xA5\xBD"]

  (peg/match grammar/jg-capture ":keyword")
  # => @[":keyword"]

  (peg/match grammar/jg-capture ":range")
  # => @[":range"]

  (peg/match grammar/jg-capture ":0x0x0x0")
  # => @[":0x0x0x0"]

  (peg/match grammar/jg-capture ":a-keyword")
  # => @[":a-keyword"]

  (peg/match grammar/jg-capture "::")
  # => @["::"]

  (peg/match grammar/jg-capture ":")
  # => @[":"]

  (peg/match grammar/jg-capture "0")
  # => @["0"]

  (peg/match grammar/jg-capture "12")
  # => @["12"]

  (peg/match grammar/jg-capture "-65912")
  # => @["-65912"]

  (peg/match grammar/jg-capture "1.3e18")
  # => @["1.3e18"]

  (peg/match grammar/jg-capture "-1.3e18")
  # => @["-1.3e18"]

  (peg/match grammar/jg-capture "18r123C")
  # => @["18r123C"]

  (peg/match grammar/jg-capture "11raaa&a")
  # => @["11raaa&a"]

  (peg/match grammar/jg-capture "1_000_000")
  # => @["1_000_000"]

  (peg/match grammar/jg-capture "0xbeef")
  # => @["0xbeef"]

  (try
    (peg/match grammar/jg-capture "\"\\u001\"")
    ([e] e))
  # => "bad escape"

  (peg/match grammar/jg-capture "\"\\u0001\"")
  # => @["\"\\u0001\""]

  (peg/match grammar/jg-capture "\"\\U000008\"")
  # => @["\"\\U000008\""]

  (peg/match grammar/jg-capture "(def a 1)")
  # => @["(def a 1)"]

  (try
    (peg/match grammar/jg-capture "[:a :b)")
    ([e] e))
  # => "match error at line 1, column 7"

  (peg/match grammar/jg-capture "(def a # hi\n 1)")
  # => @["(def a # hi\n 1)"]

  (try
    (peg/match grammar/jg-capture "(def a # hi 1)")
    ([e] e))
  # => "match error at line 1, column 15"

  (peg/match grammar/jg-capture "[1]")
  # => @["[1]"]

  (peg/match grammar/jg-capture "# hello")
  # => @["# hello"]

  (peg/match grammar/jg-capture "``hello``")
  # => @["``hello``"]

  (peg/match grammar/jg-capture "8")
  # => @["8"]

  (peg/match grammar/jg-capture "[:a :b]")
  # => @["[:a :b]"]

  (peg/match grammar/jg-capture "[:a :b] 1")
  # => @["[:a :b] 1"]

  (def sample-source
    (string "# \"my test\"\n"
            "(+ 1 1)\n"
            "# => 2\n"))

  (peg/match grammar/jg-capture sample-source)
  # => @["# \"my test\"\n(+ 1 1)\n# => 2\n"]

  )

# make a version of jg that captures a single form
(def grammar/jg-capture-one
  (->
   # jg is a struct, need something mutable
   (table ;(kvs grammar/jg))
   # capture just one form
   (put :main '(capture :root0))
   # tried using a table with a peg but had a problem, so use a struct
   table/to-struct))

(comment

  (def sample-source
    (string "# \"my test\"\n"
            "(+ 1 1)\n"
            "# => 2\n"))

  (peg/match grammar/jg-capture-one sample-source)
  # => @["# \"my test\"\n"]

  (peg/match grammar/jg-capture-one sample-source 11)
  # => @["\n(+ 1 1)\n"]

  (peg/match grammar/jg-capture-one sample-source 20)
  # => @["# => 2\n"]

  )

# XXX: any way to avoid this?
(var- pegs/in-comment 0)

(def- pegs/jg-comments
  (->
    # jg* from grammar are structs, need something mutable
    (table ;(kvs grammar/jg))
    (put :main '(choice (capture :value)
                        :comment))
    #
    (put :comment-block ~(sequence
                           "("
                           (any :ws)
                           (drop (cmt (capture "comment")
                                      ,|(do
                                          (++ pegs/in-comment)
                                          $)))
                           :root
                           (drop (cmt (capture ")")
                                      ,|(do
                                          (-- pegs/in-comment)
                                          $)))))
    (put :ptuple ~(choice :comment-block
                          (sequence "("
                                    :root
                                    (choice ")" (error "")))))
    # classify certain comments
    (put :comment ~(sequence
                     (any :ws)
                     (choice
                       (cmt (sequence
                              (line)
                              "#" (any :ws) "=>"
                              (capture (sequence
                                         (any (if-not (choice "\n" -1) 1))
                                         (any "\n"))))
                            ,|(if (zero? pegs/in-comment)
                                # record value and line
                                [:returns (string/trim $1) $0]
                                ""))
                       (cmt (capture (sequence
                                       "#"
                                       (any (if-not (+ "\n" -1) 1))
                                       (any "\n")))
                            ,|(identity $))
                       (any :ws))))
    # tried using a table with a peg but had a problem, so use a struct
    table/to-struct))

(def pegs/inner-forms
  ~{:main :inner-forms
    #
    :inner-forms (sequence
                   "("
                   (any :ws)
                   "comment"
                   (any :ws)
                   (any (choice :ws ,pegs/jg-comments))
                   (any :ws)
                   ")")
    #
    :ws (set " \0\f\n\r\t\v")
    })

(comment

  (deep=
    #
    (peg/match
      pegs/inner-forms
      ``
      (comment
        (- 1 1)
        # => 0
      )
      ``)
    #
    @["(- 1 1)\n  "
      [:returns "0" 3]])
  # => true

  (deep=
    #
    (peg/match
      pegs/inner-forms
      ``
      (comment

        (def a 1)

        # this is just a comment

        (def b 2)

        (= 1 (- b a))
        # => true

      )
      ``)
    #
    @["(def a 1)\n\n  "
      "# this is just a comment\n\n"
      "(def b 2)\n\n  "
      "(= 1 (- b a))\n  "
      [:returns "true" 10]])
  # => true

  # demo of having failure test output give nicer results
  (def result
    @["(def a 1)\n\n  "
      "# this is just a comment\n\n"
      "(def b 2)\n\n  "
      "(= 1 (- b a))\n  "
      [:returns "true" 10]])

  (peg/match
    pegs/inner-forms
    ``
    (comment

      (def a 1)

      # this is just a comment

      (def b 2)

      (= 1 (- b a))
      # => true

    )
    ``)
    # => result

  )

(defn pegs/parse-comment-block
  [cmt-blk-str]
  # mutating outer pegs/in-comment
  (set pegs/in-comment 0)
  (peg/match pegs/inner-forms cmt-blk-str))

(comment

  (def comment-str
    ``
    (comment

      (+ 1 1)
      # => 2

    )
    ``)

  (pegs/parse-comment-block comment-str)
  # => @["(+ 1 1)\n  " [:returns "2" 4]]

  (def comment-with-no-test-str
    ``
    (comment

      (+ 1 1)

    )
    ``)

  (pegs/parse-comment-block comment-with-no-test-str)
  # => @["(+ 1 1)\n\n"]

  (def comment-in-comment-str
    ``
    (comment

      (comment

         (+ 1 1)
         # => 2

       )
    )
    ``)

  (pegs/parse-comment-block comment-in-comment-str)
  # => @["" "(comment\n\n     (+ 1 1)\n     # => 2\n\n   )\n"]

)

# recognize next top-level form, returning a map
# modify a copy of jg
(def pegs/jg-pos
  (->
    # jg* from grammar are structs, need something mutable
    (table ;(kvs grammar/jg))
    # also record location and type information, instead of just recognizing
    (put :main ~(choice (cmt (sequence
                               (line)
                               (capture :value)
                               (position))
                             ,|(do
                                 (def [s-line value end] $&)
                                 {:end end
                                  :s-line s-line
                                  :type :value
                                  :value value}))
                        (cmt (sequence
                               (line)
                               (capture :comment)
                               (position))
                             ,|(do
                                 (def [s-line value end] $&)
                                 {:end end
                                  :s-line s-line
                                  :type :comment
                                  :value value}))))
    # tried using a table with a peg but had a problem, so use a struct
    table/to-struct))

(comment

  (def sample-source
    (string "# \"my test\"\n"
            "(+ 1 1)\n"
            "# => 2\n"))

  (deep=
    #
    (peg/match pegs/jg-pos sample-source 0)
    #
    @[{:type :comment
       :value "# \"my test\"\n"
       :s-line 1
       :end 12}]) # => true

  (deep=
    #
    (peg/match pegs/jg-pos sample-source 12)
    #
    @[{:type :value
       :value "(+ 1 1)\n"
       :s-line 2
       :end 20}]) # => true

  (string/slice sample-source 12 20)
  # => "(+ 1 1)\n"

  (deep=
    #
    (peg/match pegs/jg-pos sample-source 20)
    #
    @[{:type :comment
       :value "# => 2\n"
       :s-line 3
       :end 27}]) # => true

  )

(comment

  (def top-level-comments-sample
    ``
    (def a 1)

    (comment

      (+ 1 1)

      # hi there

      (comment :a )

    )

    (def x 0)

    (comment

      (= a (+ x 1))

    )
    ``)

  (deep=
    #
    (peg/match pegs/jg-pos top-level-comments-sample)
    #
    @[{:type :value
       :value "(def a 1)\n\n"
       :s-line 1
       :end 11}]
    ) # => true

  (deep=
    #
    (peg/match pegs/jg-pos top-level-comments-sample 11)
    #
    @[{:type :value
       :value
       "(comment\n\n  (+ 1 1)\n\n  # hi there\n\n  (comment :a )\n\n)\n\n"
       :s-line 3
       :end 66}]
    ) # => true

  (deep=
    #
    (peg/match pegs/jg-pos top-level-comments-sample 66)
    #
    @[{:type :value
       :value "(def x 0)\n\n"
       :s-line 13
       :end 77}]
    ) # => true

  (deep=
    #
    (peg/match pegs/jg-pos top-level-comments-sample 77)
    #
    @[{:type :value
       :value "(comment\n\n  (= a (+ x 1))\n\n)"
       :s-line 15
       :end 105}]
    ) # => true

  )

(def pegs/comment-block-maybe
  ~{:main (sequence
            (any :ws)
            "("
            (any :ws)
            "comment"
            (any :ws))
    #
    :ws (set " \0\f\n\r\t\v")})

(comment

  (peg/match
    pegs/comment-block-maybe
    ``
    (comment

      (= a (+ x 1))

    )
    ``)
  # => @[]

  (peg/match
    pegs/comment-block-maybe
    ``

    (comment

      :a
    )
    ``)
  # => @[]

  )

(defn segments/parse-buffer
  [buf]
  (var segments @[])
  (var from 0)
  (loop [parsed :iterate (peg/match pegs/jg-pos buf from)]
    (when (dyn :debug)
      (eprintf "parsed: %j" parsed))
    (when (not parsed)
      (break))
    (def segment (first parsed))
    (assert segment
            (string "Unexpectedly did not find segment in: " parsed))
    (array/push segments segment)
    (set from (segment :end)))
  segments)

(comment

  (def code-buf
    @``
    (def a 1)

    (comment

      (+ a 1)
      # => 2

      (def b 3)

      (- b a)
      # => 2

    )
    ``)

  (deep=
    (segments/parse-buffer code-buf)
    #
    @[{:value "    (def a 1)\n\n    "
       :s-line 1
       :type :value
       :end 19}
      {:value (string "(comment\n\n      "
                      "(+ a 1)\n      "
                      "# => 2\n\n      "
                      "(def b 3)\n\n      "
                      "(- b a)\n      "
                      "# => 2\n\n    "
                      ")\n    ")
       :s-line 3
       :type :value
       :end 112}]
    ) # => true

  )

(defn segments/find-comment-blocks
  [segments]
  (var comment-blocks @[])
  (loop [i :range [0 (length segments)]]
    (def segment (get segments i))
    (def {:value code-str} segment)
    (when (peg/match pegs/comment-block-maybe code-str)
      (array/push comment-blocks segment)))
  comment-blocks)

(comment

  (def segments
    @[{:value "    (def a 1)\n\n    "
       :s-line 1
       :type :value
       :end 19}
      {:value (string "(comment\n\n      "
                      "(+ a 1)\n      "
                      "# => 2\n\n      "
                      "(def b 3)\n\n      "
                      "(- b a)\n      "
                      "# => 2\n\n    "
                      ")\n    ")
       :s-line 3
       :type :value
       :end 112}])

  (deep=
    (segments/find-comment-blocks segments)
    #
    @[{:value (string "(comment\n\n      "
                      "(+ a 1)\n      "
                      "# => 2\n\n      "
                      "(def b 3)\n\n      "
                      "(- b a)\n      "
                      "# => 2\n\n    "
                      ")\n    ")
       :s-line 3
       :type :value
       :end 112}]
    )
  # => true

  )

# XXX: simplify?
(defn rewrite/rewrite-tagged
  [tagged-item last-form offset]
  (match tagged-item
    [:returns value line]
    (string "(_verify/is "
            last-form " "
            value " "
            (string "\"" "line-" (dec (+ line offset)) "\"") ")\n\n")
    nil))

(comment

  (rewrite/rewrite-tagged [:returns true 1] "(= 1 1)" 1)
  # => "(_verify/is (= 1 1) true \"line-1\")\n\n"

  )

# XXX: tried putting the following into a file, but kept having
#      difficulty getting it to work out
# XXX: an advantage of it being in a separate file is that testing
#      the contained code might be easier...
(def rewrite/verify-as-string
  ``
  # influenced by janet's tools/helper.janet

  (var _verify/start-time 0)
  (var _verify/end-time 0)
  (var _verify/test-results @[])

  (defmacro _verify/is
    [t-form e-form &opt name]
    (default name
      (string "test-" (inc (length _verify/test-results))))
    (with-syms [$ts $tr
                $es $er]
      ~(do
         (def [,$ts ,$tr] (protect ,t-form))
         (def [,$es ,$er] (protect ,e-form))
         (array/push _verify/test-results
                     {:expected-form ',e-form
                      :expected-value ,$er
                      :name ,name
                      :passed (if (and ,$ts ,$es)
                                (deep= ,$tr ,$er)
                                nil)
                      :test-form ',t-form
                      :test-value ,$tr
                      :type :is})
         ,name)))

  (defn _verify/start-tests
    []
    (set _verify/start-time (os/clock))
    (set _verify/test-results @[]))

  (defn _verify/end-tests
    []
    (set _verify/end-time (os/clock)))

  (defn _verify/dump-results
    []
    (if-let [test-out (dyn :judge-gen/test-out)]
      (spit test-out (marshal _verify/test-results))
      # XXX: could this sometimes have problems?
      (printf "%p" _verify/test-results)))

  ``)

(defn rewrite/has-tests
  [forms]
  (when forms
    (some |(tuple? $)
          forms)))

(comment

  (rewrite/has-tests @["(+ 1 1)\n  " [:returns "2" 1]])
  # => true

  (rewrite/has-tests @["(comment \"2\")\n  "])
  # => nil

  )

(defn rewrite/rewrite-block-with-verify
  [blk]
  (def rewritten-forms @[])
  (def {:value blk-str
        :s-line offset} blk)
  # parse the comment block and rewrite some parts
  (let [parsed (pegs/parse-comment-block blk-str)]
    (when (rewrite/has-tests parsed)
      (each cmt-or-frm parsed
        (when (not= cmt-or-frm "")
          (if (empty? rewritten-forms)
            (array/push rewritten-forms cmt-or-frm)
            # is `cmt-or-frm` an expected value
            (if (= (type cmt-or-frm) :tuple)
              # looks like an expected value, handle rewriting as test
              (let [last-form (array/pop rewritten-forms)
                    rewritten (rewrite/rewrite-tagged cmt-or-frm
                                                      last-form offset)]
                (assert rewritten (string "match failed for: " cmt-or-frm))
                (array/push rewritten-forms rewritten))
              # not an expected value, continue
              (array/push rewritten-forms cmt-or-frm)))))))
  rewritten-forms)

(comment

  (def comment-str
    ``
    (comment

      (+ 1 1)
      # => 2

    )
    ``)

  (def comment-blk
    {:value comment-str
     :s-line 3})

  (rewrite/rewrite-block-with-verify comment-blk)
  # => @["(_verify/is (+ 1 1)\n   2 \"line-6\")\n\n"]

  (def comment-with-no-test-str
    ``
    (comment

      (+ 1 1)

    )
    ``)

  (def comment-blk-with-no-test-str
    {:value comment-with-no-test-str
     :s-line 1})

  (rewrite/rewrite-block-with-verify comment-blk-with-no-test-str)
  # => @[]

  # comment block in comment block shields inner content
  (def comment-in-comment-str
    ``
    (comment

      (comment

         (+ 1 1)
         # => 2

       )
    )
    ``)

  (def comment-blk-in-comment-blk
    {:value comment-in-comment-str
     :s-line 10})

  (rewrite/rewrite-block-with-verify comment-blk-in-comment-blk)
  # => @[]

  )

(defn rewrite/rewrite-with-verify
  [cmt-blks]
  (var rewritten-forms @[])
  # parse comment blocks and rewrite some parts
  (each blk cmt-blks
    (array/concat rewritten-forms (rewrite/rewrite-block-with-verify blk)))
  # assemble pieces
  (var forms
    (array/concat @[]
                  @["\n\n"
                    "(_verify/start-tests)\n\n"]
                  rewritten-forms
                  @["\n(_verify/end-tests)\n"
                    "\n(_verify/dump-results)\n"]))
  (string rewrite/verify-as-string
          (string/join forms "")))

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  # XXX: expected values are all large here -- not testing

  (def sample
    ``
    (comment

      (= 1 1)
      # => true

    )
    ``)

  (rewrite/rewrite-with-verify [{:value sample
                                 :s-line 1}])

  (def sample-comment-form
    ``
    (comment

      (def a 1)

      # this is just a comment

      (def b 2)

      (= 1 (- b a))
      # => true

    )
    ``)

  (rewrite/rewrite-with-verify [{:value sample-comment-form
                                 :s-line 1}])

  (def comment-in-comment
    ``
    (comment

      (comment

        (+ 1 1)
        # => 2

      )

    )
    ``)

  (rewrite/ewrite-with-verify [{:value comment-in-comment
                                :s-line 1}])

  )
(defn input/slurp-input
  [input]
  (var f nil)
  (if (= input "-")
    (set f stdin)
    (if (os/stat input)
      # XXX: handle failure?
      (set f (file/open input :rb))
      (do
        (eprint "path not found: " input)
        (break [nil nil]))))
  (file/read f :all))

(def args/params
  ["Rewrite comment blocks as tests."
   "debug" {:help "Debug output."
            :kind :flag
            :short "d"}
   "output" {:default ""
             :help "Path to store output to."
             :kind :option
             :short "o"}
   "version" {:default false
              :help "Version output."
              :kind :flag
              :short "v"}
   :default {:default "-"
             :help "Source path or - for STDIN."
             :kind :option}])

(comment

  (def file-path "./jg.janet")

  (deep=
    (do
      (setdyn :args ["jg" file-path])
      (argparse/argparse ;args/params))
    #
    @{"version" false
      "output" ""
      :order @[:default]
      :default file-path}) # => true

  )

(defn args/parse
  []
  (when-let [res (argparse/argparse ;args/params)]
    (let [input (res :default)
          # XXX: overwrites...dangerous?
          output (res "output")
          version (res "version")]
      (setdyn :debug (res "debug"))
      (assert input "Input should be filepath or -")
      {:input input
       :output output
       :version version})))

# XXX: consider `(break false)` instead of just `assert`?
(defn jg/handle-one
  [opts]
  (def {:input input
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
  # output rewritten content
  (buffer/blit buf (rewrite/rewrite-with-verify comment-blocks) -1)
  (if (not= "" output)
    (spit output buf)
    (print buf))
  true)

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (def file-path "./jg.janet")

  # output to stdout
  (jg/handle-one {:input file-path
               :output ""
               :single true})

  # output to file
  (jg/handle-one {:input file-path
               :output "/tmp/judge-gen-test-output.txt"
               :single true})

  )

(defn utils/print-color
  [msg color]
  (let [color-num (match color
                    :black 30
                    :blue 34
                    :cyan 36
                    :green 32
                    :magenta 35
                    :red 31
                    :white 37
                    :yellow 33)]
    (prin (string "\e[" color-num "m"
                  msg
                  "\e[0m"))))

(defn utils/dashes
  [&opt n]
  (default n 60)
  (string/repeat "-" n))

(defn utils/print-dashes
  [&opt n]
  (print (utils/dashes n)))

(defn utils/rand-string
  [n]
  (->> (os/cryptorand n)
       (map |(string/format "%02x" $))
       (string/join)))

(comment

  (let [len 8
        res (utils/rand-string len)]
    (truthy? (and (= (length res) (* 2 len))
                  # only uses hex
                  (all |(peg/find '(range "09" "af" "AF")
                                  (string/from-bytes $))
                       res))))
  # => true

  )

(defn jg-runner/make-judges
  [dir subdirs judge-root judge-file-prefix]
  (each path (os/dir dir)
    (def fpath (path/join dir path))
    (case (os/stat fpath :mode)
      :directory (do
                   (jg-runner/make-judges fpath (array/push subdirs path)
                                          judge-root judge-file-prefix)
                   (array/pop subdirs))
      :file (when (string/has-suffix? ".janet" fpath)
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

  (jg-runner/make-judges src-root @[] judge-root "judge-")

  )

(defn jg-runner/judge
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
      :directory (jg-runner/judge fpath results judge-root judge-file-prefix)
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

(defn jg-runner/summarize
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
  (print "all judgements made.")
  (= total-passed total-tests))

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (jg-runner/summarize @{})

  )

# XXX: consider `(break false)` instead of just `assert`?
(defn jg-runner/handle-one
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
  (jg-runner/make-judges src-root @[] judge-root judge-file-prefix)
  # judge
  (print "judging...")
  (var results @{})
  (jg-runner/judge judge-root results judge-root judge-file-prefix)
  (utils/print-dashes)
  (print)
  # summarize results
  (jg-runner/summarize results))

# XXX: since there are no tests in this comment block, nothing will execute
(comment

  (def proj-root
    (path/join (os/getenv "HOME")
               "src" "judge-gen"))

  (def src-root
    (path/join proj-root "judge-gen"))

  (jg-runner/handle-one {:judge-dir-name "judge"
                         :judge-file-prefix "judge-"
                         :proj-root proj-root
                         :src-root src-root})

  )


# from the perspective of `jpm test`
(def proj-root
  (path/abspath "."))

(defn src-root
  [src-dir-name]
  (path/join proj-root src-dir-name))

(let [all-passed (jg-runner/handle-one
                   {:judge-dir-name judge-dir-name
                    :judge-file-prefix judge-file-prefix
                    :proj-root proj-root
                    :src-root (src-root src-dir-name)})]
  (when (not all-passed)
    (os/exit 1))
  (when silence-jpm-test
    (os/exit 1)))
