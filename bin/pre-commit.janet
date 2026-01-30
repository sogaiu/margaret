#! /usr/bin/env janet

(use ./sh-dsl)

(defn copy-file
  [src dst]
  (spit dst (slurp src)))

(prin "copying meg.janet to root dir...")
(copy-file "margaret/meg.janet" "meg.janet")
(print "done")

(print "running niche...")
(def niche-exit ($ janet ./bin/niche.janet))
(assertf (zero? niche-exit)
         "niche exited: %d" niche-exit)
(print "done")

