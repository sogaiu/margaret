(import ./meg)

(defn frame?
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

  (frame? '{:entry 0
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

  (frame? '{:exit 0
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

  (frame? {:exit 1})
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

(defn idx-for-frame-no
  [frame-no frames]
  (def frame (find |(cond
                      (has-key? $ :entry)
                      (= (get $ :entry) frame-no)
                      #
                      (has-key? $ :exit)
                      (= (get $ :exit) frame-no))
                   frames))
  (assert frame
          (string/format "failed to find frame for frame-no: %d" frame-no))
  #
  (get frame :idx))

(comment

  (idx-for-frame-no 2 @[{:entry 1 :idx 0} {:exit 2 :idx 1}])
  # =>
  1

  )

(defn first-frame?
  [frame frames]
  (deep= frame (first frames)))

(defn last-frame?
  [frame frames]
  (deep= frame (last frames)))

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
  [buf frame ret frames]
  (buffer/push buf "<pre>[")
  #
  (cond
    (has-key? frame :entry)
    (buffer/push buf `<font color="green">` "entered" `</font>`)
    #
    (has-key? frame :exit)
    (buffer/push buf `<font color="red">` "exiting" `</font>`))
  (def frame-no
    (get frame :entry (get frame :exit)))
  (assert frame-no
          (string/format "failed to find frame number for frame: %n"
                         frame))
  (buffer/push buf
               " frame "
               `<font color="orange">` (string frame-no) `</font>`)
  #
  (when (has-key? frame :exit)
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
    (when (last-frame? frame frames)
      (def outer-ret
        (if (= "nil" ret-str)
          "nil"
          (string/format "%n" (get-in frame [:state :captures]))))
      (buffer/push buf "; peg/match returns: ")
      (buffer/push buf
                   (if (= "nil" ret)
                     `<font color="red">`
                     `<font color="green">`)
                   outer-ret
                   `</font>`)))
  #
  (buffer/push buf "]</pre>"))

(defn render-match-params
  [buf frame]
  (def spaces
    (string/repeat " " (length "(peg/match ")))
  # XXX: hard-wiring tilde here...is that good enough?
  (buffer/push buf
               "<pre>(peg/match ~"
               (escape (string/format "%n"
                                      (get-in frame [:state :grammar]))))
  (buffer/push buf
               "\n" spaces
               `"`
               `<font color="green">`
               (escape (string/slice (get-in frame [:state :original-text])
                                     0 (get frame :index)))
               `</font>`
               `<font color="red">`
               (escape (string/slice (get-in frame [:state :original-text])
                                     (get frame :index)))
               `</font>`
               `"`)
  (def start (get-in frame [:state :start]))
  (def args (get-in frame [:state :extrav]))
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
  [buf frame]
  (buffer/push buf
               "<pre>captures: "
               (escape (string/format "%n" (get-in frame [:state :captures])))
               "</pre>")
  (def tags (get-in frame [:state :tags]))
  (when (not (empty? tags))
    (def tagged-captures (get-in frame [:state :tagged-captures]))
    (def tag-map (zipcoll tags tagged-captures))
    (buffer/push buf
                 "<pre>tagged-captures: "
                 (escape (string/format "%n" tag-map))
                 "</pre>"))
  (def mode (get-in frame [:state :mode]))
  (when (= mode :peg-mode-accumulate)
    (buffer/push buf
                 "<pre>mode: "
                 (escape mode)
                 "</pre>")
    (buffer/push buf
                 "<pre>scratch: "
                 `@"`
                 (escape (get-in frame [:state :scratch]))
                 `"`
                 "</pre>")))

(defn render-frame-params
  [buf frame ret]
  (buffer/push buf
               "<pre>peg: "
               `<font color="orange">`
               (escape (string/format "%n" (get frame :peg)))
               `</font>`)
  (buffer/push buf " ")
  #
  (def text
    (string/slice (get-in frame [:state :original-text])
                  (get-in frame [:state :text-start])
                  (get-in frame [:state :text-end])))
  (def index (get frame :index))
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
               (string (get frame :index))
               "</pre>")
  #
  (when (has-key? frame :exit)
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
  [buf stack frames]
  (def backtrace (reverse stack))
  (def top (first backtrace))
  (def top-frame-no (get top :entry))
  (def top-idx (idx-for-frame-no top-frame-no frames))
  (buffer/push buf
               "<pre>"
               `<font color="orange">`
               (string `<a color="orange" href="` top-idx ".html" `">`
                       top-frame-no `</a>`
                       " " (escape (string/format "%n" (get top :peg)))
                       "\n")
               `</font>`
               ;(map |(let [frame-no (get $ :entry)
                            idx (idx-for-frame-no frame-no frames)
                            peg (get $ :peg)]
                        (string `<a href="` idx ".html" `">`
                                frame-no `</a>`
                                " " (escape (string/format "%n" peg))
                                "\n"))
                     (drop 1 backtrace))
               "</pre>"))

(defn find-entry
  [frame frames]
  (assert (has-key? frame :exit)
          (string/format "expected exit, got: %n" frame))
  (def frame-no (get frame :exit))
  (def entry
    (find |(= frame-no (get $ :entry))
          frames))
  (assert entry
          (string/format "failed to find entry for: %n" frame))
  #
  (get entry :idx))

(defn find-exit
  [frame frames]
  (assert (has-key? frame :entry)
          (string/format "expected entry, got: %n" frame))
  (def frame-no (get frame :entry))
  (def exit
    (find |(= frame-no (get $ :exit))
          frames))
  (assert exit
          (string/format "failed to find exit for: %n" frame))
  #
  (get exit :idx))

(defn render-frame
  [frame prv nxt stack frames]
  (assert (or (has-key? frame :entry)
              (has-key? frame :exit))
          (string/format "frame must have :entry or :exit: %n" frame))
  (def buf @"")
  (def ret
    (when (has-key? frame :exit)
      (get frame :ret)))
  (def beg
    (when (not (first-frame? frame frames))
      0))
  (def end
    (when (not (last-frame? frame frames))
      (dec (length frames))))
  (def entry
    (when (has-key? frame :exit)
      (find-entry frame frames)))
  (def exit
    (when (has-key? frame :entry)
      (find-exit frame frames)))
  #
  (render-summary buf frame ret frames)
  (buffer/push buf "\n")
  (render-nav buf beg entry prv nxt exit end)
  (buffer/push buf "<hr>")

  (render-match-params buf frame)
  (buffer/push buf "<hr>")

  (render-captures-et-al buf frame)
  (buffer/push buf "<hr>")

  (render-frame-params buf frame ret)
  (buffer/push buf "<hr>")

  (render-backtrace buf stack frames)
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

(defn main
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

    (assert (not (empty? content))
            "expected non-empty content")

    (def [success? results] (protect (parse content)))

    (when (not success?)
      (eprintf "failed to parse content")
      (os/exit 1))

    (assert (tuple? results)
            (string/format "expected tuple but found %s" (type results)))

    (assert (all |(if (frame? $)
                    true
                    (pp [:frame $]))
                 results)
            (string/format "expected all elements to be frames"))

    # XXX: raw log for debugging
    (spit "dump.jdn" (string/format "%n" results))

    (def frames @[])

    # replace frames within results
    (eachp [idx frame] results
      (def frame-mod (struct/to-table frame))
      (put frame-mod :idx idx)
      (put frames idx frame-mod))

    (def stack @[])

    (eachp [idx frame] frames
      (when (has-key? frame :entry)
        (array/push stack frame))
      #
      (def prv
        (if (zero? idx) nil (dec idx)))
      (def nxt
        (if (= idx (dec (length frames))) nil (inc idx)))
      #
      (spit (string/format "%d.html" idx)
            (render-frame frame prv nxt stack frames))
      #
      (when (has-key? frame :exit)
        (assert (= (get frame :exit)
                   (get (array/peek stack) :entry))
                (string/format "mismatch - expected: %d, but got: %d"
                               (get frame :exit)
                               (get (array/peek stack) :entry)))
        (array/pop stack)))))

(defn render
  [peg text &opt start & args]
  (default start 0)
  (default args [])
  (main {:peg peg
         :text text
         :start start
         :args args}))
