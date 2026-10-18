<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M083: The getting-started vignette covers the first app run, a finished download, the server port, and finding model keys

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — a vignette and a help page that package users read   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m083-getting-started-gaps   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A reader who follows `vignette("getting-started")` on a new machine does not stop at one of the four gaps that the M071 review found.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** four passages of `vignettes/getting-started.Rmd.orig` and its new
knit: opening the LM Studio app once after the install, the status word of
a finished download and how to read it, a server start that the later calls
reach when the last-used port is not 1234, and where to find the keys of
models that are not on the computer. The `lms_server_ready()` help sentence
that says a fresh install has no models. Tests for the package claims of
the new text. One NEWS entry.

**Out:** the `lms_server_start()` help claim that the CLI returns before
the REST API answers, which needs a headless llmster install (stays in its
ROADMAP candidate row, narrowed by this plan). A download loop that polls
until the download ends (the M071 gate chose no loop; a candidate row if a
reader asks for one). The other vignettes.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets.
     Every item opens with its positional label — `ACn:` — the item's
     position counted top-to-bottom, the number Coverage cites; an
     insertion, removal, or reorder renumbers the labels and the Coverage
     lines together. -->

- [x] AC1: The "Install LM Studio" section of
      `vignettes/getting-started.Rmd.orig` tells the reader to open the LM
      Studio app at least once after installing it and before the
      `has_lms()` check. Any reason the section gives for this step
      paraphrases a sentence of https://lmstudio.ai/docs/cli as read on the
      day of review. If the page gives no reason, the section gives none.
- [x] AC2: The "Download the model" section names both `status` values that
      `lms_download_status()` returns for a finished download:
      `"already_downloaded"` and the value for a finished job id. One of its
      chunks reads the value out of the result. The job-id value equals the
      `status` that a live `lms_download_status()` call returns after
      `lms_download()` has finished for a small model that was not on disk
      before the call. A re-check downloads such a model and deletes none.
- [x] AC3: In a live run where the server was last started on port 8080 and
      then stopped, the code of the "Start the server" section, run as
      written, makes `lms_server_ready()` return `TRUE` and `list_models()`
      return a data frame, both called with their default host.
- [x] AC4: The "Find a model" section tells the reader where to find the
      key of a model that is not on their computer. In a live run, the key
      read from that place for `google/gemma-3-1b` and for one other model,
      each passed to `lms_download()`, returns a job id or
      `"already_downloaded"`.
- [x] AC5: The `lms_server_ready()` help no longer says that a fresh LM
      Studio install has no models downloaded: the sentence of `R/serve.R`
      that begins "An empty list counts, because a fresh LM Studio install"
      is replaced by one that makes no claim about what a new install
      holds. After `devtools::document()`, `git status man/` shows no change
      against the branch commit.
- [x] AC6: `vignettes/getting-started.Rmd` is the output of
      `data-raw/knit-vignettes.R` run on the new source, and
      `tests/testthat/test-vignette-knit.R` passes. In the source, the word
      list of the vignette prose convention of `cairn/DESIGN.md`, ignoring
      case and matched as substrings, finds no match; the regular
      expressions of the vignette code convention find no match inside R
      chunks; and a search for "`r " finds no inline R expression.
- [x] AC7: `tests/testthat/test-vignette-claims.R` has a test for each of
      the two package claims that the new text rests on. The port test goes
      through `lms_server_start(port = 1234)` with the CLI call mocked and
      fails when `port` is dropped in `lms_server_start()` or in
      `build_args_server_start()`, each removed alone in a scratch copy. The
      status test fails when the job-id branch or the `"already_downloaded"`
      branch of `lms_download_status()` is removed alone, and its job-id
      mock uses the AC2 value. `devtools::test()` and `devtools::check()`
      report no failure or warning, and no note beyond those that
      `devtools::check()` gives on main at the branch point.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T3
- AC2 → T1, T3
- AC3 → T1, T3
- AC4 → T1, T3
- AC5 → T4
- AC6 → T5
- AC7 → T2, T6

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Live probes, with the token from `~/.lms-token` (never printed).
      Read https://lmstudio.ai/docs/cli for the first-run step and the LM
      Studio model catalog for where a key shows. Download a small model
      that is not on disk and read `lms_download_status()` until the
      download ends; record the final `status`. Start the server on another
      port, stop it, then run the planned start code and read
      `lms_server_ready()` and `list_models()`; also try it with the server
      still running on 8080. Try a key from the catalog for gemma-3-1b and
      one other model. Finish with the server started once on 1234 and stopped,
      so the user's last-used port is 1234 again. One work-log line per
      probe, with the date and the observed value.
- [x] T2: Tests first in `tests/testthat/test-vignette-claims.R` for the two
      package claims of AC7 (mocked, no live server), each planted red in a
      scratch copy.
- [x] T3: Rewrite the four passages of `vignettes/getting-started.Rmd.orig`
      from the T1 observations, in the M070 register (DESIGN.md vignette
      conventions).
- [x] T4: Replace the fresh-install sentence of the `lms_server_ready()`
      roxygen in `R/serve.R` and run `devtools::document()`.
- [x] T5: Re-knit with
      `Rscript data-raw/knit-vignettes.R vignettes/getting-started.Rmd.orig`
      and the token, with a work-log line for the run; run the word, regex,
      and inline-expression searches; add one NEWS entry under the
      development version.
- [x] T6: Run `devtools::test()` and `devtools::check()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which work to take next — the getting-started gaps candidate row.
- 2026-10-18: question set: may implement and review start and stop the server, load models, download a model if a probe needs one, and re-knit with the token — allowed.
- 2026-10-18: collision check: absorbed in full the candidate row "Four gaps in `vignette("getting-started")`"; absorbed the `lms_server_ready()` help part of the row "The `lms_server_start()` help says that the CLI returns before the REST API answers", whose headless llmster part stays there; no D-entry, archive, or planned milestone overlaps (D-018 covers download reply faults only).
- 2026-10-18: inbox sweep: 0 open issues, 0 open PRs on jmgirard/rlmstudio.
- 2026-10-18: lessons harvested: M009 (a sentence about what LM Studio does needs a live call after the step, so T1 probes each LM Studio claim; re-knit one vignette by passing its source) and M004 (a test needs every package it reaches in DESCRIPTION).
- 2026-10-18: plan chose a start chunk that the later calls reach (AC3) over a recovery note that tells the reader to read the port and pass `host`, because the vignette's later calls use the default host; falsified by a live run where an explicit `port = 1234` does not make the server answer on 1234, for example while it runs on another port.
- 2026-10-18: plan chose a pointer to where keys are listed (AC4) over a package function that searches the catalog, because the REST endpoint table of cairn/references/lmstudio-api-surface.md has no catalog search and GP1 allows only wrappers; falsified by an LM Studio endpoint that searches the catalog.
- 2026-10-18: criteria audit (full mode, fresh Opus reader) returned 11 findings; 10 taken as narrowings: AC1 paraphrase of a docs sentence; AC2 names both finished values and re-checks with a new download, never a delete; AC3 names port 8080 and adds `list_models()`; AC4 names two keys; AC5 anchors on the sentence text and `git status man/`; AC6 word list as substrings and regexes inside R chunks only; AC7 port test through `lms_server_start()` with two removal sites, status test with two branch removals, notes against main. Finding 5 (end with the last-used port back on 1234) is a run property, moved to T1. Finding 9's work-log record of the knit is a recording instrument, moved to T5; AC6 states the deliverable property (the knit script's output) instead.
- 2026-10-18: set in-progress on branch m083-getting-started-gaps, cut from main at a51b423.
- 2026-10-18: T1 docs read: https://lmstudio.ai/docs/cli says "You need to run LM Studio at least once before you can use `lms`" and that `lms` ships with LM Studio.
- 2026-10-18: T1 catalog read: https://lmstudio.ai/models lists models; a model's own page is https://lmstudio.ai/models/<publisher>/<name> (google/gemma-3-1b; the functiongemma family page links google/functiongemma-270m). The `lms get google/gemma-3-1B-it-QAT` line on the gemma page is not a download key: `lms_download()` aborted "google/gemma-3-1b-it-qat not found".
- 2026-10-18: T1 port probe (LM Studio CLI, macOS): after a start on 8080 and a stop, `lms server status --json` said port 8080; `lms_server_start(wait = 30)` with no port started on 8080 and `lms_server_ready()` gave FALSE; `lms_server_start(port = 1234, wait = 30)` gave `lms_server_ready()` TRUE and `list_models()` a data frame. With the server still running on 8080, a start with `port = 1234` also gave TRUE.
- 2026-10-18: T1 side finding: for under 1 s after a start that switches the port, `lms server status` reports the old port and not running, and `lms server stop` then says "not running", so `lms_server_stop()` reports "already stopped" and leaves the server up; recorded as a candidate row.
- 2026-10-18: T1 download probe: `lms_download("google/functiongemma-270m")` (not on disk) gave job_1846f7bb47; `lms_download_status()` read "downloading", then "completed" with `completed_at`; `lms_download("google/gemma-3-1b")` gave "already_downloaded". The model stays on disk (569.72 MB). Server left stopped with last-used port 1234.
- 2026-10-18: T2: two tests added to `test-vignette-claims.R`; both pass. Plants in scratch copies, each alone: port dropped at the `build_args_server_start()` call of `lms_server_start()` (1 failed), `--port` dropped in `build_args_server_start()` (1 failed), `return(NULL)` before the status request (2 failed, 1 error), the `"already_downloaded"` test replaced by `FALSE` (2 failed); unchanged control 0 failed.
- 2026-10-18: T3: four passages written from the T1 records: open the app once (paraphrasing the docs sentence), `port = 1234` in the start chunk with the reason, the catalog page address as the key source (with the family-page note), and the `status` element with "downloading", "completed", and "already_downloaded"; the download chunk now prints `status$status`. `test-vignette-knit.R` fails until the T5 knit.
- 2026-10-18: T4: the help sentence now reads "An empty list counts, so a server that lists no models gives `TRUE`", a package claim that `test-server-ready.R:89` covers, in place of a claim about LM Studio; a second `devtools::document()` writes nothing.
- 2026-10-18: T5: `Rscript data-raw/knit-vignettes.R vignettes/getting-started.Rmd.orig` with the token knitted to `vignettes/getting-started.Rmd` with no error; the start chunk shows "started successfully on port 1234" and the download chunk `"already_downloaded"`. The model list now holds google/functiongemma-270m from T1, and the batch replies changed with the run. Word list (substring, ignoring case), code regexes over the 58 R chunk lines, and "`r " searches found nothing; each search went red on a planted line. One NEWS entry added.
- 2026-10-18: T6: `devtools::test()` 24444 expectations, 0 failed, 0 errors, 3 skipped (live tests, server stopped); `devtools::check()` 0 errors, 0 warnings, 0 notes.
- 2026-10-18: claim audit: 21 claims read, 2 corrected — NEWS.md (the port sentence read as if the app starts the server; now names `port = 1234` and the last-used-port reason), tests/testthat/test-vignette-claims.R (the mock comment called made-up values real). Two of the reader's optional points taken: the vignette now says that a page's `lms get` name is not always a download key (T1 record), and the `test-server-ready.R:86` comment drops the fresh-install claim. Re-knit with the token, word and inline searches clean, the knit, claims, and server-ready test files pass.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. -->

Pass 1, 2026-10-18, branch head 8de63ca, main a51b423 (not moved since the cut).

- AC1 evidence: `getting-started.Rmd.orig` "Install LM Studio" says "After you install LM Studio, open the app once, and then restart R", before the `check-lms` chunk that calls `has_lms()`. Its reason, "you need to run LM Studio at least once before you can use `lms`", paraphrases https://lmstudio.ai/docs/cli, read 2026-10-18: "You need to run LM Studio at least once before you can use lms."
- AC2 evidence: the section names `"downloading"`, `"completed"` ("the download finished"), and `"already_downloaded"`; the `download` chunk runs `status <- lms_download_status(job_id)` then `status$status`. Live 2026-10-18: `lms_download("liquid/lfm2-350m")` (not on disk before; `lms ls` listed no lfm model) gave job_a2d441b906, and `lms_download_status()` read "downloading" then "completed". No model was deleted.
- AC3 evidence: live 2026-10-18: `lms_server_start(port = 8080, wait = 30)`, `lms_server_stop()`, then `lms server status --json` gave `{"running":false,"port":8080}`. The `start-server` chunk, read from the source and evaluated as written, returned `TRUE` from its `lms_server_ready()`; `list_models(quiet = TRUE)` with the default host then returned a data.frame of 6 rows. Server stopped with last-used port 1234.
- AC4 evidence: "Find a model" points to https://lmstudio.ai/models and says a model's own page address ends with its key. Live 2026-10-18: `lms_download("google/gemma-3-1b")` (from https://lmstudio.ai/models/google/gemma-3-1b) gave "already_downloaded"; `lms_download("liquid/lfm2-350m")` (from https://lmstudio.ai/models/liquid/lfm2-350m, linked from the lfm2 family page) gave job id job_a2d441b906.
- AC5 evidence: `grep -n "fresh LM Studio install" R/serve.R man/lms_server_ready.Rd` finds nothing; `R/serve.R:757` now reads "An empty list counts, so a server that lists no models gives `TRUE`", no claim about a new install. After `devtools::document()`, `git status --short man/ NAMESPACE` is empty.
- AC6 evidence: the last line of `getting-started.Rmd` names MD5 7575ee7baed14e75361794e2f884d496, which `md5 -q` gives for the source, written by `data-raw/knit-vignettes.R` (work log, claim-audit re-knit); `test-vignette-knit.R` passes inside the full suite. The 14 prose words (case-insensitive substring) and the 16 code regexes over the 58 R chunk lines found no match; "`r " found 0. Each search went red on a planted line during T5.
- AC7 evidence: in scratch copies, each plant alone: port dropped at the `build_args_server_start()` call of `lms_server_start()` → the port test 1 failed; `--port` dropped in `build_args_server_start()` → 1 failed; `return(NULL)` before the status request (job-id branch) → status test 2 failed and 1 error; the `"already_downloaded"` test replaced by `FALSE` → 2 failed; unchanged controls 0 failed for both tests. The port test calls `lms_server_start(port = 1234, wait = 0)` with `processx::run` mocked; the job-id mock's status is "completed" (AC2). `devtools::test()`: 24444 expectations, 0 failed, 0 errors, 0 warnings, 3 skipped (live tests). `devtools::check()`: 0 errors, 0 warnings, 0 notes, so no note beyond main.
- Gate: `cairn_validate.py` all checks passed; `devtools::document()` no diff; `pkgdown::check_pkgdown()` no problems; README not touched; NEWS.md has the entry, with no milestone number; no new top-level files; no principle changed, so `cairn_impact` skipped.
- spawned: diff-bug, blame-history, prior-review
- diff-bug #1: "until completed" never names a failed download, and `lms_download_status()` returns "failed" (D-018) — fix now, fixed e5477d2 ("If it is `"failed"`, the download did not finish"; `test-load-download-shape.R:503-507` covers the value).
- diff-bug #2: "the first case" is ambiguous after the new paragraph lists "downloading" first — fix now, fixed e5477d2 (now names `"already_downloaded"`). Re-knit with the token; knit and claims test files pass; full suite 24444, 0 failed; word and inline searches clean.
- diff-bug #3: a start with no `port` still prints "on the default port", and the `lms_server_start()` help example says "default port" (`R/serve.R:105`, `:153`) — follow-up, predates the branch: candidate row "No-port start outside getting-started", filed at hygiene for the line cap.
- diff-bug #4: the README Quick Start starts with no `port` — follow-up: the same row.
- diff-bug #5: the `install_lmstudio()` message (`R/setup.R:148`) leaves out the open-the-app step — follow-up: the same row.
- diff-bug #6: half of the new status test repeats an older test with a weaker request check — reject, planned change: AC7 asked for one test over both branches, and `local_no_request_allowed()` stays in the older test.
- diff-bug #7: the port test does not check the readiness host — reject, false: `test-serve.R:357` and `:410` assert the host `http://localhost:8080` for a port start.
- diff-bug #8: the knitted model list shows probe leftovers, and `status$status` reuses a word — reject: the knit records the live machine by design (DESIGN Conventions), and the variable name is style.
- blame-history #1: the no-port start also sits in `headless-config`, `chat-options`, `text-analysis`, and `README.Rmd` — follow-up: the same row.
- blame-history #2: the re-knit batch output no longer shows a reply that ignores its system prompt — reject, false: "does not always follow" is not falsified by one run that follows it, and that sentence is not branch-added.
- blame-history #3: the new help sentence gives no reason for the empty-list rule — reject, planned change: AC5 called for a sentence without the unverified LM Studio claim, and the rule's test stands.
- blame-history #4: the knitted list has no lfm2 row though review downloaded it — reject, false: the knit ran before the review download; `liquid/lfm2-350m` and `google/functiongemma-270m` stay on disk.
- blame-history #5: "run LM Studio at least once" reads as general against the headless path — reject, false: it sits in the desktop install path and paraphrases the docs; headless setup has its own vignette.
- blame-history #6: no loop, consistent with M071 — noted.
- prior-review #1: "starts on the port that it used last time" has no after-step live check — reject, false: the review re-ran it 2026-10-18 — after a start on 8080 and a stop, a start with no `port` ran on 8080 and `lms_server_ready()` gave FALSE; after 1234, it ran on 1234 and gave TRUE.
- prior-review #2: the open-the-app sentence rests on the docs, not a live run — reject, planned change: AC1 chose a docs paraphrase, the sentence names the docs as its source, and a new install is not available here.
- prior-review #3: the NEWS bullet repeats the port claim — reject, false: the claim held in the prior-review #1 re-run.
