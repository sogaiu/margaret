# Tracing

The support for tracing is in its infancy, but it is perhaps somewhat
better compared to having no information about execution flow (^^;

## Caveats

Due to implementation differences between `peg.c` and `margaret`,
execution flow may differ in certain ways.

Some know cases include:

* Janet's native PEG implementation compiles a source PEG to a custom
  bytecode first before "execution".  In this process of compilation,
  some transformations can take place.  For example, at the time of
  this writing, the PEG:

    ```janet
    (range "ac" "02")
    ```

  gets compiled to bytecode that would match the bytecode obtained by
  compiling:

    ```janet
    (set "abc012")
    ```

  Thus, the execution flows of the two implementations can differ
  in certain cases.

* There is currently no attempt at protecting from too many recursive
  calls in `margaret` so execution results may differ.

## Example Output

### Simple Example

As mentioned elsewhere, tracing output for `margaret` can be enabled
by setting the `VERBOSE` environment variable to a non-empty string
(e.g. "1").

```janet
(import margaret/meg)

(os/setenv "VERBOSE" "1")

(meg/match ~(sequence (capture (some "smile") :x)
                      (backref :x))
           "smile!")
# =>
@["smile" "smile"]
```

Currently, corresponding output looks like:

```

:state: @{:captures @[]
  :depth 1024
  :extrav ()
  :has-backref true
  :linemap @[]
  :linemaplen -1
  :mode :peg-mode-normal
  :original-text "smile!"
  :outer-text-end 6
  :scratch @""
  :tagged-captures @[]
  :tags @[]
  :text-end 6
  :text-start 0}
:grammar: @{:main (sequence (capture (some "smile") :x) (backref :x))}
>> entry: (:index 0) (:peg (sequence (capture (some "smile") :x) (backref :x)))

...

:state: @{:captures @["smile"]
  :depth 1024
  :extrav ()
  :has-backref true
  :linemap @[]
  :linemaplen -1
  :mode :peg-mode-normal
  :original-text "smile!"
  :outer-text-end 6
  :scratch @""
  :tagged-captures @["smile"]
  :tags @[:x]
  :text-end 6
  :text-start 0}
:grammar: @{:main (sequence (capture (some "smile") :x) (backref :x))}
>> entry: (:peg (backref :x)) (:index 5)
<< exit: (:ret 5) (:index 5) (:peg (backref :x))
<< exit: (:ret 5) (:index 0) (:peg (sequence (capture (some "smile") :x) (backref :x)))
```

Not very pretty for sure.  With a suitable terminal, there is some
color involved, so for folks with sufficient visual color-processing
capabilities, that might be of some help in perceiving the output.

Discussion and ideas welcome (^^;

### Explanation of Output

In the above output, `:state:` signals that some subsequent lines
represent the overall PEG's execution state.  The content is fairly
similar to
[`PegState`](https://github.com/janet-lang/janet/blob/e2a8951f688fec8362f725e4a8afd3c79bc1854e/src/core/peg.c#L38-L62)
in Janet's `peg.c`.

The lines starting with `:grammar:` indicate the grammar being matched
against.  This may be slightly different from what you might expect
due to some internal preprocessing.  For example, if you specified:

```janet
(some "hello")
```

as the PEG to be matched against, you might see instead:

```janet
@{:main (some "hello")}
```

AFAIU, this should be fine for the most part.

Lines prefixed with:

* `>> entry:`
* `<< exit:`

indicate the entry into and exiting out of processing particular PEG
specials, respectively.

For example, in:

```
>> entry: (:index 5) (:peg (backref :x))
```

* `(:index 5)` means `5` is the index position of the text being matched over,
* `(:peg (backref :x))` means the curent PEG form is `(backref :x)`

Similarly, in:

```
<< exit: (:ret 5) (:index 5) (:peg (backref :x))
```

* `(:ret 5)` means the return value for the PEG is `5` (new index position),
* `(:index 5)` means `5` _was_ the index position of the text being matched over,
* `(:peg (backref :x))` means the curent PEG form is `(backref :x)`

Note that by correlating pairs of `(:index ...)` and `(:peg ...)`
values, one can usually match up entries and exits.
