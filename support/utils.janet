(defn print-color
  [msg color]
  (let [color-num (match color
                    :black 30
                    :blue 34
                    :cyan 36
                    :green 32
                    :magenta 35
                    :red 31
                    :white 37
                    :yellow 33)]
    (prin (string "\e[" color-num "m"
                  msg
                  "\e[0m"))))

(defn dashes
  [&opt n]
  (default n 60)
  (string/repeat "-" n))

(defn print-dashes
  [&opt n]
  (print (dashes n)))

(defn rand-string
  [n]
  (->> (os/cryptorand n)
       (map |(string/format "%02x" $))
       (string/join)))

(comment

  (let [len 8
        res (rand-string len)]
    (truthy? (and (= (length res) (* 2 len))
                  # only uses hex
                  (all |(peg/find '(range "09" "af" "AF")
                                  (string/from-bytes $))
                       res))))
  # => true

  )
