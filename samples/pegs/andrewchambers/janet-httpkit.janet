(import ../../../margaret/meg :as peg)

(comment
  
  # https://tools.ietf.org/html/rfc2616
  # https://tools.ietf.org/html/rfc6265
  (def- cookie-header-peg
    ~{
      :main (sequence :OWS :cookie-string :OWS (not 1))
      :OWS (any (sequence (opt :obs-fold) :WSP))
      :obs-fold "\r\n"
      :WSP (set " \t")
      :cookie-string (sequence :cookie-pair (any (sequence "; " :cookie-pair)))
      :cookie-pair   (sequence :cookie-name "=" :cookie-value)
      :cookie-value  (choice
                       (capture  (any :cookie-octet))
                       # XXX do we need to unescape within the quotes?
                       (sequence "\"" (capture (any :cookie-octet)) "\""))
      :cookie-name   (capture :token)
      :cookie-octet  (choice "\x21"
                             (range "\x23\x2b")
                             (range "\x2d\x3a")
                             (range "\x3c\x5b")
                             (range "\x5d\x7e"))
      :token (some (sequence (not (choice :CTL :separator)) 1))
      :CTL (choice 127 (range "\x00\x1f"))
      :separator (set "()<>@,;:\\\"/[]?={} \t")
      })

  (deep=
    (peg/match cookie-header-peg "a=b; b=c")
    @["a" "b" "b" "c"])
  # => true

  )
