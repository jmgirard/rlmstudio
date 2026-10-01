# M071: The getting-started vignette reads plainly and covers a first run

- **Status:** review
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

- [x] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/getting-started.Rmd.orig` holds each of these strings:
      `has_lms(`, `check_lms_version(`, `lms_server_start(`,
      `lms_server_ready(`, `list_models(`, `lms_download(`, `lms_load(`,
      `lms_chat(`, `system_prompt =`, `lms_chat_batch(`, `lms_unload(`, and
      `lms_server_stop(`. The source holds the text `headless-config`. In
      the knitted `vignettes/getting-started.Rmd`, no line starts with
      ```` ```{r ```` or with `#> Error`. The block of each chunk that calls
      `list_models(`, `lms_chat(`, or `lms_chat_batch(` holds a line that
      starts with `#>` after its last code line.
- [x] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [x] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside its
      ```` ```{r} ```` chunks, with the YAML header and inline code.
- [x] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      large language model, local server, model key, loading a model,
      system prompt, and batch.
- [x] AC5: Take each prose sentence and each `#` comment line that states
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
- [x] T5: List the claims of AC5 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
- [x] T6: Add the NEWS entry and run the checks of AC6.

## Work log

- 2026-09-30: created by /milestone-plan.
- 2026-09-30: M070 review handed one finding (F8) to this rewrite. The knit ran with the model on disk, so the download chunk shows "already downloaded" and no download job, next to prose about a download.
- 2026-09-30: implement started on branch m071-getting-started-rewrite. Gate answered (see Decisions).
- 2026-09-30: T1 probe, live, gemma-3-1b on disk: `check_lms_version()` TRUE with the "modern architecture (0.4.0+)" message. `lms_server_ready()` FALSE before start and after stop, TRUE after start. `list_models()` gave 5 models, columns state, type, display_name, key, architecture, size_gb. `lms_download()` gave "already_downloaded", and `lms_download_status()` of it gave status "already_downloaded", job_id "N/A". A three-input `lms_chat_batch()` gave 3 strings, one per input.
- 2026-09-30: T2 source rewritten to the Scope outline. The AC1 to AC3 search script finds every AC1 string, no code-list match, and no prose-list match. Run on the old source, it finds `repeat` and 4 prose words.
- 2026-09-30: T3 knitted from a clean start (server stopped, no model loaded). The knit has no chunk header and no error line. The list_models, lms_chat, and lms_chat_batch blocks each end in output lines. A `trimws()` line was added after the batch, because the replies carry trailing spaces and line breaks.
- 2026-09-30: T4 fresh Opus reader (R user, no LLM background) found each of the six AC4 terms explained at or before first prose use. It listed 6 hard steps and 8 unexplained terms. Fixed: prompt, CLI, localhost, the type and state columns, a new install with no models, and job id. Also fixed: a model that ignores its system prompt, and headless. Not fixed: the status word for a finished download, because the knit has no live download job and AC5 bars a claim with no live check. Also not fixed: why to restart R, and "port", which shows in output only. Re-knitted clean.
- 2026-09-30: T5 added 6 tests to `test-vignette-claims.R`. With `>=` changed to `>` in `check_lms_version()`, the version test failed. With the download URL changed, the browser test failed. Code restored. `devtools::test()`: 0 fail, 3 skip, 19801 pass.
- 2026-09-30: T5 fix: `lms_server_start()` docs say the `wait` limit is not hard, so the prose says "about", and "a few seconds" became "does not answer at once". Re-knitted clean.
- 2026-09-30: ledger 1: `install_lmstudio(method = "browser")` opens the download page. Test: "install_lmstudio() with the browser method opens the download page" (new).
- 2026-09-30: ledger 2: when R finds lms, `has_lms()` is TRUE. Tests: "has_lms is TRUE when lms sits on the PATH", "has_lms is FALSE when no lookup finds the CLI".
- 2026-09-30: ledger 3: `check_lms_version()` is TRUE for 0.4.0 or later. Test: "check_lms_version() is TRUE from version 0.4.0 and FALSE below it" (new).
- 2026-09-30: ledger 4: requests go to localhost:1234 by default. Ledger 8: `list_models()` gives one row per model with a key column. Test: "list_models() asks localhost:1234 by default and gives one row per model" (new).
- 2026-09-30: ledger 5: `lms_server_start()` waits about `wait` seconds. Tests: "wait_for_server starts no request after the budget passes", "lms_server_start returns quietly once the server answers".
- 2026-09-30: ledger 6: a wait that runs out warns, and the script goes on. Test: "lms_server_start warns rather than aborts when the wait runs out".
- 2026-09-30: ledger 7: `lms_server_ready()` is TRUE only when LM Studio answers. Tests: "a 200 whose body carries a model list is ready", "a port held by something else passes the TCP probe and fails here", "a closed port is not ready".
- 2026-09-30: ledger 9: `lms_download()` gives "already_downloaded" or a job id. Test: "a download reply that passes the rules returns the job id or already_downloaded".
- 2026-09-30: ledger 10: `lms_download_status()` of "already_downloaded" reports that status. Test: "lms_download_status() of already_downloaded reports that status and sends no request" (new).
- 2026-09-30: ledger 11: `lms_chat()` sends `input` and `system_prompt` and returns the reply text. Test: "lms_chat() sends the input and the system prompt and returns the reply text" (new).
- 2026-09-30: ledger 12: `lms_chat_batch()` sends each input alone with the same system prompt, replies in order. Tests: "lms_chat_batch() sends the system prompt with each input and returns the replies in order" (new), "lms_chat_batch() sends each input as its own request, one row each".
- 2026-09-30: ledger 13, LM Studio: the model list holds models on disk, with state "unloaded" before a load and "loaded" after it. Gemma is type llm, and Nomic is type embedding. Live: T1 probe.
- 2026-09-30: ledger 14, LM Studio: the server does not answer at once. Backed by the `lms_server_start()` docs, which say the CLI returns before the REST API answers. Live: T1 gave `lms_server_ready()` FALSE before the start.
- 2026-09-30: ledger 15, LM Studio: a model on disk gives "already_downloaded". Live: T1 probe and each knit.
- 2026-09-30: ledger 16, model: a reply does not always follow the system prompt. Live: the first T3 knit asked for one word and got "Apple" with an emoji.
- 2026-09-30: T6 NEWS entry added. `devtools::document()` gave no diff. `pkgdown::check_pkgdown()` found no problems. With the server stopped and the token unset, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-30: claim audit: 42 claims read, 2 corrected — vignettes/getting-started.Rmd.orig, vignettes/getting-started.Rmd
- 2026-09-30: claim audit detail: "reads before your prompt" became "gets with your prompt", which the re-read found holds. The batch caution now says that a reply can carry extra spaces, which holds. Its clause that a model does not always follow its system prompt rests on ledger 16 alone, and the re-read found no support for it in the files. Re-knitted clean.
- 2026-09-30: status set to review.
- 2026-09-30: review return 1 (defect): AC5 failed. In 3 of 3 live runs, the server answered at once after `lms server start`, against the vignette sentence "The server does not answer at once". A live chat to an unloaded model loaded it and replied. The vignette sentence "A model must be loaded before it can answer" is not in the ledger. AC1 to AC4 passed. AC6, the gate, and the reviewers did not run. Status set to in-progress.
- 2026-09-30: resumed on the branch after review return 1. The default branch had not moved.
- 2026-09-30: return fix 1: the start text now says that `lms_server_start()` starts the server and then waits for an answer from LM Studio. It makes no claim about the time that LM Studio takes to answer. Ledger 5 backs it. This supersedes ledger 14.
- 2026-09-30: return fix 2: "A model must be loaded before it can answer" is gone. The new text says that a chat with an unloaded model can make LM Studio load it. Then the chat waits for the load.
- 2026-09-30: ledger 17, LM Studio: a chat with an unloaded model can load it, and the chat waits for the load. Live probe: `lms_server_ready()` was TRUE 0.004 s after the start returned. `lms_chat()` to an unloaded `google/gemma-3-1b` took 5.14 s and left it loaded, and a second chat took 0.18 s.
- 2026-09-30: re-knitted clean: 0 chunk headers, 0 error lines. The AC2 search found 0 code hits and 0 inline R, with 3 of 3 hits on planted lines. The AC3 search found 0 prose hits over 116 of 193 lines. `devtools::test()`, run twice: 0 fail, 3 skip, 19690 pass. No file under R/ or tests/ changed since T5, which gave 19801.
- 2026-09-30: the `lms_server_start()` help makes the same claim as the removed sentence. It is out of scope, so a candidate row in ROADMAP holds it.
- 2026-09-30: claim audit: 54 claims read, 1 corrected — vignettes/getting-started.Rmd.orig, vignettes/getting-started.Rmd
- 2026-09-30: claim audit detail: "On a new install, you have no models yet" was wrong. LM Studio ships an embedding model in `~/.lmstudio/.internal/bundled-models/`. The text now says that a new install has no model to chat with, and it names the embedding model. The re-read passed each of its 3 sentences with live calls. The reader also ran the start, chat, load, and batch claims live, and each matched. Re-knitted clean.
- 2026-09-30: the server was stopped and the token unset. `devtools::document()` gave no diff, and `pkgdown::check_pkgdown()` found no problems. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-30: status set to review.
- 2026-09-30: review: the 10 lines above went under the Review section by mistake. They moved here unchanged.

## Decisions

- 2026-09-30 (gate): The model stays on disk for the knit. The download text says that `lms_download()` returns "already_downloaded" for a model on disk and a job id for a new download. The knitted output shows the first case. This answers finding F8.
- 2026-09-30 (gate): The vignette shows no loop that waits for a download. The text tells the reader to call `lms_download_status()` with the job id until the download ends.

## Review

- AC1 (2026-09-30): `knitr::purl()` of the source gave 66 lines, and `grep -F` found each of the 12 strings at least once. The source holds `headless-config` once. The knitted file has 0 lines that start with ```` ```{r ```` and 0 that start with `#> Error`. An awk pass over the knitted blocks found a `#>` line after the last code line in the `list_models(`, `lms_chat(`, and `lms_chat_batch(` blocks.
- AC2 (2026-09-30): An R script searched the 66 purled lines for each of the 16 DESIGN.md code patterns and found 0 matches. As a control, 3 planted lines (`lapply(`, `repeat`, `\(x)`) gave 3 matches. A search of the source for `` `r `` found 0 matches.
- AC3 (2026-09-30): The same script kept the 115 of 192 source lines outside the ```` ```{r} ```` chunks, with the YAML header among them. A case-blind search for each of the 14 DESIGN.md prose entries found 0 matches. As a control, a planted line that started with a prose-list word in capitals gave 1 match.
- AC4 (2026-09-30): A `grep` of the knitted file, output lines left out, found the first use of each term. "large language model" first shows at line 12, in the sentence that explains it. "local server" first shows at line 48, and the next sentence of line 48 explains it. The heading at line 46 says "the server" before that. "model key" first shows at line 72, in the sentence that explains it. The first use of "load" is "Load the package" at line 27, which is about the R package. The first use for a model is line 138, in the sentence that explains it. "system prompt" first shows at line 155, and "batch" at line 175, each in the sentence that explains it.
- AC5 (2026-09-30), FAIL: Each of the 16 tests that the ledger names exists under `tests/testthat/`. Live calls on this machine matched the ledger for the model list, the `already_downloaded` reply, and the extra spaces in batch replies. Live calls did not match the sentence "The server does not answer at once" (knitted line 53). In 3 of 3 runs, `lms server start` returned in about 0.16 s, and `lms_server_ready()` was TRUE in its first call, 0.02 s or less later. Ledger 14 backed that sentence with the docs and a FALSE before the start, not with a live call after the start. Also, "A model must be loaded before it can answer" (line 139) is not in the ledger. A live `lms_chat()` to an unloaded `google/gemma-3-1b` returned a reply, and the model state went from "unloaded" to "loaded" with a 60-minute idle limit. So when a chat names an unloaded model, LM Studio loads it, and the vignette does not say so. LM Studio was left with the server stopped and no model loaded.
- AC1 (2026-09-30, pass 2): `knitr::purl()` of the source at 82055dc gave 86 lines. A fixed-string search found each of the 12 strings, `system_prompt =` twice and the others once. The source holds `headless-config` once. The knitted file has 0 lines that start with ```` ```{r ```` and 0 that start with `#> Error`. An R script split the knitted code blocks. It found a `#>` line after the last code line in the blocks at lines 80 (`list_models(`), 163 (`lms_chat(`), and 184 (`lms_chat_batch(`). A planted block with no output after its last code line read FALSE.
- AC2 (2026-09-30, pass 2): An R script searched the 86 purled lines for each of the 16 DESIGN.md code patterns and found 0 matches. As a control, 3 planted lines (`lapply(`, `repeat`, `\(x)`) gave 3 matches. A search of the source for `` `r `` found 0 matches.
- AC3 (2026-09-30, pass 2): The script kept the 118 of 195 source lines outside the ```` ```{r} ```` chunks, with the YAML header (lines 1 to 8) among them. Whole lines were searched, so inline code is in the domain. A case-blind search for each of the 14 DESIGN.md prose entries found 0 matches. As a control, a planted line with 3 prose-list words in capitals gave 3 matches.
- AC4 (2026-09-30, pass 2): A `grep` of the knitted file, `#>` lines left out, found the first use of each term. "large language model" first shows at line 12, in the sentence that explains it. The word "server" first shows in the heading at line 46. "local server" first shows at line 48, and the next sentence explains it. "model key" first shows at line 72, in the sentence that explains it. The first "load" is "Load the package" at line 27, which is about the R package. The first use for a model is line 140, in the sentence that explains it. "system prompt" first shows at line 158, and "batch" at line 178, each in the sentence that explains it.
- AC5 (2026-09-30, pass 2): Each of the 16 tests that the work-log ledger names exists by exact name. They sit in 5 files: `test-vignette-claims.R`, `test-setup.R`, `test-serve.R`, `test-server-ready.R`, and `test-load-download-shape.R`. Those 5 files ran with 0 failures, 0 errors, and 1443 passes. The ledger has a named test for each package claim of the source. One live run on this machine checked each LM Studio sentence. It started with the server stopped and no model loaded. `lms` sits at `~/.lmstudio/bin/lms`. `lms_server_start(wait = 30)` returned in 0.489 s with `lms_server_ready()` TRUE. `list_models()` gave the same 5 keys as `lms ls --json`, all "unloaded", with types "llm" and "embedding". The one bundled model file is the Nomic embedding model. A chat with it raised `rlmstudio_api_error`, and an embedding of "hello" gave a 1 x 768 matrix. `lms_download()` gave "already_downloaded". A chat with the unloaded gemma-3-1b took 6.586 s and left it "loaded", and a second chat took 0.231 s. `lms_load()` took 4.538 s and left it "loaded". With "Answer in one short sentence.", 4 of 5 replies held two sentences. With "Answer with one word.", 1 of 3 batches gave "Apple 🍎". In 2 of 3 batches, a reply held extra spaces or line breaks. `lms_unload()` left the model "unloaded", and `lms_server_ready()` was FALSE after the stop.
