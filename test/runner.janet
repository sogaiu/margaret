(import ../vendor/jg-verdict :as "jgv")
(import ../vendor/path)

(def proj-root
  (path/abspath "."))

(def src-root
  (path/join proj-root "examples"))

(jgv/handle-one
  {:judge-dir-name "judge"
   :judge-file-prefix "judge-"
   :proj-root proj-root
   :src-root src-root})

# XXX: disable "All tests passed." message from `jpm test`
(os/exit 1)
