(import ../support/jg-runner :as "jgr")
(import ../support/path)

# from the perspective of `jpm test`
(def proj-root
  (path/abspath "."))

(def src-root
  (path/join proj-root "examples"))

(jgr/handle-one
  {:judge-dir-name "judge"
   :judge-file-prefix "judge-"
   :proj-root proj-root
   :src-root src-root})

# XXX: disable "All tests passed." message from `jpm test`
(os/exit 1)
