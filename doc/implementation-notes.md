# Implementation Notes

## Brief History

Following along with bakpakin's [How Janet's PEG module
works](https://bakpakin.com/writing/how-janets-peg-works.html) led to
the idea that may be something more full-fledged might be done.

Having worked through [mal](https://github.com/kanaka/mal) a couple of
times (part of which involves implementing tree-walking interpreters),
it was natural to reuse some of that experience.

The initial complete implementation held up ok until the arrival of
the `sub` and `split` PEG specials (^^;

Although with some struggle, `sub` was grafted on, the result was very
unsatisfactory and the idea of trying to accomodate `split` as well
was quite unappealing.

Things stalled for a while until one day, a decision was made to try
somewhat from scratch and aim to implement `sub` and `split` as early
as possible (relative to most of the other PEG specials).

As luck would have it, this approach seems to have worked :)

The latest attempt tries to follow some of the structure of the C
implementation more closely than the first attempt.  Hopefully, this
will reduce the chance of a future rewrite (at least one motivated by
trying to cope with difficulty in emulating future additions to
Janet's `peg.c`).

## Misc Notes

In many cases an attempt was made to follow the original
[`peg.c`](https://github.com/janet-lang/janet/blob/master/src/core/peg.c)
implementation by bakpakin.  Some motivations for doing so include:

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
