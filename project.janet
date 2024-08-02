(import ./support/path)

(declare-project
  :name "margaret"
  :url "https://github.com/sogaiu/margaret"
  :repo "git+https://github.com/sogaiu/margaret.git")

(def proj-root
  (os/cwd))

(def src-root
  (path/join proj-root "margaret"))

(declare-source
 :source [src-root])

