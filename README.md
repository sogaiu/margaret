# Margaret - Janet's peg/match in Janet

This aims to be a pure-Janet implementation of Janet's `peg/match`.

## Background

While reading bakpakin's [How Janet's PEG module
works](https://bakpakin.com/writing/how-janets-peg-works.html),
started typing the code in and evaluating it, next thing I knew...

## Status

All peg specials have implementations and tests.

## Why?

* Aid in understanding Janet's PEG system
* Generate example PEG specials usages
* Experiment with adding diagnostic info / tracing
* Experiment with additional constructs

## Setup

* Clone this repository and cd to the relevant directory

* Ensure `janet` and `jpm` are on your `PATH`

* Install if you like: `jpm install`

## Usage

`meg/match` is an attempt at implementing `peg/match`, so for example,
if `margaret` has already been installed:

```janet
(import margaret/meg)

(meg/match ~(capture (some "smile")) "smile!")
```

should work.

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

## Testing

Run all tests by:

* `jpm test` from the project directory of margaret

There are currently tests for:

* [margaret's `meg` module](margaret/meg.janet)

* [`peg` module tutorial](tutorials/tutorial.janet)

* [modified code from bakpakin's article](tutorials/article.janet)

Some of the tests were adapted / copied from Janet's tests.

## Specials Implementation Status

Each of the Janet PEG specials has an initial implementation with
tests.  Specifically, that includes:

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

## Implementation Notes

In many cases an attempt to follow the original
[`peg.c`](https://github.com/janet-lang/janet/blob/master/src/core/peg.c)
implementation by bakpakin was made.  Some motivations for doing so
include:

* If `peg.c` changes, tracking those changes may be easier.

* If an experimentally added special in margaret proves useful, it
  might be easier to port it to `peg.c`.

* Arriving at a correct implementation might be easier because
  comparing it with a similar one is more meaningful.

* Debugging information obtained here might be more relevant when
  trying to understand a situation in the original `peg.c` context.

* Reading margaret's implementation might be an easier place to start
  if one wants to study `peg.c`.

Some differences include:

* `peg.c` creates a bytecode representation before execution and some
  information (e.g. tag names) is not retained.  In at least one case,
  some uses of `range` get compiled to the same type of bytecode
  instruction used by `set`.

* `peg.c` has protections for too much recursion.

## Acknowledgments

Thanks to (at least) the following folks:

* ahungry
* andrewchambers
* bakpakin
* CosmicToast
* crocket
* goto-engineering
* GrayJack
* ianthehenry
* ikarius
* jcmkk3
* LeafGarland
* leahneukirchen
* LeviSchuck
* MikeBeller
* nate
* pepe
* pyrmont
* Saikyun
* skuza
* subsetpark
* swlkr
* tami5
* uvtc
* yumaikas

...and other Janet community members :)
