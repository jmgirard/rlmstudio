# M053: The server start call says why a start was refused

**Status:** done (2026-09-29, PR #53 https://github.com/jmgirard/rlmstudio/pull/53).

**Goal:** If its own checks or the LM Studio CLI refuse a start,
`lms_server_start()` says what is wrong.

**Outcome:** `rlm_check_port()` with `port_fault()` in `R/utils-args.R`, and
`rlm_check_flag(cors, "cors")`, run before the CLI with any `wait`. `port`
must be `NULL` or one whole number from 1 to 65535, and it is an integer
after the check. A failed start quotes the CLI stderr, or stdout, through
`cli_output_text()` in `R/serve.R`. That helper writes a byte that is not
valid UTF-8 as `<ff>` and collapses whitespace, the non-breaking space
included. Help page, the `warn_unless_ready()` comment, and NEWS are updated.

**Decisions:** none cross-cutting. The plan gate chose an R-side port check
plus the CLI output, numbers only for `port`, and a `cors` check here.

**Review:** One pass of three lenses, 6 of 6 criteria verified. Five gate
fixes landed with tests. Invalid UTF-8 CLI text lost the exit code. The
port printed in scientific notation under a negative `scipen`. A
non-breaking space hid stdout. Detail lines were not pinned, and the rule
omitted `NULL`. The label and color-code findings joined the CLI-output
candidate row. Six findings were rejected with reasons.
