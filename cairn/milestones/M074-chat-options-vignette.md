# M074: A vignette shows chat options, conversations, and errors in scripts

- **Status:** review
- **Priority:** normal
- **Depends on:** M070
- **Driving RR:** —
- **Principles touched:** GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — a new vignette that package users read
- **Branch/PR:** m074-chat-options-vignette

## Goal

A user can choose a chat route, set request options, hold a conversation,
and handle errors in a script, from one new vignette.

## Scope

**In:** A new `vignettes/chat-options.Rmd.orig`, knitted by the M070 script
to `vignettes/chat-options.Rmd`. The sections cover these steps in order:

1. The three routes of `lms_chat()` (`api_type`) and what each one
   supports, in a short table.
2. Request options such as `temperature`, passed through the dots, and a
   misspelled option that the server ignores (GP4).
3. A follow-up question with `previous_response_id`.
4. A whole conversation as a `messages` data frame on `lms_chat_openai()`.
5. The raw reply with `simplify = FALSE`.
6. Catching `rlmstudio_no_server` and `rlmstudio_api_error` with
   `tryCatch()` in a script (GP3). The no-server case calls a port where
   no server listens, such as `host = "http://localhost:1"`, so the knit
   keeps its own server running.

The model is `google/gemma-3-1b`. The code and prose follow the vignette
rules in DESIGN.md Conventions (M070). A NEWS entry.

**Out:** Streaming stays in its candidate row. Structured output and batch
scoring are M073.

## Acceptance criteria

- [x] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/chat-options.Rmd.orig` holds each of these strings:
      `api_type = "native"`, `api_type = "openai"`, `temperature =`,
      `previous_response_id =`, `lms_chat_openai(`, `messages =`,
      `simplify = FALSE`, `tryCatch(`, `rlmstudio_no_server`, and
      `rlmstudio_api_error`. In the knitted `vignettes/chat-options.Rmd`,
      no line starts with ```` ```{r ```` or with `#> Error`. The block of
      each chunk that calls `lms_chat(` or `lms_chat_openai(` holds a line
      that starts with `#>` after its last code line.
- [x] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [x] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside
      its ```` ```{r} ```` chunks, with the YAML header and inline code.
- [x] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      route, request option, response id, conversation history, raw reply,
      and condition class.
- [x] AC5: Take each prose sentence and each `#` comment line that states
      what a package function does with an argument, returns, or raises,
      beyond what its name says. A named test under `tests/testthat/`
      exercises that behavior. A sentence about what LM Studio itself does
      matches what a live call on this machine returned.
- [x] AC6: `NEWS.md` has an entry under the development-version heading
      that names the new vignette. `devtools::document()` gives no diff,
      `devtools::test()` passes, and `pkgdown::check_pkgdown()` passes.
      With the server stopped and `RLMSTUDIO_API_TOKEN` unset,
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3, T10
- AC2 → T2, T10
- AC3 → T2, T4, T10
- AC4 → T2, T4, T7
- AC5 → T1, T5, T7, T8, T9
- AC6 → T6, T8, T10

## Tasks

- [x] T1: Probe on this machine each call of the outline, and log what each
      returns: the three routes, `temperature` and a misspelled option, a
      follow-up by `previous_response_id`, a `messages` data frame, a raw
      reply, a call to `host = "http://localhost:1"`, and an API error.
      Read `?lms_chat` and `?rlmstudio-conditions` for the route rules
      that the table states.
- [x] T2: Write the source to the outline in Scope. Keep each code chunk
      short, with a comment that says what it does. Add the source to the
      list that `data-raw/knit-vignettes.R` knits.
- [x] T3: Knit with `data-raw/knit-vignettes.R` from a clean start. Read
      the knitted file for error lines and for the output lines of AC1.
- [x] T4: Spawn a fresh reader with the persona of a researcher who knows
      R and has run `getting-started`. It reads the knitted vignette and
      lists each step that it cannot follow and each term used before it is
      explained. Fix each item, or log why not, and re-knit.
- [x] T5: List the claims of AC5 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
- [x] T6: Add the NEWS entry and run the checks of AC6.
- [x] T7: Fix the review findings F1, F2, F4, F6, F7, and F9 in the source. Name the dots that the package checks, and say that a `NULL` option is dropped. Limit the mismatch text to one loaded model and to the default and openai routes. Back or drop the temperature-0 sentence, and explain "system prompt" before its first use. Point to `?lms_chat` for `ttl`.
- [x] T8: Fix F3. Add an `rlmstudio_bad_response` handler to `chat_or_na()`, and say which errors still stop a loop. Narrow the intro and the NEWS entry to match.
- [x] T9: Fix F5 and F8. Give the openai part of the log-probability test a mock reply that carries log probabilities, or back the "No" cell with a live call. Rewrap the test header and the two long source lines.
- [x] T10: Re-knit from a clean start, and re-run the checks of AC1 to AC6.

## Work log

- 2026-09-30: created by /milestone-plan.
- 2026-10-01: started by /milestone-implement on branch m074-chat-options-vignette.
- 2026-10-01: question gate: the API error example is a misspelled model name, the options section shows `temperature` alone, and the title is "Chat Options, Conversations, and Errors".
- 2026-10-01: T1 probe, `google/gemma-3-1b` at context 2048: all three routes reply. The openresponses and native replies carry a `response_id` attribute, and the openai reply has none.
- 2026-10-01: T1 probe: the raw openresponses reply holds `temperature` 0 with `temperature = 0`, and 0.8 with a misspelled `temprature = 0`. The openai route also ignores `temprature`. The native route refuses it with `rlmstudio_api_error`, status 400, code `unrecognized_keys`.
- 2026-10-01: T1 probe: at `temperature = 0`, a follow-up by `previous_response_id` to "My favorite color is green." answered "Green.". The same question with no id answered "Blue.". Both held in 4 of 4 runs on both routes. A name prompt gave unstable answers.
- 2026-10-01: T1 probe: a four-row `messages` data frame with an assistant turn answered "Your favorite color is green." in 3 of 3 runs. The raw openresponses reply has 31 fields, among them `id`, `output`, `usage`, and `temperature`.
- 2026-10-01: T1 probe: `host = "http://localhost:1"` raised `rlmstudio_no_server`. The model `google/gemma-3-1bb` raised `rlmstudio_model_mismatch` (status 200) on the openresponses and openai routes, and `rlmstudio_api_error` (status 404, code `model_not_found`) on native.
- 2026-10-01: mini gate on the T1 finding: the error section catches the misspelled model on both routes, so it also handles `rlmstudio_model_mismatch`. Scope item 6 names two classes, and no criterion changes.
- 2026-10-01: T2 note: `data-raw/knit-vignettes.R` knits every `vignettes/*.Rmd.orig` with no list, so T2 adds nothing to the script.
- 2026-10-01: T2: wrote `vignettes/chat-options.Rmd.orig` to the six-step outline. A scan of the source finds all ten AC1 strings, no AC2 code pattern, no inline R, and no AC3 prose word.
- 2026-10-01: T3: the first knit left the chunk that defines `chat_or_na()` with `lms_chat(` and no `#>` line, and a scratch block checker flagged it. A working call now ends that chunk. The re-knit from a clean start has no `{r` fence and no `#> Error` line. All 9 blocks that call a chat function have a `#>` line after the last code line.
- 2026-10-01: T4: a fresh Opus reader with the persona listed 9 steps and 12 terms. Route and request option were defined only after their headings, and response id and raw reply were used before their definition. All four are now defined at or before first use.
- 2026-10-01: T4 fixes: the intro defines route and request option. Response id and the table columns are defined above the table, and a route choice follows it. Field, `host`, port, HTTP status, and `unrecognized_keys` are explained. The text says how `lms_chat_openai()` relates to the openai route. The `trimws()` sentence no longer claims a line break that the knit did not show.
- 2026-10-01: T4 fixes: the prompt "Name a fruit of that color." gave "A mango!". It became "Write my favorite color in capital letters.", which gave "GREEN!", and one sentence states that. A pointer to <https://lmstudio.ai/docs/developer> was added. Its native chat page, read this session, lists `temperature`.
- 2026-10-01: T4 not fixed: how long the server keeps a reply, which was not probed. Also the other fields of `names(raw)`, which the text does not use, and a list of error codes, which is out of scope. A re-knit from a clean start passes the T3 checks.
- 2026-10-01: T5 ledger, routes: `api_type` picks the route and each returns the text, backed by the new test "lms_chat() sends each api_type to its own route and returns the reply text". The default route is also backed by "lms_chat() sends the input and the system prompt and returns the reply text".
- 2026-10-01: T5 ledger, table: the response id column is backed by test-thread.R "lms_chat() sends previous_response_id on both thread routes" and "lms_chat() refuses previous_response_id on the openai route". The log probability column is backed by the new test "lms_chat() returns log probabilities on the default route alone".
- 2026-10-01: T5 ledger, table: the `schema` and `ttl` column is backed by test-arg-guards.R "a schema on a route other than openai aborts …" and "a ttl on a route other than openai aborts …". The `response_id` attribute is backed by test-thread.R "lms_chat() returns the attribute on the two thread routes" and "lms_chat_openai() and lms_chat() on openai return no attribute".
- 2026-10-01: T5 ledger, options and history: new tests "lms_chat() sends a request option as written, a misspelled name included, on each route", "lms_chat() on the openai route sends the system prompt and the prompt as its messages", and "lms_chat_openai() sends a messages data frame as one message per row, in order".
- 2026-10-01: T5 ledger, raw reply and errors: `simplify = FALSE` is backed by test-thread.R "a call with simplify = FALSE returns the body with no attribute". `rlmstudio_no_server` is backed by test-chat.R "lms_chat passes rlmstudio_no_server through for api_type …", once for each route.
- 2026-10-01: T5 ledger, errors: the `status` and `code` fields are backed by test-model-check.R "a recorded model_not_found reply carries its code on both routes" and "an API error carries the code string of the body, or NULL". The mismatch and its `model` and `reply_model` fields are backed by "lms_chat() raises the mismatch on the default route and the openai route".
- 2026-10-01: T5 ledger, other: the `host` default is backed by "lms_load(), lms_chat(), and lms_unload() take a host argument". The 30-second wait comment is backed by test-serve.R "wait_for_server starts no request after the budget passes".
- 2026-10-01: T5 ledger, LM Studio claims: the knitted output shows each one. Those are the replies, the raw `temperature` of 0 and 0.8, the native refusals (400 `unrecognized_keys`, 404 `model_not_found`), the default-route mismatch, the follow-up "Green." against "Blue.", and "GREEN!".
- 2026-10-01: T5 probe: the raw openresponses reply holds the text "Blue." at `output[[1]]$content[[1]]$text`. The raw openai fields are `id`, `object`, `created`, `model`, `choices`, `usage`, `stats`, and `system_fingerprint`. The raw native fields are `model_instance_id`, `output`, `stats`, and `response_id`. So the fields differ by route.
- 2026-10-01: T5: added 5 tests to `tests/testthat/test-vignette-claims.R`. A planted defect in a scratch copy turned each one red, and no other test. The plants were a wrong native path, a filter on unknown dots, a swapped system role, reversed message rows, and a changed native warning. `devtools::test()`: 0 failed, 0 errors, 3 live skips.
- 2026-10-01: T6: added the NEWS entry. `devtools::document()` gives no diff, and `pkgdown::check_pkgdown()` finds no problems. With the server stopped and `RLMSTUDIO_API_TOKEN` unset, `devtools::check()` gives 0 errors, 0 warnings, and 0 notes.
- 2026-10-01: claim audit: 56 claims read, 2 corrected — vignettes/chat-options.Rmd.orig, vignettes/chat-options.Rmd. "The server keeps no history" on the openai route had no live evidence and now rests on the missing response id. The route advice no longer suggests that `lms_chat()` takes a data frame. The same reader re-read both and found that they hold.
- 2026-10-01: after the audit, a re-knit from a clean start passes the T3 checks, and the source scan passes the AC2 and AC3 checks.
- 2026-10-01: all tasks done. `devtools::test()`: 0 failed, 0 errors, 3 live skips. Status set to review.
- 2026-10-01: review return 1 (defect): AC5 fails on F1, the false sentence "The package does not check the names of request options". At the gate the user chose to send it back and fix F1 to F9 as T7 to T10. F10 to F12 are rejected for the reasons in the Review section. AC5 is unticked. Status set to in-progress.
- 2026-10-01: AC3 rewrapped so that no line starts with a quoted fence. The words are unchanged. `cairn_validate.py` read that line as an open code fence and counted the Review section as plan lines.
- 2026-10-01: resumed by /milestone-implement. No question gate: T9 takes the mock reply, and T7 drops the temperature-0 claim.
- 2026-10-01: T7: the options text names the checked dots (`stream`, `instructions` on the default route, `messages` on openai) and says a `NULL` option is left out. "As you wrote it" and both temperature-0 claims are gone. "System prompt" is explained at its first use, and the `ttl` sentence is a pointer to `?lms_chat`. The mismatch text says "with one model loaded" and names the default and openai routes.
- 2026-10-01: T8: `chat_or_na()` has an `rlmstudio_bad_response` handler after the mismatch handler, since the mismatch is also a bad response. The text says that other errors, such as a wrong argument, still stop a loop. The intro and the NEWS entry now name the four classes.
- 2026-10-01: T9: the openai mock in the log-probability test now carries log probabilities. The test file header is rewrapped. The two long source lines went in T7.
- 2026-10-01: T9: new test "lms_chat() on the native route returns a reply from another model with no error". The option test now also sends `temperature = NULL` and finds no field.
- 2026-10-01: T9 plants in a scratch copy: `c()` in place of `modifyList()` turned the option test red on two routes. Openai logprobs read from the reply turned the log-probability test red. A native model check turned the native test red.
- 2026-10-01: T9: `devtools::test()` ran 1973 tests: 0 failed, 0 errors, 3 live skips.
- 2026-10-01: T10: re-knit from a clean start. The output shows "Green." with the id, "Blue." without it, "GREEN!", and raw temperatures 0 and 0.8. All four error calls return `NA` with their message.
- 2026-10-01: T10 AC1 to AC3: purl gives 166 lines with all 10 strings. The knit has no `{r` fence and no `#> Error` line. All 9 chat blocks have a `#>` line after the last code line. The 16 code patterns and 14 prose words find 0 hits, and a plant of each matches.
- 2026-10-01: T10 AC6: `document()` gives no diff, and `check_pkgdown()` finds no problems. With the server stopped and the token unset, `devtools::check()` gives 0 errors, 0 warnings, and 0 notes.
- 2026-10-01: claim audit: 46 claims read, 1 corrected — vignettes/chat-options.Rmd.orig, vignettes/chat-options.Rmd. The checked option names read as a full list but left out `response_format` with `schema`, so the list now opens with "For example". The same reader re-read it and found that it holds.
- 2026-10-01: after the audit, a re-knit passes the T10 scans with the same live answers. All tasks done. Status set to review.
- 2026-10-01: review pass 2 started by /milestone-review. Fresh evidence for AC1 to AC6 is recorded, and the consistency gate passes. The diff reviewer is still running (checkpoint, review not finished).

## Decisions

## Review

Evidence gathered 2026-10-01 on `m074-chat-options-vignette`, level with `origin/main` (no merge needed).

- AC1: `knitr::purl()` of the source gives 136 lines, and each of the 10 strings is present. The knitted file has 0 lines that start with ```` ```{r ```` and 0 that start with `#> Error`. Of the 9 chunks that call `lms_chat(` or `lms_chat_openai(`, all 9 have a `#>` line after their last code line.
- AC2: The 16 regular expressions of the DESIGN.md code list find 0 matches in the purled code. The source holds 0 inline `` `r `` expressions. A planted `lapply(` line matches the first expression, so the search can fail.
- AC3: A case-blind search for the 14 entries of the DESIGN.md prose list finds 0 matches. It ran over the 194 of 344 source lines outside the chunks, with the YAML header and inline code. A planted list word in capitals matches, so the search can fail.
- AC4: Read in the knitted file this session. Route is explained at its first use on line 13 and request option on line 14. Response id is explained on line 51, before the table. Conversation history is explained on line 192, condition class on line 305, and raw reply on line 257. The only earlier use of raw reply is the heading on line 255, directly above that sentence.
- AC5, package claims: each of the 19 tests named in the T5 ledger exists under `tests/testthat/`, found by name. All pass in the AC6 test run.
- AC5, LM Studio claims: a live probe on this machine, with `google/gemma-3-1b`, gave the results that the vignette states. The default and native routes return a `response_id` attribute, and the openai route returns none. A follow-up by response id answered "Green.", and the same question with no id answered "Blue.". The raw `temperature` was 0 with `temperature = 0` and 0.8 with the misspelled name. Port 1 raised `rlmstudio_no_server`. The misspelled model on the native route raised `rlmstudio_api_error` with status 404 and code `model_not_found`. The misspelled option on the native route gave status 400 and code `unrecognized_keys`. The misspelled model on the default route raised `rlmstudio_model_mismatch` with `model` "google/gemma-3-1bb" and `reply_model` "google/gemma-3-1b". `previous_response_id` on the openai route raised an error. The probe stopped the server and unloaded the model at its end.
- AC6: `NEWS.md` has the entry under "rlmstudio (development version)", and it names `vignette("chat-options")`. `devtools::document()` left `git status` clean. `devtools::test()` ran 1972 tests in 49 files: 0 failed, 0 errors, 3 live skips. `pkgdown::check_pkgdown()` found no problems. With the server stopped and `RLMSTUDIO_API_TOKEN` unset, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate: `cairn_validate.py` passed, exit 0. No DESIGN.md principle changed, so `cairn_impact.py` was skipped. README is not touched. The branch adds no new top-level file.

Independent review, 2026-10-01: three fresh reviewers (diff, history, prior reviews). Findings merged across reviewers, most severe first, with the proposed disposition. The gate decides each one.

- F1 (diff 4, history 1): "The package does not check the names of request options" is false. `lms_chat()` aborts on `instructions` on the default route and `messages` on the openai route (`rlm_check_route_dots`, R/chat.R:2520), and it checks `stream` (R/utils-args.R:472). This sentence states what a package function does with an argument, and no test can back it, so AC5 fails. Proposed: fix now, by naming the checked names.
- F2 (diff 5): "sends it in the request as you wrote it" is not always true. The dots merge by `utils::modifyList()` (R/chat.R:354), which drops a `NULL` option and merges a nested list. Proposed: fix now with F1.
- F3 (diff 1, history 3): the intro, the `chat_or_na()` text, and NEWS say that one failed call does not stop a script. The function catches three classes only. A plain `rlmstudio_bad_response`, an httr2 transport error, and an argument abort still stop the loop. Proposed: fix now, by a handler for `rlmstudio_bad_response` and narrower wording.
- F4 (history 2, diff 6): the mismatch sentence holds only with one chat model loaded (D-025). With two loaded, the server sends 400 `model_not_found`. The class list also does not say that the native route never raises the mismatch. Proposed: fix now.
- F5 (diff 2): the openai part of the new log-probability test passes for any package behavior, because its mock reply has no log probabilities. Proposed: fix now, by a mock that carries them, or move the "No" cell to an LM Studio claim backed by a live call.
- F6 (prior 1): "At 0, the model takes its most likely token each time" is a model claim with no live call that shows it. Proposed: fix now, by a reworded sentence or a live call.
- F7 (prior 3): "system prompt" appears in the conversation section before its bullet explains it. Proposed: fix now.
- F8 (diff 9, history 6, prior 5): the test-file header and two vignette source lines run past the wrap. Proposed: fix now with the rest.
- F9 (prior 2): the `ttl` sentence and "a reply that it keeps" rest on `?lms_chat`, with no test or probe. The follow-up call shows that the server keeps a reply, so that part holds. The `ttl` sentence states LM Studio behavior that no live call showed. Proposed: fix now, by a pointer to `?lms_chat` in place of the claim.
- F10 (diff 3): the new route test strips the `response_id` attribute. Proposed: reject, because test-thread.R "lms_chat() returns the attribute on the two thread routes" backs the claim.
- F11 (prior 4): the native-route warning test matches message text. Proposed: reject, because the warning has no class to match.
- F12 (history 4 and 5, diff 7 and 8): `store = FALSE`, the narrow meaning of `rlmstudio_no_server`, and the return type of `logprobs = TRUE` on openai are not covered. Proposed: reject, because the vignette does not use them and the help pages state them.

Gate decision on pass 1: F1 to F9 fixed as T7 to T9, and F10 to F12 rejected for the reasons above.

Review pass 2, evidence gathered 2026-10-01 on `m074-chat-options-vignette` at 467bd71, level with `origin/main` (no merge needed). The pass-1 ticks were cleared, and each box is ticked again against its pass-2 line.

- AC1 (pass 2): `knitr::purl()` of the source gives 140 lines. Each of the 10 strings is present at least once. The knitted file has 436 lines, with 0 that start with ```` ```{r ```` and 0 that start with `#> Error`. Of the 9 blocks that call `lms_chat(` or `lms_chat_openai(`, all 9 have a `#>` line after their last code line.
- AC2 (pass 2): The 16 regular expressions of the DESIGN.md code list find 0 matches in the 140 purled lines. Planted `lapply(`, `\(z)`, and `t(m)` lines each match, so the search can fail. The source holds 0 inline `` `r `` expressions.
- AC3 (pass 2): A case-blind search for the 14 entries of the DESIGN.md prose list finds 0 matches. It ran over the 214 of 368 source lines outside the chunks, with the YAML header and inline code. A planted line with a list word in capitals matches, so the search can fail.
- AC4 (pass 2): Read in the knitted file this session, with a case-blind search for the first use of each term. Route is explained at its first use on line 13, and request option on line 14. Response id is explained on line 52, before the table on line 58. Conversation history is explained on line 199, and condition class on line 313. Raw reply is explained on line 266. Its only earlier use is the heading on line 263, three lines above.
- AC5 (pass 2), package claims: each test of the T5 ledger and of T9 exists under `tests/testthat/`, found by name. The claims that T7 and T8 added are each backed by a named test. The checked `stream` is backed by test-arg-guards.R "a stream other than FALSE or NULL aborts …() before the server probe". The checked `instructions` and `messages` are backed by test-chat-dot-clash.R "lms_chat() aborts on a dot that it passes itself". The `NULL` option and the misspelled name are backed by "lms_chat() sends a request option as written, a misspelled name included, on each route". A body that is not JSON is backed by test-chat-body-parse.R "a 200 body that does not parse raises rlmstudio_bad_response". The mismatch as a bad response is backed by test-model-check.R "lms_chat() raises the mismatch on the default route and the openai route". Its helper asserts both classes. No mismatch on native is backed by "lms_chat() on the native route returns a reply from another model with no error".
- AC5 (pass 2), the wrong-argument sentence: test-arg-guards.R exercises the abort before any request in "a bad model or job id aborts …(), named, before any request". No test asserts that this error lacks the four classes. A probe this session gave the classes `rlang_error`, `error`, and `condition` for a bad `stream` and for a two-string model.
- AC5 (pass 2), LM Studio claims: a live probe this session with `google/gemma-3-1b` gave what the vignette states. All three routes replied, and the default and native replies carried a `response_id` attribute. The raw `temperature` was 0 with `temperature = 0` and 0.8 with `temprature = 0`, in a raw reply of 31 fields. A follow-up by response id answered "Green.", and the same question with no id answered "Blue.". The `messages` data frame answered "Your favorite color is green.", and the longer one "GREEN!". Port 1 raised `rlmstudio_no_server`. The misspelled model gave 404 `model_not_found` on native and a mismatch on the default route, with `model` "google/gemma-3-1bb" and `reply_model` "google/gemma-3-1b". The misspelled option on native gave 400 `unrecognized_keys`. The probe stopped the server and unloaded the model at its end.
- AC6 (pass 2): `NEWS.md` has the entry under "rlmstudio (development version)", and it names `vignette("chat-options")`. `devtools::document()` left `git status` clean. `devtools::test()` gave 19806 expectations in 49 files, with 0 failed, 0 errors, and 3 live skips. `pkgdown::check_pkgdown()` found no problems. With the server stopped and `RLMSTUDIO_API_TOKEN` unset, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate (pass 2): `cairn_validate.py` passed, exit 0. No DESIGN.md principle changed, so `cairn_impact.py` was skipped. README is not touched, and the branch adds no top-level file. The `document()`, `check_pkgdown()`, NEWS, and `check()` items of the profile are in the AC6 line.

Independent review, pass 2, 2026-10-01: three fresh reviewers (diff, history, prior reviews). All three found F1 to F9 fixed. Findings merged across reviewers, most severe first, with the proposed disposition. The gate decides each one.

- G1 (diff 3): "A misspelled name goes to the server with no check by the package" is false for a short name. R matches it to an argument before the dots, so `sys = "x"` fills `system_prompt` and sends nothing under `sys`. Checked this session. Proposed: fix now, by narrowing the sentence to a name such as `temprature`.
- G2 (diff 8): no test shows that `lms_chat()` checks the server at its own `host`. The test-chat.R no-server tests stub the check. Proposed: fix now, by a test that calls a port with no server and expects `rlmstudio_no_server`.
- G3 (diff 1): the intro says that you catch the errors of a missing server or a failed reply. A server that stops during a request raises `httr2_failure` (R/conditions.R), which no handler catches. Proposed: fix now, by naming that case where the text says which errors still stop a loop.
- G4 (diff 2): with a `NULL` `code` field, `chat_or_na()` prints "code .", checked this session. The bullet does not say that the field can be `NULL`. Proposed: fix now, in the handler and the bullet, then re-knit.
- G5 (diff 4, prior 2): the option test is still named "as written", the wording that F2 removed. Proposed: fix now, by a rename. The nested-list merge of `utils::modifyList()` is rejected, because the vignette does not set a field that the package also sets.
- G6 (history 1, prior 4): the log-probability cell "No" on openai reads as an LM Studio limit, but it is what the package returns. Proposed: fix now, by saying that the table shows what `lms_chat()` supports.
- G7 (diff 5, history 3): the native-route test puts the other model only in `model_instance_id`, and the shared check reads `model`. Proposed: fix now, by a `model` field in the mock and a comment that names the decision.
- G8 (history 4, diff 7): the response id definition says that the server keeps the reply. With `store = FALSE` it does not. Proposed: fix now, by "by default".
- G9 (prior 1): the clean-up does not say that `lms_server_stop()` also stops a server that ran before the vignette. The text-analysis vignette says it. Proposed: fix now, by one sentence.
- G10 (diff 6, prior 7): "handler" and "attribute" are used with no explanation, and "server" appears in the intro before its explanation. Proposed: fix now. The `ttl` pointer stays, because a gloss is an LM Studio claim with no live call.
- G11 (session, AC5 evidence): no test asserts that an argument error lacks the four classes. Proposed: fix now, by one assertion in an existing guard test.
- G12 (diff 10, prior 8): the paragraph at source line 177 is wrapped short. Proposed: fix now. Long test titles are rejected, because main already has 45 such lines in that file.
- G13 (diff 9): "the fields differ from route to route" rests on the T5 live probe, not on the knit. Proposed: reject, because AC5 accepts a live call.
- G14 (history 5): if the package adds streaming, the `stream` example goes stale. Proposed: reject, because streaming is a low candidate, and that milestone updates the text.
- G15 (history 6): the new tests repeat checks of other files. Proposed: reject, because the file header states that by design.
- G16 (prior 3): the native warning test matches message text. Proposed: reject, as F11 was, because the warning has no class.
- G17 (prior 5): the last NEWS sentence has no test. Proposed: reject, because the knit shows four failed calls that return `NA`.
- G18 (prior 6): "checks a few option names" can read as a conflict with the rule that the package keeps no list of fields. Proposed: reject, because the text gives the reason for each checked name.
- G19 (prior 9): the knit shows the model ignore "Answer with one word". Proposed: reject, because no claim depends on it.
- G20 (history 7): the NEWS entry follows the form of its neighbors. Noted, no action.
