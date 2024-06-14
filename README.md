# Margaret - Janet's peg/match in Janet

This aims to be a pure-Janet implementation of Janet's `peg/match`.

## Background

While reading bakpakin's [How Janet's PEG module
works](https://bakpakin.com/writing/how-janets-peg-works.html),
started typing the code in and evaluating it, next thing I knew...

## Specials Implementation Status

Each of the Janet PEG specials has an initial implementation with
tests -- that includes:

* Primitive Patterns
  * [integer patterns](examples/0.integer.janet)
  * [range](examples/range.janet)
  * [set](examples/set.janet)
  * [string patterns](examples/0.string.janet)
  * [boolean patterns](examples/0.boolean.janet)

* Combinators
  * [any](examples/any.janet)
  * [at-least](examples/at-least.janet)
  * [at-most](examples/at-most.janet)
  * [backmatch](examples/backmatch.janet)
  * [between](examples/between.janet)
  * [choice, {plus}](examples/choice.janet)
  * [if](examples/if.janet)
  * [if-not](examples/if-not.janet)
  * [look, >](examples/look.janet)
  * [opt, ?](examples/between.janet)
  * [repeat, "n"](examples/repeat.janet)
  * [sequence, *](examples/sequence.janet)
  * [some](examples/some.janet)
  * [split](examples/split.janet)
  * [sub](examples/sub.janet)
  * [thru](examples/thru.janet)
  * [to](examples/to.janet)
  * [unref](examples/unref.janet)

* Captures
  * [accumulate, %](examples/accumulate.janet)
  * [argument](examples/argument.janet)
  * [backref, \->](examples/backref.janet)
  * [capture, \<-, quote](examples/capture.janet)
  * [cmt](examples/cmt.janet)
  * [column](examples/column.janet)
  * [constant](examples/constant.janet)
  * [drop](examples/drop.janet)
  * [error](examples/error.janet)
  * [group](examples/group.janet)
  * [int](examples/int.janet)
  * [int-be](examples/int-be.janet)
  * [lenprefix](examples/lenprefix.janet)
  * [line](examples/line.janet)
  * [number](examples/number.janet)
  * [position, $](examples/position.janet)
  * [replace, /](examples/replace.janet)
  * [uint](examples/uint.janet)
  * [uint-be](examples/uint-be.janet)

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

## Other Docs

* [Why?](doc/why.md)
* [Tutorials](doc/tutorials.md)
* [Testing](doc/testing.md)
* [Implementation Notes](doc/implementation-notes.md)
* [Credits](doc/credits.md)