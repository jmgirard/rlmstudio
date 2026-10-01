# M070: The vignettes are knitted ahead of time from a live LM Studio

- **Status:** review
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

- [x] AC1: For each of `getting-started`, `headless-config`, and
      `text-analysis`, `vignettes/<name>.Rmd.orig` exists. A search of
      `vignettes/<name>.Rmd` finds no line that starts with ```` ```{r ````
      and no line that starts with `#> Error`.
- [x] AC2: Start on this machine with the LM Studio server stopped, no
      model loaded, and `RLMSTUDIO_API_TOKEN` unset. Then
      `devtools::check()` gives 0 errors and 0 warnings. The server is
      still stopped after it.
- [x] AC3: `data-raw/knit-vignettes.R`, run on this machine, behaves as
      follows in three cases. (a) The server runs at start. The script
      stops with a message that names the running server. (b) The server
      is stopped and a model is loaded at start. The script stops with a
      message that names the model. In (a) and (b), no `vignettes/*.Rmd`
      file changes (`git status`). (c) It gets a scratch source in which
      one chunk calls `stop()`. The script exits with a non-zero status and
      a message that names the chunk. It writes no `.Rmd` for that source.
      It ends with the server stopped and no model listed by
      `lms ps --json`.
- [x] AC4: A search of the three `.Rmd.orig` sources finds no line that
      starts with `#>` and none of the phrases `vignette is built` or
      `the build`, ignoring case. The tarball that `R CMD build` writes
      holds no file whose name ends in `.Rmd.orig` (`tar -tzf`).
- [x] AC5: `devtools::document()` gives no diff, `devtools::test()` passes,
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
- [x] T5: Stop the server, unset the token, and run `devtools::check()`.
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
- 2026-09-30: T5 done. With the server stopped, no model loaded, and `RLMSTUDIO_API_TOKEN` unset (`env -u`), `devtools::check()` gave 0 errors, 0 warnings, 0 notes, and the server stayed stopped. The `pkgbuild::build()` tarball lists no `.Rmd.orig`. `devtools::document()` left no diff, `pkgdown::check_pkgdown()` found no problems, and `devtools::test()` gave 0 failed, 0 errors, 3 skipped.
- 2026-09-30: claim audit: 96 claims read, 3 corrected — data-raw/knit-vignettes.R (the `loaded_models()` comment; the header on later sources after a failed chunk), vignettes/headless-config.Rmd.orig and .Rmd (cut a sentence that named the removed `lms_ready` value). The same reader re-read all three, and all hold. `%||%` was replaced by an `is.null()` fallback for R before 4.4. Two findings on carried-over headless prose went to the M072 work log. headless-config re-knitted from a clean start, exit 0, and the AC3 (b) case re-ran with the new `loaded_models()`.
- 2026-09-30: all tasks done. Status set to review.

## Decisions

## Review

Review run 2026-09-30 on `m070-knit-ahead-vignettes` at 6335a55. `origin/main` did not move after the branch was cut.

- AC1: all three `vignettes/<name>.Rmd.orig` sources exist. `grep -c` finds 0 lines starting with ```` ```{r ```` and 0 starting with `#> Error` in each knitted `.Rmd`. The same chunk search over the sources finds 10, 13, and 14 chunks, so the pattern matches when chunks are present.
- AC2: the start state was `lms server status --json` with `running` false, `lms ps --json` empty, and no `RLMSTUDIO_API_TOKEN` in the environment. `env -u RLMSTUDIO_API_TOKEN Rscript -e 'devtools::check()'` gave 0 errors, 0 warnings, 0 notes, with the vignette rebuild OK. After the check, the server status still read `running` false and `lms ps --json` was empty.
- AC3: (a) After `lms server start`, `Rscript data-raw/knit-vignettes.R` exited 1. Its message began "The LM Studio server is running." (b) The server was stopped and `lms ps --json` listed `google/gemma-3-1b`. The script exited 1 with "A model is loaded: google/gemma-3-1b." In (a) and (b), `git status --short vignettes/` was empty. (c) A scratch source outside the repo had a chunk `boom`. That chunk started the server, loaded `google/gemma-3-1b` (listed by `lms ps --json` inside the chunk), and called `stop("planted failure")`. The script exited 1 with "The chunk 'boom' of <path> failed: planted failure". It wrote no `scratch.Rmd`. After it, the server status read `running` false and `lms ps --json` was empty.
- AC4: `grep -c '^#>'` finds 0 lines in each of the three `.Rmd.orig` sources, against 21, 72, and 47 in the knitted `.Rmd` files. A case-blind search for `vignette is built` or `the build` finds 0 lines in each source. `R CMD build` of the branch exited 0. `tar -tzf` of `rlmstudio_0.2.2.9000.tar.gz` lists 0 files ending in `.Rmd.orig` and lists the three `vignettes/<name>.Rmd` files.
- AC5: `devtools::document()` left `git status` showing only this milestone file, so it gave no diff. `devtools::test()` gave 0 failed, 0 errors, 3 skipped, and 19671 passed expectations. `pkgdown::check_pkgdown()` printed "No problems found."

Consistency gate:

- `cairn_validate.py` exited 0, all checks passed. No DESIGN principle changed (the DESIGN diff adds three Conventions bullets), so `cairn_impact.py` did not run.
- `devtools::document()` gave no diff (AC5). `pkgdown::check_pkgdown()` passed (AC5). `devtools::check()` gave 0 errors, 0 warnings, 0 notes (AC2).
- README: the branch does not touch `README.Rmd` or `README.md`.
- `.Rbuildignore`: the one new path type, `vignettes/*.Rmd.orig`, has an entry. `data-raw/` was already excluded.
- NEWS.md: the branch adds no entry. No exported function changed. The readers of the two released vignettes see the same examples with knitted output, without the paragraphs about the build. The gate judged this not to need an entry, and the approval gate shows this judgment.

Independent review: three fresh reviewers (Opus diff-bug, Sonnet blame-history, Sonnet prior-review). The PR-comment probe returned no comments. No finding shows an acceptance criterion failing. Findings merged across lenses, with the proposed disposition (decided at the approval gate):

- F1 (diff-bug 1, blame 1): NEWS.md:69 and NEWS.md:214, two development-version entries, say two things that M070 removes. First, a vignette skips its REST examples at a server that does not answer. Second, the build restores the server and model state. Proposed: fix now.
- F2 (diff-bug 2): NEWS.md has no entry for the knit-ahead build, and a check no longer needs LM Studio. This reverses the gate judgment above. Proposed: fix now, with F1.
- F3 (diff-bug 3): `knit_source()` knits in its own frame, so a chunk that assigns `temp` or `target` changes the copy. `file.copy()` is not checked. Proposed: fix now.
- F4 (diff-bug 4): the clean-start check runs once. A vignette whose teardown leaves the server running makes the next source start from that state. Proposed: fix now, with a teardown after each source.
- F5 (diff-bug 5, blame 3, prior 2): on a headless host, the `finally` clause does not stop the daemon, and `lms ps --json` with the daemon down possibly gives no JSON. Not tested. Proposed: follow-up in the `lms daemon up` candidate row.
- F6 (diff-bug 6): a chunk warning is knitted as `#> Warning` with exit 0. Proposed: follow-up candidate row.
- F7 (diff-bug 7, blame 6, prior 1): the knitted headless-config shows desktop output ("managed by the LM Studio GUI and will remain running"), the author's model list, and a wrong `str_extract()` reply. Proposed: noted, the M072 work log holds two of the three. Add the model list there.
- F8 (diff-bug 8): the download chunks show "already downloaded", next to prose about a download. Proposed: follow-up in the M071 and M072 work logs.
- F9 (diff-bug 9, blame 5): the shipped sources break the new DESIGN word and code lists. Proposed: reject, because the plan puts the rewrites in M071 to M073.
- F10 (diff-bug 10): LESSONS M009 says `collapse = TRUE` puts code and output in one block, but output with backticks goes to a separate block (headless-config.Rmd:142). Proposed: fix now.
- F11 (diff-bug 11): prose cuts beyond the named list (the `lms_ready` sentence, the REST stop paragraphs). Proposed: reject, because they described the removed gates and the work log names them.
- F12 (diff-bug 12): a `lms ps` entry with no `identifier` or `modelKey` gives an unclear error. A failure outside a chunk is named with the last chunk label. Proposed: reject, edge cases that leave no state.
- F13 (diff-bug 13, blame 7): hidden chunks leave blank lines, and the setup chunk shows as inert code. Proposed: reject, cosmetic.
- F14 (blame 2, prior 4): nothing re-knits before a release or compares `.Rmd` with `.Rmd.orig`, so output can go stale. Proposed: follow-up in the release walk candidate row.
- F15 (blame 4): text-analysis now ends with an unconditional `lms_unload_all()` with no warning to the reader. Proposed: follow-up in the M073 work log.
- F16 (prior 3): the `lms daemon up` candidate row still describes the removed gate chunks. Proposed: noted, M072 has a task that narrows the row.

Triage at the gate (2026-09-30): the maintainer accepted every proposed disposition.

- Fixed now: F1 and F2. NEWS.md drops the two entries and adds one entry for the knit-ahead build. Its "Before" sentence was read from `v0.2.2:vignettes/getting-started.Rmd`, whose chunks run under `eval=lms_installed`.
- Fixed now: F3 and F4. `knit_source()` knits in `new.env(parent = globalenv())` and stops when `file.copy()` fails. The loop calls `teardown()` after each source. A two-source scratch test discriminates. In source A, a chunk starts the server, loads `google/gemma-3-1b`, and sets `target`. Source B prints the server status and `lms ps --json`. The script at 881ad6d wrote A to `elsewhere.Rmd`, and B showed `running` true and the loaded model. The fixed script wrote `A.Rmd`, and B showed `running` false and `[]`. The AC3 cases (a), (b), and (c) gave the same results on the fixed script. Copies of the three sources in a scratch folder knitted with exit 0, with no chunk line and no error or warning text, and the server ended stopped with no model.
- Fixed now: F10. LESSONS M009 now says that output with backticks goes to a separate block.
- Follow-up: F5 in the `lms daemon up` candidate row. F6 and F14 in the release walk candidate row (one row, for the ROADMAP line cap). F7 and F8 in the M072 work log, F8 also in the M071 work log. F15 in the M073 work log.
- Noted: F16 (M072 narrows the row).
- Rejected: F9 (the plan puts the rewrites in M071 to M073), F11 (the cut prose described the removed gates), F12 (edge cases that leave no state), F13 (cosmetic).
