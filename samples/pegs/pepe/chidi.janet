(import ../../../margaret/meg :as peg)

(comment

  (defn- caprl [m u q v]
    {:method m
     :uri u
     :query-string q
     :http-version v})
  (defn- caph [n c] {n c})
  (defn- colhs [& hs] {:headers (freeze (merge ;hs))})
  (defn- capb [b] {:body b})
  (defn- colr [& xs] (freeze (merge ;xs)))
  
  (def request-grammar
    ~{:sp " "
      :crlf "\r\n"
      :http "HTTP/"
      :to-sp (* '(to :sp) :sp)
      :to-crlf (* '(to :crlf) :crlf)
      :request (/ (* :to-sp '(to (+ "?" :sp))
                     (any "?") :to-sp :http :to-crlf) ,caprl)
      :header (/ (* '(to ":") ": " :to-crlf) ,caph)
      :headers (/ (* (some :header) :crlf) ,colhs)
      :body (/ '(any (if-not -1 1)) ,capb)
      :main (/ (* :request :headers :body) ,colr)})
  
  (deep=
    (peg/match
      request-grammar
      (string "GET / HTTP/1.1\r\n"
              "Host: example.com\r\n"
              "\r\n"))
    #
    @[{:headers {"Host" "example.com"}
       :body ""
       :uri "/"
       :method "GET"
       :http-version "1.1"
       :query-string ""}]) # => true

  (deep=
    (peg/match
      request-grammar
      (string "GET /fun?key=value HTTP/1.1\r\n"
              "Host: example.org\r\n"
              "\r\n"))
    #
    @[{:headers {"Host" "example.org"}
       :body ""
       :uri "/fun"
       :method "GET"
       :http-version "1.1"
       :query-string "key=value"}]) # => true

)
