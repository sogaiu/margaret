(import ./meg)

(defn event?
  [cand]
  (and (dictionary? cand)
       (or (has-key? cand :entry)
           (and (has-key? cand :exit)
                (has-key? cand :ret)))
       (has-key? cand :index)
       (has-key? cand :peg)
       (has-key? cand :grammar)
       (has-key? cand :state)))

(comment

  (event? '{:entry 0
            :index 0
            :peg (sequence (capture (some "smile") :x) (backref :x))
            :grammar @{:main (sequence (capture (some "smile") :x) (backref :x))}
            :state @{:original-text "smile!"
                     :extrav []
                     :has-backref true
                     :outer-text-end 6
                     #
                     :text-start 0
                     :text-end 6
                     #
                     :captures @[]
                     :tagged-captures @[]
                     :tags @[]
                     #
                     :scratch @""
                     :mode :peg-mode-normal
                     #
                     :linemap @[]
                     :linemaplen -1}})
  # =>
  true

  (event? '{:exit 0
            :ret 5
            :index 0
            :peg (sequence (capture (some "smile") :x) (backref :x))
            :grammar @{:main (sequence (capture (some "smile") :x) (backref :x))}
            :state @{:original-text "smile!"
                     :extrav []
                     :has-backref true
                     :outer-text-end 6
                     #
                     :text-start 0
                     :text-end 6
                     #
                     :captures @["smile" "smile"]
                     :tagged-captures @["smile" "smile"]
                     :tags @[:x :x]
                     #
                     :scratch @""
                     :mode :peg-mode-normal
                     #
                     :linemap @[]
                     :linemaplen -1}})
  # =>
  true

  (event? {:exit 1})
  # =>
  false

  )

(defn escape
  [x]
  (->> x
       (peg/match
         ~(accumulate (any (choice (sequence `"` (constant "&quot;"))
                                   (sequence "&" (constant "&amp;"))
                                   (sequence "'" (constant "&#39;"))
                                   (sequence "<" (constant "&lt;"))
                                   (sequence ">" (constant "&gt;"))
                                   (capture 1)))))
       first))

(comment

  (escape "<function replacer>")
  # =>
  "&lt;function replacer&gt;"

  )

(defn idx-for-event-no
  [event-no events]
  (def event (find |(cond
                      (has-key? $ :entry)
                      (= (get $ :entry) event-no)
                      #
                      (has-key? $ :exit)
                      (= (get $ :exit) event-no))
                   events))
  (assert event
          (string/format "failed to find event for event-no: %d" event-no))
  #
  (get event :idx))

(comment

  (idx-for-event-no 2 @[{:entry 1 :idx 0} {:exit 2 :idx 1}])
  # =>
  1

  )

(defn first-event?
  [event events]
  (deep= event (first events)))

(defn last-event?
  [event events]
  (deep= event (last events)))

(defn render-nav
  [buf beg entry prv nxt exit end]
  (buffer/push buf "<pre>")
  (if beg
    (buffer/push buf `<a href="` (string beg) ".html" `">[start]</a>`)
    (buffer/push buf "[start]"))
  (buffer/push buf " ")
  #
  (if entry
    (buffer/push buf `<a href="` (string entry) ".html" `">[entry]</a>`)
    (buffer/push buf "[entry]"))
  (buffer/push buf " ")
  #
  (if prv
    (buffer/push buf `<a href="` (string prv) ".html" `">[prev]</a>`)
    (buffer/push buf "[prev]"))
  (buffer/push buf " ")
  #
  (if nxt
    (buffer/push buf `<a href="` (string nxt) ".html" `">[next]</a>`)
    (buffer/push buf "[next]"))
  (buffer/push buf " ")
  #
  (if exit
    (buffer/push buf `<a href="` (string exit) ".html" `">[exit]</a>`)
    (buffer/push buf "[exit]"))
  (buffer/push buf " ")
  #
  (if end
    (buffer/push buf `<a href="` (string end) ".html" `">[end]</a>`)
    (buffer/push buf "[end]"))
  (buffer/push buf "</pre>"))

(defn render-summary
  [buf event ret events]
  (buffer/push buf "<pre>[")
  #
  (cond
    (has-key? event :entry)
    (buffer/push buf `<font color="green">` "entered" `</font>`)
    #
    (has-key? event :exit)
    (buffer/push buf `<font color="red">` "exiting" `</font>`))
  (def event-no
    (get event :entry (get event :exit)))
  (assert event-no
          (string/format "failed to find event number for event: %n"
                         event))
  (buffer/push buf
               " event "
               `<font color="orange">` (string event-no) `</font>`)
  #
  (when (has-key? event :exit)
    (def ret-str
      (cond
        (= :nil ret)
        "nil"
        #
        (number? ret)
        (string ret)
        #
        (errorf "ret not :nil or number: %n" ret)))
    (buffer/push buf " with value: " ret-str)
    (when (last-event? event events)
      (def outer-ret
        (if (= "nil" ret-str)
          "nil"
          (string/format "%n" (get-in event [:state :captures]))))
      (buffer/push buf "; meg/match returns: ")
      (buffer/push buf
                   (if (= "nil" ret)
                     `<font color="red">`
                     `<font color="green">`)
                   outer-ret
                   `</font>`)))
  #
  (buffer/push buf "]</pre>"))

(defn render-match-params
  [buf event]
  (def spaces
    (string/repeat " " (length "(meg/match ")))
  # XXX: hard-wiring tilde here...is that good enough?
  (buffer/push buf
               "<pre>(meg/match ~"
               (escape (string/format "%n"
                                      (get-in event [:state :grammar]))))
  (buffer/push buf
               "\n" spaces
               `"`
               `<font color="green">`
               (escape (string/slice (get-in event [:state :original-text])
                                     0 (get event :index)))
               `</font>`
               `<font color="red">`
               (escape (string/slice (get-in event [:state :original-text])
                                     (get event :index)))
               `</font>`
               `"`)
  (def start (get-in event [:state :start]))
  (def args (get-in event [:state :extrav]))
  (cond
    (not (empty? args))
    (do
      (buffer/push buf
                   "\n" spaces
                   (escape (string start)))
      (buffer/push buf
                   "\n" spaces
                   ;(map |(escape (string/format "%n " $)) args))
      # remove last space
      (buffer/popn buf 1))
    #
    (not (zero? start))
    (buffer/push buf
                 "\n" spaces
                 (escape (string start))))
  (buffer/push buf ")</pre>"))

(defn render-captures-et-al
  [buf event]
  (buffer/push buf
               "<pre>captures: "
               (escape (string/format "%n" (get-in event [:state :captures])))
               "</pre>")
  (def tags (get-in event [:state :tags]))
  (when (not (empty? tags))
    (def tagged-captures (get-in event [:state :tagged-captures]))
    (def tag-map (zipcoll tags tagged-captures))
    (buffer/push buf
                 "<pre>tagged-captures: "
                 (escape (string/format "%n" tag-map))
                 "</pre>"))
  (def mode (get-in event [:state :mode]))
  (when (= mode :peg-mode-accumulate)
    (buffer/push buf
                 "<pre>mode: "
                 (escape mode)
                 "</pre>")
    (buffer/push buf
                 "<pre>scratch: "
                 `@"`
                 (escape (get-in event [:state :scratch]))
                 `"`
                 "</pre>")))

(defn render-event-params
  [buf event ret]
  (buffer/push buf
               "<pre>peg: "
               `<font color="orange">`
               (escape (string/format "%n" (get event :peg)))
               `</font>`)
  (buffer/push buf " ")
  #
  (def text
    (string/slice (get-in event [:state :original-text])
                  (get-in event [:state :text-start])
                  (get-in event [:state :text-end])))
  (def index (get event :index))
  #
  (buffer/push buf "</pre>")
  #
  (buffer/push buf
               "<pre>text: "
               `<font color="green">`
               (escape (string/slice text 0 index))
               `</font>`
               `<font color="red">`
               (escape (string/slice text index))
               `</font>`
               "</pre>")
  #
  (buffer/push buf
               "<pre>index: "
               (string (get event :index)))
  (when (has-key? event :exit)
    (when (and (number? ret) (> ret index))
      (buffer/push buf
                   " advanced to: "
                   `<font color="green">` (string ret) `</font>`)))
  (buffer/push buf "</pre>")
  #
  (when (has-key? event :exit)
    (buffer/push buf "<pre>matched: ")
    (cond
      (= ret :nil)
      (buffer/push buf `<font color="red">` "no" `</font>`)
      #
      (number? ret)
      (let [match-str (escape (string/slice text index ret))]
        (buffer/push buf `"<font color="green">` match-str `</font>"`))
      #
      (errorf "ret not :nil or number: %n" ret))
    (buffer/push buf "</pre>")))

(defn render-backtrace
  [buf stack events]
  (def backtrace (reverse stack))
  (def top (first backtrace))
  (def top-event-no (get top :entry))
  (def top-idx (idx-for-event-no top-event-no events))
  (buffer/push buf
               "<pre>"
               `<font color="orange">`
               (string `<a color="orange" href="` top-idx ".html" `">`
                       top-event-no `</a>`
                       " " (escape (string/format "%n" (get top :peg)))
                       "\n")
               `</font>`
               ;(map |(let [event-no (get $ :entry)
                            idx (idx-for-event-no event-no events)
                            peg (get $ :peg)]
                        (string `<a href="` idx ".html" `">`
                                event-no `</a>`
                                " " (escape (string/format "%n" peg))
                                "\n"))
                     (drop 1 backtrace))
               "</pre>"))

(defn find-entry
  [event events]
  (assert (has-key? event :exit)
          (string/format "expected exit, got: %n" event))
  (def event-no (get event :exit))
  (def entry
    (find |(= event-no (get $ :entry))
          events))
  (assert entry
          (string/format "failed to find entry for: %n" event))
  #
  (get entry :idx))

(defn find-exit
  [event events]
  (assert (has-key? event :entry)
          (string/format "expected entry, got: %n" event))
  (def event-no (get event :entry))
  (def exit
    (find |(= event-no (get $ :exit))
          events))
  (assert exit
          (string/format "failed to find exit for: %n" event))
  #
  (get exit :idx))

(defn render-event
  [event prv nxt stack events]
  (assert (or (has-key? event :entry)
              (has-key? event :exit))
          (string/format "event must have :entry or :exit: %n" event))
  (def buf @"")
  (def ret
    (when (has-key? event :exit)
      (get event :ret)))
  (def beg
    (when (not (first-event? event events))
      0))
  (def end
    (when (not (last-event? event events))
      (dec (length events))))
  (def entry
    (when (has-key? event :exit)
      (find-entry event events)))
  (def exit
    (when (has-key? event :entry)
      (find-exit event events)))
  #
  (render-summary buf event ret events)
  (buffer/push buf "\n")
  (render-nav buf beg entry prv nxt exit end)
  (buffer/push buf "<hr>")

  (render-match-params buf event)
  (buffer/push buf "<hr>")

  (render-captures-et-al buf event)
  (buffer/push buf "<hr>")

  (render-event-params buf event ret)
  (buffer/push buf "<hr>")

  (render-backtrace buf stack events)
  #
  buf)

########################################################################

(comment

  (meg/match ~(sequence (capture (some "smile") :x)
                        (backref :x))
             "smile!")

  (meg/match "a" "b")

  (meg/match ~(sequence (capture "a") "b" (capture "c"))
             "abc")

  (meg/match ~(sub (capture "abcd") (capture "abc"))
             "abcdef")

  (meg/match ~(sub (capture "abcd")
                   (sub (capture "abc")
                        (capture "ab")))
             "abcdef")

  (meg/match ~(sequence (to "jane")
                        (sub (thru "bits")
                             (split ", " (capture (some 1)))) :s+
                        (to "us")
                        (capture "us"))
             "all your janet, c, bits are belong to us")

  (meg/match ~(split "," (capture 1))
             "a,b,c")

  (meg/match ~(cmt (capture 1)
                   ,(fn [cap]
                      (= cap "a")))
             "ab")

  (meg/match ~(capture "a") "ba" 1)
  
  (meg/match ~(capture "a") "ba" 0 :a :b)

  (meg/match ~(accumulate (sequence (capture 1)
                                    (capture 1)
                                    (capture 1)))
             "abc")

  (meg/match ~(look 3 (capture "cat"))
             "my cat")

  (meg/match ~(sequence (number :d nil :tag)
                        (capture (lenprefix (backref :tag)
                                            1)))
             "3abc")

  (meg/match ~{:main (sequence :tagged -1)
               :tagged (unref (replace (sequence :open-tag :value :close-tag)
                                       ,struct))
               :open-tag (sequence (constant :tag)
                                   "<"
                                   (capture :w+ :tag-name)
                                   ">")
               :value (sequence (constant :value)
                                (group (any (choice :tagged :untagged))))
               :close-tag (sequence "</"
                                    (backmatch :tag-name)
                                    ">")
               :untagged (capture (any (if-not "<" 1)))}
             "<p><em>Hello</em></p>")

  (meg/match ~{:space (some " ")
               :trailing '(any (if-not (set "\0\r\n") 1))
               :middle '(some (if-not (set " \0\r\n") 1))
               :params (+ -1 (* :space
                                (+ (* ":" :trailing)
                                   (* :middle :params))))
               :command (+ '(some (range "az" "AZ"))
                           (/ '(between 3 3 (range "09"))
                              ,scan-number))
               :word (some (if-not " " 1))
               :prefix ':word
               :main (* (? (* (constant :prefix)
                              ":" :prefix :space))
                        (constant :command)
                        :command
                        (constant :params)
                        (group :params))}
             ":okwhatever OPER ASMR asmr")

  )

########################################################################

(defn args-from-cmd-line
  [& argv]
  (assert (>= (length argv) 2)
          (string/format "at least peg and string required"))

  (def peg
    (let [cand (get argv 0)]
      (assert cand "expected peg, got nothing")
      (def [success? result] (protect (parse cand)))
      (assert success?
              (string/format "failed to parse peg, got:\n  `%s`"
                             result))
      result))

  (assert (meg/analyze peg)
          (string/format "problem with peg: %n" peg))

  (def text
    (let [result (get argv 1)]
      (assert result "expected text, got nothing")
      result))

  (def start
    (let [result (scan-number (get argv 2 "0"))]
      (assert result
              (string/format "expected number or nothing, got: %s"
                             (get argv 2)))
      result))

  # XXX: should check for errors and report here...
  (def args
    (map parse (drop 3 argv)))

  {:peg peg
   :text text
   :start start
   :args args})

########################################################################

(defn events?
  [cand]
  (assert (array? cand)
          (string/format "expected array but found %s" (type cand)))
  #
  (each item cand
    (assert (event? item)
            (string/format "invalid event: %n" item)))
  #
  true)

########################################################################

(defn main
  ````
  Render HTML files to represent a `meg/match` call.

  Input:

  If the first argument is a dictionary, it may have the keys:

  * :peg
  * :text
  * :start (optional)
  * :args (optional)

  with associated values to correspond to a call to `meg/match`.

  An example dictionary is:

  ```
  {:peg '(sequence "e")
   :text "hello"
   :start 1
   :args []}
  ```

  Otherwise, the arguments are assumed to result from a command line
  invocation and should all be strings.  The first argument will be
  ignored as it represents the "executing" file.  The subsequent
  arguments should be strings representing values (which the code will
  try to "cast" appropriately) that are to be passed to `meg/match`.

  A suitable command line invocation might be:

  ```
  render.janet '(capture "b")' "ab" 1
  ```

  Output:

  The resulting HTML files have names like `0.html`, `1.html`, etc.
  That is, an integer followed by `.html`.  These are created in the
  current directory.

  Each file represents an "event" in a trace of the execution of the
  `meg/match` call.  The first event is represented by `0.html`, the
  next event by `1.html`, etc.

  ````
  [& argv]
  (def {:peg peg
        :text text
        :start start
        :args args}
    # XXX: is there a better check?
    (if (dictionary? (get argv 0))
      (get argv 0)
      (args-from-cmd-line ;(drop 1 argv))))

  # XXX: check peg, text, start, and args?

  (with [of (file/temp)]
    (os/setenv "VERBOSE" "1")
    (setdyn :meg-trace of)
    (setdyn :meg-color false)

    (meg/match peg text start ;args)

    (file/seek of :set 0)

    (def content (file/read of :all))

    (assert (not (empty? content)) "trace empty")

    (def [success? events] (protect (parse-all content)))

    (assert success? "failed to parse trace data")

    (assert (events? events) "invalid events")

    # XXX: raw log for debugging
    (spit "dump.jdn" (string/format "%n" events))

    (def stack @[])

    (eachp [idx event] events
      (when (has-key? event :entry)
        (array/push stack event))
      #
      (def prv
        (if (zero? idx) nil (dec idx)))
      (def nxt
        (if (= idx (dec (length events))) nil (inc idx)))
      #
      (spit (string/format "%d.html" idx)
            (render-event event prv nxt stack events))
      #
      (when (has-key? event :exit)
        (assert (= (get event :exit)
                   (get (array/peek stack) :entry))
                (string/format "mismatch - expected: %d, but got: %d"
                               (get event :exit)
                               (get (array/peek stack) :entry)))
        (array/pop stack)))))

(defn render
  ``
  Convenience function for tersely invoking `main`.
  ``
  [peg text &opt start & args]
  (default start 0)
  (default args [])
  (main {:peg peg
         :text text
         :start start
         :args args}))
