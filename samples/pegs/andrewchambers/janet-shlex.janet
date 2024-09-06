(import ../../../margaret/meg :as peg)

(comment

  (def- grammar
    ~{
      :ws (set " \t\r\n")
      :escape (* "\\" (capture 1))
      :dq-string (accumulate (* "\""
                                (any (+ :escape (if-not "\"" (capture 1))))
                                "\""))
      :sq-string (accumulate (* "'" (any (if-not "'" (capture 1))) "'"))
      :token-char (+ :escape (* (not :ws) (capture 1)))
      :token (accumulate (some :token-char))
      :value (* (any (+ :ws)) (+ :dq-string :sq-string :token) (any :ws))
      :main (any :value)
      })

  (deep=
    (peg/match grammar ` "c d \" f" ' y z'  a b a\ b --cflags `)
    @["c d \" f" " y z" "a" "b" "a b" "--cflags"])
  # =>
  true

)
