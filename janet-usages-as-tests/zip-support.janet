# based on code by corasaurus-hex

# `slice` doesn't necessarily preserve the input type

# XXX: differs from clojure's behavior
#      e.g. (butlast [:a]) would yield nil(?!) in clojure
(defn butlast
  [indexed]
  (if (empty? indexed)
    nil
    (if (tuple? indexed)
      (tuple/slice indexed 0 -2)
      (array/slice indexed 0 -2))))

(comment

  (butlast @[:a :b :c])
  # =>
  @[:a :b]

  (butlast [:a])
  # =>
  []

  )

(defn rest
  [indexed]
  (if (empty? indexed)
    nil
    (if (tuple? indexed)
      (tuple/slice indexed 1 -1)
      (array/slice indexed 1 -1))))

(comment

  (rest [:a :b :c])
  # =>
  [:b :c]

  (rest @[:a])
  # =>
  @[]

  )

# XXX: can pass in array - will get back tuple
(defn tuple-push
  [tup x & xs]
  (if tup
    [;tup x ;xs]
    [x ;xs]))

(comment

  (tuple-push [:a :b] :c)
  # =>
  [:a :b :c]

  (tuple-push nil :a)
  # =>
  [:a]

  (tuple-push @[] :a)
  # =>
  [:a]

  )

(defn to-entries
  [val]
  (if (dictionary? val)
    (pairs val)
    val))

(comment

  (to-entries {:a 1 :b 2})
  # =>
  @[[:a 1] [:b 2]]

  (to-entries {})
  # =>
  @[]

  (to-entries @{:a 1})
  # =>
  @[[:a 1]]

  # XXX: leaving non-dictionaries alone and passing through...
  #      is this desirable over erroring?
  (to-entries [:a :b :c])
  # =>
  [:a :b :c]

  )

# XXX: when xs is empty, "all" becomes nil
(defn first-rest-maybe-all
  [xs]
  (if (or (nil? xs) (empty? xs))
    [nil nil nil]
    [(first xs) (rest xs) xs]))

(comment

  (first-rest-maybe-all [:a :b])
  # =>
  [:a [:b] [:a :b]]

  (first-rest-maybe-all @[:a])
  # =>
  [:a @[] @[:a]]

  (first-rest-maybe-all [])
  # =>
  [nil nil nil]

  # XXX: is this what we want?
  (first-rest-maybe-all nil)
  # =>
  [nil nil nil]

  )

