# Margaret - Janet's peg/match in Janet

This aims to be a pure-Janet implementation of Janet's `peg/match`.

Apart from having fun, here are some reasons [why](doc/why.md) this
could be of some interest.

## Setup

* Clone this repository and cd to the relevant directory

* Ensure `janet` and `jpm` are on your `PATH`

* Install if you like: `jpm install`

## Usage

### Basic Use

`meg/match` is an attempt at implementing `peg/match`, so for example,
if `margaret` has already been installed:

```janet
(import margaret/meg)

(meg/match ~(capture (some "smile")) "smile!")
```

should work.

### Tracing

There is some primitive support for tracing.  It can be enabled by
setting the `VERBOSE` environment variable to a non-empty string.

Either:

* set the `VERBOSE` env var (say to "1") before starting `janet`, or
* use `(os/setenv "VERBOSE" "1")` in code

before calling `meg/match`.

Output format is very much in-flux but ATM one can see:

* capture stack
* tags
* specials execution order

...and other details.

See [here](doc/tracing.md) for more.

## Users

* [janet-pegdoc](https://github.com/sogaiu/janet-pegdoc) reuses examples
  from margaret to show sample invocations of `peg/match` as well as
  a source for generating quizzes.

* [small-peg-tracer](https://github.com/sogaiu/small-peg-tracer) uses
  the emulation and tracing capabilities of margaret while generating
  views of simulated `peg/match` execution.

## Other Docs

* [The Specials](doc/the-specials.md) lists what's currently implemented
* [Tutorials](doc/tutorials.md) of a sort
* [Testing](doc/testing.md) details
* [Implementation Notes](doc/implementation-notes.md) for the curious
* [Credits](doc/credits.md) to acknowledge help