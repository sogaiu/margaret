# Tracing

The support for tracing is in its infancy, but it is perhaps somewhat
better compared to having no information about execution flow (^^;

Note `margaret`'s execution flow may differ from Janet's `peg.c` in
some cases, see the Caveats section below for details.

## Example Output

So, what does tracing output look like?

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

```janet
[
{:entry 0 :index 0 :peg "(sequence (capture (some \"smile\") :x) (backref :x))" :grammar "@{:main (sequence (capture (some \"smile\") :x) (backref :x))}" :state @{:captures "@[]" :depth 1024 :extrav "()" :has-backref true :linemap @[] :linemaplen -1 :mode :peg-mode-normal :original-text "smile!" :outer-text-end 6 :scratch @"" :tagged-captures "@[]" :tags @[] :text-end 6 :text-start 0} }
...
{:exit 0 :ret 5 :index 0 :peg "(sequence (capture (some \"smile\") :x) (backref :x))" :grammar "@{:main (sequence (capture (some \"smile\") :x) (backref :x))}" :state @{:captures "@[\"smile\" \"smile\"]" :depth 1024 :extrav "()" :has-backref true :linemap @[] :linemaplen -1 :mode :peg-mode-normal :original-text "smile!" :outer-text-end 6 :scratch @"" :tagged-captures "@[\"smile\" \"smile\"]" :tags @[:x :x] :text-end 6 :text-start 0} }
]
```

Not very pretty for sure.  With a suitable terminal, there is some
color involved, so for folks with sufficient visual color-processing
capabilities, that might be of some help in perceiving the output.

Reformatted, it could look something like this:

```janet
[
 {:entry 0
  :index 0
  :peg "(sequence (capture (some \"smile\") :x) (backref :x))"
  :grammar "@{:main (sequence (capture (some \"smile\") :x) (backref :x))}"
  :state @{:original-text "smile!"
           :extrav "()"
           :has-backref true
           :outer-text-end 6
           #
           :text-start 0
           :text-end 6
           #
           :captures "@[]"
           :tagged-captures "@[]"
           :tags @[]
           #
           :scratch @""
           :mode :peg-mode-normal
           #
           :linemap @[]
           :linemaplen -1
           :depth 1024}}
 ...
 {:exit 0
  :ret 5
  :index 0
  :peg "(sequence (capture (some \"smile\") :x) (backref :x))"
  :grammar "@{:main (sequence (capture (some \"smile\") :x) (backref :x))}"
  :state @{:original-text "smile!"
           :extrav "()"
           :has-backref true
           :outer-text-end 6
           #
           :text-start 0
           :text-end 6
           #
           :captures "@[\"smile\" \"smile\"]"
           :tagged-captures "@[\"smile\" \"smile\"]"
           :tags @[:x :x]
           #
           :scratch @""
           :mode :peg-mode-normal
           #
           :linemap @[]
           :linemaplen -1
           :depth 1024}}
]
```

Discussion and ideas welcome (^^;

### Explanation of Output

The above output should be "readable" / "parseable" by `janet`.
Further, it should correspond to a tuple where each element is a
struct.

There are two types of structs, one for entry into processing a
particular peg special and the other for exiting.

The common key-value pairs for the structs are:

* `:index` - the index position of the text being matched over
* `:peg` - the currently relevant peg "call"
* `:grammar` - grammar being matched against [1]
* `:state` - represents execution state for the peg; similar to
[`PegState`](https://github.com/janet-lang/janet/blob/e2a8951f688fec8362f725e4a8afd3c79bc1854e/src/core/peg.c#L38-L62)
in Janet's `peg.c`

Each entry struct has an `:entry` key with a corresponding number
representing the current step of execution.

Each exit struct has an `:exit` key with a corresponding number
representing the current step of execution, along with a `:ret` key
associated with a return value (index position).

It should be possible to pair each entry struct with a corresponding
exit struct as they should share the same associated value for
`:entry` and `:exit`, respectively.

## Caveats

Due to implementation differences between `peg.c` and `margaret`,
execution flow may differ in certain ways.

Some known cases include:

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

## Footnotes

[1] This may be slightly different from what you might expect due to
some internal preprocessing.  For example, if you specified:

```janet
(some "hello")
```

as the PEG to be matched against, you might see instead:

```janet
@{:main (some "hello")}
```

AFAIU, this should be fine for the most part.
