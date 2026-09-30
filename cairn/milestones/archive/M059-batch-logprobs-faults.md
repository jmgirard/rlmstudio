# M059: Batch logprobs and repeated-argument faults

**Status:** done (2026-09-30, PR #59 https://github.com/jmgirard/rlmstudio/pull/59).

**Goal:** `lms_chat_batch()` names a repeated argument in its own abort, and
on the native route it treats `logprobs = TRUE` as off, with one warning.

**Outcome:** Two dots that reach one `lms_chat()` argument, or an `input`
dot, abort in `rlm_check_chat_dots_once()`, which reads `rlm_dots_reached()`.
The abort is unclassed and precedes the other dots checks and the probe. On
native, `rlm_dot_filling()` finds the dot that fills `logprobs` and sets it to
`FALSE` in place. The batch warns once after the probe, past `quiet`.
`do.call("chat_once", ..., quote = TRUE)` passes dots unevaluated. Help, NEWS,
and the R/conditions.R fault list were updated.

**Decisions:** D-032 (native logprobs off, one warning past `quiet`) and
D-033 (narrows the M019 column rule to two routes, D-014 unchanged).

**Review:** Pass 1 returned the milestone once on AC3 and AC5. Removing the
`logprobs` dot let a shortened `log` or an unnamed dot take its place.
The fix sets the dot in place. Pass 2 ran three lenses: all six criteria
passed, and none of 12 findings showed a failure. The gate fixed four: a
`quote = TRUE` test, a named `chat_once`, a comment, and test labels. Two
went to candidate rows. The rest were rejected. The M017 lesson grew.
