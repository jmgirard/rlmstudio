<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M027: A load or download reply with the wrong JSON shape aborts with rlmstudio_bad_response

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** M026   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP2   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing, because three exported functions change what they accept, raise, and return   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m027-load-download-shape   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`lms_load()`, `lms_download()`, and `lms_download_status()` abort with
`rlmstudio_bad_response` on a status-200 body that breaks a field rule below.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** A field check on the status-200 body of each of the three functions,
before the function reads it. Exact-name reads in `print.lms_download_status()`.
Help page and NEWS. M027 uses the words "JSON string", "number", and "present"
as M026 defines them. It follows M026 because both rewrite the same
paragraphs of `R/conditions.R` and NEWS.md.

Background. On 2026-09-22 a mocked reply gave these results. `lms_load()`
raised `rlmstudio_api_error` "API Load Failed: {}" for `{}`, and an unclassed
error for `"x"`. It returned the model for `{"statusX": "loaded"}`, and `NULL`
with `echo_load_config = TRUE` and no `load_config`. `lms_download()` returned
`TRUE` for `{}`, `[]`, and `null`. It returned `1L` for `{"job_id": 1}` and a
list for `{"job_id": ["a", "b"]}`. `lms_download_status()` returned an empty
object for `{}`, and printing it failed with "EXPR must be a length 1 vector".
A body with `bytes_per_secondX: "a"` printed with "non-numeric argument to
binary operator", because `$` matched the extended name.

**Out:**
- The model list. That work is M026.
- A `"failed"` status in the reply of `lms_download()`. The rules check
  types, not status values. That work is a new candidate row.
- Fields that no rule names, such as `started_at`. They come back as they
  arrive.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: `lms_load()` reads a status-200 load body under one rule. The body
      is a JSON object whose `status` is the JSON string `"loaded"`. With
      `echo_load_config = TRUE`, its `load_config` is also a JSON object, and
      the call returns it as a list. Any other status-200 body aborts with
      `rlmstudio_bad_response`.
- [x] AC2: `lms_download()` reads a status-200 body under one rule. The body is
      a JSON object whose `status` is a JSON string. If `status` is
      `"already_downloaded"`, the call returns `"already_downloaded"`
      invisibly, as before. Otherwise `job_id` is a JSON string, and the call
      returns it. Any other status-200 body aborts with
      `rlmstudio_bad_response`. The call no longer returns `TRUE`.
- [x] AC3: `lms_download_status()` reads a status-200 body under two rules.
      The body is a JSON object whose `job_id` and `status` are JSON strings.
      Its `total_size_bytes`, `downloaded_bytes`, and `bytes_per_second` are
      each a number, or absent, or `null`. Any other status-200 body aborts
      with `rlmstudio_bad_response`. `print()` reads each field by its exact
      name. For each of the three fields, a test prints an object from a body
      that holds the field under an extended name with the value `"a"`, and
      not the field itself. Each print returns without error.
- [x] AC4: Each abort of AC1 to AC3 has `status` `200L`. The first line of the
      message holds the label of the function: `API Load Failed`,
      `API Download Failed`, or `API Status Request Failed`. The message names
      the field that broke the rule, or it says that the body is not a JSON
      object. It does not contain `simplify`.
- [x] AC5: A test pins each rule of AC1 to AC3 with one body per fault, and
      each body breaks one rule. Take each field that a rule requires. Its
      faults are the field absent, `null`, and under a name that extends it.
      The field as each other type from number, string, boolean, array, and
      object is a fault too. An array fault is `[]` and `["a"]`, and an object
      fault is `{}` and `{"a": 1}`. Take each field that a rule lets be absent or
      `null`. Absent, `null`, and an extended name each pass, and each other
      type fails. `status` as a JSON string other than `"loaded"` is a fault
      for `lms_load()`. The `load_config` faults run with
      `echo_load_config = TRUE`, and `load_config: []` passes with `FALSE`.
      The `job_id` faults of `lms_download()` run with `status`
      `"downloading"`. `{"status": "already_downloaded", "job_id": 1}` passes
      and returns `"already_downloaded"`. For each function, the body as a
      JSON array, string, number, boolean, and `null` is a fault.
- [x] AC6: The LM Studio docs pages for load, download, and download status
      each show an example response (lmstudio-ai/docs,
      `1_developer/2_rest/{load,download,download-status}.md`, "Response"
      blocks). A test passes each through its function and asserts the
      return value. The existing tests pass. No existing test is removed,
      and an existing test changes its reply body, its call, or an
      expectation only where the old body breaks a rule of AC1 to AC3.
- [x] AC7: The `rlmstudio-conditions` help page names the three functions as
      raisers of `rlmstudio_bad_response` for a body with the wrong shape. It
      no longer says that they can fail with an unclassed error, fail with
      `rlmstudio_api_error` for `{}`, or report success for `{}`. The
      `@return` of `lms_download()` says that the call aborts when the body
      holds neither a `job_id` nor the status `"already_downloaded"`. NEWS.md
      has an entry for AC1, AC2, and AC3. `devtools::test()` is clean, and
      `devtools::document()` produces no diff.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T1, T2, T3
- AC5 → T1, T2, T3
- AC6 → T1, T2, T3
- AC7 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: `lms_load()`. Tests first. After `parse_ok_body()`
      (`R/load.R:133-141`), check the rule of AC1 and abort through
      `rlm_abort_bad_response()` with the hint that T1 of M026 wrote. The
      status-200 path no longer reaches `rlm_abort_api()`. Read fields with
      `[[` (LESSONS, M018). Call with `force = TRUE`, so that the load reply is
      the body under test. Write the AC1, AC4, AC5, and AC6 load tests.
- [x] T2: `lms_download()`. Tests first. Check the rule of AC2 after
      `parse_ok_body()` (`R/download.R:71-90`), and drop the `invisible(TRUE)`
      branch. Write the AC2, AC4, AC5, and AC6 download tests. Fix the
      reply `{"job_id": "job-1"}` at `test-body-parse.R:69`, which has no
      `status`, and record each edited test in the work log.
- [x] T3: `lms_download_status()` and its print method. Tests first. Check the
      rules of AC3 after `parse_ok_body()` (`R/download.R:147-151`). Read
      fields with `[[` in `print.lms_download_status()`
      (`R/download.R:177-206`). Write the AC3, AC4, AC5, and AC6 status tests.
- [x] T4: Docs. Rewrite the "Server not running" and "Malformed response"
      sections of `R/conditions.R` and the `@return` of `lms_download()`. Add
      the NEWS entries. Run `devtools::document()` and `devtools::test()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-22: created by /milestone-plan.
- 2026-09-22: criteria audit, full mode, fresh [O] reader, on one draft for M026 and M027. See the M026 work log for the nine fixes. The fixes here are exact-name reads in `print()`, pass cases for optional fields, and the message labels. A boolean top-level body and a correct "Before" line in AC1 are fixes too.
- 2026-09-22: criteria re-audit, full mode, second fresh [O] reader. See the M026 work log. The fixes here are a false claim about existing tests, probes of `load_config` and `job_id` under both branches, array and object fault forms, and print tests for all three numeric fields. The `@return` clause checked nothing, and the "Before" line in AC1 moved to the background.
- 2026-09-22: plan gate chose `rlmstudio_bad_response` for a load body whose `status` is not `"loaded"` over `rlmstudio_api_error`. The docs list `"loaded"` as the only value, and D-007 rejected an API error with status 200. Falsified by a live LM Studio that answers a failed load with status 200 and an `error` object.
- 2026-09-22: plan chose to check field types and not status values over a check against the documented status lists. A new status from a later LM Studio then passes. Falsified by a status value that a caller of these functions misreads as success.
- 2026-09-22: implement started on branch m027-load-download-shape. Question gate skipped: the one open choice, the hint text, reuses M026's hint with the kind of reply named, through a new `rlm_abort_bad_reply()` that `list_models()` now also calls (same message).
- 2026-09-22: T1 done. `load_reply_fault()` is in `R/load.R`, and its tests in `test-load-download-shape.R` were red before the fix. Minor sub-task: M026's JSON-text helpers moved to `helper-json-forms.R` as `shape_object()` and `shape_array()`, because `helper-chat-bodies.R` already defines `json_object()`. Edited test: the `test-api-error.R` load-status test now expects `rlmstudio_bad_response` for `{"status": "pending"}`. The docs example fixtures come from lmstudio-ai/docs 2e643a417b, unchanged at 9b8bc2004f. `devtools::test()` gave 0 failures and 8702 passes.
- 2026-09-22: T2 done. `download_reply_fault()` is in `R/download.R`, the `invisible(TRUE)` branch is gone, and the new tests were red before the fix. Edited test: the `lms_download` reply in `test-body-parse.R` gained `"status": "downloading"`. A comment in `test-token-wrappers.R` now names the fields the download calls read. `devtools::test()` gave 0 failures and 8829 passes.
- 2026-09-22: T3 done. `download_status_fault()` is in `R/download.R`, and `print()` reads its five fields with `[[`. The fault and print tests were red before the fix. Discovered sub-task: `print()` passed the server's `status` to `cli::cli_text()` as format text, so `{...}` in it ran as R code. It is now spliced in as a value, with a test that is red on the old line. A [high] candidate row holds the sweep of the other cli calls. `devtools::test()` gave 0 failures and 9079 passes.
- 2026-09-22: T4 done. The help page lists the three rules and drops the old unclassed, API-error, and `TRUE` outcomes. The `simplify = FALSE` sentence now names the chat functions and `lms_embed()` only. The `@return` of `lms_download()` names the abort. NEWS has four entries, one of them for the `print()` fixes. `devtools::document()` then made no diff, and `devtools::test()` gave 0 failures and 9079 passes.
- 2026-09-22: claim audit: 68 claims read, 2 corrected — R/download.R, R/conditions.R. The `@return` of `lms_download()` now also names the abort on a `status` that is not a string. The help page names two value exceptions, the load `status` and a download reply with `"already_downloaded"`. The same reader re-read both and found them accurate.
- 2026-09-22: implement complete. `devtools::test()` gave 0 failures and 9079 passes, and `devtools::document()` made no diff. Status set to review.
- 2026-09-22: review return 1 (defect): consistency gate failed. `cairn_validate` weight caps: `cairn/ROADMAP.md` has 60 lines, cap under 60, after the T3 candidate row. AC1 to AC7 have evidence, and AC6 fails as written (review finding O3). Fix: shorten or merge a candidate row, and amend AC6 through the gate. Then re-review. Status set to in-progress.
- 2026-09-22: implement resumed after review return 1. Merged the two ROADMAP candidate rows on cut-off replies into one row, so the file has 59 lines, and `cairn_validate` passes.
- 2026-09-22: re-audit: AC6 (full) — my draft "An existing test changes a reply body or an expectation only where the old body breaks a rule of AC1 to AC3." holds on the branch but misses a removed test and a changed call. The reader proposed the wording the gate chose.
- 2026-09-22: re-audit: AC6 (full) — nothing. A second fresh reader found the chosen wording met: `test_that` counts match `main` in the four edited files, and no call changed.
- 2026-09-22: amendment return: AC6 — "No existing test is removed, and an existing test changes its reply body, its call, or an expectation only where the old body breaks a rule of AC1 to AC3." The user chose this wording at the mini gate. It replaces "An existing test changes only where its body breaks a rule of AC1 to AC3."
- 2026-09-22: implement complete after return 1. `cairn_validate` passes. No code changed since review, which recorded `devtools::test()` with 0 failures and 9079 passes. Status set to review.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->

Run 2026-09-22 on the branch head 929f7dd, which contains `origin/main` 23f4003. `devtools::test()` gave 28 files, 0 failures, 0 skips, and 9079 passes. The 11 tests in `test-load-download-shape.R` passed. Plant: a scratch copy ran that file against the `R/load.R` and `R/download.R` of `main`. Every fault test failed there: load 44 of 44, download 24 of 24, and status 42 of 42. So did 3 of the 6 print checks and the status-text check.

- AC1: the load fault test runs the top-level forms and each `status` fault, with the echo off and on. The `status` faults include `"pending"` and `"Loaded"`. It runs each `load_config` fault with the echo on. Each aborts with `rlmstudio_bad_response`. With the echo off, each `load_config` form returns `"a-model"` invisibly. With the echo on, `{}` and `{"a": 1}` return as lists. All passed.
- AC2: the download fault test runs the top-level forms and each `status` fault. It runs each `job_id` fault with `status` `"downloading"`. Each aborts with `rlmstudio_bad_response`. `{"job_id": "job-1", "status": "downloading"}` returns `"job-1"` visibly. `{"status": "already_downloaded"}` returns `"already_downloaded"` invisibly, with no `job_id` and with `job_id` 1. No path returns `TRUE`: `grep` finds no `invisible(TRUE)` in `R/download.R`. All passed.
- AC3: the status fault test runs the top-level forms, each `job_id` and `status` fault, and each fault of the three number fields. Each aborts with `rlmstudio_bad_response`. For each number field, the field absent, `null`, and extended pass. The print test holds each number field under an extended name with the value `"a"`, and not the field itself. Each of the three prints returned without error. The plant made the print fail for all three. All passed.
- AC4: `expect_shape_faults()` checks each fault case of AC1 to AC3. It asserts the class, `status` 200L, and the function label on the first line. It asserts the field name, or "not a JSON object", in the message. It asserts no "simplify" in the message. All passed.
- AC5: `json_forms` in `helper-json-forms.R` holds number, string, boolean, `[]`, `["a"]`, `{}`, `{"a": 1}`, and `null`. `required_field_faults()` builds the absent and extended cases and each form that the rule does not accept. `optional_field_cases()` builds the three pass cases and a fault for each other form. Each case changes one field of a passing body. `"pending"` and `"Loaded"` are the extra load `status` faults. `load_config: []` passes with the echo off. The `job_id` faults run with `"downloading"`. `{"status": "already_downloaded", "job_id": 1}` passes. `top_level_faults()` gives the body as each non-object form for each function. All passed.
- AC6: the three docs-example tests pass the "Response" blocks of lmstudio-ai/docs 2e643a417b through each function. Load returns `"a-model"` and the five-field config. Download returns `"job_493c7c9ded"`. Status returns the six fields and prints "Progress: 100%". The full suite passed. Two existing tests changed a body, and each old body breaks a rule. In `test-api-error.R`, `{"status": "pending"}` breaks AC1. In `test-body-parse.R`, `{"job_id": "job-1"}` has no `status` and breaks AC2. `test-token-wrappers.R` changed a comment only. In `test-model-list-shape.R`, `diff` after a rename of `json_object` and `json_array` shows only the removed helpers and a header comment. No body or assertion changed there. The helpers moved to `helper-json-forms.R` with the same code.
  AC6 unticked after the [O] review. Read as written, its last clause fails. The rename changed the text of the M026 tests in `test-model-list-shape.R`, and no body there breaks a rule of AC1 to AC3. The criterion needs a gated amendment that allows a behavior-preserving helper rename.
- AC7: the "Malformed response" section of `R/conditions.R` names the three functions as raisers, with a numbered rule for each. The "Server not running" paragraph now says that they raise the class for `{}`. `grep` finds no unclassed-error, API-error-for-`{}`, or success-for-`{}` sentence about them in `man/rlmstudio-conditions.Rd`. The `@return` of `lms_download()` names the abort for a reply with neither a `job_id` string nor `"already_downloaded"`. NEWS.md has one entry for each of AC1, AC2, and AC3, and one for `print()`. `devtools::test()` passed, and `devtools::document()` left `git status` clean.

Consistency gate, 2026-09-22. `cairn_validate.py` exited 1. `weight caps` failed because `cairn/ROADMAP.md` has 60 lines and the cap is under 60. It had 59 lines on `main`, and the `[high]` cli candidate row of T3 added one. Every other check passed. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. `devtools::document()` made no diff. README.Rmd and README.md did not change on the branch. The repo has no `_pkgdown.yml`. NEWS.md has the entries. The branch adds no top-level file. Result: gate failure, so the milestone returns to `in-progress` before the independent review.

Independent review, run in parallel with the gate and read after it failed. The findings stay untriaged until the next review gate.
- [S] prior-review lens: no regression of a past review finding. The PR comment probe returned no comments.
- [S] blame-history lens: no finding undoes deliberate past work. It traced each of six changes to D-017, D-001, the work log, or LESSONS. The lost `TRUE` return and the `R/list.R` helper change are two of them.
- [O] diff-bug lens, most severe first:
  - O1: duplicate JSON keys pass on their first value. `{"status":"loaded","status":"failed"}` passes `load_reply_fault()`. No AC breaks.
  - O2: `lms_download()` returns `""` for `{"status":"downloading","job_id":""}`. `lms_download_status("")` then fails with an unclassed argument error. No AC breaks.
  - O3: `test-model-list-shape.R` and `test-token-wrappers.R` changed although no body there breaks a rule. Read literally, the last clause of AC6 fails. No test behavior changed.
  - O4: the length checks in `is_json_string()` and `is_json_number()` (`R/list.R:230,234`) cannot fail, because `simplifyVector = FALSE` returns arrays as lists. No test can pin them.
  - O5: no test sends a bare `{}`, which the help page uses as its example. A hand check gave a message that names `status` or `job_id`.
  - O6: `print()` shows `Progress: NaN%` for sizes of 0, and `Speed: Inf MB/s` for `1e400`. This is older than the branch.
  - O7: the vignette `wait` chunk reads `res$status` with `$`. The branch did not touch it.
  - O8: `R/conditions.R:38` and `R/conditions.R:202-203` run past the usual roxygen wrap width.

Pass 2, 2026-09-22, on the branch head 61a4bd8, which contains `origin/main` 23f4003. `git diff 929f7dd HEAD` outside `cairn/` is empty, so the code is the code of pass 1.
- AC1 to AC5 and AC7: `devtools::test()` again gave 28 files, 0 failures, 0 skips, and 9079 passes. The 11 tests in `test-load-download-shape.R` passed. `devtools::document()` left `git status` clean. The pass 1 evidence lines above hold for this code.
- AC6 (amended): the docs-example tests and the full suite passed. `test_that` counts match `main` in the four edited files: `test-api-error.R` 2 top-level blocks (its looped blocks come from the same table), `test-body-parse.R` 11, `test-model-list-shape.R` 9, and `test-token-wrappers.R` 6. So no test was removed. A reply body or expectation changed in two tests only, and each old body breaks a rule: `{"status": "pending"}` breaks AC1, and `{"job_id": "job-1"}` breaks AC2. No call changed. In `test-model-list-shape.R`, only helper names changed. The helpers have the same code, so each reply body sent is the same JSON text. The delta reviewer compared the test titles with `main`. All match except one retitle in `test-api-error.R`, whose body and call stayed.
- Consistency gate, pass 2: `cairn_validate.py` passed every check, and `cairn/ROADMAP.md` has 59 lines. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. `devtools::document()` made no diff. README, pkgdown, NEWS, and top-level files are as in pass 1. Result: pass.
- Independent review, pass 2: the code is the code that the pass 1 fan-out read, so its findings stand. One fresh [O] reader read the tracking delta `929f7dd..HEAD`. It found no defect. Its minor points: D1, the rename changes the text that builds the model-list bodies, but not the JSON sent. D2, one test title changed. D3, a count of tests cannot show that a test was removed and another added, but a title comparison can. D4, the merged ROADMAP row says "warns or aborts then" where the old row said "even when the parse succeeds". D5, the merged row no longer sits next to its related row. D6, the pass 1 text on AC6 is out of date, and pass 2 supersedes it.
