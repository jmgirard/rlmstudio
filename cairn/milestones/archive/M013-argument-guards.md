# M013: A bad model or text argument aborts with a message that names the mistake

**Status:** done (2026-09-20, PR #14 https://github.com/jmgirard/rlmstudio/pull/14,
every check green, no NOTE, squash 9d1bcf6)

**Goal:** Name the faulty argument rather than send a bad value to the server.

**Outcome:** `R/utils-args.R` holds `rlm_check_id()`, `rlm_check_text()`,
`rlm_check_no_na()`, `id_fault()`, and `article_for()`. The identifier rule sits
above `stop_if_no_server()` in the nine `model` functions and in
`lms_download_status(job_id)`, replacing two `||` guards whose messages changed.
It rejects a non-character value, a `dim` attribute, a length other than one,
`NA`, an empty string, and whitespace alone. The strict text rule went into
`lms_embed(input)` and `lms_chat_batch(inputs)`, the NA-only rule into the three
chat wrappers. Ten pages state the rule. `R/conditions.R` says it runs first.

**Decisions:** D-008 records the unclassed abort and its order against the
server probe.

**Review:** Three-lens fan-out, user-facing tier, 25 findings. Eleven were
fixed at the gate, one became a candidate row, seven were rejected, and six
were verified non-findings. The first pass left AC1 unmet, because `trimws()`
passes a form feed. The criterion was kept and the code widened. The five
`R CMD check` jobs and the four other checks all passed on the pull request.

