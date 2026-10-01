# M074: A vignette shows chat options, conversations, and errors in scripts

- **Status:** in-progress
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

- [ ] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/chat-options.Rmd.orig` holds each of these strings:
      `api_type = "native"`, `api_type = "openai"`, `temperature =`,
      `previous_response_id =`, `lms_chat_openai(`, `messages =`,
      `simplify = FALSE`, `tryCatch(`, `rlmstudio_no_server`, and
      `rlmstudio_api_error`. In the knitted `vignettes/chat-options.Rmd`,
      no line starts with ```` ```{r ```` or with `#> Error`. The block of
      each chunk that calls `lms_chat(` or `lms_chat_openai(` holds a line
      that starts with `#>` after its last code line.
- [ ] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [ ] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside its
      ```` ```{r} ```` chunks, with the YAML header and inline code.
- [ ] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      route, request option, response id, conversation history, raw reply,
      and condition class.
- [ ] AC5: Take each prose sentence and each `#` comment line that states
      what a package function does with an argument, returns, or raises,
      beyond what its name says. A named test under `tests/testthat/`
      exercises that behavior. A sentence about what LM Studio itself does
      matches what a live call on this machine returned.
- [ ] AC6: `NEWS.md` has an entry under the development-version heading
      that names the new vignette. `devtools::document()` gives no diff,
      `devtools::test()` passes, and `pkgdown::check_pkgdown()` passes.
      With the server stopped and `RLMSTUDIO_API_TOKEN` unset,
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T2
- AC3 → T2, T4
- AC4 → T2, T4
- AC5 → T1, T5
- AC6 → T6

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

## Decisions

## Review
