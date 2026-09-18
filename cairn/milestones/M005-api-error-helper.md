# M005: One abort path for the seven REST failure branches

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — the abort messages users read and a condition class callers catch
- **Branch/PR:** m005-api-error-helper

## Goal

Every REST wrapper that handles a failed response reports it through one
abort path, which never crashes and which callers can catch by class.

## Scope

**In:** the seven functions that hold a line reported by
`grep -rn "req_error(is_error" R/`. They are `lms_load()`,
`lms_unload()`, `lms_download()`, `lms_download_status()`,
`lms_chat_openresponses()`, `lms_chat_openai()`, and
`lms_chat_native()`. One shared internal helper extracts the message and
raises the abort. Two crash cases are fixed there. The abort gains the
condition class `rlmstudio_api_error` and a `status` field. One
body-shape table drives every wrapper through every failure branch.

**Out:**

- `list_models()` leaves the httr2 error policy on, so a failed request
  throws the raw httr2 error. It is a candidate row.
- The `host`-reaches-the-wire assertions and the reads of the httr2
  internal `req$body$data` stay candidate rows.
- The three tests that do not discriminate their branch stay a candidate
  row.
- Folding the inline `req_perform` closures in `test-load.R` and
  `test-chat.R` into the shared recorder stays a candidate row.

## Acceptance criteria

- [ ] AC1: For every body shape the failure-message table enumerates, all
      seven functions reported by `grep -rn "req_error(is_error" R/`
      abort with the same message text, each behind its own label. That
      grep reports seven lines.
- [ ] AC2: For these five rows of the failure-message table, all seven
      functions report the same message text, each behind its own label.
      `{"error": {"message": "boom"}}` and `{"error": "boom"}` both give
      `boom`. The non-JSON body `plain text failure` gives
      `plain text failure`. `{"error": {"code": "E42"}}` and
      `{"status": "bad"}` both give `HTTP Status <n>`.
- [ ] AC3: For these six shapes the message text is `HTTP Status <n>`.
      The shapes are an empty body, `{"error": []}`, `{"error": {}}`,
      `{"error": {"message": []}}`, `{"error": ["a", "b"]}`, and
      `{"error": {"message": ""}}`.
- [ ] AC4: For each row of the failure-message table, the helper aborts
      and raises no other R error. When the body parses to a list, the
      helper reads `error` and then `error$message`, and takes the first
      of them that is a non-empty length-one character string. It reads
      `error$message` only when `error` is a list. When neither read
      gives such a string, the helper takes `HTTP Status <n>`. When the
      body does not parse to a list and is not empty, the helper takes
      the body text. When the body is empty, it takes `HTTP Status <n>`.
- [ ] AC5: Every abort the helper raises carries the condition class
      `rlmstudio_api_error` and a `status` field. That field holds the
      HTTP status of the response as an integer.
- [ ] AC6: `NEWS.md` names every function whose failure message the table
      shows changing between the parent commit and this branch. It also
      records the new condition class.
- [ ] AC7: `devtools::document()` produces no diff. `devtools::test()`
      and `devtools::check()` are clean, at 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T3, T4
- AC2 → T1, T3, T4
- AC3 → T2, T3, T4
- AC4 → T1, T2, T3, T4
- AC5 → T2, T3, T4
- AC6 → T5
- AC7 → T5

## Tasks

- [x] T1: Write the body-shape table and a test driver over it. The
      driver sends one wrapper through every row with
      `local_request_recorder()` from `tests/testthat/helper-mock-http.R`.
      Run every row at two HTTP statuses, so the status fallback is never
      fixed by one run. Give `mock_response()` a content-type argument,
      so one row can serve a body httr2 refuses to parse on the header
      alone. Run the table against all seven wrappers on the parent
      commit first. Record each row's message per wrapper in the work
      log, so AC2 and AC6 have a baseline.
- [x] T2: Add the shared helper in a new `R/utils-api-error.R`. It takes
      the response and a label. It reads at most two values out of the
      parsed body, `error` and `error$message`. It guards an empty body
      before either read. It guards both reads on length, so a value that
      is not a length-one character string falls through to the status.
      It subsets `error` only after checking that `error` is a list,
      because `$` on a plain string raises an error in R. It raises
      `cli::cli_abort()` with the class and the `status` field.
- [x] T3: Route `lms_unload()` (R/unload.R:55), `lms_load()`
      (R/load.R:131), `lms_download()` (R/download.R:85), and
      `lms_download_status()` (R/download.R:155) through the helper. Run
      the table against each of the four.
- [x] T4: Route `lms_chat_openresponses()` (R/chat.R:190),
      `lms_chat_openai()` (R/chat.R:261), and `lms_chat_native()`
      (R/chat.R:324) through the helper. Run the table against each of
      the three.
- [x] T5: Write the `NEWS.md` entry from T1's baseline diff. Update the
      DESIGN.md Conventions bullet on condition classes. Run
      `devtools::document()`, `devtools::test()`, and
      `devtools::check()`.

## Work log

- 2026-09-18: created by /milestone-plan.
- 2026-09-18: criteria audit ran in full mode, pass one, five findings. The grep domain was narrower than the promise it bounded. An empty grep satisfied it. A drafted extraction rewrite changed three documented messages and pulled against D-003. The parent-commit and DESIGN.md clauses bound instruments. All were fixed pre-gate.
- 2026-09-18: criteria audit ran in full mode, pass two, four findings. The empty-array probes varied the value and not the branch. Two further crash bodies were live. Routing chat forced four message changes and not one. Direct helper tests were a third test style against D-004. All were fixed pre-gate.
- 2026-09-18: plan gate chose one message rule at all seven wrappers over a separate chat rule. The chat rule hides server error content that D-003 says to surface. Falsified by a report that chat body text reads worse than a bare status number.
- 2026-09-18: plan gate chose one condition class with a status field over per-endpoint subclasses. A caller filters on the number instead of on more class names before 1.0. Falsified by a caller that needs one endpoint's failure and not the others.
- 2026-09-18: plan chose one body-shape table through the wrappers over direct unit tests of the helper. Direct tests are a third test style beside the two D-004 sanctions. Falsified by a helper branch no wrapper reaches.
- 2026-09-18: implement gate settled the helper name `rlm_abort_api(resp, label)`, `call = NULL` at all seven aborts, and one new `tests/testthat/test-api-error.R` for the table.
- 2026-09-18: T1 baseline at the parent commit, 11 rows against all seven wrappers. `lms_load()` reaches its own failure branch only with `force = TRUE`, because `list_models()` throws on the mocked failure first. The four `API ...` wrappers share one extraction block and gave identical text on every row. Five bodies crashed those four, four crashed `lms_chat_native()`, and one crashed the other two chat wrappers.
- 2026-09-18: amendment, AC2. The prior wording pinned five shapes to the parent commit's text at `lms_unload()`, which AC3 and AC4 together cannot produce for three of them. Two of those three parent texts were accidents of `$` on a plain string falling into a `tryCatch` handler.
- 2026-09-18: re-audit: AC2 (full) — five findings. AC2 and AC4 both yielded an empty message where AC3 demands the status. An empty body counted as non-JSON in AC2 and as the status in AC3. AC4's stated read order crashes on a string `error`.
- 2026-09-18: amendment, AC2 and AC4. Both gained "non-empty". AC4 now reads `error` first and subsets it only when it is a list.
- 2026-09-18: re-audit: AC2 (full) — nine findings. A third crash family was live, scalar JSON bodies. AC4's ordering and fallback sentences disagreed. AC4's read-count clause was unfalsifiable through the wrappers and bound code shape, so it moved to T2. AC2 promised over every non-JSON body on one exemplar.
- 2026-09-18: amendment gate chose the status number over the raw body for a JSON body with no readable message. The alternative surfaces every body in full. It honors D-003 more, but it makes an abort read as a bare brace pair or a whole HTML page, and it forces AC3 open too. Falsified by a report that a dropped `error.code` left a real failure undiagnosable.
- 2026-09-18: re-audit: AC4 (full) — seven findings. The empty-body sentence tested a read that throws. Sentences two and three carried no quantifier. "Raises no R error of its own" contradicted AC5. Coverage mapped AC4 to the task that writes the helper and to no task that tests it.
- 2026-09-18: amendment, AC4 and Coverage, adopted at the gate without a further reader. Both of AC4's fresh-reader re-entries were spent.
- 2026-09-18: T1. Table of 17 rows in `tests/testthat/test-api-error.R`, every row at statuses 400 and 503 against all seven wrappers. `mock_response()` gained a `content_type` argument. Rows added after the audits: a `text/html` body, a message holding curly braces, `{"error": null}`, `{"error": {"message": null}}`, and two bodies that parse but not to a list.
- 2026-09-18: T1 defect, found by the full suite. The driver bound its mocks to a detached environment, so `is_server_running()` stayed mocked and five `test-serve.R` assertions failed. Both mocks now bind to the driver's own frame. The parent commit passes those assertions.
- 2026-09-18: T2. `R/utils-api-error.R` holds `is_message_string()`, `api_error_message()`, and `rlm_abort_api()`.
- 2026-09-18: T3 and T4. All seven wrappers route through the helper. Three `test-unload.R` cases asserted the superseded text for the three changed shapes and were rewritten.
- 2026-09-18: T5. NEWS.md names all seven functions and the new condition class. DESIGN.md Conventions gained a bullet on `rlm_abort_api()`. `devtools::document()` produces no diff. `devtools::check()` is clean at 0 errors, 0 warnings, 0 notes.
- 2026-09-18: candidate row added. A non-JSON failure body becomes the abort message in full, with no length bound.
- 2026-09-18: measured against the Scope line "Two crash cases are fixed there". The baseline crashed on five bodies at the four `API ...` wrappers and on four at `lms_chat_native()`. The Scope count is low and is left unedited, because Scope changes only through the amendment gate.

## Decisions

### 2026-09-18: A JSON body with no readable message gives the status, not the body

**Context:** GP4 and D-003 say the server is the validator and the package
surfaces the error it returns. The helper surfaces a non-JSON body in full,
but it replaces a JSON body it finds no message in with `HTTP Status <n>`.
That asymmetry drops what the server sent for `{"error": {"code": "E42"}}`
and for JSON that carries no `error` key.

**Decision:** Keep the status fallback. The alternative surfaces every body
in full and reserves the status for an empty body alone. It was rejected
because an abort then reads as a bare brace pair or as a whole HTML error
page. It also reopens AC3, which fixes six bodies to the status.

**Consequences:** A server error whose content sits outside `error` and
`error$message` reaches the user as a status number. GP4 is traded here with
this reason recorded, which is what a guiding principle allows. A report that
a dropped field left a real failure undiagnosable reopens the choice.

## Review
