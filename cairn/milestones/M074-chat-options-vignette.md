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
- [ ] T2: Write the source to the outline in Scope. Keep each code chunk
      short, with a comment that says what it does. Add the source to the
      list that `data-raw/knit-vignettes.R` knits.
- [ ] T3: Knit with `data-raw/knit-vignettes.R` from a clean start. Read
      the knitted file for error lines and for the output lines of AC1.
- [ ] T4: Spawn a fresh reader with the persona of a researcher who knows
      R and has run `getting-started`. It reads the knitted vignette and
      lists each step that it cannot follow and each term used before it is
      explained. Fix each item, or log why not, and re-knit.
- [ ] T5: List the claims of AC5 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
- [ ] T6: Add the NEWS entry and run the checks of AC6.

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

## Decisions

## Review
