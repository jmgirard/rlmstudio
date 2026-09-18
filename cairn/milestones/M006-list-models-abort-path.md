# M006: list_models() joins the shared REST abort path

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** user-facing. It changes the condition class, the message, and the fields a failed `list_models()` raises.
- **Branch/PR:** —

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

- [ ] AC1: Take every row of `api_error_table` at every status in
      `api_error_statuses` (`tests/testthat/test-api-error.R`, the shared
      domain of record for all REST wrappers). At each one, `list_models()`
      raises a condition that inherits `rlmstudio_api_error`. Its `status`
      field equals that status as an integer. Its message ends with
      `API List Failed: ` and then the row `text`. Where that `text` is the
      sentinel `<status>`, the message ends with `HTTP Status <n>` for the
      status under test.
- [ ] AC2: `list_models()` keeps its success contract. Against the recorded
      `list_models` fixture it returns a data frame that carries the columns
      `state`, `type`, `display_name`, and `key`. With `is_server_running()`
      returning `FALSE` it aborts with the condition class
      `rlmstudio_no_server`. The request it sends targets the path
      `api/v1/models`.
- [ ] AC3: `NEWS.md` names the changed failure behavior of `list_models()`
      under the development-version heading.
- [ ] AC4: `devtools::document()` produces no diff. `devtools::test()` is
      clean. `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3, T4
- AC2 → T1, T5
- AC3 → T6
- AC4 → T1, T2, T3, T5, T6

## Tasks

- [ ] T1: In `R/list.R:53`, add `httr2::req_error(is_error = \(resp) FALSE)`
      to the models request. Keep the parse under a status 200 check. Call
      `rlm_abort_api(resp, "API List Failed")` on every other status.
- [ ] T2: In `tests/testthat/test-api-error.R:133`, add a `list_models` entry
      to `api_error_callers`. Key the loop expectation off
      `names(api_error_callers)`, so the count is read from the list rather
      than written as `7L`.
- [ ] T3: In the same driver, replace the `grepl(..., fixed = TRUE)` substring
      check at `tests/testthat/test-api-error.R:224`. Assert instead that the
      message ends with the expected fragment, so trailing text no longer
      passes.
- [ ] T4: Make sure that the new abort discriminates. In a scratch copy,
      delete the `rlm_abort_api()` call site in `R/list.R`. Run the
      failure-table tests. Record in the work log that they go red. Restore
      the file.
- [ ] T5: Delete the coverage guard at `tests/testthat/test-api-error.R:253`.
      Extend `tests/testthat/test-list.R` with the path assertion AC2 names.
      Keep the fixture-backed success test and the server-down test.
- [ ] T6: Add the `NEWS.md` entry for the changed failure behavior of
      `list_models()`.

## Work log

- 2026-09-18: created by /milestone-plan.
- 2026-09-18: plan-gate criteria audit ran in full mode and returned five findings, all fixed here. AC1 now spells out the `<status>` sentinel. The eighth-wrapper test-file update moved from a criterion to T2. The house style clause came off AC3. The host-on-the-wire clause came off AC2. The failure table is now named as the shared domain of record.
- 2026-09-18: plan gate chose deleting the coverage guard over hardening it. The guard reads package sources that R CMD check does not ship, so it never gated a merge. Falsified by a wrapper that reaches `R/` with no failure-table row and no test going red.
- 2026-09-18: plan gate chose an ends-with match over the substring match, because the substring form passes on text appended after the message. Falsified by cli formatting that puts content after the label and the text.

## Decisions

## Review
