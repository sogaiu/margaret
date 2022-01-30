# usages-as-tests

# includes various portions of (or inspiration from) bakpakin's:
#
# * helper.janet
# * jpm
# * path.janet
# * peg for janet

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

(defn display/print-color
  [msg color]
  # XXX: what if color doesn't match...
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

(defn display/dashes
  [&opt n]
  (default n 60)
  (string/repeat "-" n))

(defn display/print-dashes
  [&opt n]
  (print (display/dashes n)))

(defn display/print-form
  [form &opt color]
  (def buf @"")
  (with-dyns [:out buf]
    (printf "%m" form))
  (def msg (string/trimr buf))
  (print ":")
  (if color
    (display/print-color msg color)
    (prin msg))
  (print))
# some bits from jpm

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
  (os/execute args :px))

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

(defn jpm/create-dirs
  "Create all directories needed for a file (mkdir -p)."
  [dest]
  (def segs (peg/match jpm/path-splitter dest))
  (for i 1 (length segs)
    (def path (string/join (slice segs 0 i) jpm/sep))
    (unless (empty? path) (os/mkdir path))))

(defn jpm/copy-continue
  "Copy a file or directory recursively from one location to another."
  [src dest]
  (print "copying " src " to " dest "...")
  (if jpm/is-win
    (let [end (last (peg/match jpm/path-splitter src))
          isdir (= (os/stat src :mode) :directory)]
      (jpm/shell "C:\\Windows\\System32\\xcopy.exe"
                 (string/replace "/" "\\" src)
                 (string/replace "/" "\\" (if isdir (string dest "\\" end) dest))
                 "/y" "/s" "/e" "/i" "/c"))
    (jpm/shell "cp" "-rf" src dest)))
(defn input/slurp-input
  [input]
  (var f nil)
  (try
    (if (= input "-")
      (set f stdin)
      (if (os/stat input)
        (set f (file/open input :rb))
        (do
          (eprint "path not found: " input)
          (break nil))))
    ([err]
      (eprintf "slurp-input failed")
      (error err)))
  #
  (var buf nil)
  (defer (file/close f)
    (set buf @"")
    (file/read f :all buf))
  buf)
(def name/prog-name
  "usages-as-tests")

(def name/dot-dir-name
  ".uat_usages-as-tests")
# bl - begin line
# bc - begin column
# el - end line
# ec - end column
(defn make-attrs
  [& items]
  (zipcoll [:bl :bc :el :ec]
           items))

(defn atom-node
  [node-type peg-form]
  ~(cmt (capture (sequence (line) (column)
                           ,peg-form
                           (line) (column)))
        ,|[node-type (make-attrs ;(slice $& 0 -2)) (last $&)]))

(defn reader-macro-node
  [node-type sigil]
  ~(cmt (capture (sequence (line) (column)
                           ,sigil
                           (any :non-form)
                           :form
                           (line) (column)))
        ,|[node-type (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
           ;(slice $& 2 -4)]))

(defn collection-node
  [node-type open-delim close-delim]
  ~(cmt
     (capture
       (sequence
         (line) (column)
         ,open-delim
         (any :input)
         (choice ,close-delim
                 (error
                   (replace (sequence (line) (column))
                            ,|(string/format
                                "line: %p column: %p missing %p for %p"
                                $0 $1 close-delim node-type))))
         (line) (column)))
     ,|[node-type (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
        ;(slice $& 2 -4)]))

(def loc-grammar
  ~{:main (sequence (line) (column)
                    (some :input)
                    (line) (column))
    #
    :input (choice :non-form
                   :form)
    #
    :non-form (choice :whitespace
                      :comment)
    #
    :whitespace ,(atom-node :whitespace
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
    :comment ,(atom-node :comment
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
    :fn ,(reader-macro-node :fn "|")
    # :fn (cmt (capture (sequence (line) (column)
    #                             "|"
    #                             (any :non-form)
    #                             :form
    #                             (line) (column)))
    #          ,|[:fn (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
    #             ;(slice $& 2 -4)])
    #
    :quasiquote ,(reader-macro-node :quasiquote "~")
    #
    :quote ,(reader-macro-node :quote "'")
    #
    :splice ,(reader-macro-node :splice ";")
    #
    :unquote ,(reader-macro-node :unquote ",")
    #
    :array ,(collection-node :array "@(" ")")
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
    :tuple ,(collection-node :tuple "(" ")")
    #
    :bracket-array ,(collection-node :bracket-array "@[" "]")
    #
    :bracket-tuple ,(collection-node :bracket-tuple "[" "]")
    #
    :table ,(collection-node :table "@{" "}")
    #
    :struct ,(collection-node :struct "{" "}")
    #
    :number ,(atom-node :number
                        ~(drop (cmt
                                 (capture (some :name-char))
                                 ,scan-number)))
    #
    :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                       (set "!$%&*+-./:<?=>@^_"))
    #
    :constant ,(atom-node :constant
                          '(choice "false" "nil" "true"))
    #
    :buffer ,(atom-node :buffer
                        '(sequence `@"`
                                   (any (choice :escape
                                                (if-not "\"" 1)))
                                   `"`))
    #
    :escape (sequence "\\"
                      (choice (set "0efnrtvz\"\\")
                              (sequence "x" (2 :h))
                              (sequence "u" (4 :h))
                              (sequence "U" (6 :h))
                              (error (constant "bad escape"))))
    #
    :string ,(atom-node :string
                        '(sequence `"`
                                   (any (choice :escape
                                                (if-not "\"" 1)))
                                   `"`))
    #
    :long-string ,(atom-node :long-string
                             :long-bytes)
    #
    :long-bytes {:main (drop (sequence :open
                                       (any (if-not :close 1))
                                       :close))
                 :open (capture :delim :n)
                 :delim (some "`")
                 :close (cmt (sequence (not (look -1 "`"))
                                       (backref :n)
                                       (capture :delim))
                             ,=)}
    #
    :long-buffer ,(atom-node :long-buffer
                             '(sequence "@" :long-bytes))
    #
    :keyword ,(atom-node :keyword
                         '(sequence ":"
                                    (any :name-char)))
    #
    :symbol ,(atom-node :symbol
                        '(some :name-char))
    })

(comment

  (get (peg/match loc-grammar " ") 2)
  # =>
  '(:whitespace @{:bc 1 :bl 1 :ec 2 :el 1} " ")

  (get (peg/match loc-grammar "# hi there") 2)
  # =>
  '(:comment @{:bc 1 :bl 1 :ec 11 :el 1} "# hi there")

  (get (peg/match loc-grammar "8.3") 2)
  # =>
  '(:number @{:bc 1 :bl 1 :ec 4 :el 1} "8.3")

  (get (peg/match loc-grammar "printf") 2)
  # =>
  '(:symbol @{:bc 1 :bl 1 :ec 7 :el 1} "printf")

  (get (peg/match loc-grammar ":smile") 2)
  # =>
  '(:keyword @{:bc 1 :bl 1 :ec 7 :el 1} ":smile")

  (get (peg/match loc-grammar `"fun"`) 2)
  # =>
  '(:string @{:bc 1 :bl 1 :ec 6 :el 1} "\"fun\"")

  (get (peg/match loc-grammar "``long-fun``") 2)
  # =>
  '(:long-string @{:bc 1 :bl 1 :ec 13 :el 1} "``long-fun``")

  (get (peg/match loc-grammar "@``long-buffer-fun``") 2)
  # =>
  '(:long-buffer @{:bc 1 :bl 1 :ec 21 :el 1} "@``long-buffer-fun``")

  (get (peg/match loc-grammar `@"a buffer"`) 2)
  # =>
  '(:buffer @{:bc 1 :bl 1 :ec 12 :el 1} "@\"a buffer\"")

  (get (peg/match loc-grammar "@[8]") 2)
  # =>
  '(:bracket-array @{:bc 1 :bl 1
                     :ec 5 :el 1}
                   (:number @{:bc 3 :bl 1
                              :ec 4 :el 1} "8"))

  (get (peg/match loc-grammar "@{:a 1}") 2)
  # =>
  '(:table @{:bc 1 :bl 1
             :ec 8 :el 1}
           (:keyword @{:bc 3 :bl 1
                       :ec 5 :el 1} ":a")
           (:whitespace @{:bc 5 :bl 1
                          :ec 6 :el 1} " ")
           (:number @{:bc 6 :bl 1
                      :ec 7 :el 1} "1"))

  (get (peg/match loc-grammar "~x") 2)
  # =>
  '(:quasiquote @{:bc 1 :bl 1
                  :ec 3 :el 1}
                (:symbol @{:bc 2 :bl 1
                           :ec 3 :el 1} "x"))

  )

(def loc-top-level-ast
  (let [ltla (table ;(kvs loc-grammar))]
    (put ltla
         :main ~(sequence (line) (column)
                          :input
                          (line) (column)))
    (table/to-struct ltla)))

(defn ast
  [src &opt start single]
  (default start 0)
  (if single
    (if-let [[bl bc tree el ec]
             (peg/match loc-top-level-ast src start)]
      @[:code (make-attrs bl bc el ec) tree]
      @[:code])
    (if-let [captures (peg/match loc-grammar src start)]
      (let [[bl bc] (slice captures 0 2)
            [el ec] (slice captures -3)
            trees (array/slice captures 2 -3)]
        (array/insert trees 0
                      :code (make-attrs bl bc el ec)))
      @[:code])))

(comment

  (ast "(+ 1 1)")
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

(defn code*
  [an-ast buf]
  (case (first an-ast)
    :code
    (each elt (drop 2 an-ast)
      (code* elt buf))
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
        (code* elt buf))
      (buffer/push-string buf ")"))
    :bracket-array
    (do
      (buffer/push-string buf "@[")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "]"))
    :bracket-tuple
    (do
      (buffer/push-string buf "[")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "]"))
    :tuple
    (do
      (buffer/push-string buf "(")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf ")"))
    :struct
    (do
      (buffer/push-string buf "{")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "}"))
    :table
    (do
      (buffer/push-string buf "@{")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "}"))
    #
    :fn
    (do
      (buffer/push-string buf "|")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :quasiquote
    (do
      (buffer/push-string buf "~")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :quote
    (do
      (buffer/push-string buf "'")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :splice
    (do
      (buffer/push-string buf ";")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :unquote
    (do
      (buffer/push-string buf ",")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    ))

(defn code
  [an-ast]
  (let [buf @""]
    (code* an-ast buf)
    # XXX: leave as buffer?
    (string buf)))

(comment

  (code
    [:code])
  # =>
  ""

  (code
    '(:whitespace @{:bc 1 :bl 1
                    :ec 2 :el 1} " "))
  # =>
  " "


  (code
    '(:buffer @{:bc 1 :bl 1
                :ec 12 :el 1} "@\"a buffer\""))
  # =>
  `@"a buffer"`

  (code
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

  (let [src "{:x  :y \n :z  [:a  :b    :c]}"]
    (deep= (code (ast src))
           src))
  # => true

  )

(comment

  (comment

    (let [src (slurp (string (os/getenv "HOME")
                             "/src/janet/src/boot/boot.janet"))]
      (= (string src)
         (code (ast src))))

    )

  )

(def l/ast ast)
(def l/code code)
# based on code by corasaurus-hex

# based on code by corasaurus-hex

# `slice` doesn't necessarily preserve the input type

# XXX: differs from clojure's behavior
#      e.g. (butlast [:a]) would yield nil(?!) in clojure
(defn butlast
  [indexed]
  (if (empty? indexed)
    nil
    (if (tuple? indexed)
      (tuple/slice indexed 0 -2)
      (array/slice indexed 0 -2))))

(comment

  (butlast @[:a :b :c])
  # =>
  @[:a :b]

  (butlast [:a])
  # =>
  []

  )

(defn rest
  [indexed]
  (if (empty? indexed)
    nil
    (if (tuple? indexed)
      (tuple/slice indexed 1 -1)
      (array/slice indexed 1 -1))))

(comment

  (rest [:a :b :c])
  # =>
  [:b :c]

  (rest @[:a])
  # =>
  @[]

  )

# XXX: can pass in array - will get back tuple
(defn tuple-push
  [tup x & xs]
  (if tup
    [;tup x ;xs]
    [x ;xs]))

(comment

  (tuple-push [:a :b] :c)
  # =>
  [:a :b :c]

  (tuple-push nil :a)
  # =>
  [:a]

  (tuple-push @[] :a)
  # =>
  [:a]

  )

(defn to-entries
  [val]
  (if (dictionary? val)
    (pairs val)
    val))

(comment

  (to-entries {:a 1 :b 2})
  # =>
  @[[:a 1] [:b 2]]

  (to-entries {})
  # =>
  @[]

  (to-entries @{:a 1})
  # =>
  @[[:a 1]]

  # XXX: leaving non-dictionaries alone and passing through...
  #      is this desirable over erroring?
  (to-entries [:a :b :c])
  # =>
  [:a :b :c]

  )

# XXX: when xs is empty, "all" becomes nil
(defn first-rest-maybe-all
  [xs]
  (if (or (nil? xs) (empty? xs))
    [nil nil nil]
    [(first xs) (rest xs) xs]))

(comment

  (first-rest-maybe-all [:a :b])
  # =>
  [:a [:b] [:a :b]]

  (first-rest-maybe-all @[:a])
  # =>
  [:a @[] @[:a]]

  (first-rest-maybe-all [])
  # =>
  [nil nil nil]

  # XXX: is this what we want?
  (first-rest-maybe-all nil)
  # =>
  [nil nil nil]

  )

(def s/butlast butlast)
(def s/rest rest)
(def s/tuple-push tuple-push)
(def s/to-entries to-entries)
(def s/first-rest-maybe-all first-rest-maybe-all)

(defn zipper
  ``
  Returns a new zipper consisting of two elements:

  * `root` - the passed in root node.

  * `state` - table of info about node's z-location in the tree with keys:

    * `:ls` - left siblings

    * `:pnodes` - path of nodes from root to current z-location

    * `:pstate` - parent node's state

    * `:rs` - right siblings

    * `:changed?` - indicates whether "editing" has occured

  * `state` has a prototype table with four functions:

    * :branch? - fn that tests if a node is a branch (has children)

    * :children - fn that returns the child nodes for the given branch.

    * :make-node - fn that takes a node + children and returns a new branch
                   node with the same.

    * :make-state - fn for creating a new state
  ``
  [root &keys {:branch? branch?
               :children children
               :make-node make-node}]
  #
  (defn make-state
    [&opt ls rs pnodes pstate changed?]
    (table/setproto @{:ls ls
                      :pnodes pnodes
                      :pstate pstate
                      :rs rs
                      :changed? changed?}
                    @{:branch? branch?
                      :children children
                      :make-node make-node
                      :make-state make-state}))
  #
  [root (make-state)])

(comment

  # XXX

  )

(defn zip
  ``
  Returns a zipper for nested sequences (tuple/array/table/struct),
  given a root sequence.
  ``
  [sequence]
  (zipper sequence
          :branch? |(or (dictionary? $) (indexed? $))
          :children s/to-entries
          :make-node (fn [p xs] xs)))

(comment

  (def a-node
    [:x [:y :z]])

  (def [the-node the-state]
    (zip a-node))

  the-node
  # =>
  a-node

  # merge is used to "remove" the prototype table of `st`
  (merge {} the-state)
  # =>
  @{}

  )

(defn node
  "Returns the node at `zloc`."
  [zloc]
  (zloc 0))

(comment

  (node (zip [:a :b [:x :y]]))
  # =>
  [:a :b [:x :y]]

  )

(defn state
  "Returns the state for `zloc`."
  [zloc]
  (zloc 1))

(comment

  # merge is used to "remove" the prototype table of `st`
  (merge {}
         (-> (zip [:a [:b [:x :y]]])
             state))
  # =>
  @{}

  )

(defn branch?
  ``
  Returns true if the node at `zloc` is a branch.
  Returns false otherwise.
  ``
  [zloc]
  (((state zloc) :branch?) (node zloc)))

(comment

  (branch? (zip [:a :b [:x :y]]))
  # =>
  true

  )

(defn children
  ``
  Returns children for a branch node at `zloc`.
  Otherwise throws an error.
  ``
  [zloc]
  (if (branch? zloc)
    (((state zloc) :children) (node zloc))
    (error "Called `children` on a non-branch zloc")))

(comment

 (children (zip [:a :b [:x :y]]))
  # =>
  [:a :b [:x :y]]

  )

(defn make-state
  ``
  Convenience function for calling the :make-state function for `zloc`.
  ``
  [zloc &opt ls rs pnodes pstate changed?]
  (((state zloc) :make-state) ls rs pnodes pstate changed?))

(comment

  # merge is used to "remove" the prototype table of `st`
  (merge {}
         (make-state (zip [:a :b [:x :y]])))
  # =>
  @{}

  )

(defn down
  ``
  Moves down the tree, returning the leftmost child z-location of
  `zloc`, or nil if there are no children.
  ``
  [zloc]
  (when (branch? zloc)
    (let [[node st] zloc
          [k rest-kids kids]
          (s/first-rest-maybe-all (children zloc))]
      (when kids
        [k
         (make-state zloc
                     []
                     rest-kids
                     (if (not (empty? st))
                       (s/tuple-push (st :pnodes) node)
                       [node])
                     st
                     (st :changed?))]))))

(comment

  (node (down (zip [:a :b [:x :y]])))
  # =>
  :a

  (-> (zip [:a :b [:x :y]])
      down
      branch?)
  # =>
  false

  (try
    (-> (zip [:a])
        down
        children)
    ([e] e))
  # =>
  "Called `children` on a non-branch zloc"

  (deep=
    #
    (merge {}
           (-> [:a [:b [:x :y]]]
               zip
               down
               state))
    #
    '@{:ls ()
       :pnodes ((:a (:b (:x :y))))
       :pstate @{}
       :rs ((:b (:x :y)))})
  # =>
  true

  )

(defn right
  ``
  Returns the z-location of the right sibling of the node
  at `zloc`, or nil if there is no such sibling.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} st
        [r rest-rs rs] (s/first-rest-maybe-all rs)]
    (when (and (not (empty? st)) rs)
      [r
       (make-state zloc
                   (s/tuple-push ls node)
                   rest-rs
                   (st :pnodes)
                   (st :pstate)
                   (st :changed?))])))

(comment

  (-> (zip [:a :b])
      down
      right
      node)
  # =>
  :b

  (-> (zip [:a])
      down
      right)
  # =>
  nil

  )

(defn make-node
  ``
  Returns a branch node, given `zloc`, `node` and `children`.
  ``
  [zloc node children]
  (((state zloc) :make-node) node children))

(comment

  (make-node (zip [:a :b [:x :y]])
             [:a :b] [:x :y])
  # =>
  [:x :y]

  )

(defn up
  ``
  Moves up the tree, returning the parent z-location of `zloc`,
  or nil if at the root z-location.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls
         :pnodes pnodes
         :pstate pstate
         :rs rs
         :changed? changed?} st]
    (when pnodes
      (let [pnode (last pnodes)]
        (if changed?
          [(make-node zloc pnode [;ls node ;rs])
           (make-state zloc
                       (pstate :ls)
                       (pstate :rs)
                       (pstate :pnodes)
                       (pstate :pstate)
                       true)]
          [pnode pstate])))))

(comment

  (def m-zip
    (zip [:a :b [:x :y]]))

  (deep=
    (-> m-zip
        down
        up)
    m-zip)
  # =>
  true

  (deep=
    (-> m-zip
        down
        right
        right
        down
        up
        up)
    m-zip)
  # =>
  true

  )

# XXX: used by `root` and `df-next`
(defn end?
  "Returns true if `zloc` represents the end of a depth-first walk."
  [zloc]
  (= :end (state zloc)))

(defn root
  ``
  Moves all the way up the tree for `zloc` and returns the node at
  the root z-location.
  ``
  [zloc]
  (if (end? zloc)
    (node zloc)
    (if-let [p (up zloc)]
      (root p)
      (node zloc))))

(comment

  (def a-zip
    (zip [:a :b [:x :y]]))

  (node a-zip)
  # =>
  (-> a-zip
      down
      right
      right
      down
      root)

  )

(defn df-next
  ``
  Moves to the next z-location, depth-first.  When the end is
  reached, returns a special z-location detectable via `end?`.
  Does not move if already at the end.
  ``
  [zloc]
  #
  (defn recur
    [loc]
    (if (up loc)
      (or (right (up loc))
          (recur (up loc)))
      [(node loc) :end]))
  #
  (if (end? zloc)
    zloc
    (or (and (branch? zloc) (down zloc))
        (right zloc)
        (recur zloc))))

(comment

  (def a-zip
    (zip [:a :b [:x]]))

  (node (df-next a-zip))
  # =>
  :a

  (-> a-zip
      df-next
      df-next
      node)
  # =>
  :b

  (-> a-zip
      df-next
      df-next
      df-next
      df-next
      df-next
      end?)
  # =>
  true

  )

(defn replace
  "Replaces existing node at `zloc` with `node`, without moving."
  [zloc node]
  (let [[_ st] zloc]
    [node
     (make-state zloc
                 (st :ls)
                 (st :rs)
                 (st :pnodes)
                 (st :pstate)
                 true)]))

(comment

  (-> (zip [:a :b [:x :y]])
      down
      (replace :w)
      root)
  # =>
  [:w :b [:x :y]]

  (-> (zip [:a :b [:x :y]])
      down
      right
      right
      down
      (replace :w)
      root)
  # =>
  [:a :b [:w :y]]

  )

(defn edit
  ``
  Replaces the node at `zloc` with the value of `(f node args)`,
   where `node` is the node associated with `zloc`.
  ``
  [zloc f & args]
  (replace zloc
           (apply f (node zloc) args)))

(comment

  (-> (zip [1 2 [8 9]])
      down
      (edit inc)
      root)
  # =>
  [2 2 [8 9]]

  )

(defn insert-child
  ``
  Inserts `child` as the leftmost child of the node at `zloc`,
  without moving.
  ``
  [zloc child]
  (replace zloc
           (make-node zloc
                      (node zloc)
                      [child ;(children zloc)])))

(comment

  (-> (zip [:a :b [:x :y]])
      (insert-child :c)
      root)
  # =>
  [:c :a :b [:x :y]]

  )

(defn append-child
  ``
  Appends `child` as the rightmost child of the node at `zloc`,
  without moving.
  ``
  [zloc child]
  (replace zloc
           (make-node zloc
                      (node zloc)
                      [;(children zloc) child])))

(comment

  (-> (zip [:a :b [:x :y]])
      (append-child :c)
      root)
  # =>
  [:a :b [:x :y] :c]

  )

(defn rightmost
  ``
  Returns the z-location of the rightmost sibling of the node at
  `zloc`, or the current node's z-location if there are none to the
  right.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} st]
    (if (and (not (empty? st))
             (indexed? rs)
             (not (empty? rs)))
      [(last rs)
       (make-state zloc
                   (s/tuple-push ls node ;(s/butlast rs))
                   []
                   (st :pnodes)
                   (st :pstate)
                   (st :changed?))]
      zloc)))

(comment

  (-> (zip [:a :b [:x :y]])
      down
      rightmost
      node)
  # =>
  [:x :y]

  )

(defn remove
  ``
  Removes the node at `zoc`, returning the z-location that would have
  preceded it in a depth-first walk.
  Throws an error if called at the root z-location.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls
         :pnodes pnodes
         :pstate pstate
         :rs rs} st]
    #
    (defn recur
      [a-zloc]
      (if-let [child (and (branch? a-zloc) (down a-zloc))]
        (recur (rightmost child))
        a-zloc))
    #
    (if (not (empty? st))
      (if (pos? (length ls))
        (recur [(last ls)
                (make-state zloc
                            (s/butlast ls)
                            rs
                            pnodes
                            pstate
                            true)])
        [(make-node zloc (last pnodes) rs)
         (make-state zloc
                     (pstate :ls)
                     (pstate :rs)
                     (pstate :pnodes)
                     (pstate :pstate)
                     true)])
      (error "Called `remove` at root"))))

(comment

  (-> (zip [:a :b [:x :y]])
      down
      right
      remove
      node)
  # =>
  :a

  (try
    (remove (zip [:a :b [:x :y]]))
    ([e] e))
  # =>
  "Called `remove` at root"

  )

(defn left
  ``
  Returns the z-location of the left sibling of the node
  at `zloc`, or nil if there is no such sibling.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} st]
    (when (and (not (empty? st))
               (indexed? ls)
               (not (empty? ls)))
      [(last ls)
       (make-state zloc
                   (s/butlast ls)
                   [node ;rs]
                   (st :pnodes)
                   (st :pstate)
                   (st :changed?))])))

(comment

  (-> (zip [:a :b :c])
      down
      right
      right
      left
      node)
  # =>
  :b

  (-> (zip [:a])
      down
      left)
  # =>
  nil

  )

(defn df-prev
  ``
  Moves to the previous z-location, depth-first.
  If already at the root, returns nil.
  ``
  [zloc]
  #
  (defn recur
    [a-zloc]
    (if-let [child (and (branch? a-zloc)
                        (down a-zloc))]
      (recur (rightmost child))
      a-zloc))
  #
  (if-let [left-loc (left zloc)]
    (recur left-loc)
    (up zloc)))

(comment

  (-> (zip [:a :b [:x :y]])
      down
      right
      df-prev
      node)
  # =>
  :a

  (-> (zip [:a :b [:x :y]])
      down
      right
      right
      down
      df-prev
      node)
  # =>
  [:x :y]

  )

(defn insert-right
  ``
  Inserts `a-node` as the right sibling of the node at `zloc`,
  without moving.
  ``
  [zloc a-node]
  (let [[node st] zloc
        {:ls ls :rs rs} st]
    (if (not (empty? st))
      [node
       (make-state zloc
                   ls
                   [a-node ;rs]
                   (st :pnodes)
                   (st :pstate)
                   true)]
      (error "Called `insert-right` at root"))))

(comment

  (def a-zip
    (zip [:a :b [:x :y]]))

  (-> a-zip
      down
      (insert-right :z)
      root)
  # =>
  [:a :z :b [:x :y]]

  (try
    (insert-right a-zip :e)
    ([e] e))
  # =>
  "Called `insert-right` at root"

  )

(defn insert-left
  ``
  Inserts `a-node` as the left sibling of the node at `zloc`,
  without moving.
  ``
  [zloc a-node]
  (let [[node st] zloc
        {:ls ls :rs rs} st]
    (if (not (empty? st))
      [node
       (make-state zloc
                   (s/tuple-push ls a-node)
                   rs
                   (st :pnodes)
                   (st :pstate)
                   true)]
      (error "Called `insert-left` at root"))))

(comment

  (def a-zip
    (zip [:a :b [:x :y]]))

  (-> a-zip
      down
      (insert-left :z)
      root)
  # =>
  [:z :a :b [:x :y]]

  (try
    (insert-left a-zip :e)
    ([e] e))
  # =>
  "Called `insert-left` at root"

  )

(defn rights
  "Returns siblings to the right of `zloc`."
  [zloc]
  (when-let [st (state zloc)]
    (st :rs)))

(comment

  (-> (zip [:a :b [:x :y]])
      down
      rights)
  # =>
  [:b [:x :y]]

  )

(defn lefts
  "Returns siblings to the left of `zloc`."
  [zloc]
  (if-let [st (state zloc)
           ls (st :ls)]
    ls
    []))

(comment

  (-> (zip [:a :b])
      down
      lefts)
  # =>
  []

  (-> (zip [:a :b [:x :y]])
      down
      right
      right
      lefts)
  # =>
  [:a :b]

  )

(defn leftmost
  ``
  Returns the z-location of the leftmost sibling of the node at `zloc`,
  or the current node's z-location if there are no siblings to the left.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} st]
    (if (and (not (empty? st))
             (indexed? ls)
             (not (empty? ls)))
      [(first ls)
       (make-state zloc
                   []
                   [;(s/rest ls) node ;rs]
                   (st :pnodes)
                   (st :pstate)
                   (st :changed?))]
      zloc)))

(comment

  (-> (zip [:a :b [:x :y]])
      down
      leftmost
      node)
  # =>
  :a

  (-> (zip [:a :b [:x :y]])
      down
      rightmost
      leftmost
      node)
  # =>
  :a

  )

(defn path
  "Returns the path of nodes that lead to `zloc` from the root node."
  [zloc]
  (when-let [st (state zloc)]
    (st :pnodes)))

(comment

  (path (zip [:a :b [:x :y]]))
  # =>
  nil

  (-> (zip [:a :b [:x :y]])
      down
      path)
  # =>
  [[:a :b [:x :y]]]

  (-> (zip [:a :b [:x :y]])
      down
      right
      right
      down
      path)
  # =>
  [[:a :b [:x :y]] [:x :y]]

 )

(defn right-until
  ``
  Try to move right from `zloc`, calling `pred` for each
  right sibling.  If the `pred` call has a truthy result,
  return the corresponding right sibling.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when-let [right-sib (right zloc)]
    (if (pred right-sib)
      right-sib
      (right-until right-sib pred))))

(comment

  (-> [:code
       [:tuple
        [:comment "# hi there"] [:whitespace "\n"]
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      zip
      down
      right
      down
      (right-until |(match (node $)
                      [:comment]
                      false
                      #
                      [:whitespace]
                      false
                      #
                      true))
      node)
  # =>
  [:symbol "+"]

  )

(defn search-from
  ``
  Successively call `pred` on z-locations starting at `zloc`
  in depth-first order.  If a call to `pred` returns a
  truthy value, return the corresponding z-location.
  Otherwise, return nil.
  ``
  [zloc pred]
  (if (pred zloc)
    zloc
    (when-let [next-zloc (df-next zloc)]
      (when (end? next-zloc)
        (break nil))
      (search-from next-zloc pred))))

(comment

  (-> (zip [:a :b :c])
      down
      (search-from |(match (node $)
                      :b
                      true))
      node)
  # =>
  :b

  (-> (zip [:a :b :c])
      down
      (search-from |(match (node $)
                      :d
                      true)))
  # =>
  nil

  (-> (zip [:a :b :c])
      down
      (search-from |(match (node $)
                      :a
                      true))
      node)
  # =>
  :a

  )

(defn search-after
  ``
  Successively call `pred` on z-locations starting after
  `zloc` in depth-first order.  If a call to `pred` returns a
  truthy value, return the corresponding z-location.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when (end? zloc)
    (break nil))
  (when-let [next-zloc (df-next zloc)]
    (if (pred next-zloc)
      next-zloc
      (search-after next-zloc pred))))

(comment

  (-> (zip [:b :a :b])
      down
      (search-after |(match (node $)
                       :b
                       true))
      left
      node)
  # =>
  :a

  (-> (zip [:b :a :b])
      down
      (search-after |(match (node $)
                       :d
                       true)))
  # =>
  nil

  (-> (zip [:a [:b :c [2 [3 :smile] 5]]])
      (search-after |(match (node $)
                       [_ :smile]
                       true))
      down
      node)
  # =>
  3

  )

(defn unwrap
  ``
  If the node at `zloc` is a branch node, "unwrap" its children in
  place.  If `zloc`'s node is not a branch node, do nothing.

  Throws an error if `zloc` corresponds to a top-most container.
  ``
  [zloc]
  (unless (branch? zloc)
    (break zloc))
  #
  (when (empty? (state zloc))
    (error "Called `unwrap` at root"))
  #
  (def kids (children zloc))
  (var i (dec (length kids)))
  (var curr-zloc zloc)
  (while (<= 0 i) # right to left
    (set curr-zloc
         (insert-right curr-zloc (get kids i)))
    (-- i))
  # try to end up at a sensible spot
  (set curr-zloc
       (remove curr-zloc))
  (if-let [ret-zloc (right curr-zloc)]
    ret-zloc
    curr-zloc))

(comment

  (-> (zip [:a :b [:x :y]])
      down
      right
      right
      unwrap
      root)
  # =>
  [:a :b :x :y]

  (-> (zip [:a :b [:x :y]])
      down
      unwrap
      root)
  # =>
  [:a :b [:x :y]]

  (-> (zip [[:a]])
      down
      unwrap
      root)
  # =>
  [:a]

  (-> (zip [[:a :b] [:x :y]])
      down
      down
      remove
      unwrap
      root)
  # =>
  [:b [:x :y]]

  (try
    (-> (zip [:a :b [:x :y]])
        unwrap)
    ([e] e))
  # =>
  "Called `unwrap` at root"

  )

(defn wrap
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
              (not (deep= (node cur-zloc)
                          (node end-zloc)))) # left to right
    (array/push kids (node cur-zloc))
    (set cur-zloc (right cur-zloc)))
  (when (nil? cur-zloc)
    (error "Called `wrap` with invalid value for `end-zloc`."))
  # also collect the last node
  (array/push kids (node end-zloc))
  #
  # 2. replace locations that will be removed with non-container nodes
  #
  (def dummy-node
    (make-node start-zloc wrap-node (tuple)))
  (set cur-zloc start-zloc)
  # trying to do this together in step 1 is not straight-forward
  # because the desired exiting condition for the while loop depends
  # on cur-zloc becomnig end-zloc -- if `replace` were to be used
  # there, the termination condition never gets fulfilled properly.
  (for i 0 (dec (length kids)) # left to right again
    (set cur-zloc
         (-> (replace cur-zloc dummy-node)
             right)))
  (set cur-zloc
       (replace cur-zloc dummy-node))
  #
  # 3. remove all relevant locations
  #
  (def new-node
    (make-node start-zloc wrap-node (tuple ;kids)))
  (for i 0 (dec (length kids)) # right to left
    (set cur-zloc
         (remove cur-zloc)))
  # 4. put the new container node into place
  (replace cur-zloc new-node))

(comment

  (def start-zloc
    (-> (zip [:a [:b] :c :x])
        down
        right))

  (node start-zloc)
  # =>
  [:b]

  (-> (wrap start-zloc [])
      root)
  # =>
  [:a [[:b]] :c :x]

  (def end-zloc
    (right start-zloc))

  (node end-zloc)
  # =>
  :c

  (-> (wrap start-zloc [] end-zloc)
      root)
  # =>
  [:a [[:b] :c] :x]

  (try
    (-> (wrap end-zloc [] start-zloc)
        root)
    ([e] e))
  # =>
  "Called `wrap` with invalid value for `end-zloc`."

  )

(def z/down down)
(def z/left left)
(def z/node node)
(def z/right right)
(def z/unwrap unwrap)
(def z/zip zip)
(def z/zipper zipper)

(defn has-children?
  ``
  Returns true if `node` can have children.
  Returns false if `node` cannot have children.
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

  (has-children?
    [:tuple @{}
     [:symbol @{} "+"] [:whitespace @{} " "]
     [:number @{} "1"] [:whitespace @{} " "]
     [:number @{} "2"]])
  # =>
  true

  (has-children? [:number @{} "8"])
  # =>
  false

  )

(defn zip
  ``
  Returns a zipper location (zloc or z-location) for a tree
  representing Janet code.
  ``
  [tree]
  (defn branch?
    [a-node]
    (truthy? (and (indexed? a-node)
                  (not (empty? a-node))
                  (has-children? a-node))))
  #
  (defn children
    [a-node]
    (if (branch? a-node)
      (slice a-node 2)
      (error "Called `children` on a non-branch node")))
  #
  (defn make-node
    [a-node children]
    [(first a-node) @{} ;children])
  #
  (z/zipper tree
            :branch? branch?
            :children children
            :make-node make-node))

(comment

  (def root-node
    @[:code @{} [:number @{} "8"]])

  (def [the-node the-state]
    (zip root-node))

  the-node
  # =>
  root-node

  (merge {} the-state)
  # =>
  @{}

  )

(defn attrs
  ``
  Return the attributes table for the node of a z-location.  The
  attributes table contains at least bounds of the node by 1-based line
  and column numbers.
  ``
  [zloc]
  (get (z/node zloc) 1))

(comment

  (type (import ./location :as l))
  # =>
  :table

  )

(comment

  (-> (l/ast "(+ 1 3)")
      zip
      z/down
      attrs)
  # =>
  @{:bc 1 :bl 1 :ec 8 :el 1}

  )

(defn zip-down
  ``
  Convenience function that returns a zipper which has
  already had `down` called on it.
  ``
  [tree]
  (-> (zip tree)
      z/down))

(comment

  #(import ./location :as l)

  (-> (l/ast "(+ 1 3)")
      zip-down
      z/node)
  # =>
  '(:tuple @{:bc 1 :bl 1
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
                      :ec 7 :el 1} "3"))

  )

(defn right-until
  ``
  Try to move right from `zloc`, calling `pred` for each
  right sibling.  If the `pred` call has a truthy result,
  return the corresponding right sibling.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when-let [right-sib (z/right zloc)]
    (if (pred right-sib)
      right-sib
      (right-until right-sib pred))))

(comment

  (-> [:code @{}
       [:tuple @{}
        [:comment @{} "# hi there"] [:whitespace @{} "\n"]
        [:symbol @{} "+"] [:whitespace @{} " "]
        [:number @{} "1"] [:whitespace @{} " "]
        [:number @{} "2"]]]
      zip-down
      z/down
      (right-until |(match (z/node $)
                      [:comment]
                      false
                      #
                      [:whitespace]
                      false
                      #
                      true))
      z/node)
  # =>
  [:symbol @{} "+"]

  (-> [:code @{}
       [:tuple @{}
        [:keyword @{} ":a"]]]
      zip-down
      z/down
      (right-until |(match (z/node $)
                      [:comment]
                      false
                      #
                      [:whitespace]
                      false
                      #
                      true)))
  # =>
  nil

  )

# wsc == whitespace, comment
(defn right-skip-wsc
  ``
  Try to move right from `zloc`, skipping over whitespace
  and comment nodes.

  When at least one right move succeeds, return the z-location
  for the last successful right move destination.  Otherwise,
  return nil.
  ``
  [zloc]
  (right-until zloc
               |(match (z/node $)
                  [:whitespace]
                  false
                  #
                  [:comment]
                  false
                  #
                  true)))

(comment

  #(import ./location :as l)

  (-> (l/ast
        ``
        (# hi there
        + 1 2)
        ``)
      zip-down
      z/down
      right-skip-wsc
      z/node)
  # =>
  [:symbol @{:bc 1 :bl 2 :ec 2 :el 2} "+"]

  (-> (l/ast "(:a)")
      zip-down
      z/down
      right-skip-wsc)
  # =>
  nil

  )

(defn left-until
  ``
  Try to move left from `zloc`, calling `pred` for each
  left sibling.  If the `pred` call has a truthy result,
  return the corresponding left sibling.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when-let [left-sib (z/left zloc)]
    (if (pred left-sib)
      left-sib
      (left-until left-sib pred))))

(comment

  #(import ./location :as l)

  (-> (l/ast
        ``
        (# hi there
        + 1 2)
        ``)
      zip-down
      z/down
      right-skip-wsc
      right-skip-wsc
      (left-until |(match (z/node $)
                      [:comment]
                      false
                      #
                      [:whitespace]
                      false
                      #
                      true))
      z/node)
  # =>
  [:symbol @{:bc 1 :bl 2 :ec 2 :el 2} "+"]

  (-> [:code @{}
       [:tuple @{}
        [:keyword @{} ":a"]]]
      zip-down
      z/down
      (left-until |(match (z/node $)
                      [:comment]
                      false
                      #
                      [:whitespace]
                      false
                      #
                      true)))
  # =>
  nil

  )

(defn left-skip-wsc
  ``
  Try to move left from `zloc`, skipping over whitespace
  and comment nodes.

  When at least one left move succeeds, return the z-location
  for the last successful left move destination.  Otherwise,
  return nil.
  ``
  [zloc]
  (left-until zloc
               |(match (z/node $)
                  [:whitespace]
                  false
                  #
                  [:comment]
                  false
                  #
                  true)))

(comment

  #(import ./location :as l)

  (-> (l/ast
        ``
        (# hi there
        + 1 2)
        ``)
      zip-down
      z/down
      right-skip-wsc
      right-skip-wsc
      left-skip-wsc
      z/node)
  # =>
  [:symbol @{:bc 1 :bl 2 :ec 2 :el 2} "+"]

  )

(def j/append-child append-child)
(def j/down down)
(def j/end? end?)
(def j/insert-child insert-child)
(def j/insert-left insert-left)
(def j/left left)
(def j/node node)
(def j/replace replace)
(def j/right right)
(def j/right-until right-until)
(def j/root root)
(def j/unwrap unwrap)
(def j/up up)
(def j/wrap wrap)
(def j/zip zip)
(def j/zip-down zip-down)

# ti == test indicator, which can look like any of:
#
# # =>
# # before =>
# # => after
# # before => after

(defn find-test-indicator
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
                                         content)]
                       (do
                         (set label-left (string/trim l))
                         (set label-right (string/trim r))
                         true)
                       false)))
   label-left
   label-right])

(comment

  (def src
    ``
    (+ 1 1)
    # =>
    2
    ``)

  (let [[zloc l r]
        (find-test-indicator (-> (l/ast src)
                                 j/zip-down))]
    (and zloc
         (empty? l)
         (empty? r)))
  # =>
  true

  (def src
    ``
    (+ 1 1)
    # before =>
    2
    ``)

  (let [[zloc l r]
        (find-test-indicator (-> (l/ast src)
                                 j/zip-down))]
    (and zloc
         (= "before" l)
         (empty? r)))
  # =>
  true

  (def src
    ``
    (+ 1 1)
    # => after
    2
    ``)

  (let [[zloc l r]
        (find-test-indicator (-> (l/ast src)
                                 j/zip-down))]
    (and zloc
         (empty? l)
         (= "after" r)))
  # =>
  true

  )

(defn find-test-expr
  [ti-zloc]
  # check for appropriate conditions "before"
  (def before-zlocs @[])
  (var curr-zloc ti-zloc)
  (var found-before nil)
  (while curr-zloc
    (set curr-zloc
         (j/left curr-zloc))
    (when (nil? curr-zloc)
      (break))
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
    #
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

  (def src
    ``
    (comment

      (def a 1)

      (put @{} :a 2)
      # =>
      @{:a 2}

      )
    ``)

  (def [ti-zloc _ _]
    (find-test-indicator (-> (l/ast src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  '(:comment @{:bc 3 :bl 6 :ec 7 :el 6} "# =>")

  (def test-expr-zloc
    (find-test-expr ti-zloc))

  (j/node test-expr-zloc)
  # =>
  '(:tuple @{:bc 3 :bl 5 :ec 17 :el 5}
           (:symbol @{:bc 4 :bl 5 :ec 7 :el 5} "put")
           (:whitespace @{:bc 7 :bl 5 :ec 8 :el 5} " ")
           (:table @{:bc 8 :bl 5 :ec 11 :el 5})
           (:whitespace @{:bc 11 :bl 5 :ec 12 :el 5} " ")
           (:keyword @{:bc 12 :bl 5 :ec 14 :el 5} ":a")
           (:whitespace @{:bc 14 :bl 5 :ec 15 :el 5} " ")
           (:number @{:bc 15 :bl 5 :ec 16 :el 5} "2"))

  (-> (j/left test-expr-zloc)
      j/node)
  # =>
  '(:whitespace @{:bc 1 :bl 5 :ec 3 :el 5} "  ")

  )

(defn find-expected-expr
  [ti-zloc]
  (def after-zlocs @[])
  (var curr-zloc ti-zloc)
  (var found-comment nil)
  (var found-after nil)
  #
  (while curr-zloc
    (set curr-zloc
         (j/right curr-zloc))
    (when (nil? curr-zloc)
      (break))
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
    #
    (and found-after
         (match (j/node (first after-zlocs))
           [:whitespace _ "\n"]
           true))
    (if-let [from-next-line (drop 1 after-zlocs)
             next-line (take-until |(match (j/node $)
                                      [:whitespace _ "\n"]
                                      true)
                                   from-next-line)
             target (->> next-line
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

  (def src
    ``
    (comment

      (def a 1)

      (put @{} :a 2)
      # =>
      @{:a 2}

      )
    ``)

  (def [ti-zloc _ _]
    (find-test-indicator (-> (l/ast src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  '(:comment @{:bc 3 :bl 6 :ec 7 :el 6} "# =>")

  (def expected-expr-zloc
    (find-expected-expr ti-zloc))

  (j/node expected-expr-zloc)
  # =>
  '(:table @{:bc 3 :bl 7 :ec 10 :el 7}
           (:keyword @{:bc 5 :bl 7 :ec 7 :el 7} ":a")
           (:whitespace @{:bc 7 :bl 7 :ec 8 :el 7} " ")
           (:number @{:bc 8 :bl 7 :ec 9 :el 7} "2"))

  (-> (j/left expected-expr-zloc)
      j/node)
  # =>
  '(:whitespace @{:bc 1 :bl 7 :ec 3 :el 7} "  ")

  (def src
    ``
    (comment

      (butlast @[:a :b :c])
      # => @[:a :b]

      (butlast [:a])
      # => []

    )
    ``)

  (def [ti-zloc _ _]
    (find-test-indicator (-> (l/ast src)
                             j/zip-down
                             j/down)))

  (j/node ti-zloc)
  # =>
  '(:comment @{:bc 3 :bl 4 :ec 16 :el 4} "# => @[:a :b]")

  (find-expected-expr ti-zloc)
  # =>
  :no-expected-expression

  )

(defn make-label
  [left right]
  (string ""
          (when (not (empty? left))
            (string " " left))
          (when (or (not (empty? left))
                    (not (empty? right)))
            (string " =>"))
          (when (not (empty? right))
            (string " " right))))

(comment

  (make-label "hi" "there")
  # =>
  " hi => there"

  (make-label "hi" "")
  # =>
  " hi =>"

  (make-label "" "there")
  # =>
  " => there"

  (make-label "" "")
  # =>
  ""

  )

(defn find-test-exprs
  [ti-zloc]
  # look for a test expression
  (def test-expr-zloc
    (find-test-expr ti-zloc))
  (case test-expr-zloc
    :no-test-expression
    (break [nil nil])
    #
    :unexpected-result
    (errorf "unexpected result from `find-test-expr`: %p"
            test-expr-zloc))
  # look for an expected value expression
  (def expected-expr-zloc
    (find-expected-expr ti-zloc))
  (case expected-expr-zloc
    :no-expected-expression
    (break [test-expr-zloc nil])
    #
    :unexpected-result
    (errorf "unexpected result from `find-expected-expr`: %p"
            expected-expr-zloc))
  #
  [test-expr-zloc expected-expr-zloc])

(defn wrap-as-test-call
  [start-zloc end-zloc test-label]
  (-> (j/wrap start-zloc [:tuple @{}] end-zloc)
      # newline important for preserving long strings
      (j/insert-child [:whitespace @{} "\n"])
      # name of test macro
      (j/insert-child [:symbol @{} "_verify/is"])
      # for column zero convention, insert leading whitespace
      # before the beginning of the tuple (_verify/is ...)
      (j/insert-left [:whitespace @{} "  "])
      # add location info argument
      (j/append-child [:whitespace @{} " "])
      (j/append-child [:string @{} test-label])))

(defn rewrite-comment-zloc
  [comment-zloc]
  # move into comment block
  (var curr-zloc (j/down comment-zloc))
  (var found-test nil)
  # process comment block content
  (while (not (j/end? curr-zloc))
    (def [ti-zloc label-left label-right]
      (find-test-indicator curr-zloc))
    (unless ti-zloc
      (break))
    (def [test-expr-zloc expected-expr-zloc]
      (find-test-exprs ti-zloc))
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
                 ti-line-no ((get (j/node ti-zloc) 1) :bl)
                 test-label (string `"`
                                    `line-` ti-line-no
                                    (make-label label-left label-right)
                                    `"`)]
             (set found-test true)
             (wrap-as-test-call start-zloc end-zloc test-label)))))
  # navigate back out to top of block
  (when found-test
    # morph comment block into upscope block if a test was found
    (-> curr-zloc
        j/up
        j/down
        (j/replace [:whitespace @{} "\n"])
        j/up)))

(comment

  (def src
    ``
    (comment

      (def a 1)

      (put @{} :a 2)
      # left =>
      @{:a 2}

      (+ 1 1)
      # => right
      2

      )
    ``)

  (-> (l/ast src)
      j/zip-down
      rewrite-comment-zloc
      j/root
      l/code)
  # =>
  (string "("                            "\n"
          "\n"
          "\n"
          "  (def a 1)"                  "\n"
          "\n"
          "  (_verify/is"                "\n"
          "  (put @{} :a 2)"             "\n"
          "  # left =>"                  "\n"
          `  @{:a 2} "line-6 left =>")`  "\n"
          "\n"
          "  (_verify/is"                "\n"
          "  (+ 1 1)"                    "\n"
          "  # => right"                 "\n"
          `  2 "line-10 => right")`      "\n"
          "\n"
          "  )")

  )

(defn rewrite-comment-block
  [comment-src]
  (-> (l/ast comment-src)
      j/zip-down
      rewrite-comment-zloc
      j/root
      l/code))

(comment

  (def src
    ``
    (comment

      (def a 1)

      (put @{} :a 2)
      # =>
      @{:a 2}

      (+ 1 1)
      # left => right
      2

      )
    ``)

  (rewrite-comment-block src)
  # =>
  (string "("                             "\n"
          "\n"
          "\n"
          "  (def a 1)"                   "\n"
          "\n"
          "  (_verify/is"                 "\n"
          "  (put @{} :a 2)"              "\n"
          "  # =>"                        "\n"
          `  @{:a 2} "line-6")`           "\n"
          "\n"
          "  (_verify/is"                 "\n"
          "  (+ 1 1)"                     "\n"
          "  # left => right"             "\n"
          `  2 "line-10 left => right")`  "\n"
          "\n"
          "  )")

  )

(defn rewrite
  [src]
  (var curr-zloc
    (-> (l/ast src)
        j/zip-down
        # XXX: leading newline is a hack to prevent very first thing
        #      from being a comment block
        (j/insert-left [:whitespace @{} "\n"])
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
                    (rewrite-comment-zloc comment-zloc)]
             (j/unwrap rewritten-zloc)
             comment-zloc))
      (break)))
  (-> curr-zloc
      j/root
      l/code))

(comment

  (def src
    ``
    (require "json")

    (defn my-fn
      [x]
      (+ x 1))

    (comment

      (def a 1)

      (put @{} :a 2)
      # =>
      @{:a 2}

      (my-fn 1)
      # =>
      2

      )

    (defn your-fn
      [y]
      (* y y))

    (comment

      (your-fn 3)
      # =>
      9

      (def b 1)

      (+ b 1)
      # =>
      2

      (def c 2)

      )

    ``)

  (rewrite src)
  # =>
  (string "\n"
          `(require "json")`      "\n"
          "\n"
          "(defn my-fn"           "\n"
          "  [x]"                 "\n"
          "  (+ x 1))"            "\n"
          "\n"
          "\n"
          "\n"
          "\n"
          "  (def a 1)"           "\n"
          "\n"
          "  (_verify/is"         "\n"
          "  (put @{} :a 2)"      "\n"
          "  # =>"                "\n"
          `  @{:a 2} "line-12")`  "\n"
          "\n"
          "  (_verify/is"         "\n"
          "  (my-fn 1)"           "\n"
          "  # =>"                "\n"
          `  2 "line-16")`        "\n"
          "\n"
          "  "                    "\n"
          "\n"
          "(defn your-fn"         "\n"
          "  [y]"                 "\n"
          "  (* y y))"            "\n"
          "\n"
          "\n"
          "\n"
          "\n"
          "  (_verify/is"         "\n"
          "  (your-fn 3)"         "\n"
          "  # =>"                "\n"
          `  9 "line-28")`        "\n"
          "\n"
          "  (def b 1)"           "\n"
          "\n"
          "  (_verify/is"         "\n"
          "  (+ b 1)"             "\n"
          "  # =>"                "\n"
          `  2 "line-34")`        "\n"
          "\n"
          "  (def c 2)"           "\n"
          "\n"
          "  "                    "\n")

  )

(comment

  # https://github.com/sogaiu/judge-gen/issues/1
  (def src
    ```
    (comment

      (-> ``
          123456789
          ``
          length)
      # =>
      9

      (->
        ``
        123456789
        ``
        length)
      # =>
      9

      )
    ```)

  (rewrite src)
  # =>
  (string "\n"
          "\n"
          "\n"
          "\n"
          "  (_verify/is"    "\n"
          "  (-> ``"         "\n"
          "      123456789"  "\n"
          "      ``"         "\n"
          "      length)"    "\n"
          "  # =>"           "\n"
          `  9 "line-7")`    "\n"
          "\n"
          "  (_verify/is"    "\n"
          "  (->"            "\n"
          "    ``"           "\n"
          "    123456789"    "\n"
          "    ``"           "\n"
          "    length)"      "\n"
          "  # =>"           "\n"
          `  9 "line-15")`   "\n"
          "\n"
          "  ")

  )

# XXX: try to put in file?  had trouble originally when working on
#      judge-gen.  may be will have more luck?
(def verify-as-string
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
    (if-let [test-out (dyn :usages-as-tests/test-out)]
      (spit test-out (marshal _verify/test-results))
      # XXX: could this sometimes have problems?
      (printf "%p" _verify/test-results)))

  ``)

(defn rewrite-as-test-file
  [src]
  (string verify-as-string
          "\n"
          "(_verify/start-tests)"
          "\n"
          (rewrite src)
          "\n"
          "(_verify/end-tests)"
          "\n"
          "(_verify/dump-results)"
          "\n"))

# no tests so won't be executed
(comment

  (->> (slurp "./to-test-dogfood.janet")
       rewrite-as-test-file
       (spit "./sample-test-dogfood.janet"))

  )

(def to-test/rewrite-as-test-file rewrite-as-test-file)

(defn validate/valid-code?
  [form-bytes]
  (let [p (parser/new)
        p-len (parser/consume p form-bytes)]
    (when (parser/error p)
      (break false))
    (parser/eof p)
    (and (= (length form-bytes) p-len)
         (nil? (parser/error p)))))

(comment

  (validate/valid-code? "true")
  # =>
  true

  (validate/valid-code? "(")
  # =>
  false

  (validate/valid-code? "()")
  # =>
  true

  (validate/valid-code? "(]")
  # =>
  false

  )

(defn generate/handle-one
  [opts]
  (def {:input input
        :output output} opts)
  # read in the code
  (def buf (input/slurp-input input))
  (when (not buf)
    (eprint)
    (eprint "Failed to read input for: " input)
    (break false))
  # light sanity check
  (when (not (validate/valid-code? buf))
    (eprint)
    (eprint "Failed to parse input as valid Janet code: " input)
    (break false))
  # output rewritten content
  (def rewritten
    (try
      (to-test/rewrite-as-test-file buf)
      ([err]
        (eprintf "rewrite failed")
        nil)))
  (when (nil? rewritten)
      (break false))
  (if (not= "" output)
    (spit output rewritten)
    (print rewritten))
  true)

# since there are no tests in this comment block, nothing will execute
(comment

  (def file-path "./generate.janet")

  # output to stdout
  (generate/handle-one {:input file-path
                        :output ""})

  # output to file
  (generate/handle-one {:input file-path
                        :output (string "/tmp/"
                                        name/prog-name
                                        "-test-output.txt")})

  )
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
                  (all |(peg/find '(range "09" "af" "AF") # :h
                                  (string/from-bytes $))
                       res))))
  # =>
  true

  )

(defn utils/no-ext
  [file-path]
  (when file-path
    (if-let [rev (string/reverse file-path)
             dot (string/find "." rev)]
      (string/reverse (string/slice rev (inc dot)))
      file-path)))

(comment

  (utils/no-ext "fun.janet")
  # =>
  "fun"

  (utils/no-ext "/etc/man_db.conf")
  # =>
  "/etc/man_db"

  )

(defn judges/make-judges
  [src-root judge-root]
  (def subdirs @[])
  (def out-in-tbl @{})
  (defn helper
    [src-root subdirs judge-root]
    (each path (os/dir src-root)
      (def in-path (path/join src-root path))
      (case (os/stat in-path :mode)
        :directory
        (do
          (helper in-path (array/push subdirs path)
                  judge-root)
          (array/pop subdirs))
        #
        :file
        (when (string/has-suffix? ".janet" in-path)
          (def judge-file-name
            (string (utils/no-ext path) ".judge"))
          (let [out-path (path/join judge-root
                                    ;subdirs
                                    judge-file-name)]
            (unless (generate/handle-one {:input in-path
                                          :output out-path})
              (eprintf "Test generation failed for: %s" in-path)
              (eprintf "Please confirm validity of source file: %s" in-path)
              (error nil))
            (put out-in-tbl
                 (path/abspath out-path)
                 (path/abspath in-path)))))))
  #
  (helper src-root subdirs judge-root)
  out-in-tbl)

# since there are no tests in this comment block, nothing will execute
(comment

  (def proj-root
    (path/join (os/getenv "HOME")
               "src" name/prog-name))

  (def judge-root
    (path/join proj-root name/dot-dir-name))

  (def src-root
    (path/join proj-root name/prog-name))

  (os/mkdir judge-root)

  (judges/make-judges src-root judge-root)

  )

(defn judges/find-judge-files
  [dir]
  (def file-paths @[])
  (defn helper
    [dir file-paths]
    (each path (os/dir dir)
      (def full-path (path/join dir path))
      (case (os/stat full-path :mode)
        :directory
        (helper full-path file-paths)
        #
        :file
        (when (string/has-suffix? ".judge" path)
          (array/push file-paths [full-path path]))))
    file-paths)
  #
  (helper dir file-paths))

(defn judges/execute-command
  [opts]
  (def {:command command
        :count count
        :judge-file-rel-path jf-rel-path
        :results-dir results-dir
        :results-full-path results-full-path} opts)
  (when (dyn :debug)
    (eprintf "command: %p" command))
  (let [jf-rel-no-ext (utils/no-ext jf-rel-path)
        err-path
        (path/join results-dir
                   (string "stderr-" count "-" jf-rel-no-ext ".txt"))
        out-path
        (path/join results-dir
                   (string "stdout-" count "-" jf-rel-no-ext ".txt"))]
    (try
      (with [ef (file/open err-path :w)]
        (with [of (file/open out-path :w)]
          (let [ecode (os/execute command :px {:err ef
                                               :out of})]
            (when (not (zero? ecode))
              (eprintf "non-zero exit code: %d" ecode)))
          (file/flush ef)
          (file/flush of)))
      ([_]
        (error {:out-path out-path
                :err-path err-path
                :type :command-failed}))))
  (def marshalled-results
    (try
      (slurp results-full-path)
      ([err]
        (eprintf "Failed to read in marshalled results from: %s"
                 results-full-path)
        (error nil))))
  # resurrect the results
  (try
    (unmarshal (buffer marshalled-results))
    ([err]
      (eprintf "Failed to unmarshal content from: %s"
               results-full-path)
      (error nil))))

(defn judges/make-results-dir-path
  [judge-root]
  (path/join judge-root
             (string "." (os/time) "-"
                     (utils/rand-string 8) "-"
                     "usages-as-tests")))

(comment

  (peg/match ~(sequence (choice "/" "\\")
                        "."
                        (some :d)
                        "-"
                        (some :h)
                        "-"
                        "usages-as-tests")
             (judges/make-results-dir-path ""))
  # => @[]

  )

(defn judges/ensure-results-full-path
  [results-dir fname i]
  (let [fpath (path/join results-dir
                         (string i "-" (utils/no-ext fname) ".jimage"))]
    # note: create-dirs expects a path ending in a filename
    (jpm/create-dirs fpath)
    (unless (os/stat results-dir)
      (eprintf "Failed to create dir for path: %s" fpath)
      (error nil))
    fpath))

(defn judges/judge-all
  [judge-root test-src-tbl]
  (def results @{})
  (def file-paths
    (sort (judges/find-judge-files judge-root)))
  (var count 0)
  (def results-dir (judges/make-results-dir-path judge-root))
  #
  (each [jf-full-path jf-rel-path] file-paths
    (print "  " jf-rel-path)
    (def results-full-path
      (judges/ensure-results-full-path results-dir jf-rel-path count))
    (when (dyn :debug)
      (eprintf "results path: %s" results-full-path))
    # backticks below for cross platform compatibility
    (def command [(dyn :executable "janet")
                  "-e" (string "(os/cd `" judge-root "`)")
                  "-e" (string "(do "
                               "  (setdyn :usages-as-tests/test-out "
                               "          `" results-full-path "`) "
                               "  (dofile `" jf-full-path "`) "
                               ")")])
    (when (dyn :debug)
      (eprintf "command: %p" command))
    (def results-for-path
      (try
        (judges/execute-command
          {:command command
           :count count
           :judge-file-rel-path jf-rel-path
           :results-dir results-dir
           :results-full-path results-full-path})
        ([err]
          (when err
            (if-let [err-type (err :type)]
              # XXX: if more errors need to be handled, check err-type
              (let [{:out-path out-path
                     :err-path err-path} err]
                (eprint)
                (eprintf "Command failed:\n  %p" command)
                (eprint)
                (eprint "Potentially relevant paths:")
                (eprintf "  %s" jf-full-path)
                #
                (def err-file-size (os/stat err-path :size))
                (when (pos? err-file-size)
                  (eprintf "  %s" err-path))
                #
                (eprint)
                (when (pos? err-file-size)
                  (eprint "Start of test stderr output")
                  (eprint)
                  (eprint (string (slurp err-path)))
                  #(eprint)
                  (eprint "End of test stderr output")
                  (eprint)))
              (eprintf "Unknown error:\n %p" err)))
          (error nil))))
    (def src-full-path
      (in test-src-tbl jf-full-path))
    (assert src-full-path
            (string "Failed to determine source for test: " jf-full-path))
    (put results
         src-full-path results-for-path)
    (++ count))
  results)

(defn summary/report
  [results]
  (when (empty? results)
    (eprint "No test results")
    (break true))
  (var total-tests 0)
  (var total-passed 0)
  (def failures @{})
  # analyze results
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
  # report any failures
  (var i 0)
  (each fpath (sort (keys failures))
    (def failed-tests (get failures fpath))
    (each fail failed-tests
      (def {:test-value test-value
            :expected-value expected-value
            :name test-name
            :passed test-passed
            :test-form test-form} fail)
      (++ i)
      (print)
      (prin "--(")
      (display/print-color i :cyan)
      (print ")--")
      (print)
      (display/print-color "source file:" :yellow)
      (print)
      (display/print-color (string (utils/no-ext fpath) ".janet") :red)
      (print)
      (print)
      #
      (display/print-color "failed:" :yellow)
      (print)
      (display/print-color test-name :red)
      (print)
      #
      (print)
      (display/print-color "form" :yellow)
      (display/print-form test-form)
      #
      (print)
      (display/print-color "expected" :yellow)
      (display/print-form expected-value)
      #
      (print)
      (display/print-color "actual" :yellow)
      (display/print-form test-value :blue)))
  (when (zero? (length failures))
    (print)
    (print "No tests failed."))
  # summarize totals
  (print)
  (display/print-dashes)
  (when (= 0 total-tests)
    (print "No tests found, so no judgements made.")
    (break true))
  (if (not= total-passed total-tests)
    (display/print-color total-passed :red)
    (display/print-color total-passed :green))
  (prin " of ")
  (display/print-color total-tests :green)
  (print " passed")
  (display/print-dashes)
  (= total-passed total-tests))

(comment

  (summary/report @{})
  # =>
  true

  (def results
    '@[{:expected-value true
        :passed true
        :name "line-6"
        :test-form (validate/valid-code? "true")
        :type :is
        :expected-form true
        :test-value true}
       {:expected-value false
        :passed true
        :name "line-9"
        :test-form (validate/valid-code? "(")
        :type :is
        :expected-form false
        :test-value false}
       {:expected-value true
        :passed true
        :name "line-12"
        :test-form (validate/valid-code? "()")
        :type :is
        :expected-form true
        :test-value true}
       {:expected-value false
        :passed true
        :name "line-15"
        :test-form (validate/valid-code? "(]")
        :type :is
        :expected-form false
        :test-value false}])

  (let [buf @""]
    (with-dyns [:out buf]
      (summary/report @{"validate.jimage" results}))
    (string/has-prefix? "\nNo tests failed." buf))
  # =>
  true

  )

(defn runner/handle-one
  [opts]
  (def {:judge-dir-name judge-dir-name
        :proj-root proj-root
        :src-root src-root} opts)
  (def judge-root
    (path/join proj-root judge-dir-name))
  (try
    (do
      (display/print-dashes)
      (print)
      (print (string name/prog-name " is starting..."))
      (print)
      (display/print-dashes)
      # remove old judge directory
      (prin "Cleaning out: " judge-root " ... ")
      (jpm/rm judge-root)
      # make a fresh judge directory
      (os/mkdir judge-root)
      (print "done")
      # copy source files
      (prin "Copying source files... ")
      # shhhhh
      (with-dyns [:out @""]
        # each item copied separately for platform consistency
        (each item (os/dir src-root)
          (def full-path (path/join src-root item))
          (jpm/copy-continue full-path judge-root)))
      (print "done")
      # create judge files
      (prin "Creating tests files... ")
      (flush)
      (def ts-tbl
        (judges/make-judges src-root judge-root))
      (print "done")
      # judge
      (print "Running tests...")
      (def results
        (judges/judge-all judge-root ts-tbl))
      (display/print-dashes)
      # summarize results
      (def all-passed
        (summary/report results))
      (print)
      # XXX: if detecting that being run via `jpm test` is possible,
      #      may be can show following only when run from `jpm test`
      (print (string name/prog-name
                     " is done, later output may be from `jpm test`"))
      (print)
      (display/print-dashes)
      all-passed)
    #
    ([err]
      (when err
        (eprint "Unexpected error:\n")
        (eprintf "\n%p" err))
      (eprint "Runner stopped")
      nil)))

# since there are no tests in this comment block, nothing will execute
(comment

  (def proj-root
    (path/join (os/getenv "HOME")
               "src" name/prog-name))

  (def src-root
    (path/join proj-root name/prog-name))

  (runner/handle-one {:judge-dir-name name/dot-dir-name
                      :proj-root proj-root
                      :src-root src-root})

  )

# from the perspective of `jpm test`
(def proj-root
  (path/abspath "."))

(defn deduce-src-root
  []
  (let [current-file (dyn :current-file)]
    (assert current-file
            ":current-file is nil")
    (let [cand-name (utils/no-ext (path/basename current-file))]
      (assert (and cand-name
                   (not= cand-name ""))
              (string "failed to deduce name for: "
                      current-file))
      cand-name)))

(defn suffix-for-judge-dir-name
  [runner-path]
  (assert (string/has-prefix? (path/join "test" path/sep) runner-path)
          (string "path must start with `test/`: " runner-path))
  (let [path-no-ext (utils/no-ext runner-path)]
    (assert (and path-no-ext
                 (not= path-no-ext ""))
            (string "failed to deduce name for: "
                    runner-path))
    (def rel-to-test
      (string/slice path-no-ext (length "test/")))
    (def comma-escaped
      (string/replace-all "," ",," rel-to-test))
    (def all-escaped
      (string/replace-all "/" "," comma-escaped))
    all-escaped))

(defn deduce-judge-dir-name
  []
  (let [current-file (dyn :current-file)]
    (assert current-file
            ":current-file is nil")
    (let [suffix (suffix-for-judge-dir-name current-file)]
      (assert suffix
              (string "failed to determine suffix for: "
                      current-file))
      (string ".uat_" suffix))))

# XXX: hack to prevent from running when testing
(when (nil? (dyn :usages-as-tests/test-out))
  (let [src-root (deduce-src-root)
        judge-dir-name (deduce-judge-dir-name)]
    (def stat (os/stat src-root))
    (unless stat
      (eprint "src-root must exist: " src-root)
      (os/exit 1))
    (unless (= :directory (stat :mode))
      (eprint "src-root must be a directory: " src-root)
      (os/exit 1))
    (let [all-passed (runner/handle-one
                       {:judge-dir-name judge-dir-name
                        :proj-root proj-root
                        :src-root src-root})]
      (when (not all-passed)
        (os/exit 1)))))
