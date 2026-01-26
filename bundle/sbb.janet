# adapted from jeep and spork

########################################################################

(defn ddumpf
  [msg & args]
  (when (os/getenv "VERBOSE")
    (if (not (empty? args))
      (eprintf msg ;args)
      (eprint msg))))

########################################################################

# adapted from spork/path
(def- w32-grammar
  ~{:main (sequence (opt (sequence (replace (capture :lead)
                                            ,(fn [& xs]
                                               [:lead (get xs 0)]))
                                   (any (set `\/`))))
                    (opt (capture :span))
                    (any (sequence :sep (capture :span)))
                    (opt (sequence :sep (constant ""))))
    :lead (sequence (opt (sequence :a `:`)) `\`)
    :span (some (if-not (set `\/`) 1))
    :sep (some (set `\/`))})

(comment

  (peg/match w32-grammar `C:\WINDOWS\config.sys`)
  # =>
  @[[:lead `C:\`] "WINDOWS" "config.sys"]

  # absolute file path from root of drive C:
  (peg/match w32-grammar `C:\Documents\Newsletters\Summer2018.pdf`)
  # =>
  @[[:lead `C:\`] "Documents" "Newsletters" "Summer2018.pdf"]

  # relative path from root of current drive
  (peg/match w32-grammar `\Program Files\Custom Utilities\StringFinder.exe`)
  # =>
  @[[:lead `\`] "Program Files" "Custom Utilities" "StringFinder.exe"]

  # relative path to a file in a subdirectory of current directory
  (peg/match w32-grammar `2018\January.xlsx`)
  # =>
  @["2018" "January.xlsx"]

  # relative path to a file in a directory starting from current directory
  (peg/match w32-grammar `..\Publications\TravelBrochure.pdf`)
  # =>
  @[".." "Publications" "TravelBrochure.pdf"]

  # absolute path to a file from root of drive C:
  (peg/match w32-grammar `C:\Projects\apilibrary\apilibrary.sln`)
  # =>
  @[[:lead `C:\`] "Projects" "apilibrary" "apilibrary.sln"]

  # XXX
  # relative path from current directory of drive C:
  (peg/match w32-grammar `C:Projects\apilibrary\apilibrary.sln`)
  # =>
  @["C:Projects" "apilibrary" "apilibrary.sln"]

  (peg/match w32-grammar "autoexec.bat")
  # =>
  @["autoexec.bat"]

  (peg/match w32-grammar `C:\`)
  # =>
  @[[:lead `C:\`]]

  # XXX
  (peg/match w32-grammar `C:`)
  # =>
  @["C:"]

  )

(def- posix-grammar
  ~{:main (sequence (opt (sequence (replace (capture :lead)
                                            ,(fn [& xs]
                                               [:lead (get xs 0)]))
                                   (any "/")))
                    (opt (capture :span))
                    (any (sequence :sep (capture :span)))
                    (opt (sequence :sep (constant ""))))
    :lead "/"
    :span (some (if-not "/" 1))
    :sep (some "/")})

(comment

  (peg/match posix-grammar "/home/alice/.bashrc")
  # =>
  @[[:lead "/"] "home" "alice" ".bashrc"]

  (peg/match posix-grammar ".profile")
  # =>
  @[".profile"]

  (peg/match posix-grammar "/tmp/../usr/local/../bin")
  # =>
  @[[:lead "/"] "tmp" ".." "usr" "local" ".." "bin"]

  (peg/match posix-grammar "/")
  # =>
  @[[:lead "/"]]

  )

(defn normalize
  [path &opt doze?]
  (default doze? (= :windows (os/which)))
  (def accum @[])
  (def parts
    (peg/match (if doze?
                 w32-grammar
                 posix-grammar)
               path))
  (var seen 0)
  (var lead nil)
  (each x parts
    (match x
      [:lead what] (set lead what)
      #
      "." nil
      #
      ".."
      (if (zero? seen)
        (array/push accum x)
        (do
          (-- seen)
          (array/pop accum)))
      #
      (do
        (++ seen)
        (array/push accum x))))
  (def ret
    (string (or lead "")
            (string/join accum (if doze? `\` "/"))))
  #
  (if (empty? ret)
    "."
    ret))

(comment

  (normalize `C:\WINDOWS\config.sys` true)
  # =>
  `C:\WINDOWS\config.sys`

  (normalize `C:\Documents\Newsletters\Summer2018.pdf` true)
  # =>
  `C:\Documents\Newsletters\Summer2018.pdf`

  (normalize `\Program Files\Custom Utilities\StringFinder.exe` true)
  # =>
  `\Program Files\Custom Utilities\StringFinder.exe`

  (normalize `2018\January.xlsx` true)
  # =>
  `2018\January.xlsx`

  # XXX: not enough info to eliminate ..
  (normalize `..\Publications\TravelBrochure.pdf` true)
  # =>
  `..\Publications\TravelBrochure.pdf`

  (normalize `C:\Projects\apilibrary\apilibrary.sln` true)
  # =>
  `C:\Projects\apilibrary\apilibrary.sln`

  (normalize `C:Projects\apilibrary\apilibrary.sln` true)
  # =>
  `C:Projects\apilibrary\apilibrary.sln`

  (normalize "autoexec.bat" true)
  # =>
  "autoexec.bat"

  (normalize `C:\` true)
  # =>
  `C:\`

  (normalize `C:` true)
  # =>
  "C:"

  (normalize `C:\WINDOWS\SYSTEM32\..` true)
  # =>
  `C:\WINDOWS`

  (normalize `C:\WINDOWS\SYSTEM32\..\SYSTEM32` true)
  # =>
  `C:\WINDOWS\SYSTEM32`

  )

(defn join
  [& els]
  (def end (last els))
  (when (and (one? (length els))
             (not (string? end)))
    (error "when els only has a single element, it must be a string"))
  #
  (def [items sep]
    (cond
      (true? end)
      [(slice els 0 -2) `\`]
      #
      (false? end)
      [(slice els 0 -2) "/"]
      #
      [els (if (= :windows (os/which)) `\` "/")]))
  #
  (normalize (string/join items sep)))

(comment

  (join `C:` "WINDOWS" "config.sys" true)
  # =>
  `C:\WINDOWS\config.sys`

  (join `C:` "Documents" "Newsletters" "Summer2018.pdf" true)
  # =>
  `C:\Documents\Newsletters\Summer2018.pdf`

  (join "" "Program Files" "Custom Utilities" "StringFinder.exe" true)
  # =>
  `\Program Files\Custom Utilities\StringFinder.exe`

  (join "2018" "January.xlsx" true)
  # =>
  `2018\January.xlsx`

  (join ".." "Publications" "TravelBrochure.pdf" true)
  # =>
  `..\Publications\TravelBrochure.pdf`

  (join `C:` "Projects" "apilibrary" "apilibrary.sln" true)
  # =>
  `C:\Projects\apilibrary\apilibrary.sln`

  (join "autoexec.bat" true)
  # =>
  "autoexec.bat"

  (join `C:` true)
  # =>
  "C:"

  # below here are some possibly non-obvious "techniques"

  (join `C:Projects` `apilibrary` `apilibrary.sln` true)
  # =>
  `C:Projects\apilibrary\apilibrary.sln`

  (join `C:` "" true)
  # =>
  `C:\`

  (join "" "tmp" false)
  # =>
  "/tmp"

  )

(defn abspath?
  [path &opt doze?]
  (default doze? (= :windows (os/which)))
  (if doze?
    # https://stackoverflow.com/a/23968430
    # https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
    (truthy? (peg/match ~(sequence :a `:\`) path))
    (string/has-prefix? "/" path)))

(comment

  (abspath? "/" false)
  # =>
  true

  (abspath? "." false)
  # =>
  false

  (abspath? ".." false)
  # =>
  false

  (abspath? `C:\` true)
  # =>
  true

  (abspath? `C:` true)
  # =>
  false

  (abspath? "config.sys" true)
  # =>
  false

  )

(defn abspath
  [path &opt doze?]
  (default doze? (= :windows (os/which)))
  (if (abspath? path doze?)
    (normalize path doze?)
    # dynamic variable useful for testing
    (join (or (dyn :localpath-cwd) (os/cwd))
             path
             doze?)))

(comment

  (with-dyns [:localpath-cwd "/root"]
    (abspath "." false))
  # =>
  "/root"

  (with-dyns [:localpath-cwd `C:\WINDOWS`]
    (abspath "config.sys" true))
  # =>
  `C:\WINDOWS\config.sys`

  )

# XXX: specification is kind of vague...
(defn basename
  [path &opt doze?]
  (def tos (= :windows (os/which)))
  (default doze? tos)
  #
  (when (and (not doze?) (= "/" path))
    (break "/"))
  #
  (def s (if (or doze? tos) `\` "/"))
  # https://en.wikipedia.org/wiki/Basename
  (def path-no-s-at-end
    (if (string/has-suffix? s path)
      (string/slice path 0 -2)
      path))
  #
  (def revpath (string/reverse path-no-s-at-end))
  (def i (string/find s revpath))
  (if i
    (-> (string/slice revpath 0 i)
        string/reverse)
    path))

(comment

  (basename "/")
  # =>
  "/"

  (basename "/tmp/hello.txt")
  # =>
  "hello.txt"

  (basename "/etc/X11/")
  # =>
  "X11"

  (basename `C:\WINDOWS\config.sys` true)
  # =>
  "config.sys"

  (basename `C:\WINDOWS\SYSTEM32\` true)
  # =>
  "SYSTEM32"

  )

########################################################################

(defn get-os-stuff
  []
  (def seps {:windows `\` :mingw `\` :cygwin `\`})
  (def tos (os/which))
  [tos (get seps tos "/")])

########################################################################

(defn add-manpages
  [manifest s]
  (ddumpf "add-manpages: %n" manifest)
  (def manpages (get-in manifest [:info :manpages] []))
  (os/mkdir (string (dyn :syspath) s "man"))
  (os/mkdir (string (dyn :syspath) s "man" s "man1"))
  (each mp manpages
    (bundle/add-file manifest mp)))

(defn add-sources
  [manifest s]
  (ddumpf "add-sources: %n" manifest)
  (each src (get-in manifest [:info :sources])
    (def {:prefix prefix
          :items items} src)
    (when prefix
      (bundle/add-directory manifest prefix))
    (def pre (if prefix (string prefix s) ""))
    (each i items
      (cond
        (string? i)
        (bundle/add manifest i (string pre i))
        #
        (tuple? i)
        (let [[src rename] i]
          # XXX: ensure src refers to a file?
          (bundle/add-file manifest src (string pre rename)))
        #
        (errorf "expected string or tuple, got: %n" (type i))))))

(defn add-binscripts
  [manifest [tos s]]
  (ddumpf "add-binscripts: %n" manifest)
  (each binscript (get-in manifest [:info :binscripts] [])
    (def {:main main
          :hardcode-syspath hardcode-syspath
          :is-janet is-janet} binscript)
    (def main (abspath main))
    (def bin-name (basename main))
    (def dest (join "bin" bin-name))
    (def contents
      (with [f (file/open main :rbn)]
        (def line-1 (:read f :line))
        (def auto-shebang
          (and is-janet (not (string/has-prefix? "#!" line-1))))
        (def dynamic-syspath (= hardcode-syspath :dynamic))
        (def line-2
          (string "(put root-env :original-syspath "
                  "(os/realpath (dyn *syspath*))) # auto generated\n"))
        (def line-3
          (string/format "(put root-env :syspath %v) # auto generated\n"
                         (dyn *syspath*)))
        (def line-4
          (string/format "(put root-env :install-time-syspath %v) %s\n"
                         (dyn *syspath*)
                         "# auto generated"))
        (def rest (:read f :all))
        (string (if auto-shebang (string "#!/usr/bin/env janet\n"))
                line-1
                (if (or dynamic-syspath hardcode-syspath) line-2)
                (if hardcode-syspath line-3)
                (if hardcode-syspath line-4)
                rest)))
    (def bin-temp (string bin-name ".temp"))
    # XXX: want bundle/add-buffer so this temp file would be unneeded...
    (defer (os/rm bin-temp)
      (spit bin-temp contents)
      (bundle/add-bin manifest bin-temp bin-name))
    (when (or (= :windows tos) (= :mingw tos))
      (def absdest (join (dyn *syspath*) dest))
      # jpm and janet-pm have bits like this
      # https://github.com/microsoft/terminal/issues/217#issuecomment-737594785
      (def bat-content
        (string "@echo off\r\n"
                "goto #_undefined_# 2>NUL || "
                `title %COMSPEC% & janet "` absdest `" %*`))
      (def bat-name (string main ".bat"))
      # XXX: want bundle/add-buffer so this temp file would be unneeded...
      (defer (os/rm bat-name)
        (spit bat-name bat-content)
        (bundle/add-bin manifest bat-name)))))

########################################################################

# adapted from declare-cc
(def- colors
  {:green "\e[32m"
   :red "\e[31m"})

(defn- color
  "Color text with ascii escape sequences if (os/isatty)"
  [input-color text]
  (if (os/isatty)
    (string (get colors input-color "\e[0m") text "\e[0m")
    text))

(defn run-tests
  "Run tests on a project in the current directory."
  [&opt root-directory]
  (ddumpf "run-tests: %n" root-directory)
  (var errors-found 0)
  (defn dodir
    [dir]
    (each sub (sort (os/dir dir))
      (def ndir (string dir "/" sub))
      (case (os/stat ndir :mode)
        :file (when (string/has-suffix? ".janet" ndir)
                (print "running " ndir " ...")
                (flush)
                (def result
                  (os/execute [(dyn *executable* "janet") "--" ndir] :p))
                (when (not= 0 result)
                  (++ errors-found)
                  (eprinf (color :red "non-zero exit code in %s: ") ndir)
                  (eprintf "%d" result)))
        :directory (dodir ndir))))
  (dodir (or root-directory "test"))
  (if (zero? errors-found)
    (print (color :green "✓ All tests passed."))
    (do
      (prin (color :red "✘ Failing test scripts: "))
      (printf "%d" errors-found)
      (os/exit 1)))
  (flush))

