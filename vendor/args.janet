(import ./vendor/argparse)

(def params
  ["Rewrite comment blocks as tests."
   # vim, vscode
   # emacs uses 0 for beginning of line
   #"column" {:default "1"
   #          :help "Column number, 1-based."
   #          :kind :option
   # emacs, vim, vscode
   "debug" {:help "Debug output."
            :kind :flag
            :short "d"}
   "format" {:default "jdn"
             :help "Output format, jdn or text."
             :kind :option
             :short "f"}
   "line" {:default "0"
           :help "1-based cursor location linue number, 0 means no cursor."
           :kind :option
           :short "l"}
   "output" {:default ""
             :help "Path to store output to."
             :kind :option
             :short "o"}
   # XXX: "include" -> prepend or unwrap comment blocks in place?
   "prepend" {:default false
              :help "Prepend original source code."
              :kind :flag
              :short "p"}
   "single" {:default false
             :help "Select single comment block or all relevant."
             :kind :flag
             :short "s"}
   "version" {:default false
              :help "Version output."
              :kind :flag
              :short "v"}
   :default {:default "-"
             :help "Source path or - for STDIN."
             :kind :option}])

(comment

 (def file-path "./jg.janet")

 (do
   (setdyn :args ["jg" file-path])
   (argparse/argparse ;params))
`
@{"version" false
  "line" "0"
  "output" ""
  :order @[:default]
  "format" "jdn"
  "prepend" false
  "single" false
  :default file-path}
`

 (do
   (setdyn :args ["jg" file-path "-p"])
   (argparse/argparse ;params))
`
@{"version" false
  "line" "0"
  "output" ""
  :order @[:default "prepend"]
  "format" "jdn"
  "prepend" true
  "single" false
  :default file-path}
`

 )

(defn parse
  []
  (let [res (argparse/argparse ;params)
        #column (scan-number (res "column"))
        input (res :default)
        format (res "format")
        line (scan-number (res "line"))
        single (res "single")
        # XXX: overwrites...dangerous?
        output (res "output")
        prepend (res "prepend")
        version (res "version")]
    (setdyn :debug (res "debug"))
    (assert (or (= format "jdn")
                (= format "text"))
            "Format should be jdn or text.")
    (assert input "Input should be filepath or -")
    #(assert (<= 1 column) "Column should be 1 or greater.")
    (assert (<= 0 line) "Line should be 0 or greater.")
    (when (dyn :debug)
      (eprint "line number (cursor at): " line))
    {:format format
     :input input
     :line line
     :output output
     :prepend prepend
     :single single
     :version version}))
