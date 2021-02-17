(defn slurp-input
  [input]
  (var f nil)
  (if (= input "-")
    (set f stdin)
    (if (os/stat input)
      # XXX: handle failure?
      (set f (file/open input :rb))
      (do
        (eprint "path not found: " input)
        (break [nil nil]))))
  (file/read f :all))
