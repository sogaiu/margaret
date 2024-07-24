# janet-usages-as-tests

Generate and run tests from usage examples

## Background

It can be useful to record usages (calls):

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

`janet-usages-as-tests` is an evolution of
[usages-as-tests](https://github.com/sogaiu/usages-as-tests).  The
basic idea is the same once things are setup.

## Running Tests

### Repositories Using janet-usages-as-tests

Invoke `jpm test` as usual.

### This Repository

Invoking `jpm test` will not work for this repository as it is not set
up to be tested in that manner.

Instead, to test the code in this repository, invoke:
```
janet make-and-run-juat-tests.janet
```

## Setup and Configuration

There are a few ways `janet-usages-as-tests` can be used with some
target project.

The basic idea in each case is to put an appropriate `.janet` file in
the `test` subdirectory of the target project so that it is executed
when `jpm test` is invoked.

The aforementioned `.janet` file is a launching script for code in
`janet-usages-as-tests` and should also be edited to contain names of
files and directories in which to search for usages to convert into
tests.

Some directories are skipped in this process of searching for usages
(to turn into tests), including:

* `.git` directories
* directories containing a file named `.gitrepo`

### Git Subrepo

0. Ensure [git-subrepo](https://github.com/ingydotnet/git-subrepo) is
   installed.

1. In the target project, use the `git subrepo clone` command to
   clone `janet-usages-as-tests` to an appropriate subdirectory of
   the target project.  For the sake of discussion below, let's
   say this subdirectory is named `juat`.

2. Copy `juat/make-and-run-juat-tests-subrepo.janet` to the target
   project's `test` subdirectory.  This file will run via `jpm test`.

3. Edit the just copied `test/make-and-run-juat-tests-subrepo.janet`
   file so that it:

     * uses `juat/janet-usages-as-tests/make-and-run-tests.janet` [*]

     * specifies files and/or directories that are the target of
       usages to be treated as tests

Some repositories that use this method include:

* [janet-checksums](https://github.com/sogaiu/janet-checksums "Some
  digest functions in Janet")
* [janet-jsonish](https://github.com/sogaiu/janet-jsonish "JSON <-> JDN
  Converter in Pure Janet")
* [janet-punyishcode](https://github.com/sogaiu/janet-totp "Punycode
  decoding / encoding in Janet")
* [janet-tempdir](https://github.com/sogaiu/janet-tempdir "Some temp
  dir creation bits for Janet")
* [janet-totp](https://github.com/sogaiu/janet-totp "TOTP in Janet")
* [janet-zipper](https://github.com/sogaiu/janet-zipper "Zippers in
  Janet")
* [simple-peg-tracer](https://github.com/sogaiu/simple-peg-tracer
  "Simple Janet PEG tracer")

[*] If you chose a subdirectory name other than `juat`, the path will
likely need to be edited to match.

### Copying In-Place

0. Clone this repository somewhere.

1. Copy just the subdirectory named `janet-usages-as-tests` of the
   cloned repository as a subdirectory of a target project.

2. Copy or move the included `make-and-run-juat-tests.janet` file into
   the `test` directory of the target project.

3. Edit `make-and-run-juat-tests.janet` to specify files and/or
   directories that are the target of usages to be treated as tests.

Some repositories that use this method include:

* [ajrepl](https://github.com/sogaiu/ajrepl "Emacs Support for Janet
  REPL Interaction")
* [index-janet-source](https://github.com/sogaiu/index-janet-source
  "Index Janet Source Code")
* [jandent](https://github.com/sogaiu/jandent "Janet Indenter")
* [janet-peg](https://github.com/sogaiu/janet-peg "Parse and Generate
  Janet Source Code")
* [janet-pegdoc](https://github.com/sogaiu/janet-pegdoc "Janet PEG
  special doc tool")
* [janet-ref](https://github.com/sogaiu/janet-ref "Janet Reference
   Tool")
* [janet-walk-dir](https://github.com/sogaiu/janet-walk-dir "Walking
  Directory Trees")
* [janet-xmlish](https://github.com/sogaiu/janet-xmlish "Hack to Work
  with Some Amount of XML")
* [jpm-tasks-view](https://github.com/sogaiu/jpm-tasks-view
  "View jpm tasks by tag")
* [margaret](https://github.com/sogaiu/margaret "A Janet
  implementation of Janet’s peg/match")

### Git Submodule

1. In place of step 1 above, add this repository as a submodule of a
   target project.

2. Copy or move the included `make-and-run-juat-tests-submodule.janet`
   file into the `test` directory of the target project.

3. Edit `make-and-run-juat-tests-submodule.janet` to specify files
   and/or directories that are the target of usages to be treated as
   tests.

Note that
[jaylib-wasm-demo](https://github.com/sogaiu/jaylib-wasm-demo) is a
repository that uses this approach.

## Writing Tests

Within `comment` blocks, put expressions / forms to be tested along
with expected values (or expressions):

```janet
(comment

  (- 1 1)
  # =>
  0

  )
```

Here `(- 1 1)` is the expression to be tested and `0` is the
corresponding expected value.  The instance of `# =>` indicates
the presence of a test / usage.

See [Usage / Test Writing Tips](./doc/tips.md) for more details.

## Acknowledgments

* andrewchambers - suggestion and explanation
* bakpakin - janet, jpm, helper.janet, path.janet, peg for janet, etc.
* pepe - discussion, One-Shot Power Util Solver ™ motivation, and naming
* pyrmont - discussion and exploration
* rduplain - bringing to light customization of `jpm test`
* Saikyun - discussion and testing
* srnb@gitlab - suggestion

