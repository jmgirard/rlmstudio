# M005: One abort path for the seven REST failure branches

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — the abort messages users read and a condition class callers catch
- **Branch/PR:** —

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
- [ ] AC2: For these five shapes the message text is the one the parent
      commit gives at `lms_unload()`. The shapes are a nested
      `error.message` string, `{"error": {"code": "E42"}}`, a string
      `error`, JSON with no `error` key, and non-JSON text.
- [ ] AC3: For these six shapes the message text is `HTTP Status <n>`.
      The shapes are an empty body, `{"error": []}`, `{"error": {}}`,
      `{"error": {"message": []}}`, `{"error": ["a", "b"]}`, and
      `{"error": {"message": ""}}`.
- [ ] AC4: The helper reads at most two values out of the parsed body.
      They are `error$message` and `error`. For either read, a value that
      is not a length-one character string yields `HTTP Status <n>`.
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
- AC4 → T2
- AC5 → T2, T3, T4
- AC6 → T5
- AC7 → T5

## Tasks

- [ ] T1: Write the body-shape table and a test driver over it. The
      driver sends one wrapper through every row with
      `local_request_recorder()` from `tests/testthat/helper-mock-http.R`.
      Run the table against all seven wrappers on the parent commit
      first. Record each row's message per wrapper in the work log, so
      AC2 and AC6 have a baseline.
- [ ] T2: Add the shared helper in a new `R/utils-api-error.R`. It takes
      the response and a label. It guards an empty body before either
      read. It guards both reads on length, so a value that is not a
      length-one character string falls through to the status. It raises
      `cli::cli_abort()` with the class and the `status` field.
- [ ] T3: Route `lms_unload()` (R/unload.R:55), `lms_load()`
      (R/load.R:131), `lms_download()` (R/download.R:85), and
      `lms_download_status()` (R/download.R:155) through the helper. Run
      the table against each of the four.
- [ ] T4: Route `lms_chat_openresponses()` (R/chat.R:190),
      `lms_chat_openai()` (R/chat.R:261), and `lms_chat_native()`
      (R/chat.R:324) through the helper. Run the table against each of
      the three.
- [ ] T5: Write the `NEWS.md` entry from T1's baseline diff. Update the
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

## Decisions

## Review
