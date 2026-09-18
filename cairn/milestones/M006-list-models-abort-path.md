# M006: list_models() joins the shared REST abort path

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** user-facing. It changes the condition class, the message, and the fields a failed `list_models()` raises.
- **Branch/PR:** `m006-list-models-abort-path`

## Goal

`list_models()` reports a failed REST response through `rlm_abort_api()`, the
path the other seven REST wrappers already use.

## Scope

**In:** `R/list.R:53` turns the httr2 error policy off on the models request.
It aborts through `rlm_abort_api(resp, "API List Failed")` on any status other
than 200. `list_models` joins `api_error_callers` in
`tests/testthat/test-api-error.R`, so the failure table drives eight wrappers.
The table driver stops matching the abort text as a bare substring. The
coverage guard at the end of that file is deleted. `NEWS.md` gets an entry.

**Out:** A length bound on an abort message read out of a non-JSON body goes to
the standing candidate row. So does the normalizing of a scalar JSON body. An
assertion that `host` reaches the wire goes to the standing candidate row that
names the unload functions. The other seven wrappers shipped in M005.

## Acceptance criteria

- [x] AC1: Take every row of `api_error_table` at every status in
      `api_error_statuses` (`tests/testthat/test-api-error.R`, the shared
      domain of record for all REST wrappers). At each one, `list_models()`
      raises a condition that inherits `rlmstudio_api_error`. Its `status`
      field equals that status as an integer. Its message ends with
      `API List Failed: ` and then the row `text`. Where that `text` is the
      sentinel `<status>`, the message ends with `HTTP Status <n>` for the
      status under test.
- [x] AC2: `list_models()` keeps its success contract. Against the recorded
      `list_models` fixture it returns a data frame that carries the columns
      `state`, `type`, `display_name`, and `key`. With `is_server_running()`
      returning `FALSE` it aborts with the condition class
      `rlmstudio_no_server`. The request it sends targets the path
      `api/v1/models`.
- [x] AC3: `NEWS.md` names the changed failure behavior of `list_models()`
      under the development-version heading.
- [x] AC4: `devtools::document()` produces no diff. `devtools::test()` is
      clean. `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3, T4
- AC2 → T1, T5
- AC3 → T6
- AC4 → T1, T2, T3, T5, T6

## Tasks

- [x] T1: In `R/list.R:53`, add `httr2::req_error(is_error = \(resp) FALSE)`
      to the models request. Keep the parse under a status 200 check. Call
      `rlm_abort_api(resp, "API List Failed")` on every other status.
- [x] T2: In `tests/testthat/test-api-error.R:133`, add a `list_models` entry
      to `api_error_callers`. Key the loop expectation off
      `names(api_error_callers)`, so the count is read from the list rather
      than written as `7L`.
- [x] T3: In the same driver, replace the `grepl(..., fixed = TRUE)` substring
      check at `tests/testthat/test-api-error.R:224`. Assert instead that the
      message ends with the expected fragment, so trailing text no longer
      passes.
- [x] T4: Make sure that the new abort discriminates. In a scratch copy,
      delete the `rlm_abort_api()` call site in `R/list.R`. Run the
      failure-table tests. Record in the work log that they go red. Restore
      the file.
- [x] T5: Delete the coverage guard at `tests/testthat/test-api-error.R:253`.
      Extend `tests/testthat/test-list.R` with the path assertion AC2 names.
      Keep the fixture-backed success test and the server-down test.
- [x] T6: Add the `NEWS.md` entry for the changed failure behavior of
      `list_models()`.

## Work log

- 2026-09-18: created by /milestone-plan.
- 2026-09-18: plan-gate criteria audit ran in full mode and returned five findings, all fixed here. AC1 now spells out the `<status>` sentinel. The eighth-wrapper test-file update moved from a criterion to T2. The house style clause came off AC3. The host-on-the-wire clause came off AC2. The failure table is now named as the shared domain of record.
- 2026-09-18: plan gate chose deleting the coverage guard over hardening it. The guard reads package sources that R CMD check does not ship, so it never gated a merge. Falsified by a wrapper that reaches `R/` with no failure-table row and no test going red.
- 2026-09-18: plan gate chose an ends-with match over the substring match, because the substring form passes on text appended after the message. Falsified by cli formatting that puts content after the label and the text.
- 2026-09-18: question gate chose a candidate row for a replacement coverage guard over no record. It also chose a separate NEWS bullet over folding `list_models()` into the shipped seven-wrapper bullet.
- 2026-09-18: T2 and T3 landed before T1, so the failure-table run that follows is the red-before-fix evidence. Minor reorder, no scope change.
- 2026-09-18: T2 done. `list_models` joins `api_error_callers` and the loop expectation reads its length from the list. With `R/list.R` untouched, every row at both statuses reported a wrong class for `list_models` alone. The classes were `httr2_http_400` and `httr2_http_503`. The other seven callers reported `ok`.
- 2026-09-18: T2 absorbed the coverage-guard deletion from T5, because the guard asserts seven callers and contradicts the eighth entry in the same file. Minor reorder, no scope change.
- 2026-09-18: T3 done. The driver matches the tail of the condition message with `endsWith()` in place of the fixed substring `grepl()`.
- 2026-09-18: T1 done. `R/list.R` turns the httr2 error policy off and aborts through `rlm_abort_api(resp, "API List Failed")` on any status other than 200. The failure-table file then went green, and `devtools::test()` was clean.
- 2026-09-18: T4 done. In a scratch copy of the tree, deleting the `rlm_abort_api()` call site in `R/list.R` turned the failure-table tests red. `list_models` reported `<no error raised>` at every row and both statuses. The other seven callers reported `ok`. The scratch copy was then discarded and the working tree was unchanged.
- 2026-09-18: T5 done. `tests/testthat/test-list.R` now asserts that the request `list_models()` sends targets the path `/api/v1/models`. The fixture-backed success test and the server-down test are unchanged. The coverage guard came out under T2. In a scratch copy, changing the path in `R/list.R` to `api/v1/modelz` turned the new assertion red with `actual: "/api/v1/modelz"`, so it discriminates. The assertion does not skip, because httpuv is installed.
- 2026-09-18: T6 done. `NEWS.md` gets its own bullet under the development-version heading for the changed failure behavior of `list_models()`. The before and after text in that bullet is read off the two runs recorded above.
- 2026-09-18: a candidate row for a replacement coverage guard was added to the ROADMAP, per the question gate. Search-first found the `stop_if_no_server()` guard row, which is a different call-site family, so the new row cross-references it rather than merging into it.
- 2026-09-18: claim audit: 10 claims read, 0 corrected. Files were `NEWS.md`, `tests/testthat/test-api-error.R`, and `tests/testthat/test-list.R`. The reader raised two notes that are not claim defects. The NEWS bullet omits the cli `✖ ` prefix the real message carries, which matches the three shipped bullets above it. The new path assertion needs httpuv, a suggested package, so on a machine without it that one assertion skips while the request-count assertion still runs.
- 2026-09-18: `devtools::document()` produced no diff. `devtools::test()` was clean. `devtools::check()` reported 0 errors, 0 warnings, and 0 notes.
- 2026-09-18: review step 3 done. All four criteria carry fresh evidence in the Review section and all four boxes are ticked. Review step 4 done. `cairn_validate.py` passed every check and fired no advisory. The toolchain gate passed, and no pkgdown site is present. Checkpoint: the three review lenses are still running, so no findings are recorded yet.

## Decisions

## Review

2026-09-18. Reviewed at `7f1dee6` on `m006-list-models-abort-path`, even with
`origin/main` at `8553c85`.

### Acceptance-criterion evidence

- AC1: pass. The table holds 22 rows and runs at statuses 400 and 503, so
  `list_models()` was driven through 44 cases. A direct run over those cases
  reported `ok` at all 44. The condition inherits `rlmstudio_api_error`. Its
  `status` field equals the status under test as an integer. The message ends
  with `API List Failed: ` plus the row `text`. Where the row `text` is the
  `<status>` sentinel, the message ends with `HTTP Status <n>`. The driver in
  `tests/testthat/test-api-error.R` covers all eight callers and passed in the
  same state.
- AC2: pass. `tests/testthat/test-list.R` ran clean, five expectations, no
  skips. The fixture-backed test returns a data frame that carries `state`,
  `type`, `display_name`, and `key`. With `is_server_running()` returning
  `FALSE` the call aborts with the class `rlmstudio_no_server`. The recorded
  request targets the path `/api/v1/models`, and exactly one request goes out.
- AC3: pass. `NEWS.md` carries a bullet under the `# rlmstudio (development
  version)` heading. It names the new message, the condition class, the
  `status` field, and the `HTTP Status <n>` fallback. It states the old raw
  httr2 error as the before state.
- AC4: pass. `devtools::document()` left the working tree clean, so it produced
  no diff. `devtools::test()` was clean across all fourteen test files.
  `devtools::check()` reported `Status: OK` with 0 errors, 0 warnings, and 0
  notes on version 0.2.2.9000.
