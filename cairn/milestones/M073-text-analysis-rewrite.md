# M073: The text-analysis vignette scores a data frame of texts in plain code

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M070
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — the vignette for the package's core use
- **Branch/PR:** m073-text-analysis-rewrite

## Goal

A researcher can follow `text-analysis` from a data frame of texts to new
columns of summaries, labels, scores, and similarities.

## Scope

**In:** A rewrite of `vignettes/text-analysis.Rmd.orig`, knitted by the
M070 script. It starts from a data frame with an `id` column and a `text`
column of about six short reviews. Each result goes back into that data
frame as a column. The sections cover these steps in order:

1. The quiet option.
2. A batch of summaries with `lms_chat_batch()`.
3. Labels and star ratings from a `schema`, as columns.
4. A rating scored from token probabilities for every text. A batch runs
   with `logprobs = TRUE`, and a plain `for` loop calls
   `lms_score_expected()` on each row.
5. What a failed input looks like in the result.
6. Similarity between texts from `lms_embed()`, through a short helper
   function named in the vignette.

It ends with `list_instances()` and `lms_unload_all()`. Every chat call
sets `temperature = 0`. It warns that a small model makes mistakes, with an
example from the knitted output. The code and prose follow the vignette
rules in DESIGN.md Conventions (M070). A NEWS entry.

**Out:** If the loop proves awkward, a package function that scores the
`logprobs` column of a batch in one call becomes a candidate row. Routes and
conversations are M074.

## Acceptance criteria

- [x] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/text-analysis.Rmd.orig` holds each of these strings:
      `rlmstudio.quiet`, `lms_chat_batch(`, `format = "data.frame"`,
      `schema =`, `logprobs = TRUE`, `lms_score_expected(`, `for (`,
      `lms_embed(`, `list_instances(`, and `lms_unload_all(`. In the knitted
      `vignettes/text-analysis.Rmd`, no line starts with ```` ```{r ```` or
      with `#> Error`. The block of each chunk that calls
      `lms_chat_batch(`, `lms_score_expected(`, or `lms_embed(` holds a line
      that starts with `#>` after its last code line.
- [x] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [x] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside its ```` ```{r} ````
      chunks, with the YAML header and inline code.
- [x] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      token, log probability, expected value, JSON schema, embedding, and
      cosine similarity.
- [ ] AC5: Take each prose sentence and each `#` comment line that states
      what a package function does with an argument, returns, or raises,
      beyond what its name says. A named test under `tests/testthat/`
      exercises that behavior. A sentence about what LM Studio itself does
      matches what a live call on this machine returned.
- [x] AC6: `NEWS.md` has an entry under the development-version heading
      that names the rewritten vignette. `devtools::document()` gives no
      diff, `devtools::test()` passes, and `pkgdown::check_pkgdown()`
      passes. With the server stopped and `RLMSTUDIO_API_TOKEN` unset,
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T2
- AC3 → T2, T4
- AC4 → T2, T4
- AC5 → T1, T5, T7, T9
- AC6 → T6

## Tasks

- [x] T1: Probe on this machine a data-frame batch on the default route
      with `logprobs = TRUE` and `top_logprobs`, and log the shape of its
      `logprobs` column, a failed input included. Show that
      `lms_score_expected()` scores each non-failed row.
- [x] T2: Rewrite the source to the outline in Scope. Keep each code chunk
      short, with a comment that says what it does.
- [x] T3: Knit with `data-raw/knit-vignettes.R` from a clean start. Read
      the knitted file for error lines and for the output lines of AC1.
      Check that the small-model example in the prose matches the knitted
      output, and fix the prose on each re-knit where it does not.
- [x] T4: Spawn a fresh reader with the persona of a researcher who knows
      R and wants to rate texts. It reads the knitted vignette and lists
      each step that it cannot follow and each term used before it is
      explained. Fix each item, or log why not, and re-knit.
- [x] T5: List the claims of AC5 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
- [x] T6: Add the NEWS entry and run the checks of AC6.
- [x] T7: Fix the load path. Make the vignette work, or say what to do, when
      the model is already loaded. Give the unload step before a larger
      `context_length`. Rewrite the context-length sentence to match the
      live probe in the Review section. Back each new claim with a test or
      a probe.
- [ ] T8: Fix the other prose findings that the Review section marks T8,
      re-knit from a clean start, and re-run the AC1 to AC4 checks.
- [ ] T9: Nest the two flat loops of `test-vignette-claims.R` one
      `test_that()` per pass, and add a direct test that a successful
      `lms_server_stop()` sends `server stop`.

## Work log

- 2026-09-30: created by /milestone-plan.
- 2026-09-30: M070 review handed one finding (F15) to this rewrite. The vignette now ends with a plain `lms_unload_all()`, which also unloads models that the reader loaded before. M068 had kept those models. The prose gives no warning.
- 2026-10-01: implement started on branch m073-text-analysis-rewrite.
- 2026-10-01: question gate. A long review fails because the model loads with `context_length = 1024`. The similarity column compares each review to one query sentence. The long review stays in every step.
- 2026-10-01: T1 probe, gemma-3-1b, OpenResponses route, data-frame batch with `logprobs = TRUE` and `top_logprobs = 10`. Columns: input, output, logprobs, response_id, and three token counts. The `logprobs` column is a list. Each scored row holds a data frame of 20 rows with `step_token`, `step_logprob`, `candidate_token`, `candidate_logprob`, and `step`. A text of about 1,800 tokens under a 1,024-token context failed alone with `NA` output, `NULL` logprobs, and one warning. Its condition was `rlmstudio_api_error`, status 500, "tokens to keep ... greater than the context length". `lms_score_expected()` scored each of the 3 other rows. Default context is 8192, and the embedding model's is 2048 and embedded the long text.
- 2026-10-01: T2 source rewritten to the Scope outline, with six reviews, a `for` loop for scores, and a `cosine_similarity()` helper. Purled code holds the 10 AC1 strings, and the AC2 patterns, inline R, and AC3 words find no match.
- 2026-10-01: T3 knitted 3 times from a clean start, with the same output each time. No chunk header or `#> Error` line. The 6 chunks that call the batch, score, or embed functions each end with `#>` lines. A plant that removes them turns the check red. New prose names what the output shows. Examples are the reply "3\n", the `**` summary, and the 5 stars of "Terrible". Others are a score below 2 beside 5 stars, and the review closest to the query. Dropped a claim that a new run gives the same replies, because the T1 scores differed from the knit.
- 2026-10-01: T4 fresh Opus reader (researcher persona) listed 21 steps and 9 unexplained terms. Fixed: a wrong claim that a schema batch puts `NA` in `output`, where it holds the error. Also fixed: `api_type = "openai"`, schema keywords, and "how sure", which no output showed. Glossed: step, server, load, request, reply columns, `**`, 768 columns, and the similarity baseline. Also fixed: a wrong section pointer, model instance, `llm`, model key, and the server stop. Re-knit gave the same output lines.
- 2026-10-01: T4 items not fixed. Tokens per character, a good `context_length`, its default, memory cost, and how to reload with a larger one are machine-dependent or unprobed. The blank candidate's identity is unverified. Which measure to prefer is the researcher's call. A successful list element, JSON itself, and condition class names stay out to keep the steps short.
- 2026-10-01: T5 ledger, part 1 (file:line of `test_that`). Quiet hides load messages: vignette-claims:19. Quiet hides the batch bar: flag-args:502. The failed-input warning shows past quiet: chat-schema:646. `wait` waits up to its budget: serve:225, serve:264, serve:346. `context_length` is sent: load:11.
- 2026-10-01: T5 ledger, part 2. One request per text, same system prompt, rows in order, `output`: vignette-claims:43, vignette-claims:242. Id and token columns: chat-batch:947. A schema needs `"openai"`: arg-guards:559. One column per field, string and integer types: chat-schema:825, chat-schema:897. The openai route asks the given host: new vignette-claims test.
- 2026-10-01: T5 ledger, part 3. The logprobs column of data frames with `step` from 1, and `top_logprobs` sent: new vignette-claims test. Score reads step 1, keeps the scale, sums "3" and " 3", rescales: score:137, score:44, score:75. A failed input does not stop the batch, gives `NA` and `NULL`, and one warning: chat-batch:98, chat-batch:183. A schema `output` keeps the error: new vignette-claims test. List format: chat-batch:98.
- 2026-10-01: T5 ledger, part 4. `lms_embed()` rows in order: embed:129. `list_instances()` rows and config columns: list-instances:62, list-instances:170. `lms_unload_all()` unloads each instance: unload:165. `lms_unload()` by id: unload:16. LM Studio claims rest on the knitted output: the top candidate, the 10 candidates, the context-length error, and the 2048 embedding context.
- 2026-10-01: T5 added 3 tests to `test-vignette-claims.R`. Plants in a scratch `R/chat.R` turned each red on its own expectation: dropped dots failed `top_logprobs`, a fixed host failed the host check, and a failure slot of `NA` failed the condition check. Suite: 1953 tests, 0 failed, 3 live skips.
- 2026-10-01: T6 rewrote the existing development NEWS entry for `vignette("text-analysis")`, which was never released, in place of a second entry. `document()` gave no diff, and `check_pkgdown()` found no problems. With the server stopped and the token unset, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- 2026-10-01: claim audit: 74 claims read, 7 corrected — vignettes/text-analysis.Rmd.orig, vignettes/text-analysis.Rmd, tests/testthat/test-vignette-claims.R
- 2026-10-01: the 7 corrections. Prose: the `input` column, the embedding cut without warning, the unbacked "comes with LM Studio", the package label in the error, and the list that `lms_score_expected()` returns. Tests: a 400 mock on the openai route, and a test name. The same reader re-read all 7 as OK. Re-knit gave the same output lines, and the suite gave 1953 tests with 0 failed.
- 2026-10-01: status set to review.
- 2026-10-01: review returned the milestone, defect return 1. AC5 failed: a live probe gave a 299-token reply under a 128-token context, against the vignette sentence "your prompt and its reply together". Review send-back added T7 to T9 for the fix-now findings in the Review section, and mapped AC5 to T7 and T9. Status set to in-progress.
- 2026-10-01: rewrapped the AC3 line breaks with no change of words. A line that started with a four-backtick code span made `cairn_validate` read an open code fence, and count the rest of the file against the plan cap.
- 2026-10-01: implement resumed after the return. Question gate: for a model that is already loaded, the prose says what to do, and no code unloads it. The summary chunk calls `trimws()`.
- 2026-10-01: T7 rewrote the context-length sentence to "the most tokens that a prompt to it can hold". It added an unload-first paragraph before the load chunk. It gave the unload step before a larger `context_length`. Backing: long-prompts:127 (no load request for a loaded model), unload:16, and load:11. A live probe loaded at 512. A second load at 1024 left 512, and an unload and a load gave 1024.

## Decisions

## Review

- AC1 (2026-10-01, fresh): `knitr::purl()` of the source gives 165 lines, and each of the 10 strings is present. In the knitted file, no line starts with an unknitted chunk header. No line starts with `#> Error`. Six chunks call `lms_chat_batch(`, `lms_score_expected(`, or `lms_embed(`, at knitted lines 110, 163, 230, 284, 327, and 363. Each has a `#>` line after its last code line. A copy with the `#>` lines removed turned all 6 red.
- AC2 (2026-10-01, fresh): each of the 16 regular expressions of the DESIGN.md code list matched 0 of the 165 purled lines. A search of the source for `` `r `` found 0 lines. Planted `lapply(` and `\(x)` lines matched their patterns.
- AC3 (2026-10-01, fresh): the source has 376 lines and 13 chunks, with 13 openers and 13 closers. The 197 lines outside the chunks include the YAML header and the inline code. A case-blind search for each of the 14 entries of the DESIGN.md prose list matched 0 of them. A planted line with a capitalized list entry matched.
- AC4 (2026-10-01, fresh read of the knitted file): a case-blind search found the first use of each term, and the defining sentence is at that line. Token: line 43, "a short piece of text". JSON schema: line 147, "a description of the fields". Log probability: line 218, "the natural log of that probability". Expected value: line 276, "the average of the numbers, each weighted by its probability". Embedding: line 350, "a list of numbers that stands for the meaning". Cosine similarity: line 355, "measures how close two embeddings are". The only earlier match of any term is the model key at line 19. That key is an identifier, and the line says the model turns text into numbers.
- AC5 (2026-10-01, fresh): the 23 `file:line` references of the T5 ledger were read in the current tree. 21 land on a `test_that()` header whose name states the claimed behavior. `arg-guards:559` lands inside the generated test of line 557, "a schema on a route other than openai aborts". `vignette-claims:242` drifted after T5 added tests, and the claim it backed (system prompt with each input, replies in order) is now at line 355. A re-read of the knitted prose found 2 claims that the ledger does not name. For `lms_score_expected()` returning a list with `expected_value`, `test-score.R` asserts `res$expected_value` at lines 15, 37, 56, 96, and 132. For `lms_server_stop()` stopping a server that ran before, `vignette-claims:557` asserts that `server stop` is sent with no condition. That test calls `lms_daemon_stop(force = TRUE)`, which reaches `lms_server_stop()` through `R/daemon.R:133`, so the backing is indirect. The LM Studio claims match the knitted output (top candidate `3`, the context-length error text, the 2,048 embedding context). `devtools::test()`: 19,764 expectations, 0 failed, 0 errors, 3 live skips.
- AC6 (2026-10-01, fresh): `NEWS.md` has an entry under "rlmstudio (development version)" that names `vignette("text-analysis")` and describes the rewrite. `devtools::document()` left `git status` with no change outside this file. `devtools::test()` passed, as AC5 records. `pkgdown::check_pkgdown()` found no problems. `lms server status` said the server was not running, and no model was loaded. With `RLMSTUDIO_API_TOKEN` unset, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- Consistency gate (2026-10-01): `cairn_validate.py` passed with exit 0, coverage complete included. `DESIGN.md` has no change on the branch, so `cairn_impact` was skipped. Toolchain checks: `document()` gave no diff, `check_pkgdown()` and `check()` passed (AC6), and NEWS has the entry (AC6). The branch does not touch README.Rmd, README.md, or any generated file, and it adds no top-level file.
- AC5 failed after the independent review (2026-10-01): a live probe checked a sentence in "Start the server and load the model". It says the context length is the most tokens the model holds at once, "your prompt and its reply together". `google/gemma-3-1b` was loaded with `context_length = 128`. It took a 28-token prompt and gave a 299-token reply, with `max_output_tokens = 300`. Without the cap, the reply ran past 6 minutes before the probe was stopped. The box is unticked.
- Other live probes of the same session: the sixth review fits in the 2,048-token embedding context, because a sentence added at its end changed its embedding. A 400-sentence text was cut with no warning, because the same sentence did not change its embedding. A second `lms_load(model, context_length = 1024)` left the loaded model at 128.
- Review lenses: D is the diff-bug lens (Opus), B the blame-history lens (Sonnet), and P the prior-review lens (Sonnet). P's GitHub probe found no review comments. Each finding is listed with its proposed disposition, for the maintainer to triage at the next gate.
- Fix now, T7: D1 and D3. If `google/gemma-3-1b` is already loaded, `lms_load()` keeps its context length and says nothing under quiet. The failure demo then breaks, and `lms_unload(model)` unloads the reader's own instance. Probe 3 shows the no-op.
- Fix now, T7: D2 and B3. "Load the model with a larger `context_length`" does nothing for a loaded model. The reader must unload it first.
- Fix now, T7: P4. The context-length sentence is the AC5 failure above.
- Fix now, T8: B1 and P2. The logprobs section does not say that the batch must stay on the default route. On the `"openai"` route the cells are `NULL`, and the loop skips every row.
- Fix now, T8: D5, B5, and P3. The embedding paragraph does not say whether the sixth review was cut. Probe 1 shows that it fits, and that a longer text is cut.
- Fix now, T8: D4. "`trimws()` removes the line break" names a call that no chunk makes, and the tables keep the break.
- Fix now, T8: D9. "Step" is used at source line 105 and defined at line 198. "The server" and "loads" are used before their glosses.
- Fix now, T8: D15. Source lines 100 and 193 are not rewrapped.
- Fix now, T9: P1. The new loops at `test-vignette-claims.R:183` and `:220` are flat, and `cairn/tools/loop-sweep.R` lists both as flat.
- Fix now, T9: D8. No direct test shows that a successful `lms_server_stop()` sends `server stop`.
- Follow-up: D6 and D7. The score loop stops on a row with no candidate in `scale` or with zero rows. The rescale hides how much probability fell off the scale. Proposed as a candidate row for a function that scores the `logprobs` column of a batch, the Scope Out item.
- Reject: B2, the score prose leaves out the M069 step rules and other return fields. The plan asked for short steps, and the prose is accurate.
- Reject: B4, `lms_unload(model)` names one model. The sentence says "each one", and T7 rewrites it.
- Reject: B6, "each field" in place of "top-level property". The schema has only top-level fields.
- Reject: B7, the knit ships `#> Warning` lines. No defect today, and the knit-warning candidate can read it.
- Reject: B8, the `lms_server_ready()` call is gone. No claim depends on it.
- Reject: B9, a `lms_chat()` logprobs test backs no sentence now. It still backs package behavior.
- Reject: D10, the warning says `NA` while the `logprobs` cell is `NULL`. The message is package text from before this branch.
- Reject: D11, the warning names condition classes. T4 chose to leave them out.
- Reject: D12, `context_length` is a server config column. The knitted output shows it.
- Reject: D13, the embeddings use no nomic task prefixes. The baseline sentence says "here".
- Reject: D14, the new mocks are simpler than real replies. The tests assert the claimed behavior and failed on plants.
- Reject: D16, the server enforces "must be" in the schema. The sentence describes what the schema asks.
- Reject: D17, the blank candidate is not explained. T4 logged this.
- Reject: P4 part 2, the temperature 0 sentence. The knitted top candidate `3` is the reply.
- Reject: P5, "up to about 30 seconds". The serve tests back it.
- Reject: P6, the quiet prose names one warning. The article "a" keeps it true.
- Reject: P7, `list_models()` is named before `library()`. It is a mention, not a step to run.
- Reject: P8, `$` on a condition object. The partial-match risk is for parsed JSON.
