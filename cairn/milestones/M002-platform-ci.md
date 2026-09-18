# M002: R CMD check on macOS, Windows, and Ubuntu in CI

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — a CI workflow file, dev tooling no package user consumes
- **Branch/PR:** `m002-platform-ci`

## Goal

Automate the all-platform commitment (D-002) with the standard `R CMD check` workflow on macOS, Windows, and Ubuntu.

## Scope

**In:** Add `.github/workflows/R-CMD-check.yaml` from `usethis::use_github_action("check-standard")`. Its `push` trigger ignores `cairn/**` like the two existing workflows. Confirm `.Rbuildignore` keeps `^\.github$`.

**Out:** Fixing a package bug the new jobs surface on one platform → a hotfix or candidate row (plan gate, 2026-09-17). Making the headless CI job install LM Studio → ROADMAP candidate row. Any change to the coverage workflow → not needed.

## Acceptance criteria

- [ ] AC1: `.github/workflows/R-CMD-check.yaml` exists and its job matrix names `macos-latest`, `windows-latest`, and `ubuntu-latest`. Evidence: read the file.
- [ ] AC2: The workflow's `push` trigger carries `paths-ignore` with `cairn/**` and its `pull_request` trigger carries none, matching `test-headless.yaml` and `test-coverage.yaml`. Evidence: read all three files.
- [ ] AC3: On the milestone PR, the R-CMD-check workflow runs to completion on all three matrix entries. A green run satisfies this. A red run caused by a package failure on one platform also satisfies it once that failure is recorded as a hotfix or candidate row. Evidence: `gh pr checks <N>` output and, on a red run, the ROADMAP row or hotfix branch.

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T2

## Tasks

- [x] T1: Run `usethis::use_github_action("check-standard")`, then add `paths-ignore: ['cairn/**']` under `push` and keep `pull_request` without one. Confirm `.Rbuildignore` holds `^\.github$`.
- [x] T2: Confirm the workflow locally before review: the file parses, its matrix names the three platforms, and `devtools::check()` is clean. The PR check run is read at review under AC3, because the PR opens at the merge gate.

## Work log

- 2026-09-17: created by /milestone-plan.
- 2026-09-17: criteria audit ran in reduced mode on a fresh [O] reader; it returned rewordings for AC2 (name the three files the comparison reads) and AC3 (state the platform-bug case); both adopted.
- 2026-09-17: plan gate chose "workflow runs to completion, platform bugs go to hotfix" over "stay open until all green" because the deliverable is the workflow and a platform bug is a separate release blocker under D-002; falsified by a red run that no hotfix or candidate row records.
- 2026-09-17: T1 added `.github/workflows/R-CMD-check.yaml` from the usethis template, with `paths-ignore: ['cairn/**']` under `push`. The command also added an R-CMD-check badge to README.Rmd, so README.md was re-knitted. `devtools::test()` clean, 58 passing.
- 2026-09-17: minor amendment to T2. It said to push the branch and read `gh pr checks`, which the git model does not allow before the merge gate, so it now confirms the workflow locally and leaves the PR check run to AC3 at review. No criterion changed.
- 2026-09-17: T2 confirmed the workflow parses, its matrix names macos-latest, windows-latest, and ubuntu-latest, and `devtools::check()` reports 0 errors, 0 warnings, 0 notes.
- 2026-09-17: claim audit: not owed — internal tier.
- 2026-09-17: implement gate kept the template's full five-entry matrix and limited the push trigger to the default branch, matching test-coverage.yaml and pkgdown.yaml. The stray tracked `.DS_Store` was untracked and gitignored first, as a trivial commit on main outside this milestone.

## Decisions

## Review
