<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M020: A chat reply without readable answer text fails that input, not the batch

- **Status:** planned   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP2, GP4, GP6   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — changes what three exported chat wrappers and the batch return and raise   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** —   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Every chat route reads its answer from the message items, and a reply without one aborts, so `lms_chat_batch()` stores it per input.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** `lms_chat_native()` and `lms_chat_openresponses()` stop reading `output[[1]]`. The LM Studio docs say a native reply can put a `reasoning` or `tool_call` item before the message, so a reasoning model returned its reasoning as the answer. Both routes now join the text of every message item in order and check the reply shape. `lms_chat_openai()` aborts on reply content that is not one string, `null` included. D-012 records that choice. `lms_chat_batch()` checks `format = "data.frame"` with `simplify = FALSE` before the server probe. The help pages and `NEWS.md` change to match. This absorbs two candidate rows: the reply-shape row (M019 review findings O4 and P4) and the `simplify = FALSE` row (M019 review findings O5 and P7).

**Out:** A reply that the token limit cut off but that still parses stays its own candidate row. Stopping a batch early on a failure that holds for every input stays its own candidate row. Returning the reasoning text or the tool calls is not in scope, and no row holds it. `simplify = FALSE` still returns the whole body. Structured output on the native and OpenResponses routes stays its own candidate row.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets.
     Every item opens with its positional label — `ACn:` — the item's
     position counted top-to-bottom, the number Coverage cites; an
     insertion, removal, or reorder renumbers the labels and the Coverage
     lines together.
     Driving RR set → its Binding criteria appear VERBATIM here (binding-
     criteria check), each ingested as a numbered criterion carrying its tag
     — `- [ ] ACn (BCm): <verbatim>` — with its own Coverage line, since
     coverage-complete counts AC checkboxes positionally (M107); departures:
     a "Deviations from RR<NN>" table ends this section. -->

- [ ] AC1: With `simplify = TRUE`, `lms_chat_native()` returns the `content` strings of the `output` items of type `"message"`. It pastes them together in order with no separator. It skips object items of any other type and object items with no `type` field. An item that is not an object aborts, as AC3 says. A test in `tests/testthat/test-chat.R` asserts the exact string for four mocked bodies. They are a `reasoning` item before the message, and a message, a `tool_call`, and a message. The third is a message, an `invalid_tool_call`, an item of an unknown type, an item with no `type`, and a message. The fourth is one message alone.
- [ ] AC2: With `simplify = TRUE`, `lms_chat_openresponses()` returns the `text` of the `output_text` parts of the `"message"` items, pasted together in order with no separator. It skips other items and parts of any other type. With `logprobs = TRUE`, it returns an `lms_chat_result` when at least one selected part carries logprobs. Its `logprobs` rows then come from those parts in order. When no selected part carries logprobs, it returns the plain string, as it does now. A test asserts the exact string for three bodies. They are a `reasoning` item before the message, two message items, and a message with an `output_text`, a `refusal`, and an `output_text` part. With `logprobs = TRUE`, it asserts the `step_token` column.
- [ ] AC3: With `simplify = TRUE`, both of those wrappers abort with `rlmstudio_bad_response` when the reply holds no readable answer text. The rule covers these shapes. `output` is absent, empty, or not an array. An item, or an OpenResponses part, is not a JSON object. An OpenResponses message `content` is not an array. There is no `"message"` item, or for OpenResponses no `output_text` part. A selected text is not one string. An empty string is one string, so a reply of `""` returns `""`. A table-driven test runs every shape on each wrapper. The not-a-string case uses a number, `true`, an array, an object, and `null`. Each of those sits once in the only message and once beside a readable message. OpenResponses runs with `logprobs` on and off. With `simplify = FALSE`, each body comes back parsed and nothing aborts.
- [ ] AC4: With `simplify = TRUE`, `lms_chat_openai()` aborts with `rlmstudio_bad_response` when the first message `content` is not one string. A `schema` with `logprobs = FALSE` is the exception, because `parse_schema_reply()` keeps that path. A test asserts this for content that is `null`, absent, `5`, `true`, `["p","q"]`, and `{"a":1}`. It runs with `logprobs` on and off, and once more with a `schema` and `logprobs = TRUE`. The condition's `content` field holds the value read, which is `NULL` for `null` or absent. Its `finish_reason` field holds the first choice's finish reason. Today `null` returns `NULL`, and with `logprobs = TRUE` it aborts with an unclassed error.
- [ ] AC5: Each body in the AC3 and AC4 tables goes to a two-input `lms_chat_batch(simplify = TRUE)` on the matching route, with `logprobs` off. The first request gets a readable reply and the second gets that body. For each `format`, the call returns with one element or row per input. The second holds the condition in a list and `NA` in a vector or data frame. The call gives one warning, which names position 2. One more run sends the AC4 `null` body with `logprobs = TRUE` and `format = "data.frame"`. It gives one warning, `NA` output, and `NULL` logprobs at position 2. A test in `tests/testthat/test-chat-batch.R` asserts this per body and format.
- [ ] AC6: `lms_chat_batch(format = "data.frame", simplify = FALSE)` aborts with no condition class and its existing message before the server probe and before any request, as D-008 orders argument faults. Today it sends every request first. A test in `tests/testthat/test-arg-guards.R` shows that the probe never ran.
- [ ] AC7: The "Malformed response" section of the `rlmstudio-conditions` help page names all four raisers. It gives the AC3 cases for `lms_chat_native()` and `lms_chat_openresponses()`. It adds the AC4 case as a third `lms_chat_openai()` case, with the values of its `content` and `finish_reason` fields. Both of those two wrappers inherit the section. The `@return` text of the three wrappers states the AC1, AC2, and AC4 rules. The `lms_chat()` details say it can raise `rlmstudio_bad_response` on every route. The `lms_chat_batch()` details no longer say that a `NULL` reply holds `NA`. After that, `devtools::document()` produces no diff.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T2, T3
- AC4 → T4
- AC5 → T1, T5
- AC6 → T6
- AC7 → T7

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [ ] T1: Give every mocked chat body a `type` on each item and part, as real LM Studio replies have. That covers the body in `tests/testthat/test-chat.R:79-92` and the `openresponses_ok()` helper in `tests/testthat/test-chat-batch.R:17-27`. Add native and OpenResponses body builders to `tests/testthat/helper-chat-bodies.R`. Two tests expect a `null` reply to give `NA` with no failure: `test-chat-batch.R:292-320` for OpenAI content and `321-341` for OpenResponses text. Rewrite both to expect a stored failure. The suite passes before any change under `R/`.
- [ ] T2: Add an internal reader for the native reply in `R/chat.R`. It selects the message items, checks the shape, and aborts through `rlm_abort_bad_response()`. `lms_chat_native()` calls it where it now reads `output[[1]]$content` (`R/chat.R:515`). Write the AC1 tests and the native AC3 rows first.
- [ ] T3: Add the OpenResponses reader in the same way, with the logprobs rows taken from every selected part. It replaces `output[[1]]$content[[1]]` (`R/chat.R:173`). Write the AC2 tests and the OpenResponses AC3 rows first.
- [ ] T4: In `lms_chat_openai()`, abort when the content is not one string, before the logprobs and plain returns (`R/chat.R:352-368`). The `schema` path keeps `parse_schema_reply()`. Write the AC4 tests first.
- [ ] T5: Write the AC5 batch table in `tests/testthat/test-chat-batch.R`, reusing `local_request_sequence()`.
- [ ] T6: In `lms_chat_batch()`, move `match.arg(format)` and the `data.frame` and `simplify` check above `stop_if_no_server()` (`R/chat.R:603-664`). Write the AC6 test first with `local_counting_probe()`, as `test-arg-guards.R:489-503` does.
- [ ] T7: Update the help text named in AC7 in `R/conditions.R` and `R/chat.R`, including "Two functions raise it" and "both functions" (`R/conditions.R:56-57` and `80-81`). Run `devtools::document()`. Add a `NEWS.md` entry. Rewrite the development-version sentence that says a `NULL` reply holds `NA`.
- [ ] T8: Run `devtools::test()` and then `devtools::check()` with `RLMSTUDIO_API_TOKEN` set, both clean.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates.
     EXEMPT from the 150-line cap (D-046): history under D-045, never edited,
     so the cap must never demand a trim here. Wrapped entries get a WARN.
     The rejected-alternative record (/milestone-plan step 4) takes this form:
     `- YYYY-MM-DD: plan gate chose <approach> over <alternative> because
     <reason>; falsified by <evidence class>.` — one per approach choice the
     gate actually weighed, none where it weighed none, and it is the record
     `/milestone-review`'s thrash trigger (b) reads. It lives here rather than
     below so an instantiated file inherits no placeholder to delete. -->

- 2026-09-22: created by /milestone-plan.
- 2026-09-22: criteria audit, full mode, fresh [O] reader: 11 findings. Ten were fixed in the criteria or became T1 and T7. The no-text choice went to the gate.
- 2026-09-22: re-audit of the gate-changed criteria, full mode, same fresh [O] reader: 6 findings, all fixed. A missed broken test went into T1. The other five changed AC1, AC3, AC4, AC5, and AC7.
- 2026-09-22: plan gate chose to join every message item's text over the first or last message only, because text after a tool call is lost otherwise. Falsified by replies whose earlier messages are not part of the answer.
- 2026-09-22: plan gate chose an abort for a reply with no answer text on every route over `NULL` everywhere or `NULL` on OpenAI only (D-012). Falsified by users who rely on `NULL` for a tool-call reply.
- 2026-09-22: plan gate chose to include the early `data.frame` and `simplify` check over a separate hotfix, because it touches the same function and test files.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md.
     EXEMPT from the 150-line cap (D-074) because D-045 makes it history like the work log — dated dispositions, never edited — so the cap must never demand a trim here either.
     Entries carry their rationale; the counterweight `decisions format`
     advisory watches for pasted output, not for entry length (D-075). -->
