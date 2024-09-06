(import ../../../margaret/meg :as peg)

(comment

  (var common-headers [])

  (defn collect-headers [x]
    (merge
      ;(seq [i :in x :when (i :header)]
         (i :header))))

  (defn pdefs
    [& x]
    (set common-headers (collect-headers x)))

  (defn preq [& x]
    (-> {:headers (collect-headers x)}
        (merge ;x)
        (put :header nil)
        (update :headers merge common-headers)))

  (defn pnode
    [tag]
    (fn [& x]
      {tag ;x}))

  (def request-grammar
    ~{:eol "\n"
      :header (* (/ (/ (* '(* :w (to ":")) ": " '(to "\n")) ,struct)
                    ,(pnode :header)) :eol)
      :definitions (* (/ (* "#" (thru :eol) (some :header)) ,pdefs) :eol)
      :title (* (/ (line) ,(pnode :start))
                (/ (* "#" (/ '(to :eol) ,string/trim) :eol) ,(pnode :title)))
      :method (/ (* '(+ "GET" "POST" "PATCH" "DELETE")) ,(pnode :method))
      :url (/ (* '(to :eol)) ,(pnode :url))
      :command (* :method " " :url :eol)
      :body (/ (* :eol (not "#")
                  '(some (if-not (* :eol (+ -1 :eol)) 1))
                  :eol)
               ,(pnode :body))
      :request (/ (* :title :command (any :header) (? :body)
                     (/ (line) ,(pnode :end)) :eol)
                  ,preq)
      :main (* (drop :definitions) (some :request))
      })
  
  (deep=
    #
    (peg/match
      request-grammar
      ``
      # definitions
      Accept: application/json
      
      # Patching on url
      PATCH https://my.api/products
      Authorization: Bearer Avsdfasdfasdf
      Content-Type: application/json
      
      {
        "price": "bambilion"
      }
      ``)
    #
    @[@{:headers @{"Accept" "application/json"
                   "Authorization" "Bearer Avsdfasdfasdf"
                   "Content-Type" "application/json"}
        :start 4
        :method "PATCH"
        :title "Patching on url"
        :url "https://my.api/products"
        :end 8}]
    )
  # =>
  true

)
