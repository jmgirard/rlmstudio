# M029: A failed or blank download reply aborts, and a download status prints no NaN or Inf

**Status:** done (2026-09-27, PR #29 https://github.com/jmgirard/rlmstudio/pull/29)

**Goal:** `lms_download()` aborts on a failed or blank-id reply, and the print
of a download status shows only finite numbers.

**Outcome:** `download_reply_fault()` passes a `"failed"` status to a new
`rlm_abort_download_failed()`, which aborts with `rlmstudio_bad_response`. The
message names a job id that is not blank. It leaves out the hint about another
program on the host. For other statuses, a
`job_id` needs a character outside `[:space:]`. `lms_download_status()` still
returns `"failed"`. `print.lms_download_status()` needs finite sizes, a total
above 0, and a finite percentage for the progress line. It shows the speed
line only for a finite speed above 0. Both vignettes read `res[["status"]]` and
stop on `"paused"`. Help page, `@return`, and three NEWS entries.

**Decisions:** D-018 narrows D-017 for the failed status and the blank job id.

**Review:** One pass, three-lens fan-out, user-facing tier. All seven criteria
passed, and `devtools::check()` was clean. The blame-history and prior-review
lenses found nothing. Of 12 diff-bug findings, D1 and D3 (a tiny total printed
`Inf%`) and D9 (a stale NEWS entry) were fixed at the gate. D2 and D4 became
one candidate row. The other seven were rejected.
