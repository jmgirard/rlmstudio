# M068: A vignette shows batch chat, structured output, logprobs scores, and embeddings

- **Status:** in-progress
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

- [ ] AC1: `knitr::purl()` of `vignettes/text-analysis.Rmd` gives R code that
      contains each of these strings: `lms_chat_batch(`,
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
- [ ] AC2: A live build keeps the state it found. On this macOS host, where
      the LM Studio desktop app runs the daemon, a render of the vignette
      leaves two things as they were before the render. One is the `running`
      field of `lms server status --json`. The other is the set of loaded
      instance ids in `lms ps --json`. This holds for two starting states.
      In state (a), the server is stopped and no model is loaded. In state
      (b), the server runs with `google/gemma-3-1b` loaded. The prose of the
      vignette about its teardown claims no starting state other than these
      two.
- [ ] AC3: Take each prose sentence of the vignette, and each `#` comment
      line in a chunk, that states what a package function does, takes, or
      returns. A named test under `tests/testthat/` exercises the behavior
      that it states. The domain is every prose sentence and every comment
      line, read one at a time. Where no test exercises a stated behavior,
      the milestone adds a test. The test checks each case that the
      sentence names, such as each property type, route, or format.
- [ ] AC4: `NEWS.md` has an entry under the development-version heading. It
      names the new vignette and each of the seven features of AC1:
      the data-frame batch, schema columns, logprobs scored by
      `lms_score_expected()`, `lms_embed()`, `list_instances()`,
      `lms_unload_all()`, and the `rlmstudio.quiet` option.
- [ ] AC5: `devtools::document()` gives no diff, `devtools::test()` passes,
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
- [ ] T4: Render live in both starting states of AC2. Log the `running`
      field and the instance ids before and after each render. Run the
      `knitr::purl()` check and the marker render of AC1. Paste the observed
      output into the `#>` comments of the chunks, so that a site built
      without LM Studio still shows output.
- [x] T5: Read the vignette prose and chunk comments one sentence at a time.
      In the work log, list each behavior sentence with the test that
      exercises it. Where none does, add a test, and log a change to package
      code that makes the test fail.
- [ ] T6: Add the NEWS entry.
- [ ] T7: Run `devtools::document()`, `devtools::test()`,
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

## Decisions

## Review
