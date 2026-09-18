# M002: R CMD check on macOS, Windows, and Ubuntu in CI

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — a CI workflow file, dev tooling no package user consumes
- **Branch/PR:** `m002-platform-ci` / https://github.com/jmgirard/rlmstudio/pull/3

## Goal

Automate the all-platform commitment (D-002) with the standard `R CMD check` workflow on macOS, Windows, and Ubuntu.

## Scope

**In:** Add `.github/workflows/R-CMD-check.yaml` from `usethis::use_github_action("check-standard")`. Its `push` trigger ignores `cairn/**` like the two existing workflows. Confirm `.Rbuildignore` keeps `^\.github$`.

**Out:** Fixing a package bug the new jobs surface on one platform → a hotfix or candidate row (plan gate, 2026-09-17). Making the headless CI job install LM Studio → ROADMAP candidate row. Any change to the coverage workflow → not needed.

## Acceptance criteria

- [x] AC1: `.github/workflows/R-CMD-check.yaml` exists and its job matrix names `macos-latest`, `windows-latest`, and `ubuntu-latest`. Evidence: read the file.
- [x] AC2: The workflow's `push` trigger carries `paths-ignore` with `cairn/**` and its `pull_request` trigger carries none, matching `test-headless.yaml` and `test-coverage.yaml`. Evidence: read all three files.
- [x] AC3: On the milestone PR, the R-CMD-check workflow runs to completion on all three matrix entries. A green run satisfies this. A red run caused by a package failure on one platform also satisfies it once that failure is recorded as a hotfix or candidate row. Evidence: `gh pr checks <N>` output and, on a red run, the ROADMAP row or hotfix branch.

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
- 2026-09-17: review recorded AC1 and AC2 evidence and ticked both boxes. Consistency gate clean. AC3 waits on the PR check run in step 8. Checkpoint taken with the diff-bug reviewer still running.
- 2026-09-17: three-lens review returned nine findings. One fixed now, the stale DESIGN Platforms line. Two go to candidate rows at hygiene. Three rejected, three noted. No return floor trigger.
- 2026-09-17: step-7 approval: m002-platform-ci approved for merge.

## Decisions

## Review

### Acceptance-criteria evidence (2026-09-17)

- AC1 met. `.github/workflows/R-CMD-check.yaml` exists, 52 lines. Parsed with `yaml.safe_load`, the `R-CMD-check` job matrix holds five `config` entries. Their distinct `os` values are `macos-latest`, `ubuntu-latest`, and `windows-latest`.
- AC2 met. All three files parsed with `yaml.safe_load`. `R-CMD-check.yaml` resolves to `{"push": {"branches": ["main", "master"], "paths-ignore": ["cairn/**"]}, "pull_request": null}`. `test-coverage.yaml` resolves to the same value. `test-headless.yaml` resolves to `{"push": {"paths-ignore": ["cairn/**"]}, "pull_request": null}`. Every one of the three carries `paths-ignore` with `cairn/**` under `push` and carries nothing under `pull_request`.
- AC3 met. `gh pr checks 3` on PR #3 reports every matrix entry green: `windows-latest (release)` pass in 2m35s, `macos-latest (release)` pass in 1m53s, `ubuntu-latest (release)` pass in 1m33s, `ubuntu-latest (devel)` pass in 7m10s, `ubuntu-latest (oldrel-1)` pass in 2m27s. The run went green, so the red-run branch of the criterion never applied. The cross-platform test risk the review raised did not materialize.
- AC3 note on the first attempt. The `test-headless` job failed once on the pull-request run, and the failure was not in this diff. The `r2u.stat.illinois.edu` apt mirror timed out, so `apt-get` did not find `r-cran-httptest2`. The push-triggered run of the same workflow on the same commit passed in 36s. A re-run of the failed job passed in 42s.

### Consistency gate (2026-09-17)

- `cairn_validate.py`: exit 0, all checks passed. No advisory fired, the release window included.
- `cairn_impact.py`: skipped. The milestone changes no DESIGN principle.
- `devtools::document()`: ran, `git status` clean afterward, so no diff.
- `devtools::build_readme()`: ran, `git status` clean afterward, so README.md is in sync with README.Rmd. The new badge URL names `R-CMD-check.yaml`, which matches the workflow's `name:` value.
- `pkgdown::check_pkgdown()`: no problems found.
- `NEWS.md`: no entry owed. The milestone changes no user-visible package behavior.
- `.Rbuildignore`: holds `^\.github$` at line 11, so the new workflow stays out of the built package.
- `devtools::check()`: 0 errors, 0 warnings, 0 notes on rlmstudio 0.2.2.9000.

### Independent review (2026-09-17)

Three fresh-context reviewers ran in parallel, because the diff touches a CI workflow and is not docs-only. The [O] diff-bug lens read the full diff against the criteria, DESIGN, and DECISIONS. The [S] history lens read `git log` and `git blame` on the touched files. The [S] prior-review lens searched the archive and probed the GitHub review threads.

Prior-review lens: no prior-review evidence. The one archived Review section covers `R/` files that this diff does not touch, and the inline-comment probe returned an empty list. Zero findings.

History lens: the change follows the `paths-ignore` convention an earlier commit added deliberately. No check workflow was ever added and then removed. The README badge follows the existing paired-edit pattern. The lens raised one finding, folded in as F7 below.

Findings and dispositions, most severe first:

- F1 ([O] 1) AC3 carries no evidence yet, because the branch is unpushed and no PR exists. Disposition: noted. The evidence lands at the `gh pr checks` read in step 8, and the box stays unticked until then.
- F2 ([O] 2) The test suite carries cross-platform risk that Windows will hit first. `tests/testthat/test-serve.R` opens real loopback listeners on random ports through `local_listener()` and `free_port()`. `tests/testthat/test-setup.R` replaces `PATH` with an empty directory and relies on `Sys.which()` finding a hand-written `lms` stub. Neither file carries `skip_on_os()`. Verified by reading both files. Disposition: noted. A red run is what AC3's own procedure dispositions, and the plan routes a platform bug to a hotfix or a candidate row.
- F3 ([O] 3) `cairn/DESIGN.md` still said CI runs R CMD check on Ubuntu only, which this branch makes false. Disposition: fixed now. The Platforms line now names all three platforms and carries the `corrected M002` mark.
- F4 ([O] 4) `test-headless.yaml` has no `branches` filter under `push`, so the three named files are not identical. Disposition: noted. AC2 quantifies only over `paths-ignore` and `pull_request`, and on that wording all three agree.
- F5 ([O] 5) The `pull_request` trigger carries no `paths-ignore`, so a tracking-only PR fires all five jobs. Disposition: rejected. AC2 requires it, and the PR run is the only route to AC3's evidence.
- F6 ([O] 6) A red `r: 'devel'` job unrelated to this package blocks the merge. The plan's escape hatch covers a platform failure, not an R-version failure. Disposition: follow-up candidate row at hygiene.
- F7 ([O] 7 and 8, plus the history lens finding) The new workflow has no `workflow_dispatch` trigger and no `concurrency` group. It pins `actions/checkout@v6` where the sibling workflows pin `@v4`. All three points are template-standard. Disposition: one follow-up candidate row at hygiene.
- F8 ([O] 9) No `NEWS.md` entry. Disposition: rejected. The consistency gate confirmed none is owed, because no user-visible package behavior changed.
- F9 ([O] 10) `upload-snapshots: true` has no `_snaps` directory to upload. Disposition: rejected. It is template-standard and harmless.

Return floor: no finding demonstrates an acceptance criterion failing, so the milestone does not return to `in-progress`. This is the first review pass, so the defect-return count stays at zero.

