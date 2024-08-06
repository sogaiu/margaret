# Background

It can be useful to record calls:

```janet
(peg/match ~(cmt (capture "hello")
                 ,(fn [cap]
                    (string cap "!")))
           "hello")
```

and the asssociated results:

```janet
@["hello!"]
```

that tend to arise while developing for later reference,
documentation, and/or reuse.

What if these pairs of things could also be used as tests?

```janet
(comment

  (peg/match ~(cmt (capture "hello")
                   ,(fn [cap]
                      (string cap "!")))
             "hello")
  # =>
  @["hello!"]

  )
```

`janet-ex-as-tests` is an evolution of
[janet-usages-as-tests](https://github.com/sogaiu/janet-usages-as-tests).
The basic idea is the same once things are setup.

