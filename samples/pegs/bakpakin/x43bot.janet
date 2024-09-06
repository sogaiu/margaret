(import ../../../margaret/meg :as peg)

(comment

  # section 2.3.1 of rfc 1459

  (def irc-peg
    "PEG to parser server IRC commands. Defined in RFC 1459"
    (peg/compile
      ~{:space (some " ")
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
                 (group :params))
        }))

  (peg/match irc-peg "NICK")
  # =>
  @[:command "NICK" :params @[]]

  (peg/match irc-peg "888")
  # =>
  @[:command 888 :params @[]]

  (peg/match irc-peg ":okwhatever OPER ASMR asmr")
  # =>
  @[:prefix "okwhatever" :command "OPER" :params @["ASMR" "asmr"]]

  )
