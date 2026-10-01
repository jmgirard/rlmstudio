# M071: The getting-started vignette reads plainly and covers a first run

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M070
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — the first vignette that a new user reads
- **Branch/PR:** m071-getting-started-rewrite

## Goal

A researcher who knows R but has not run a local model can follow
`getting-started` from installing LM Studio to a first batch of replies.

## Scope

**In:** A rewrite of `vignettes/getting-started.Rmd.orig`, knitted by the
M070 script. It speaks to the reader as "you". Each section says what the
step is for before its code. It covers: what LM Studio and a local model
are, a check that LM Studio is there (`has_lms()`, `check_lms_version()`),
starting the server and checking that it answers, finding models
(`list_models()`), downloading one, loading it, one chat with a system
prompt, a small batch with `lms_chat_batch()`, and cleaning up. One short
paragraph points users without the desktop app to `headless-config`. The
code and prose follow the vignette rules in DESIGN.md Conventions (M070). A
NEWS entry.

**Out:** Headless and remote use is M072. Batch scoring, structured output,
and embeddings are M073. Routes, conversations, and errors are M074.

## Acceptance criteria

- [ ] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/getting-started.Rmd.orig` holds each of these strings:
      `has_lms(`, `check_lms_version(`, `lms_server_start(`,
      `lms_server_ready(`, `list_models(`, `lms_download(`, `lms_load(`,
      `lms_chat(`, `system_prompt =`, `lms_chat_batch(`, `lms_unload(`, and
      `lms_server_stop(`. The source holds the text `headless-config`. In
      the knitted `vignettes/getting-started.Rmd`, no line starts with
      ```` ```{r ```` or with `#> Error`. The block of each chunk that calls
      `list_models(`, `lms_chat(`, or `lms_chat_batch(` holds a line that
      starts with `#>` after its last code line.
- [ ] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [ ] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside its
      ```` ```{r} ```` chunks, with the YAML header and inline code.
- [ ] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      large language model, local server, model key, loading a model,
      system prompt, and batch.
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

- [x] T1: Probe the live calls that the outline needs, on this machine, and
      log what each returns: `check_lms_version()`, `list_models()`, and a
      three-input `lms_chat_batch()` on `google/gemma-3-1b`.
- [x] T2: Rewrite the source to the outline in Scope. Keep each code chunk
      short, with a comment that says what it does.
- [x] T3: Knit with `data-raw/knit-vignettes.R` from a clean start. Read
      the knitted file for error lines and for the output lines of AC1.
- [x] T4: Spawn a fresh reader with the persona of a researcher who knows
      R and has not used a language model API. It reads the knitted
      vignette and lists each step that it cannot follow and each term used
      before it is explained. Fix each item, or log why not, and re-knit.
- [ ] T5: List the claims of AC5 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
- [ ] T6: Add the NEWS entry and run the checks of AC6.

## Work log

- 2026-09-30: created by /milestone-plan.
- 2026-09-30: M070 review handed one finding (F8) to this rewrite. The knit ran with the model on disk, so the download chunk shows "already downloaded" and no download job, next to prose about a download.
- 2026-09-30: implement started on branch m071-getting-started-rewrite. Gate answered (see Decisions).
- 2026-09-30: T1 probe, live, gemma-3-1b on disk: `check_lms_version()` TRUE with the "modern architecture (0.4.0+)" message. `lms_server_ready()` FALSE before start and after stop, TRUE after start. `list_models()` gave 5 models, columns state, type, display_name, key, architecture, size_gb. `lms_download()` gave "already_downloaded", and `lms_download_status()` of it gave status "already_downloaded", job_id "N/A". A three-input `lms_chat_batch()` gave 3 strings, one per input.
- 2026-09-30: T2 source rewritten to the Scope outline. The AC1 to AC3 search script finds every AC1 string, no code-list match, and no prose-list match. Run on the old source, it finds `repeat` and 4 prose words.
- 2026-09-30: T3 knitted from a clean start (server stopped, no model loaded). The knit has no chunk header and no error line. The list_models, lms_chat, and lms_chat_batch blocks each end in output lines. A `trimws()` line was added after the batch, because the replies carry trailing spaces and line breaks.
- 2026-09-30: T4 fresh Opus reader (R user, no LLM background) found each of the six AC4 terms explained at or before first prose use. It listed 6 hard steps and 8 unexplained terms. Fixed: prompt, command-line tool and CLI, localhost, the type and state columns, a new install with no models, job id, a model that does not follow its system prompt, headless and remote. Not fixed: the status word for a finished download (no live download job in this knit, per the gate, so AC5 bars naming it), why to restart R, and "port" (in output only). Re-knitted clean.

## Decisions

- 2026-09-30 (gate): The model stays on disk for the knit. The download text says that `lms_download()` returns "already_downloaded" for a model on disk and a job id for a new download. The knitted output shows the first case. This answers finding F8.
- 2026-09-30 (gate): The vignette shows no loop that waits for a download. The text tells the reader to call `lms_download_status()` with the job id until the download ends.

## Review
