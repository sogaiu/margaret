(import ../../../margaret/meg :as peg)

(comment

  (defn- named-capture
    [rule &opt name]
    (default name rule)
    ~(sequence (constant ,name) (capture ,rule)))

  (def- uri-grammar
    ~{
      :main (sequence :URI-reference (not 1))
      :URI-reference (choice :URI :relative-ref)
      :URI
      (sequence ,(named-capture :scheme)
                ":" :hier-part
                (opt (sequence "?"
                               ,(named-capture :query :raw-query)))
                (opt (sequence "#"
                               ,(named-capture :fragment :raw-fragment))))
      :relative-ref
      (sequence :relative-part
                (opt (sequence "?" ,(named-capture :query :raw-query)))
                (opt (sequence "#" ,(named-capture :fragment :raw-fragment))))
      :hier-part
      (choice (sequence "//" :authority :path-abempty)
              :path-absolute :path-rootless :path-empty)
      :relative-part
      (choice (sequence "//" :authority :path-abempty)
              :path-absolute :path-noscheme :path-empty)
      :scheme (sequence :a (any (choice :a :d "+" "-" ".")))
      :authority
      (sequence (opt (sequence ,(named-capture :userinfo) "@"))
                ,(named-capture :host)
                (opt (sequence ":" ,(named-capture :port))))
      :userinfo (any (choice :unreserved :pct-encoded :sub-delims ":"))
      :host (choice :IP-literal :IPv4address :reg-name)
      :port (any :d)
      :IP-literal (sequence "[" (choice :IPv6address :IPvFuture  ) "]" )
      :IPv4address
      (sequence :dec-octet "." :dec-octet "." :dec-octet "." :dec-octet)
      :IPvFuture
      (sequence "v" (at-least 1 :hexdig)
                "." (at-least 1 (sequence :unreserved :sub-delims ":")))
      :IPv6address
      (choice
        (sequence (repeat 6 (sequence :h16 ":")) :ls32)
        (sequence "::" (repeat 5 (sequence :h16 ":")) :ls32)
        (sequence (opt :h16)
                  "::" (repeat 4 (sequence :h16 ":")) :ls32)
        (sequence (opt (sequence (at-most 1 (sequence :h16 ":")) :h16))
                  "::"
                  (repeat 3 (sequence :h16 ":")) :ls32)
        (sequence (opt (sequence (at-most 2 (sequence :h16 ":")) :h16))
                  "::"
                  (repeat 2 (sequence :h16 ":")) :ls32)
        (sequence (opt (sequence (at-most 3 (sequence :h16 ":")) :h16))
                  "::" (sequence :h16 ":") :ls32)
        (sequence (opt (sequence (at-most 4 (sequence :h16 ":")) :h16))
                  "::" :ls32)
        (sequence (opt (sequence (at-most 5 (sequence :h16 ":")) :h16))
                  "::" :h16)
        (sequence (opt (sequence (at-most 6 (sequence :h16 ":")) :h16))
                  "::"))
      :h16 (between 1 4 :hexdig)
      :ls32 (choice (sequence :h16 ":" :h16) :IPv4address)
      :dec-octet
      (choice (sequence "25" (range "05"))
              (sequence "2" (range "04") :d)
              (sequence "1" :d :d)
              (sequence (range "19") :d) :d)
      :reg-name (any (choice :unreserved :pct-encoded :sub-delims))
      :path (choice :path-abempty :path-absolute
                    :path-noscheme :path-rootless :path-empty)
      :path-abempty  ,(named-capture ~(any (sequence "/" :segment)) :raw-path)
      :path-absolute
      ,(named-capture
         ~(sequence "/"
                    (opt (sequence :segment-nz
                                   (any (sequence "/" :segment)))))
         :raw-path)
      :path-noscheme
      ,(named-capture
         ~(sequence :segment-nz-nc
                    (any (sequence "/" :segment)))
         :raw-path)
      :path-rootless
      ,(named-capture
         ~(sequence :segment-nz
                    (any (sequence "/" :segment)))
         :raw-path)
      :path-empty (not :pchar)
      :segment (any :pchar)
      :segment-nz (some :pchar)
      :segment-nz-nc (some (choice :unreserved :pct-encoded :sub-delims "@" ))
      :pchar (choice :unreserved :pct-encoded :sub-delims ":" "@")
      :query (any (choice :pchar (set "/?")))
      :fragment (any (choice :pchar (set "/?")))
      :pct-encoded (sequence "%" :hexdig :hexdig)
      :unreserved (choice :a :d  (set "-._~"))
      :gen-delims (set ":/?#[]@")
      :sub-delims (set "!$&'()*+,;=")
      :hexdig (choice :d (range "AF") (range "af"))
      })

  (peg/match uri-grammar "foo://127.0.0.1")
  # => @[:scheme "foo" :host "127.0.0.1" :raw-path ""]

  (deep=
    (peg/match uri-grammar
               "foo://example.com:8042/over%20there?name=fer%20ret#nose")
    #
    @[:scheme "foo"
      :host "example.com"
      :port "8042" 
      :raw-path "/over%20there"
      :raw-query "name=fer%20ret"
      :raw-fragment "nose"]) # => true
  
  (peg/match uri-grammar "/over/there?name=ferret#nose")
  # => @[:raw-path "/over/there" :raw-query "name=ferret" :raw-fragment "nose"]

  (peg/match uri-grammar "//")
  # => @[:host "" :raw-path ""]

  (peg/match uri-grammar "/")
  # => @[:raw-path "/"]
  
  (peg/match uri-grammar "")
  # => @[]

)
