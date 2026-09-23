<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M024: A chat reply that does not parse as JSON fails its input alone

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP2   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes the condition that three exported chat functions and `lms_chat_batch()` raise   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A status-200 chat reply that does not parse as JSON aborts with `rlmstudio_bad_response`, so a batch keeps its other replies.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** A shared parse helper, built from the guard in `lms_embed()` (`R/embed.R:88-101`). It parses with `check_type = FALSE` and aborts with `rlmstudio_bad_response` when the parse fails. `lms_embed()`, `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat_openai()` use it (`R/chat.R:186`, `:328`, `:840`). The abort happens whatever `simplify` is, and its message points at the host. A valid JSON body under a `text/plain` header is read as JSON. Help pages and NEWS.md are updated. Absorbs the candidate row on a 200 chat body that is not JSON (M023 review finding O2).

**Out:** The unguarded parses in `lms_load()`, `lms_download()`, and `lms_download_status()` go to a new candidate row. A condition field that holds the raw body text goes to a new candidate row. A non-JSON failure body (status 400 and up) stays in its own candidate row. The probe in `lms_server_ready()` (`R/serve.R:667`) already turns every error into `FALSE` and is left alone.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: Take `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat_openai()`, each with `simplify = TRUE` and `FALSE`. A status-200 body that does not parse as JSON raises `rlmstudio_bad_response`. The condition's `status` is `200L`. Its message says that the body did not parse as JSON and does not contain `simplify = FALSE`. On the OpenAI route, the condition carries `content` and `finish_reason`, both `NULL`. A test runs every route and setting against three bodies: an HTML page under `text/html`, a cut-off JSON text under `application/json`, and an empty body. It asserts the class, the `status`, the message clause, the absent `simplify = FALSE`, and the two OpenAI fields.
- [ ] AC2: On each route and `simplify` setting, take a valid JSON reply body under `Content-Type: text/plain`. The call returns what the same body returns under `application/json`. A test asserts `identical()` results for each route and setting.
- [ ] AC3: In `lms_chat_batch()` with no `schema` and `logprobs = FALSE`, the second of three inputs gets the HTML body or the empty body of AC1. That input fails alone. The first and third elements hold their replies. The second holds the condition where the result is a list, and `NA` where it is text. With `format = "data.frame"`, the reply columns of row 2 are `NA`. The call gives one warning that names position 2. A test covers each body with each `api_type` and each `format` (`"vector"`, `"list"`, `"data.frame"`).
- [ ] AC4: The message of the AC1 condition does not contain the body text. On each route, a test uses the body `<html>MARKER</html>`, where the parse fails at the marker. It asserts that `conditionMessage()` does not match `MARKER`.
- [ ] AC5: On a status-200 body that does not parse as JSON, `lms_embed()` raises `rlmstudio_bad_response` with `status` `200L`. Its message says that the body did not parse as JSON, points at the host, and does not contain `simplify = FALSE`. A valid JSON body under `text/plain` still returns the embeddings matrix. The existing tests in `tests/testthat/test-embed.R` assert this and pass.
- [ ] AC6: The `rlmstudio-conditions` help page is updated in four places. The "Malformed response" section names the three chat functions as raisers of the parse failure and states that it is raised whatever `simplify` is. Its count of raising functions matches the functions it names. The "Server not running" section no longer says that a call can fail "as a raw parse error". The closing paragraph no longer says that only an embeddings body points at the host. The help of `lms_chat_batch()` states that such an input fails alone. NEWS.md has an entry for the change.
- [ ] AC7: `devtools::test()` reports no failures, and `devtools::document()` leaves no diff. `devtools::check()`, run with LM Studio live and `RLMSTUDIO_API_TOKEN` set, reports 0 errors and 0 warnings. Any NOTE is named and justified in the Review section.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T1, T2
- AC5 → T2
- AC6 → T4
- AC7 → T5

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. -->

- [ ] T1: Write the tests of AC1, AC2, and AC4 first, in a new file `tests/testthat/test-chat-body-parse.R`. Use `mock_response()` from `helper-mock-http.R`, which takes a `content_type`, and the reply builders in `helper-chat-bodies.R`. Make sure that they fail on the current code for the reason each asserts, not by accident (LESSONS, M008 and M012).
- [ ] T2: Move the guard of `lms_embed()` into a shared helper in `R/utils-api-error.R`. It takes the response, the label, and extra condition fields, so the OpenAI route can pass `content = NULL` and `finish_reason = NULL`. Call it from `lms_embed()` and the three chat functions, before the `simplify` branch. Run `test-embed.R` and the T1 tests to green.
- [ ] T3: Add the AC3 batch tests, next to the bare-value batch test in `test-bare-body.R` or in the T1 file. Make sure that the batch catches the new condition through its existing `rlmstudio_bad_response` handler (`R/chat.R:1187-1188`), with no change to the loop.
- [ ] T4: Update the help text named in AC6 in `R/conditions.R` and in the `lms_chat_batch()` roxygen block. Add the NEWS.md entry. Run `devtools::document()`.
- [ ] T5: Run `devtools::test()`, then `devtools::check()` with LM Studio live and the token set (LESSONS, M009). Record the results.

## Work log
<!-- owner: any skill · append-only -->

- 2026-09-22: Planned. The criteria audit ran in full mode with a fresh [O] reader and returned 10 findings. All were fixed before the gate. The fixes add an empty-body probe, the OpenAI `content` and `finish_reason` fields, and a test that the message omits `simplify = FALSE`. They move the marker to the parse failure point and name the batch bodies, with `NA` reply columns. AC5 now states behavior, AC6 names three help passages, and AC7 accepts justified NOTEs.
- 2026-09-22: Gate chose chat routes only over also guarding `lms_load()` and the download functions. They make one call each with no batch to lose. A report of a user who lost work to one of them reopens the choice.
- 2026-09-22: Gate chose parsing by content (`check_type = FALSE`) over an abort on a `text/plain` header. The abort reports two causes as one, and it leaves no way through a proxy that rewrites the header. A server that sends non-JSON under `text/plain` on purpose falsifies the choice.
- 2026-09-22: Gate chose to abort with `simplify = FALSE` too over a return of the raw text. A text return makes the type of `simplify = FALSE` depend on the server. A user who needs the page to diagnose a proxy falsifies the choice.
- 2026-09-22: Gate chose no condition field for the raw body over a `body` field. With the field, a batch holds a large page for each failed input. The falsifier of the previous line applies here too.

## Decisions
<!-- owner: implement, review · append-only -->

## Review
<!-- owner: review · exclusive -->
