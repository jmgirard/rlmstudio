# M028: Brace tests for the six cli sites that show server or CLI text

**Status:** done (2026-09-27, PR #28 https://github.com/jmgirard/rlmstudio/pull/28)

**Goal:** Six cli call sites show server or CLI text and have no brace test. If
braces in that text run as R code, a new test for that site fails.

**Outcome:** Six tests plant `{cat("EVALUATED")}` in server or CLI text and
assert that the braces show as written and that nothing is printed. The sites:
chat reply print, download status heading, `lms_download()` alert,
`lms_daemon_stop()` abort, `check_lms_version()` message, installer abort. A new `helper-brace-probe.R` holds the probe and
`capture_shown()`. No code under `R/` changed. With the text in the format
string of its site, each test went red.

**Decisions:** none.

**Review:** One pass, three-lens fan-out, internal tier. Both criteria passed,
and `devtools::check()` was clean. Three findings were fixed at the gate. O1
stubs `utils::askYesNo()`, so the install test cannot stop at a prompt. O3
pins `rlmstudio.quiet`, and O9 uses the bare mock name. O2 and O5 joined the `/hotfix` row about the
dropped installer output. O4, O7, O8, S1, and S2 were rejected. S1 claimed that
the download status had no brace test, but `test-load-download-shape.R` has one.
