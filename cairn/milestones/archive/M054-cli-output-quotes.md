# M054: A failed CLI or installer run quotes what it wrote

**Status:** done (2026-09-29, PR #54 https://github.com/jmgirard/rlmstudio/pull/54).

**Goal:** The abort of a failed LM Studio CLI or headless installer run
gives the exit code. It also quotes what the run wrote.

**Outcome:** `rlm_abort_cli_run()` in `R/serve.R` builds five aborts: server
start and stop, daemon start and stop, and the installer. `cli_output_clean()`
reads stderr first and stdout second. It writes an invalid byte as `<xx>`.
It runs `cli::ansi_strip()`, and `strip_escapes()` after it. It collapses
whitespace.
`cli_output_cut()` keeps the last 1000 characters. `cli_output_text()` is
removed. `lms_server_stop()` treats "not running" as done. The installer
exit check moved out of its `tryCatch()`. Help pages and NEWS are updated.

**Decisions:** none cross-cutting. The plan gate chose the one-line quote
and an info message on a second server stop. It kept the last 1000
characters, folded the installer fix in, and removed escapes.

**Review:** Two passes of three lenses. Pass 1 returned the milestone: some
escape forms passed through, and three help-page faults. Pass 2 verified 6 of
6 criteria. The gate fixed the `with_lms_daemon()` GUI teardown text, with a
test. Three escape-cleaning cases went to a candidate row. Twelve findings
were rejected with reasons.
