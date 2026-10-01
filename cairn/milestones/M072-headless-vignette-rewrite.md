# M072: The headless vignette covers what differs without the desktop app

- **Status:** planned
- **Priority:** normal
- **Depends on:** M070
- **Driving RR:** —
- **Principles touched:** IP1, IP2
- **Resolves:** —
- **Surface tier:** user-facing — a vignette that package users read
- **Branch/PR:** —

## Goal

A user on a machine without the LM Studio desktop app, or with LM Studio on
another machine, can follow `headless-config` to a working server.

## Scope

**In:** A rewrite of `vignettes/headless-config.Rmd.orig`, knitted by the
M070 script. It covers only what differs from `getting-started`: installing
the command line tool with `install_lmstudio(method = "headless")`, shown and
not run, which asks before it installs (IP2). It also covers the daemon
(`lms_daemon_start()`, `lms_daemon_status()`, `lms_daemon_stop()`), the
server on a slow host, and a script wrapped in `with_lms_daemon()`. A new
section covers a server that requires an API token (`RLMSTUDIO_API_TOKEN`
and the `token` argument) and a server on another machine (the `host`
argument). Remote-host code is shown and not run. The text says that text
then goes to that machine (IP1). The download, load, and chat steps link to
`getting-started` and are not repeated. The code and prose follow the
vignette rules in DESIGN.md Conventions (M070). A NEWS entry.

**Out:** A headless llmster run of the knit stays in the candidate row on
`lms daemon up`. Batch work is M073, and chat options are M074.

## Acceptance criteria

- [ ] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/headless-config.Rmd.orig` holds each of these strings:
      `install_lmstudio(method = "headless")`, `lms_daemon_start(`,
      `lms_daemon_status(`, `lms_daemon_stop(`, `lms_server_start(`,
      `with_lms_daemon(`, `RLMSTUDIO_API_TOKEN`, `token =`, and `host =`. It
      holds neither `lms_download(` nor `list_models(`. In the knitted
      `vignettes/headless-config.Rmd`, no line starts with ```` ```{r ````
      or with `#> Error`. The block of the chunk that calls
      `lms_daemon_status(` holds a line that starts with `#>` after its last
      code line.
- [ ] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [ ] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside its
      ```` ```{r} ```` chunks, with the YAML header and inline code.
- [ ] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      headless, daemon, host, and API token.
- [ ] AC5: The prose next to the `host =` chunk states that the input text
      goes to that machine. The prose next to `install_lmstudio()` states
      that it asks before it installs, unless `RLMSTUDIO_ALLOW_INSTALL` is
      set.
- [ ] AC6: Take each prose sentence and each `#` comment line that states
      what a package function does with an argument, returns, or raises,
      beyond what its name says. A named test under `tests/testthat/`
      exercises that behavior. A sentence about what LM Studio itself does
      matches what a live call on this machine returned.
- [ ] AC7: `NEWS.md` has an entry under the development-version heading
      that names the rewritten vignette. `devtools::document()` gives no
      diff, `devtools::test()` passes, and `pkgdown::check_pkgdown()`
      passes. With the server stopped and `RLMSTUDIO_API_TOKEN` unset,
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T2
- AC3 → T2, T4
- AC4 → T2, T4
- AC5 → T1, T2
- AC6 → T1, T5
- AC7 → T6

## Tasks

- [ ] T1: Probe `lms_daemon_status()` and `with_lms_daemon()` on this
      machine, where the desktop app runs the daemon, and log what each
      returns. Read `?rlmstudio_token` and `?install_lmstudio` for the
      token and consent rules that the prose states.
- [ ] T2: Rewrite the source to the outline in Scope. Keep each code chunk
      short, with a comment that says what it does.
- [ ] T3: Knit with `data-raw/knit-vignettes.R` from a clean start. Read
      the knitted file for error lines and for the output lines of AC1.
- [ ] T4: Spawn a fresh reader with the persona of a researcher who knows
      R and runs a remote Linux server. It reads the knitted vignette and
      lists each step that it cannot follow and each term used before it is
      explained. Fix each item, or log why not, and re-knit.
- [ ] T5: List the claims of AC6 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
      Narrow the `lms daemon up` candidate row: the vignette no longer
      stops a daemon during a package check.
- [ ] T6: Add the NEWS entry and run the checks of AC7.

## Work log

- 2026-09-30: created by /milestone-plan.

## Decisions

## Review
