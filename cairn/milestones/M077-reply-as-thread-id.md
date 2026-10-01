<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M077: A chat continues a thread from the reply itself

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP4
- **Resolves:** —
- **Surface tier:** user-facing — it changes what an exported argument accepts
- **Branch/PR:** m077-reply-as-thread-id

## Goal

A user continues a stored chat thread with `previous_response_id = first`, where `first` is the reply of the earlier call.

## Scope

**In:** `rlm_check_response_id()` reads the `response_id` attribute of the value it gets, with `exact = TRUE`. It checks and sends that attribute in place of the value (D-039). This covers `lms_chat()`, `lms_chat_native()`, `lms_chat_openresponses()`, and the `...` of `lms_chat_batch()`. Tests, help, NEWS, and the `follow-up` chunk of `vignette("chat-options")`, re-knitted against a live LM Studio.

**Out:** A class on the reply text. D-030 rejected it, and D-039 keeps that rejection. The `attr(,"response_id")` print line stays, as D-030 records. A batch stop at an id the server does not hold stays in its ROADMAP candidate row.

## Acceptance criteria

- [x] AC1: `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()` take as `previous_response_id` a value that carries a `response_id` attribute, such as the simplified reply of an earlier call. They send the string in that attribute, as a plain string, as the `previous_response_id` field of the request body. For each function, a test passes a reply string and an `lms_chat_result` that carry the attribute. It reads the field from the sent body. For `lms_chat_native()`, whose route returns no `lms_chat_result`, the test builds that value by hand. More tests show three facts. The attribute wins over a value that is itself a usable id. An attribute with a class or names is sent as a plain string. An attribute under another name, such as `response_idx`, is not read.
- [x] AC2: `lms_chat_batch()` can get such a value as `previous_response_id` in its `...`. On the native and OpenResponses routes, it then sends the string in the attribute as the `previous_response_id` field of the request for each input. With `api_type = "openai"`, `lms_chat()` and `lms_chat_batch()` refuse such a value with the route message that they give for a string. Tests read the field from each recorded request of a two-input batch on each thread route. They also assert the refusal on each of the two functions.
- [x] AC3: A value whose `response_id` attribute is not one usable string under the rule of `id_fault()` aborts before the server probe, with no condition class. The message names both `previous_response_id` and the `response_id` attribute. On the OpenAI route, this abort comes before the route refusal. A test uses each value of `thread_bad_values` in `tests/testthat/test-thread.R` as the attribute. It covers each of the four functions, and `lms_chat()` and `lms_chat_batch()` on each of the three routes.
- [x] AC4: Each input with no `response_id` attribute that the tests at the plan commit pass as `previous_response_id` is checked and sent as before this milestone. The tests in `tests/testthat/test-*.R` pass, and `git diff <plan commit> -- tests/testthat` removes or changes no `expect_` line. A new test shows that a reply string with no attribute goes out as the id itself.
- [x] AC5: The `follow-up` chunk of `vignettes/chat-options.Rmd.orig` passes `first` itself as `previous_response_id`. The prose before the chunk says to pass the reply, and one sentence says that the id string from `attr(first, "response_id")` also works. `vignettes/chat-options.Rmd` is knitted from that edited source against a live LM Studio. In it, the call that passes `first` answers green, and the prose after the chunk matches the knitted output.
- [x] AC6: The help of `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()` says four things. `previous_response_id` takes a value that carries a `response_id` attribute and sends that attribute. A value with no such attribute is sent as the id itself. So a reply with no id, such as a native reply sent with `store = FALSE`, gets status 400. The vector and data-frame formats of `lms_chat_batch()` return output with no attribute. The help of `lms_chat_batch()` says the same or points to `lms_chat()`. NEWS.md has an entry for the change.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T1, T2
- AC5 → T4
- AC6 → T3

## Tasks

- [x] T1: Write the AC1 to AC4 tests in `tests/testthat/test-thread.R` first, and see the new ones fail. Reuse `thread_bad_values` (line 173) and `thread_routes` (line 39) for AC3.
- [x] T2: In `rlm_check_response_id()` (`R/utils-args.R`, near line 395), read `attr(value, "response_id", exact = TRUE)`. When it is not `NULL`, check it with `id_fault()` under a message that names the attribute, and return its plain string. `lms_chat()` keeps passing the raw value to its delegates (`R/chat.R:146`), so the existing delegate test stays as it is. The batch check at `R/chat.R:2004` is not changed. Run the profile's verify slot.
- [x] T3: Update the `previous_response_id` roxygen of the four functions (`R/chat.R:53`, `:239`, `:1382`, `:1771`) and the `@return` text that says to pass the attribute. Run `devtools::document()`. Add the NEWS entry.
- [x] T4: Edit the `follow-up` chunk and its prose in `vignettes/chat-options.Rmd.orig`. Knit with `data-raw/knit-vignettes.R` against a live LM Studio, with the token as the user memory names it. Restore the other vignettes with `git checkout --` (LESSONS, M009). Match the prose after the chunk to the output. Run `devtools::test()`.

## Work log

- 2026-10-01: created by /milestone-plan.
- 2026-10-01: criteria audit (full mode, fresh Opus reader) returned 14 findings over AC1 to AC6 and 3 missed cases. Each had one clear fix, applied before the gate. The fixes add a hand-built native `lms_chat_result` and probes for attribute precedence, exact name, and a classed attribute. They add the OpenAI refusal, `thread_bad_values` on all routes, and a message that names both. They add a `test-*.R` pathspec with an `expect_` diff, the vignette prose, help on a reply with no id and on batch formats, and D-039.
- 2026-10-01: plan gate chose reading the `response_id` attribute over a new S3 class on the reply text, because `vctrs::vec_c()` fails to combine a classed string with a plain one (D-030, GP2); falsified by a user who passes a reply with no id and cannot tell why the server answered 400.
- 2026-10-01: plan gate chose a vignette chunk that shows `first` alone over one that shows both forms, because one call keeps the chunk short; falsified by a reader who needs the id string form and misses the sentence that names it.
- 2026-10-01: implement started on branch m077-reply-as-thread-id. No question gate, because the plan left only the abort wording open and AC3 fixes what it names.
- 2026-10-01: T1 done. Ten new tests in `test-thread.R`. Nine fail before T2, and the reply with no id passes, as AC4 expects.
- 2026-10-01: T2 done. `rlm_check_response_id()` reads the attribute with `exact = TRUE` and returns it as a plain string. A planted `exact = FALSE` and a planted raw return each fail the three function tests. `devtools::test()`: 1993 tests, 0 failed, 0 errors, 3 skipped.
- 2026-10-01: T3 done. The `previous_response_id` help of the three functions, the batch `...` help, and the three `@return` texts say to pass the reply. NEWS entry added. `devtools::document()` rewrote the four Rd files. No test reads them.
- 2026-10-01: T4 done. The `follow-up` chunk passes `first`, and the prose before and after it says so. Knitted `chat-options` alone, so no other vignette needed a restore. The call that passes `first` answered "Green." and the call with no id "Blue.". The last of three knits changed the replies of the route chunk, which no prose describes. `devtools::test()`: 1993 tests, 0 failed, 0 errors, 3 skipped.
- 2026-10-01: claim audit: 32 claims read, 1 corrected — tests/testthat/test-thread.R
- 2026-10-01: the audit found no evidence for the AC6 claim of status 400 on a reply with no id. A live probe with google/gemma-3-1b sent a native `store = FALSE` reply, which had no attributes, as `previous_response_id`. The native route answered 400 with code `invalid_string`, and the OpenResponses route 400 with code `invalid_value`. The wording stays, and the same reader cleared it on re-read.
- 2026-10-01: implement complete, status set to review. The style hook flags plan-owned and history text in this file and in NEWS.md that was there before. The branch adds one hit, the em dash of the fixed claim-audit line.
- 2026-10-01: review started. AC1 to AC6 verified and ticked, and the consistency gate passed. Three fresh reviewers are running, and their findings are not yet triaged.

## Decisions

## Review

Fresh evidence, 2026-10-01, on branch head 765a467. The default branch, origin/main 749ef14, did not move after the branch was cut.

- AC1: the three `continues a thread from a value that carries the reply id` tests in `test-thread.R` pass (native 5, OpenResponses 5, `lms_chat()` 10 expectations, 0 failed). Each reads the `previous_response_id` field of the sent body for a reply string and a hand-built `lms_chat_result`, on each thread route. The same tests show the attribute winning over an id string, a classed and named attribute sent as `"resp_7"`, and a `response_idx` attribute not read.
- AC2: `lms_chat_batch() continues a thread from a value in its dots on both thread routes` passes (4 expectations, 0 failed). For each carrier, it reads `"resp_7"` from both recorded requests of a two-input batch on the native and OpenResponses routes. The OpenAI refusal test passes (10 expectations). Both `lms_chat()` and `lms_chat_batch()` give the route message for each carrier, with no package class, no probe call, and no delegate call.
- AC3: the four `aborts on a response_id attribute that is not one usable string` tests pass (native 31, OpenResponses 31, `lms_chat()` 92, `lms_chat_batch()` 91 expectations, 0 failed). Each of the six `thread_bad_values` is used as the attribute, on all three routes for `lms_chat()` and `lms_chat_batch()`. Each abort matches its message, names `previous_response_id` and the `response_id` attribute, and carries no package class. On the OpenAI route, the message holds no `api_type` text, so the abort comes before the route refusal. The probe count stays 0.
- AC4: `devtools::test()` gives 20105 expectations, 0 failed, 0 errors, and 3 skipped (the live tests, with no server running). `git diff 749ef14..HEAD -- tests/testthat` has 0 removed lines, so no `expect_` line was removed or changed. `a reply that came back with no id goes out as its own text` passes (7 expectations). A native reply with no `response_id` field has no attributes and is sent as `"hi"` by all four functions.
- AC5: the `follow-up` chunk of `chat-options.Rmd.orig` passes `previous_response_id = first`. The prose before it says to pass the reply itself, and its last sentence says that `attr(first, "response_id")` also works. The MD5 footer of `chat-options.Rmd` (2a8ae2a1...) equals `md5` of the edited `.orig`, so the knit used that source. In the knitted output, the call that passes `first` answers "Green." and the call with no id answers "Blue.". The prose after the chunk says that the model answered from the first prompt with the reply and guessed with no id, which matches. The `vignette-claims` and `vignette-knit` test files pass inside the AC4 run.
- AC6: a read of the `previous_response_id` roxygen of `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()` in `R/chat.R` finds all four facts in each. A value with a `response_id` attribute sends that attribute. A value with no attribute is sent as the id itself. A native reply sent with `store = FALSE` (for `lms_chat_native()`, a reply of this function) gets `rlmstudio_api_error` with status 400. The vector and data-frame formats of `lms_chat_batch()` carry no attribute. The `...` help of `lms_chat_batch()` says the same and points to `lms_chat()`. Each of the three Rd files names `store = FALSE` 3 times. NEWS.md has a top entry with two sub-items for the change.

Consistency gate, 2026-10-01: `cairn_validate.py` passes (exit 0). No DESIGN principle changed, so `cairn_impact` is skipped. `devtools::document()` leaves no diff. `pkgdown::check_pkgdown()` finds no problems. README is not touched. NEWS.md has the entry, with no milestone number. The branch adds no top-level file. `devtools::check()` gives 0 errors, 0 warnings, and 0 notes.
