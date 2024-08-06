# Test Writing Tips

## Samples

The [sample repositories](./doc_samples.md) alluded to in the README
contain numerous test examples.  Examining the `(comment ...)`
portions of some of the files in the sample repositories might be
helpful in getting a sense of typical usage.

## Basics

The basic form is:

```janet
(comment

  (- 1 1)
  # =>
  0

  )
```

Within a comment block, express a(t least one) test as a triple of:

* a form to test
* a test indicator
* a form representing an expected value

Thus:

* `(- 1 1)` is a form to be tested,
* `# =>` is a test indicator, and
* `0` expresses that `0` is the expected value

## Multiple Tests Per `comment`

More than one triple (comment block test) can be placed in a comment
block.  For example, for the following:

```janet
(comment

  (+ 1 1)
  # =>
  2

  (- 1 1)
  # =>
  0

  )
```

two tests will be created and executed.

## Non-Tests Within `comment`

It's also fine to put other forms in the comment block, all such forms
may be evaluated during testing.  For example, in the following:

```janet
(comment

  (def a 1)

  (+ a 1)
  # =>
  2

  )
```

`(def a 1)` will be executed during testing.

However, if a comment block has no tests (i.e. no expected values
indicated), the forms within the comment block will NOT be executed.
Thus, for the following:

```janet
(comment

  (print "hi")

  )
```

since there are no expected values indicated, `(print "hi")` will
NOT be executed.  One of the reasons for this behavior is to
prevent pre-existing comment blocks from having unintentional
side-effects.

## Caveats

### Regarding `()`

Use `'()` or `[]` instead of `()` in some places when expressing
expected values that are tuples, e.g.

```janet
...
# =>
'(:hi 1)
```
or:

```janet
...
# =>
[:hi 1]
```

not:

```janet
...
# =>
(:hi 1)
```

This notational rule is necessary because using `()` implies a call
of some sort.

### Regarding `def` and friends

A `def` form will NOT work as "a form to test".  For example:

```janet
(comment

  (def a 1)
  # =>
  1

  )
```

is not valid.

The following will work though, so please use it (or similar) instead:

```janet
(comment

  (def a 1)

  a
  # =>
  1

  )
```

### Regarding `marshal` / `unmarshal`

The expressions in each test must yield values that can be used with
Janet's `marshal`.  (The reason for this limitation is because
`marshal` / `unmarshal` are used to save and restore test results
which are aggregated to produce an overall summary.)

Thus the following will not work:

```janet
(comment

  printf
  # =>
  printf

  )
```

as `marshal` cannot handle `printf`:

```
repl:1:> (marshal printf)
error: no registry value and cannot marshal <cfunction printf>
  in marshal
  in _thunk [repl] (tailcall) on line 2, column 1
```

Though not equivalent, one can do this sort of thing instead:

```janet
(comment

  (describe printf)
  # =>
  "<cfunction printf>"

  )
```

or may be this is sufficient in some cases:

```janet
(comment

  (type printf)
  # =>
  :cfunction

  )
```

