(import ../../../margaret/meg :as peg)

(comment

  (def- ascii-chars (string/from-bytes ;(range 256)))
  (def- end-sep "e")

  (def- peg-decode
    ~{:ascii (set ,ascii-chars)
      :sep ,end-sep
      :integer (* "i"
                  (cmt (<- (* (? "-") :d+))
                       ,parse)
                  :sep)
      :string (cmt (* (/ (<- :d+)
                         ,parse :1)
                      ":"
                      (<- (lenprefix (-> :1) :ascii)))
                   ,|$1)
      :list (group (* "l" (any (+ :data)) :sep))
      :table (* "d" (replace (any (* :string :data)) ,struct))
      :data (+ :list :table :integer :string)
      :main (any :data)})

  (peg/match peg-decode "i-7654321e")
  # => @[-7654321]

  (peg/match peg-decode "i1234567e")
  # => @[1234567]
  
  (peg/match peg-decode "i1234ei5678e")
  # => @[1234 5678]

  (peg/match peg-decode "4:abcd")
  # => @["abcd"]

  (peg/match peg-decode "4:abcd4:efgh")
  # => @["abcd" "efgh"]

  (peg/match peg-decode "4:abcdeee")
  # => @["abcd"]

  (peg/match peg-decode "4:abcdi1234e")
  # => @["abcd" 1234]

  (peg/match peg-decode "0:")
  # => @[""]

  (peg/match peg-decode "li3453453ei8232434ei-3434ee")
  # => @[@[3453453 8232434 -3434]]

  (peg/match peg-decode "li4343ee")
  # => @[@[4343]]

  (peg/match peg-decode "l4:abcd4:efghe")
  # => @[@["abcd" "efgh"]]

  (peg/match peg-decode "le")
  # => @[@[]]

  (peg/match peg-decode "d4:spaml1:a1:bee")
  # => @[{"spam" @["a" "b"]}]

  )
