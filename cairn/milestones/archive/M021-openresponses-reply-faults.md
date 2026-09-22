# M021: An unreadable OpenResponses reply names its fault

**Status:** done (2026-09-22, PR #21 https://github.com/jmgirard/rlmstudio/pull/21,
every check green on the first run, squash ed8cfd9)

**Goal:** A reply that `lms_chat_openresponses()` cannot read aborts with
`rlmstudio_bad_response` and a message that names its fault.

**Outcome:** `check_part_logprobs()` checks the `logprobs` value of each
`output_text` part against six type rules. It walks parts, steps, and
candidates one at a time and names the first rule broken. The text of every
part is checked before any logprobs. `logprobs_frame()` reads fields with `[[`,
so a `tokenX` field no longer stands in for `token`. Each unreadable native and
OpenResponses shape is tested for its own detail sentence. The cut-off message
moved to two candidate rows after a live probe found no cut-off marker.

**Decisions:** none.

**Review:** Two passes, three-lens fan-out, user-facing tier. Pass 1 failed
AC1 on O1: a bad candidate token before a candidate that is not an object named
R5. T7 fixed it, and T8 added the O2, O3, and O5 tests. O6 and O9 became
candidate rows, and O4, O7, O8, and O11 were rejected. Pass 2 passed all six
criteria. P1 and P2 were docs fixes at the gate, P5 became a candidate row, and
P3 and P4 were rejected. No lesson added or retired.
