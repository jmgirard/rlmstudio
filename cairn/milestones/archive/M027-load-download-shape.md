# M027: A load or download reply with the wrong JSON shape aborts with rlmstudio_bad_response

**Status:** done (2026-09-22, PR #27 https://github.com/jmgirard/rlmstudio/pull/27)

**Goal:** `lms_load()`, `lms_download()`, and `lms_download_status()` abort with
`rlmstudio_bad_response` on a status-200 body that breaks a field rule.

**Outcome:** `load_reply_fault()`, `download_reply_fault()`, and
`download_status_fault()` check each reply by exact field name before it is read.
They abort through a new `rlm_abort_bad_reply()`, which `list_models()` now also
calls with the same message. A load `status` other than `"loaded"` aborts.
`lms_download()` no longer returns `TRUE`. `print.lms_download_status()` reads
fields with `[[` and splices the server's `status` as a value, so its braces no
longer run as R code. The M026 JSON-form test helpers moved to
`helper-json-forms.R`. Help page, `@return`, and four NEWS entries.

**Decisions:** D-017 covers the load and download rules.

**Review:** Two passes, three-lens fan-out, user-facing tier. Pass 1 failed the
gate: ROADMAP had 60 lines. AC6 also failed as written, because a helper rename
changed M026 test text. Two rows were merged, and AC6 was amended at the gate
(one amendment return). Pass 2 passed all seven criteria, and `devtools::check()`
was clean. No code bug was found. At the gate, O5 (a bare `{}` case) and D4 were
fixed. O2, O6, and O7 became one download-flow row. O1, O4, O8, and D5 were rejected.
