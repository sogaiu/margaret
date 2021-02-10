(import ./vendor/argparse)

(def params
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

 (do
   (setdyn :args ["jg-verdict"
                  "-p" ".."
                  "-s" "."])
   (argparse/argparse ;params))
`
@{"version" false
  "judge-file-prefix" "judge-"
  "judge-dir-name" "judge"
  :order @["project-root" "source-root"]
  "project-root" ".."
  "source-root" "."}
`

 )

(defn parse
  []
  (def res (argparse/argparse ;params))
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
