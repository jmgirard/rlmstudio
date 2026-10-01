# M068: A vignette shows batch chat, structured output, logprobs scores, and embeddings

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — a vignette that package users read
- **Branch/PR:** m068-text-analysis-vignette

## Goal

A new vignette shows the text-analysis features that the two current
vignettes leave out, built live against LM Studio as they are.

## Scope

**In:** A new `vignettes/text-analysis.Rmd`. It shows `lms_chat_batch()` with
`format = "data.frame"`. It shows a `schema` whose properties become columns
of a data-frame batch on `api_type = "openai"`. It shows `lms_chat()` with
`logprobs = TRUE`, scored by `lms_score_expected()`. It also shows
`lms_embed()`, `list_instances()`, `lms_unload_all()`, and the
`rlmstudio.quiet` option. The chat model is `google/gemma-3-1b`, as in the
other two vignettes. The embedding model is
`text-embedding-nomic-embed-text-v1.5`, which LM Studio bundles. The build
follows the pattern of `getting-started.Rmd`: chunks behind gates, the
observed output pasted as `#>` comments, and a teardown that keeps the state
it found (M055). If the build found no model loaded, `lms_unload_all()` runs.
A NEWS entry.

**Out:** A `previous_response_id` thread example stays as the existing note
in `getting-started.Rmd`. The two current vignettes keep their content. A
headless-host run of the teardown stays in the `lms daemon up` candidate row.

## Acceptance criteria

- [x] AC1: The R code that `devtools::build()` writes for the vignette,
      `inst/doc/text-analysis.R` in the built tarball, contains each of
      these strings: `lms_chat_batch(`,
      `format = "data.frame"`, `schema =`, `api_type = "openai"`,
      `logprobs = TRUE`, `lms_score_expected(`, `lms_embed(`,
      `list_instances(`, `lms_unload_all(`, and `rlmstudio.quiet`. Take a
      live render on this machine that starts with the server stopped and no
      model loaded. The chunk option `comment` is set to a marker that the
      source does not contain. Take each chunk that calls
      `lms_chat_batch()`, `lms_score_expected()`, `lms_embed()`,
      `list_instances()`, or `lms_unload_all()`. In that render, it shows at
      least one output line with that marker. The logprobs chunk calls `lms_chat()` on the
      default route with `top_logprobs`, `temperature = 0`, and a prompt
      that asks for one digit.
- [x] AC2: A live build keeps the state it found. On this macOS host, where
      the LM Studio desktop app runs the daemon, a render of the vignette
      leaves two things as they were before the render. One is the `running`
      field of `lms server status --json`. The other is the set of loaded
      instance ids in `lms ps --json`. This holds for two starting states.
      In state (a), the server is stopped and no model is loaded. In state
      (b), the server runs with `google/gemma-3-1b` loaded. The prose of the
      vignette about its teardown claims no starting state other than these
      two.
- [x] AC3: Take each prose sentence of the vignette, and each `#` comment
      line in a chunk, that states what a package function does, takes, or
      returns. A named test under `tests/testthat/` exercises the behavior
      that it states. The domain is every prose sentence and every comment
      line, read one at a time. Where no test exercises a stated behavior,
      the milestone adds a test. The test checks each case that the
      sentence names, such as each property type, route, or format.
- [x] AC4: `NEWS.md` has an entry under the development-version heading. It
      names the new vignette and each of the seven features of AC1:
      the data-frame batch, schema columns, logprobs scored by
      `lms_score_expected()`, `lms_embed()`, `list_instances()`,
      `lms_unload_all()`, and the `rlmstudio.quiet` option.
- [x] AC5: `devtools::document()` gives no diff, `devtools::test()` passes,
      and `pkgdown::check_pkgdown()` passes. `devtools::check()` with
      `RLMSTUDIO_API_TOKEN` set gives 0 errors and 0 warnings on this
      machine, with the vignette built live from starting state (a) of AC2.

## Coverage

- AC1 → T1, T2, T3, T4
- AC2 → T2, T4
- AC3 → T5
- AC4 → T6
- AC5 → T7

## Tasks

- [x] T1: Probe the live server. Call `lms_download()` for the bundled
      `text-embedding-nomic-embed-text-v1.5`, and `lms_embed()` on it. Call
      `lms_chat()` on `google/gemma-3-1b` over the default route with
      `logprobs = TRUE`, `top_logprobs`, `temperature = 0`, and a one-digit
      prompt. Show that `lms_score_expected()` returns a list for that
      reply. Run a schema data-frame batch over `api_type = "openai"`. Log
      what each call returned. If a call fails, change the vignette's gates
      before T2.
- [x] T2: Write `vignettes/text-analysis.Rmd` on the pattern of
      `getting-started.Rmd`. Use the gates `lms_installed` and `lms_ready`,
      and an embedding gate. Hidden chunks record the server state and the
      loaded instance ids before the build. Sections cover the quiet option,
      the data-frame batch, schema columns, logprobs scored by
      `lms_score_expected()`, embeddings, and `list_instances()`. The
      vignette sets `rlmstudio.quiet` back to its old value before the
      teardown.
- [x] T3: Write the teardown. If the build found no model loaded,
      `lms_unload_all()` runs. If not, the build unloads each instance in
      the after-build list that is not in the before-build list. The prose
      names the condition for the `lms_unload_all()` chunk. If the build
      started the server, the build stops it.
- [x] T4: Render live in both starting states of AC2. Log the `running`
      field and the instance ids before and after each render. Run the
      build-tangle check and the marker render of AC1. Paste the observed
      output into the `#>` comments of the chunks, so that a site built
      without LM Studio still shows output.
- [x] T5: Read the vignette prose and chunk comments one sentence at a time.
      In the work log, list each behavior sentence with the test that
      exercises it. Where none does, add a test, and log a change to package
      code that makes the test fail.
- [x] T6: Add the NEWS entry.
- [x] T7: Run `devtools::document()`, `devtools::test()`,
      `pkgdown::check_pkgdown()`, and `devtools::check()` with the token
      set.

## Work log

- 2026-09-30: created by /milestone-plan.
- 2026-09-30: criteria audit (full mode, fresh Opus reader) returned 11 findings on AC1 to AC5. Each had one clear repair, fixed before the gate. AC1 got a purl name check, a comment marker for live output, and a fixed logprobs chunk. AC2 got instance ids, a teardown diff, and a bounded teardown claim. AC3 got chunk comments and failing plants for added tests. AC4 got named features, and AC5 got a named build state.
- 2026-09-30: plan gate chose a gated live `lms_unload_all()` over never running it, because a live run checks the call and keeps the M055 state rule; falsified by a build that unloads a model it found loaded.
- 2026-09-30: plan gate chose a live build with pasted `#>` output over a precomputed `.Rmd.orig` vignette, because it matches the two current vignettes; falsified by a reader or CRAN check that the doubled output or the live LM Studio need blocks.
- 2026-09-30: plan gate added `lms_score_expected()` beside logprobs and left threads as the `getting-started.Rmd` note, because scoring is the package's core workflow; falsified by a user who needs a thread example to use `previous_response_id`.
- 2026-09-30: implement started on branch m068-text-analysis-vignette. Question gate skipped, because the plan left no choice open.
- 2026-09-30: T1 live probe on LM Studio. `lms_download("text-embedding-nomic-embed-text-v1.5")` failed with "Invalid model name format", and the model was already listed by `list_models(type = "embedding")`. So the embedding gate reads that list and the vignette does not download it. `lms_embed()` on 3 texts returned a 3 x 768 matrix and loaded the model on demand. `lms_chat()` with logprobs on the default route returned an `lms_chat_result`, and `lms_score_expected()` returned a list with expected value 3.21. The data-frame batch returned 6 columns. The schema batch on the openai route added `sentiment` (character) and `rating` (integer). `lms_unload_all()` unloaded both instances, and the state ended as it started.
- 2026-09-30: T2 and T3 wrote `vignettes/text-analysis.Rmd`. Minor amendment: a fourth gate, `chat_ready`, says that `google/gemma-3-1b` is on disk, beside the embedding gate `embed_ready`. The hidden state chunks read instance ids from `list_models(loaded = TRUE, detailed = TRUE)`, so that every chunk that calls `list_instances()` shows output. The vignette loads the embedding model with `lms_load()`, so the teardown does not rely on a load on demand. The schema chunk gave 5 stars to "Terrible. Never again." in two renders, and the prose says so after the output. (This line first landed under `## Review` in commit 5d651c3 and was moved here.)
- 2026-09-30: T4 renders of the committed vignette. State (b): before `running=True ids=['google/gemma-3-1b']`, after the same. State (a): before `running=False ids=[]`, after the same. The marker render from state (a) showed `#M68#` lines in all 6 chunks that call the five AC1 functions. A copy without the marker lines of the score chunk failed the same check. A bare `knitr::purl()` in a fresh session drops each chunk whose `eval` names a gate ("object 'chat_ready' not found"). Its output held 1 of the 10 AC1 strings. `getting-started.Rmd` behaves the same. The `inst/doc/text-analysis.R` that `devtools::build()` wrote holds all 10. The build also left state (a) as it found it. T4 stays open on the AC1 purl wording.
- 2026-09-30: T5 ledger, setup and intro. Comment "the CLI is on this machine": test-setup.R "has_lms is TRUE when lms sits on the PATH" and "has_lms is FALSE when no lookup finds the CLI". Comment "the REST API answered": test-server-ready.R "a 200 whose body carries a model list is ready". Comment "on disk": test-list.R "list_models returns a formatted data frame". The intro sentences map to the section tests below.
- 2026-09-30: T5 ledger, quiet and batch. "`lms_load()` prints messages", "the option hides both" (load half): new test-vignette-claims.R "lms_load() prints its messages, and the quiet option hides them". Progress bar half: test-flag-args.R "quiet of lms_chat_batch() starts or skips its progress bar". "The warning about failed inputs still shows": test-chat-schema.R "the failed reply warning ignores quiet". "Sends each input as its own request", "one row per input": new "lms_chat_batch() sends each input as its own request, one row each". "Input, output, id, three token counts": test-chat-batch-usage.R "a data-frame batch adds the id and token counts of each reply".
- 2026-09-30: T5 ledger, schema and logprobs. "A `schema` goes to the server": test-chat-schema.R "a schema is sent as the documented response_format" and "lms_chat() forwards a schema on the openai route". "One column per top-level property": "a schema data frame adds one column per property after the reply columns". "String gives character, integer gives integer": "a property column's type follows the property type". The `lms_chat()` logprobs object, "if the reply carries them", "lists the candidate tokens at each step", and "fields go into the request body": new "lms_chat() on the default route sends the dots and lists the candidates".
- 2026-09-30: T5 ledger, score, embed, instances, teardown. The four `lms_score_expected()` sentences: new "lms_score_expected() reads the first step, keeps the scale, and rescales", beside test-score.R. "One row per input text, in the order given": test-embed.R "three inputs answered in order give three rows in order" and "three inputs answered out of order are placed by index". `list_instances()`: test-list-instances.R "list_instances returns one row per loaded instance of a listed type" and "each configuration field gets a column, in order of first appearance". "`lms_unload_all()` unloads every loaded model instance" and its chunk comment: test-unload.R "lms_unload_all unloads each reported instance in order and forwards dots". Sentences about the model, LM Studio, or this vignette's own build are not about a package function.
- 2026-09-30: T5 narrowed four vignette sentences to what the code does. The quiet paragraph names `lms_load()` and the batch bar. For a reply with log probabilities, the logprobs object holds a frame, and plain text otherwise. The frame lists candidates at each step. `lms_score_expected()` reads the rows whose `step_token` equals that of the first row. Eight plants each turned a new test red and were restored: progress step ignores quiet, batch sends the first input every time, openresponses drops the dots, logprobs frame keeps one step. The score plants were no rescale, a number outside `scale` kept, every step read, and entropy in nats.
- 2026-09-30: T6 added the NEWS entry under the development-version heading. It names the vignette and the seven AC4 features.
- 2026-09-30: amendment at the mini gate, chosen by the user. AC1's first sentence now reads the `inst/doc/text-analysis.R` that `devtools::build()` writes. Before, it read a bare `knitr::purl()`, which drops the gated chunks. The chunk headers keep the pattern of the other two vignettes.
- re-audit: AC1 (full) — nothing. The reader found both halves reachable, and the string check passes in a build without LM Studio as commented code, with the marker render covering live output.
- 2026-09-30: T4 closed under the amended AC1. Its task text now names the build-tangle check, a minor edit.
- 2026-09-30: T7 checks. `devtools::document()` gave no diff. `pkgdown::check_pkgdown()` found no problems. `devtools::test()` gave 0 failed, 0 errors, and 3 live tests skipped with the server stopped. `devtools::check()` with `RLMSTUDIO_API_TOKEN` set gave 0 errors, 0 warnings, and 0 notes. It started from state (a), and `lms server status --json` and `lms ps --json` read the same before and after.
- claim audit: 66 claims read, 1 corrected — tests/testthat/test-vignette-claims.R
- 2026-09-30: the claim audit (fresh Opus reader) changed a score-test comment from "the row" to "the rows" whose step token is "3". It listed three claims that the repo cannot check: that LM Studio ships the nomic embedding model, and two general sentences about small models. T1 saw the model on disk with no download on this machine. Status set to review.

## Decisions

## Review

Evidence gathered 2026-09-30 on branch head b1455de, which contains `origin/main` (491e3a2).

- AC1: `devtools::build()` from state (a) wrote a tarball whose `inst/doc/text-analysis.R` holds each of the 10 strings (1 or 2 times each). A live `knitr::knit()` ran from state (a) on a copy with `comment = "#M68#"`. All 6 chunks that call the five functions showed marker lines: batch 11, schema batch 4, score 7, embed 6, instances 3, unload-all 8. The source holds no `#M68#`. The logprobs chunk calls `lms_chat()` with no `api_type`, so it takes the default route. It sets `top_logprobs = 10` and `temperature = 0`, and its prompt says "Answer with one digit only." State read `running=False ids=[]` before and after each run.
- AC2: state (a), the `devtools::build()` render above: `running=False ids=[]` before and after. State (b), a live `rmarkdown::render()` of the committed vignette: `running=True ids=['google/gemma-3-1b']` before and after. That render loaded the embedding model, and its unload-new chunk unloaded it. The teardown paragraph names only these two starting states.
- AC3: the T5 ledger names 20 tests. Each exists by its exact name in the file that the ledger names. The review read the vignette sentence by sentence again and found no behavior sentence outside the ledger. The four new tests in `test-vignette-claims.R` check each case that their sentences name. They read the load messages and the quiet option, three requests and three rows, the sent dots and the candidates, and the four score fields with rescaling. All four pass in the AC5 test run.
- AC4: the first entry under `# rlmstudio (development version)` names `vignette("text-analysis")` and the seven features. They are the `format = "data.frame"` batch, schema properties that become columns, `logprobs = TRUE` scored by `lms_score_expected()`, `lms_embed()`, `list_instances()`, `lms_unload_all()`, and `rlmstudio.quiet`. It names no milestone.
- AC5: `devtools::document()` gave no diff. `devtools::test()` gave 0 failed, 0 errors, 3 skipped (live tests, server stopped), and 19615 passed. `pkgdown::check_pkgdown()` found no problems. `devtools::check()` with `RLMSTUDIO_API_TOKEN` set gave 0 errors, 0 warnings, and 0 notes. It started from state (a) and read `running=False ids=[]` before and after.
- Consistency gate: `cairn_validate.py` passed (exit 0). No DESIGN principle changed, so `cairn_impact` was skipped. The branch does not touch README files or add top-level files. The NEWS entry is AC4. The document, pkgdown, and check results are AC5.

Independent review: three fresh reviewers (Opus diff, Sonnet history, Sonnet prior review). The prior-review probe of GitHub PR comments returned none, so that lens read the archive and LESSONS. Findings, merged where two lenses agree, with the triage proposed at the gate:

- F1 (diff 1), fix now: the embed chunk uses `reviews`, which only the chat-gated batch chunk defines. With the embedding model on disk and `google/gemma-3-1b` absent, the build stops with "object 'reviews' not found" and skips the teardown.
- F2 (diff 2), fix now: the instances chunk runs on `lms_ready` alone. With nothing loaded, `list_instances()` returns four columns, and the `context_length` selection fails before the teardown.
- F3 (diff 5), fix now: the schema prose does not say that a schema needs `api_type = "openai"`. Other routes abort, tested in `test-arg-guards.R` "a schema on a route other than openai aborts".
- F4 (history 3), fix now: the logprobs prose does not name the default route. On the native and OpenAI routes, `lms_chat()` returns no logprobs frame.
- F5 (prior 2, history 1), fix now: the teardown prose drops the host condition that the other two vignettes carry since M055.
- F6 (diff 6), fix now: the `models-before` comment says the teardown unloads only what the build loaded. The `lms_unload_all()` branch unloads every instance.
- F7 (diff 7, history 4), fix now: the quiet prose names one warning that shows past the option. Others also do.
- F8 (diff 4, history 6, name part), fix now: the score test name says "reads the first step", but the test counts a later step with the same token.
- F9 (diff 10), fix now: the quiet case of the `lms_load()` claim test does not check that both requests ran.
- F10 (prior 5, history 7), fix now: the logprobs claim test reads body fields with `$` and pins `10L` and `0L` after a jsonlite parse. Read them with `[[` and `expect_equal()`.
- F11 (diff 12), fix now: the T1 work-log line says the embedding gate reads `list_models(type = "embedding")`. The vignette reads `list_models()`. Corrected by a new work-log line.
- F12 (diff 3, prior 6), follow-up: if an earlier chunk fails, the teardown of a vignette does not run. A new candidate row covers the three vignettes.
- F13 (diff 4, history 6, behavior part), follow-up: `lms_score_expected()` counts candidates from any later step whose token equals the first step token. This code predates the branch. A new candidate row.
- F14 (prior 1), follow-up: the new vignette copies the server-status read of the M055 finding O2 row. That row is extended to name the third vignette.
- F15 (history 2, LESSONS part), follow-up: LESSONS line 27 says "both vignettes". The hygiene pass corrects it.
- F16 (history 1, third state), reject: a build that finds the server stopped and a model loaded takes the unload-new branch and stops the server, which keeps that state. AC2 bounds the prose to two states.
- F17 (diff 8), reject: the claim audit listed the bundled-model sentence. T1 found the model on disk with no download, and `embed_ready` covers its absence.
- F18 (diff 9), reject: the plan gate chose the pasted `#>` output with a live build.
- F19 (diff 11), reject: the review evidence lands in the step-6 checkpoint commit.
- F20 (prior 3), reject: the vignette sends the reader to `vignette("getting-started")` for the server start, and that vignette has the readiness paragraph.
- F21 (prior 4), reject: the logprobs-less case claims the text alone, not the reply id.
- F22 (history 2, NEWS part), reject: the older NEWS entry "teardown of both vignettes" describes its own change, which was true then.
- F23 (history 5), reject: input truncation in `lms_embed()` is outside this vignette's scope. Its help page documents it.
- F24 (history 8), reject: the work log records the `loaded_ids()` helper as a deliberate choice.
