# Notes

## Relevant Files

### Main Program

The core functionality of `jeat` is provided by:

* `make-and-run-tests.janet`

This code drives the process of:

* extracting test expressions
* converting the expressions to tests
* running the tests
* reporting the results

`make-and-run-tests.janet` makes use of:

* `to-test.janet`

to perform the first two steps above.

`to-test.janet` is built up from the following files:

* `loc-jipper.janet` - from janet-location-zipper
* `location.janet` - from janet-peg
* `zipper.janet` - from janet-zipper

`make-and-run-tests.janet`'s behavior can be influenced by command
line parameters and/or per-project configuration info.

The file:

* `default.jeat.janet`

is a sample conf file.  When placed in the root directory of a
project, it should be renamed `.jeat.janet`.  Alternatively, if placed
in a subdirectory named `.jeat`, it should be renamed `init.janet`.

### Conveniences

The file:

* `init.janet`

(not to be confused with what could live in a `.jeat` directory) makes
the use of `jeat` simpler when importing.

### jpm Integration

The file:

* `jeat-from-jpm-test.janet`

is for integration with `jpm test`, and should be placed in a
project's `test` subdirectory.

## Per-Project Configuration

Each project that uses `jeat` should have some configuration info to
specify what to test (at minimum).

At present configuration can be in the form of:

* a file named `.jeat.janet` in the project's root directory, or

* a directory named `.jeat` (in the project's root directory),
  containing a suitable `init.janet` file (an analog of the
  aforementioned .jeat.janet`)

Having configuration info separate from the code that triggers testing
(which is what `juat` (aka `janet-usages-as-tests`) does / did), makes
upgrading / updating easier and can also separate out project-specific
details.

Example content for `.jeat.janet`:

```janet
(defn init
  []
  {# describes what to test - file and dir paths
   :jeat-target-spec
   ["spt"]
   # describes what to skip - file paths only
   #:jeat-exclude-spec
   #["spt/trace/theme.janet"]
   })
```

