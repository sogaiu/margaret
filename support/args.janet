(import ./vendor/argparse)

(def params
  ["Rewrite comment blocks as tests."
   "debug" {:help "Debug output."
            :kind :flag
            :short "d"}
   "format" {:default "jdn"
             :help "Output format, jdn or text."
             :kind :option
             :short "f"}
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
      (argparse/argparse ;params))

    @{"version" false
      "output" ""
      :order @[:default]
      "format" "jdn"
      :default file-path}) # => true

  )

(defn parse
  []
  (when-let [res (argparse/argparse ;params)]
    (let [input (res :default)
          format (res "format")
          # XXX: overwrites...dangerous?
          output (res "output")
          version (res "version")]
      (setdyn :debug (res "debug"))
      (assert (or (= format "jdn")
                  (= format "text"))
              "Format should be jdn or text.")
      (assert input "Input should be filepath or -")
      {:format format
       :input input
       :output output
       :version version})))
