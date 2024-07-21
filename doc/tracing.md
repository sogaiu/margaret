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
(e.g. "1") [1].

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
{:event-num 0 :type :entry :frame-num 0 :index 0 :peg (sequence (capture (some "smile") :x) (backref :x)) :grammar @{:main (sequence (capture (some "smile") :x) (backref :x))} :state @{:captures @[] :extrav () :grammar (sequence (capture (some "smile") :x) (backref :x)) :has-backref true :linemap @[] :linemaplen -1 :mode :peg-mode-normal :original-text "smile!" :outer-text-end 6 :scratch @"" :start 0 :tagged-captures @[] :tags @[] :text-end 6 :text-start 0} }
...
{:event-num 11 :type :exit :frame-num 0 :ret 5 :index 0 :peg (sequence (capture (some "smile") :x) (backref :x)) :grammar @{:main (sequence (capture (some "smile") :x) (backref :x))} :state @{:captures @["smile" "smile"] :extrav () :grammar (sequence (capture (some "smile") :x) (backref :x)) :has-backref true :linemap @[] :linemaplen -1 :mode :peg-mode-normal :original-text "smile!" :outer-text-end 6 :scratch @"" :start 0 :tagged-captures @["smile" "smile"] :tags @[:x :x] :text-end 6 :text-start 0} }
```

Not very pretty for sure.  With a suitable terminal, there is some
color involved, so for folks with sufficient visual color-processing
capabilities, that might be of some help in perceiving the output.

Some rearrangement and modification might make it look something like:

```janet
{:event-num 0
 :type :entry
 :frame-num 0
 :index 0
 :peg (sequence (capture (some "smile") :x) (backref :x))
 :grammar @{:main (sequence (capture (some "smile") :x) (backref :x))}
 :state @{:original-text "smile!"
          :extrav []
          :has-backref true
          :outer-text-end 6
          #
          :text-start 0
          :text-end 6
          #
          :captures @[]
          :tagged-captures @[]
          :tags @[]
          #
          :scratch @""
          :mode :peg-mode-normal
          #
          :linemap @[]
          :linemaplen -1
          #
          :start 0
          ...}}
...
{:event-num 11
 :type :exit
 :frame-num 0
 :ret 5
 :index 0
 :peg (sequence (capture (some "smile") :x) (backref :x))
 :grammar @{:main (sequence (capture (some "smile") :x) (backref :x))}
 :state @{:original-text "smile!"
          :extrav []
          :has-backref true
          :outer-text-end 6
          #
          :text-start 0
          :text-end 6
          #
          :captures @["smile" "smile"]
          :tagged-captures @["smile" "smile"]
          :tags @[:x :x]
          #
          :scratch @""
          :mode :peg-mode-normal
          #
          :linemap @[]
          :linemaplen -1
          #
          :start 0
          ...}}
```

### Explanation of Output

The above output should be "readable" / "parseable" by `janet` [2].
Further, it should correspond to a series of structs.

There are three types of structs:

* one for entry into processing a particular peg special,
* another for exiting, and
* lastly one for errors

The common key-value pairs for the structs are:

* `:event-num` - number representing the sequential order of the event
* `:type` - keyword specifying which of the three event types the event is
* `:frame-num` - number representing a single peg call frame (multiple
  events share a single frame)
* `:index` - the index position of the text being matched over
* `:peg`- the currently relevant peg "call"
* `:grammar` - grammar being matched against [3]
* `:state` - represents execution state for the peg; similar to
[`PegState`](https://github.com/janet-lang/janet/blob/e2a8951f688fec8362f725e4a8afd3c79bc1854e/src/core/peg.c#L38-L62)
in Janet's `peg.c`

Each exit event also has a `:ret` key associated with a return value
(index position or `:nil`).

Each error event also has an `:err` key associated with a string
describing the error.

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

[1] Logging can be configured via two dynamic variables:

* `:meg-trace` - default is `stderr`, set to some other `core/file`
  (e.g. the return value of `(file/temp)`) to make output go elsewhere
* `:meg-color` - default is `true`, set to `false` for no color

[2] To handle "unreadable" values, strings are used instead, so
e.g. something like:

```janet
(fn replacer [] :new-value)
```

might end up looking like:

```janet
"<function replacer>"
```

[3] This may be slightly different from what you might expect due to
some internal preprocessing.  For example, if you specified:

```janet
(some "hello")
```

as the PEG to be matched against, you might see instead:

```janet
@{:main (some "hello")}
```

AFAIU, this should be fine for the most part.
