# M070: The vignettes are knitted ahead of time from a live LM Studio

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — the vignettes that package users read
- **Branch/PR:** m070-knit-ahead-vignettes

## Goal

Each vignette ships with output that the author knitted ahead of time from a
live LM Studio, so a package check and a CRAN build never reach LM Studio.

## Scope

**In:** Each of the three vignettes moves to a source file
`vignettes/<name>.Rmd.orig`. A script, `data-raw/knit-vignettes.R`, knits
each source to `vignettes/<name>.Rmd` against the local LM Studio. It takes
the source paths as arguments and knits all sources when it gets none. If
the server answers or a model is loaded, it stops before it knits anything.
It sets the chunk option `error = FALSE`, so a chunk error stops the knit.
It stops the server and unloads every model in a `finally` clause, so a
chunk that fails leaves nothing behind. The script starts from a clean
state. So the sources lose the hidden state chunks of M055, the `eval`
gates, the pasted `#>` output, and each paragraph about what the build
does. The `.Rbuildignore` excludes the sources. DESIGN.md Conventions gets
the vignette rules: the knit-ahead build, no inline R expressions, and the
two lists below, copied verbatim. It also gets the prose register: the
prose speaks to the reader as "you", says what a step is for before its
code, and explains each term at its first use.

Code list. The R code of a vignette uses none of these regular expressions:
`\blapply\(`, `\bsapply\(`, `\bvapply\(`, `\bmapply\(`, `\bMap\(`,
`\bReduce\(`, `\bFilter\(`, `\bdo\.call\(`, `\bunlist\(`, `\bsetdiff\(`,
`\brepeat\b`, `\bsuppressWarnings\(`, `\binvisible\(`, `%\*%`, `\bt\(`,
and `\\\(`.

Prose list. The prose of a vignette uses none of these words or phrases,
ignoring case: `seamless`, `robust`, `simply`, `powerful`, `excellent`,
`shines`, `spin up`, `delve`, `comprehensive`, `leverage`, `best practice`,
`worth noting`, `vignette is built`, `the build`.

**Out:** The prose and code rewrite of each vignette to these rules is M071
(getting-started), M072 (headless-config), and M073 (text-analysis). The new
chat vignette is M074. Apart from the cuts named above, M070 changes no prose.

## Acceptance criteria

- [ ] AC1: For each of `getting-started`, `headless-config`, and
      `text-analysis`, `vignettes/<name>.Rmd.orig` exists. A search of
      `vignettes/<name>.Rmd` finds no line that starts with ```` ```{r ````
      and no line that starts with `#> Error`.
- [ ] AC2: Start on this machine with the LM Studio server stopped, no
      model loaded, and `RLMSTUDIO_API_TOKEN` unset. Then
      `devtools::check()` gives 0 errors and 0 warnings. The server is
      still stopped after it.
- [ ] AC3: `data-raw/knit-vignettes.R`, run on this machine, behaves as
      follows in three cases. (a) The server runs at start. The script
      stops with a message that names the running server. (b) The server
      is stopped and a model is loaded at start. The script stops with a
      message that names the model. In (a) and (b), no `vignettes/*.Rmd`
      file changes (`git status`). (c) It gets a scratch source in which
      one chunk calls `stop()`. The script exits with a non-zero status and
      a message that names the chunk. It writes no `.Rmd` for that source.
      It ends with the server stopped and no model listed by
      `lms ps --json`.
- [ ] AC4: A search of the three `.Rmd.orig` sources finds no line that
      starts with `#>` and none of the phrases `vignette is built` or
      `the build`, ignoring case. The tarball that `R CMD build` writes
      holds no file whose name ends in `.Rmd.orig` (`tar -tzf`).
- [ ] AC5: `devtools::document()` gives no diff, `devtools::test()` passes,
      and `pkgdown::check_pkgdown()` passes.

## Coverage

- AC1 → T2, T3
- AC2 → T3, T5
- AC3 → T1
- AC4 → T2, T4
- AC5 → T5

## Tasks

- [x] T1: Write `data-raw/knit-vignettes.R`. It reads the token from
      `RLMSTUDIO_API_TOKEN`, checks the clean start with
      `lms_server_ready()` and `lms ps --json`, knits each source with
      `knitr::knit()` and `error = FALSE`, and tears down in the `finally`
      clause of a `tryCatch()`. LESSONS M017 says that `on.exit()` never
      runs at the top level of `Rscript`. Run the three cases of AC3.
- [x] T2: Move each vignette to its `.Rmd.orig` source. Delete the hidden
      state chunks, the `eval` gates, the pasted `#>` comments, and the
      paragraphs about the build. In `text-analysis`, merge the
      `unload-all` and `unload-new` chunks into one `lms_unload_all()`
      chunk, without their comments about the build. Keep every other line.
- [x] T3: Run the script from a clean start. Read each knitted `.Rmd` for
      error lines and for output under each chunk that printed some.
- [x] T4: Add `^vignettes/.*\.Rmd\.orig$` to `.Rbuildignore`. Copy the
      vignette rules into DESIGN.md Conventions. Correct LESSONS M009,
      which says a check reads the local LM Studio state. Narrow the
      candidate row on the two hazards of a live vignette build to what the
      script still has.
- [ ] T5: Stop the server, unset the token, and run `devtools::check()`.
      Run `devtools::document()`, `devtools::test()`, and
      `pkgdown::check_pkgdown()`.

## Work log

- 2026-09-30: created by /milestone-plan.
- 2026-09-30: criteria audit (full mode, fresh Opus reader) over M070 to M074 returned 13 findings. All were fixed before the gate: a `#>` line in place of an output block, `error = FALSE` in the knit script, a model-loaded clean-start case, no `#> Error` or live chunk in a knitted file, `\[\[` and the inline `function(` rule dropped from the code list, a closed-port no-server example, prose defined as every line outside chunks, a narrowed claims criterion, terms counted in prose or comments, and an M072 criterion for its IP1 and IP2 statements.
- 2026-09-30: plan gate chose a knit-ahead build over the live build of M068 and the state chunks of M055, because checks then never reach LM Studio and the source reads like the page; falsified by a CRAN or pkgdown build that cannot use the knitted `.Rmd`, or by knitted output that goes stale between releases.
- 2026-09-30: plan gate chose plain base R with a banned-pattern list over dplyr in Suggests, because it needs no dependency change; falsified by a rewrite that needs a banned pattern to stay readable, or by reader-pass reports that the base R code is hard to follow.
- 2026-09-30: plan gate chose four vignettes (three rewrites and a new chat-options vignette) over a separate scoring vignette and over merging getting-started with headless-config; falsified by a reader pass that finds text-analysis too long to follow, or headless-config too thin to stand alone.
- 2026-09-30: plan gate chose a plain, conversational prose register over strict Simple English; falsified by reader-pass reports of sentences too long or terms not explained.
- 2026-09-30: T1 done. `data-raw/knit-vignettes.R` checks the clean start with `lms server status --json` as well as `lms_server_ready()`, because a token-guarded server with no token set reads as not ready. It knits to a temp file and copies on success. AC3 runs: (a) server running, exit 1 naming the server; (b) `google/gemma-3-1b` loaded, exit 1 naming it; (c) a scratch source that started the server, loaded the model (seen in `lms ps --json` inside the failing chunk), then called `stop()`: exit 1 naming chunk `boom`, no `.Rmd` written, server stopped, `lms ps --json` empty.
- 2026-09-30: T2 done. The three vignettes moved to `.Rmd.orig` by `git mv`. The gate variables, hidden state chunks, `eval` gates, pasted `#>` lines, and build paragraphs went. With `lms_ready` gone, the two `lms_ready <- lms_server_ready()` chunks print `lms_server_ready()` directly. The text-analysis teardown is one `lms_unload_all()` chunk. The hidden download-wait chunks stay for M071 and M072.
- 2026-09-30: T3 done. From a clean start (server stopped, `lms ps --json` empty), the script knitted all three sources, exit 0, and ended clean. The knitted `.Rmd` files hold no ```` ```{r ```` line and no `Error` or `Warning` text. Each chunk that printed shows `#>` lines. The text-analysis schema batch again gave 5 stars to "Terrible. Never again.", so its prose still matches.
- 2026-09-30: T4 done. `.Rbuildignore` excludes `^vignettes/.*\.Rmd\.orig$`. DESIGN Conventions has three vignette bullets: the knit-ahead build, the prose register and word list, and the code list, both lists verbatim from Scope. LESSONS M009 corrected in place. The live-build hazards row narrowed to the `lms_server_status(json = TRUE)` stderr parse: the vignettes no longer call it, and the script's `finally` teardown ends the failed-chunk hazard.

## Decisions

## Review
