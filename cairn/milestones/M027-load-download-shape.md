<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M027: A load or download reply with the wrong JSON shape aborts with rlmstudio_bad_response

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
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

- [ ] AC1: `lms_load()` reads a status-200 load body under one rule. The body
      is a JSON object whose `status` is the JSON string `"loaded"`. With
      `echo_load_config = TRUE`, its `load_config` is also a JSON object, and
      the call returns it as a list. Any other status-200 body aborts with
      `rlmstudio_bad_response`.
- [ ] AC2: `lms_download()` reads a status-200 body under one rule. The body is
      a JSON object whose `status` is a JSON string. If `status` is
      `"already_downloaded"`, the call returns `"already_downloaded"`
      invisibly, as before. Otherwise `job_id` is a JSON string, and the call
      returns it. Any other status-200 body aborts with
      `rlmstudio_bad_response`. The call no longer returns `TRUE`.
- [ ] AC3: `lms_download_status()` reads a status-200 body under two rules.
      The body is a JSON object whose `job_id` and `status` are JSON strings.
      Its `total_size_bytes`, `downloaded_bytes`, and `bytes_per_second` are
      each a number, or absent, or `null`. Any other status-200 body aborts
      with `rlmstudio_bad_response`. `print()` reads each field by its exact
      name. For each of the three fields, a test prints an object from a body
      that holds the field under an extended name with the value `"a"`, and
      not the field itself. Each print returns without error.
- [ ] AC4: Each abort of AC1 to AC3 has `status` `200L`. The first line of the
      message holds the label of the function: `API Load Failed`,
      `API Download Failed`, or `API Status Request Failed`. The message names
      the field that broke the rule, or it says that the body is not a JSON
      object. It does not contain `simplify`.
- [ ] AC5: A test pins each rule of AC1 to AC3 with one body per fault, and
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
- [ ] AC6: The LM Studio docs pages for load, download, and download status
      each show an example response (lmstudio-ai/docs,
      `1_developer/2_rest/{load,download,download-status}.md`, "Response"
      blocks). A test passes each through its function and asserts the
      return value. The existing tests pass. An existing test changes only
      where its body breaks a rule of AC1 to AC3.
- [ ] AC7: The `rlmstudio-conditions` help page names the three functions as
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
- [ ] T4: Docs. Rewrite the "Server not running" and "Malformed response"
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

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
