# M073: The text-analysis vignette scores a data frame of texts in plain code

- **Status:** planned
- **Priority:** normal
- **Depends on:** M070
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — the vignette for the package's core use
- **Branch/PR:** —

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

- [ ] T1: Probe on this machine a data-frame batch on the default route
      with `logprobs = TRUE` and `top_logprobs`, and log the shape of its
      `logprobs` column, a failed input included. Show that
      `lms_score_expected()` scores each non-failed row.
- [ ] T2: Rewrite the source to the outline in Scope. Keep each code chunk
      short, with a comment that says what it does.
- [ ] T3: Knit with `data-raw/knit-vignettes.R` from a clean start. Read
      the knitted file for error lines and for the output lines of AC1.
      Check that the small-model example in the prose matches the knitted
      output, and fix the prose on each re-knit where it does not.
- [ ] T4: Spawn a fresh reader with the persona of a researcher who knows
      R and wants to rate texts. It reads the knitted vignette and lists
      each step that it cannot follow and each term used before it is
      explained. Fix each item, or log why not, and re-knit.
- [ ] T5: List the claims of AC5 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
- [ ] T6: Add the NEWS entry and run the checks of AC6.

## Work log

- 2026-09-30: created by /milestone-plan.

## Decisions

## Review
