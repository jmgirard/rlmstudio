# M029: A failed or blank download reply aborts, and a download status prints no NaN or Inf

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — it changes the exported `lms_download()` and the print of a download status
- **Branch/PR:** m029-download-flow

## Goal

`lms_download()` aborts on a failed or blank-id reply, and the print of a download status shows only finite numbers.

## Scope

**In:** A `"failed"` status in the `lms_download()` reply aborts with `rlmstudio_bad_response`. A job id with no character that is not whitespace aborts in the same way. `print.lms_download_status()` leaves out the Progress line and the Speed line for numbers that are not finite or not above 0. Both vignettes read the status with `[[`, and their wait loops stop on `"paused"`. The help page, `@return`, the helper roxygen, NEWS, and D-018 (narrows D-017) change to match.

**Out:** `lms_download_status()` returns a `"failed"` status as before, because the plan gate kept it. The other download rows stay in the ROADMAP. A `downloaded_bytes` above `total_size_bytes` and the undocumented `"error"` status stay as they are, because nobody asked for a change.

## Acceptance criteria

- [ ] AC1: `lms_download()` aborts with `rlmstudio_bad_response` on a status-200 reply whose `status` is `"failed"`. The message says that LM Studio reports that the download failed. If the reply's `job_id` is a string with a character that is not whitespace, the message names it. The message does not say that something other than LM Studio can be answering. A test in `tests/testthat/test-load-download-shape.R` asserts the class and the message text for each `job_id` form. The forms are `"job-1"`, `"{1 + 1}"` (shown with its braces), absent, `1`, `""`, and `" \t"`.
- [ ] AC2: `lms_download()` aborts with `rlmstudio_bad_response` on a reply with two properties. Its `status` is neither `"already_downloaded"` nor `"failed"`. Its `job_id` is a string with no character outside `[:space:]`. The message holds the clause "`job_id` is a string with no character that is not whitespace". A test asserts the class and that clause for the `job_id` values `""`, `" "`, `"\t"`, `"\n"`, and `" \t\n"`. It does this under the statuses `"downloading"`, `"paused"`, and `"queued"`.
- [ ] AC3: In the same test file, a reply whose `job_id` is `"job-1"` returns `"job-1"` visibly for each of four statuses. The statuses are `"downloading"`, `"paused"`, `"completed"`, and `"queued"`, which the docs do not list. The existing `"already_downloaded"` cases still return `"already_downloaded"` invisibly. A status reply whose `status` is `"failed"` returns an `lms_download_status` object with that status, and `print()` shows "failed".
- [ ] AC4: `print()` on an `lms_download_status` object shows the Progress line only for finite sizes with a `total_size_bytes` above 0. It shows the Speed line only for a finite `bytes_per_second` above 0. A test prints eight cases. For each case, it asserts which of the two lines appear, and that the output holds neither "NaN" nor "Inf". The cases are both sizes 0, a total of `1e400`, a downloaded of `1e400` with a finite total, and a total of `-1`. They are also speeds of `1e400`, `0`, and `-1`, and finite positive values for all three fields.
- [ ] AC5: `grep -n '\$' vignettes/*.Rmd` prints only the `knitr::opts_chunk$set(` lines. The `wait` chunk of each vignette ends its loop on `"completed"`, `"failed"`, `"error"`, or `"paused"`. It aborts with "Model download failed." on each of these except `"completed"`.
- [ ] AC6: Three texts state the failed-status rule and the blank job id rule. They are the "Malformed response" section in `R/conditions.R`, the `@return` of `lms_download()`, and the roxygen of `download_reply_fault()`. The section's count of exceptions to the type-only rule matches the rules that it lists. `NEWS.md` has one entry for each of three changes: the failed-status abort, the blank job id abort, and the print fix.
- [ ] AC7: `devtools::document()` produces no diff. `devtools::test()` and `devtools::check()` finish with 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4
- AC6 → T2, T5
- AC7 → T6

## Tasks

- [x] T1: Write the tests for AC1 to AC3 first, in the download block of `tests/testthat/test-load-download-shape.R` (near line 185). In a scratch copy, plant a wrong message and a swapped check order. Make sure that the message tests go red (LESSONS M026).
- [x] T2: In `R/download.R`, `download_reply_fault()` (line 108) checks for `"failed"` after `"already_downloaded"` and before the job id. The job id rule uses `grepl("[^[:space:]]", x)`, as `list_models()` does for an instance id. `lms_download()` (line 76) aborts a failed reply through `rlm_abort_bad_response()` with its own hint. It splices the job id in as a value (LESSONS M012). The helper roxygen cites D-018.
- [x] T3: Write the print tests for AC4. Then guard the Progress line and the Speed line in `print.lms_download_status()` with `is.finite()` and the above-0 tests.
- [x] T4: Change the `wait` chunks of `vignettes/getting-started.Rmd` (line 84) and `vignettes/headless-config.Rmd` (line 81). Read `res[["status"]]`, and add `"paused"` to the stop states.
- [x] T5: Update the "Malformed response" section in `R/conditions.R` (lines 106 to 125) and the `@return` of `lms_download()`. Add three NEWS entries. Run `devtools::document()`.
- [ ] T6: Run `lms server start`, and set `RLMSTUDIO_API_TOKEN` (LESSONS M009). Then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-27: created by /milestone-plan. It merges two candidate rows: the `"failed"` download status (M026 and M027 plan gate) and the download-flow gaps (M027 review findings O2, O6, and O7).
- 2026-09-27: criteria audit, full mode, fresh reader, two passes. Pass 1 returned nine findings. They were the D-017 collision, missing probe forms in AC1 to AC4, a grep that read only `res$`, and a stale exception count. Pass 2 returned five. No criterion covered a `"failed"` status reply. Three probes were missing: `" \t"`, `"queued"`, and a speed of `-1`. The helper roxygen was stale. All were fixed before the commit.
- 2026-09-27: plan gate chose an `rlmstudio_bad_response` abort for a `"failed"` download. It rejected a warning with the job id returned, and a new condition class. A load reply that is not `"loaded"` already aborts with that class (D-017). A user who needs to tell a failed download from a malformed reply by class falsifies the choice.
- 2026-09-27: plan gate kept `lms_download_status()` returning a `"failed"` status and rejected an abort there. A status query that answers `"failed"` is a correct answer, and the vignette loops read it. A caller who polls the status and expects an error on failure falsifies the choice.
- 2026-09-27: plan left out the Progress and Speed lines in `print()` and rejected a shape rule against non-finite numbers. A display fault must not abort a status query. A live LM Studio reply with a non-finite size that a caller needs as an error falsifies the choice.
- 2026-09-27: implement started on branch `m029-download-flow`. No implement gate, because the plan left no choice open.
- 2026-09-27: T1 and T2 done. Tests for AC1 to AC3 went red before the fix. Four plants in a scratch copy each turned them red: a wrong failed message, the failed check moved behind the job id rule, an empty-only blank rule, and a blank job id named. `devtools::test()`: 369 tests, 0 failed.
- 2026-09-27: T3 done. The eight-case print test failed nine expectations before the guard and passes after it. `devtools::test()`: 370 tests, 0 failed.
- 2026-09-27: T4 done. Both `wait` chunks read `res[["status"]]` and stop on `"paused"`. `grep -n '\$' vignettes/*.Rmd` prints only the two `knitr::opts_chunk$set(` lines. The vignette builds run at T6.
- 2026-09-27: T5 done. The help section now counts four exceptions and limits the "something other than LM Studio" line to the other faults. `@return` and three NEWS entries added. `devtools::document()` rewrote the section in 12 Rd files. `devtools::test()`: 370 tests, 0 failed.

## Decisions

## Review
