# M073: The text-analysis vignette scores a data frame of texts in plain code

- **Status:** review
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

- [ ] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/text-analysis.Rmd.orig` holds each of these strings:
      `rlmstudio.quiet`, `lms_chat_batch(`, `format = "data.frame"`,
      `schema =`, `logprobs = TRUE`, `lms_score_expected(`, `for (`,
      `lms_embed(`, `list_instances(`, and `lms_unload_all(`. In the knitted
      `vignettes/text-analysis.Rmd`, no line starts with ```` ```{r ```` or
      with `#> Error`. The block of each chunk that calls
      `lms_chat_batch(`, `lms_score_expected(`, or `lms_embed(` holds a line
      that starts with `#>` after its last code line.
- [ ] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [ ] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside its
      ```` ```{r} ```` chunks, with the YAML header and inline code.
- [ ] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      token, log probability, expected value, JSON schema, embedding, and
      cosine similarity.
- [ ] AC5: Take each prose sentence and each `#` comment line that states
      what a package function does with an argument, returns, or raises,
      beyond what its name says. A named test under `tests/testthat/`
      exercises that behavior. A sentence about what LM Studio itself does
      matches what a live call on this machine returned.
- [ ] AC6: `NEWS.md` has an entry under the development-version heading
      that names the rewritten vignette. `devtools::document()` gives no
      diff, `devtools::test()` passes, and `pkgdown::check_pkgdown()`
      passes. With the server stopped and `RLMSTUDIO_API_TOKEN` unset,
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T2
- AC3 → T2, T4
- AC4 → T2, T4
- AC5 → T1, T5
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

## Decisions

## Review
