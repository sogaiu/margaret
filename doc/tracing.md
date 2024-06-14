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
  calls in margaret so execution results may differ.

## Example Output

### Simple Example

As mentioned elsewhere, tracing output for `margaret` can be enabled
by setting the `VERBOSE` environment variable to a non-empty string
(e.g. "1").

```janet
(import margaret/meg)

(os/setenv "VERBOSE" "1")

(meg/match ~(capture (some "smile"))
           "smile!")
# =>
"smile"
```

Currently, corresponding output looks like:

```

:state: @{:captures @[]
  :depth 1024
  :extrav ()
  :has-backref false
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
:peg: (capture (some "smile"))
:index: 0
:grammar: @{:main (capture (some "smile"))}
entry: (capture (capture (some "smile")) 0 @{:main (capture (some "smile"))})

:state: @{:captures @[]
  :depth 1024
  :extrav ()
  :has-backref false
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
:peg: (some "smile")
:index: 0
:grammar: @{:main (capture (some "smile"))}
entry: (some (some "smile") 0 @{:main (capture (some "smile"))})

:state: @{:captures @[]
  :depth 1024
  :extrav ()
  :has-backref false
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
:peg: "smile"
:index: 0
:grammar: @{:main (capture (some "smile"))}
entry: ("RULE_LITERAL" "smile" 0 @{:main (capture (some "smile"))})
exit: ("RULE_LITERAL" 5 {:index 0 :peg "smile"})

:state: @{:captures @[]
  :depth 1024
  :extrav ()
  :has-backref false
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
:peg: "smile"
:index: 5
:grammar: @{:main (capture (some "smile"))}
entry: ("RULE_LITERAL" "smile" 5 @{:main (capture (some "smile"))})
exit: ("RULE_LITERAL" nil {:index 5 :peg "smile"})
exit: (some 5 {:index 0 :peg (some "smile")})
exit: (capture 5 {:index 0 :peg (capture (some "smile"))})
```

Not very pretty for sure, discussion and ideas welcome (^^;

### Explanation of Output

In the above example, there were a number of lines prefixed with
`entry:` and `exit:`.  The former type of line signals that
processing for a particular PEG special is about to start.

For example, in:

```
entry: ("RULE_LITERAL" "smile" 0 @{:main (capture (some "smile"))})
```

* `"RULE_LITERAL"` is a name for the string primitive pattern,
* `"smile"` is 
