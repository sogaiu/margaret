(import ./support/path)

(declare-project
  :name "margaret"
  :url "https://codeberg.org/sogaiu/margaret"
  :repo "git+https://codeberg.org/sogaiu/margaret.git")

(def proj-root
  (os/cwd))

(def src-root
  (path/join proj-root "margaret"))

(declare-source
 :source [src-root])

(declare-binscript
  :main "bin/meg-render"
  :is-janet true)

