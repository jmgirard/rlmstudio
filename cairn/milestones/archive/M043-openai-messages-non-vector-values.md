# M043: The OpenAI chat function refuses a messages value that holds a value that is not an atomic vector, a list, or NULL

**Status:** done (2026-09-28, PR #43 https://github.com/jmgirard/rlmstudio/pull/43)

**Goal:** `lms_chat_openai()` refuses, before the server probe, a
`messages` value that holds a value that is not an atomic vector, a list,
or `NULL`.

**Outcome:** `non_vector_type()` in `R/utils-args.R` walks both forms of
`messages` at any depth, as `has_function()` does. It returns the
`typeof()` of the first value that is not atomic, a list, `NULL`, or a
function. `rlm_check_messages()` runs it after the function rule and
before the trial write, under the value-fault header. The detail names the
type. The `messages` help, NEWS, comments, and tests say so. A classed
vector or list still passes and is written by its class.

**Decisions:** none. The plan gate chose a type test over a class list,
following RR01 fact 2 (`cairn/reviews/archive/`).

**Review:** Three-lens fan-out, all five criteria passed on the first
pass. The gate fixed three findings. Two narrowed the help and NEWS
wording on classed vectors and S4 objects. One states the grid test's
expected types by hand. Eight findings were rejected. The
`POSIXlt` crash in httr2 stays a `/hotfix` candidate row. One LESSONS
line was extended.
