# line-no is 1-based
(defn read-input
  [f line-no]
  # store the content from f
  (var buf @"")
  # determine what the byte offset is for line-no
  (var line-no-byte-offset -1)
  (var bytes-read 0)
  (var current-line-no 0)
  # XXX: error-handling?
  (loop [new-buf :iterate (file/read f :line)]
    (++ current-line-no)
    (when (and (not= line-no 0)
               (= current-line-no line-no))
      # line-no starts at this byte offset
      # XXX: is this off by one?
      (set line-no-byte-offset bytes-read))
    (+= bytes-read (length new-buf))
    #(print "bytes-read: " bytes-read)
    (buffer/blit buf new-buf -1))
  [buf line-no-byte-offset])

(comment

  # XXX: not good to have this kind of test?
 (def test-path
   "/tmp/jg-test.txt")

 (spit test-path "hello\nhi\nho")

 (def f (file/open test-path :rb))

 (read-input f 1)
 # => [@"hello\nhi\nho" 0]

 (file/close f)

 (def f (file/open test-path :rb))

 (read-input f 2)
 # => [@"hello\nhi\nho" 6]

 (file/close f)

 )

(defn slurp-input
  [input line]
  (var f nil)
  (if (= input "-")
    (set f stdin)
    (if (os/stat input)
      # XXX: handle failure?
      (set f (file/open input :rb))
      (do
        (eprint "path not found: " input)
        (break [nil nil]))))
  (read-input f line))
