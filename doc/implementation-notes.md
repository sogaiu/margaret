# Implementation Notes

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
