# M078: A pull request runs only the CI jobs that the package can turn red

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal, because no package user relies on the GitHub Actions workflows
- **Branch/PR:** m078-ci-gate-setup

## Goal

A pull request runs only the CI jobs that the package can turn red, each job once, from workflow files that share one setup.

## Scope

**In:** Move the R-devel check out of the pull-request matrix into its own weekly workflow (D-040). Rename `test-headless.yaml` to say what it runs, remove the variable that no code reads, and run it once per PR. Give every workflow file the same `actions/checkout` version, a `workflow_dispatch` trigger, and a `concurrency` group. Update the DESIGN Platforms line and Known issues entry and the M002 lesson that names the old job.

**Out:** A live LM Studio install in CI. The gate chose the rename, so no row holds it. The macOS Package Manager workaround stays as it is, under its `[low]` candidate row. Other action versions, such as `upload-artifact@v4` and `codecov-action@v5`, stay as they are, because no report calls them stale. Branch protection stays off, because the merge gate reads `gh pr checks`.

## Acceptance criteria

- [x] AC1: The `strategy.matrix.config` list of `.github/workflows/R-CMD-check.yaml` holds exactly four entries: `macos-latest` release, `windows-latest` release, `ubuntu-latest` release, and `ubuntu-latest` oldrel-1. Evidence: the list read from the parsed file.
- [x] AC2: A new workflow `.github/workflows/R-devel-check.yaml` runs `R CMD check` on `ubuntu-latest` with R-devel. Its triggers are a weekly `schedule`, `workflow_dispatch`, and `push` to `main` or `master`, and it has no `pull_request` trigger. Evidence: the trigger keys, the `schedule` cron value, the job's `runs-on`, and its R version, read from the parsed file.
- [x] AC3: `.github/workflows/test-headless.yaml` is renamed to `.github/workflows/test-source-tree.yaml`, with the workflow name `Source-tree tests` and the job id `source-tree-tests`. It sets no `RLMSTUDIO_TEST_HEADLESS` variable, and its `push` trigger is limited to `main` or `master`. A header comment states that it runs `devtools::test()` from the source tree and installs no LM Studio. Evidence: the parsed file, and `git grep -n RLMSTUDIO_TEST_HEADLESS -- ':!cairn'`, which returns no line.
- [x] AC4: Each file that `ls .github/workflows/*.yaml` lists parses as YAML, has a `workflow_dispatch` trigger, pins every `actions/checkout` step to `@v6`, and declares a `concurrency` group. In every file but `pkgdown.yaml`, the group is `${{ github.workflow }}-${{ github.ref }}` at workflow level, with `cancel-in-progress` true for pull requests only. `pkgdown.yaml` keeps its existing job-level group unchanged. Evidence: one R script that loops over that `ls` output and prints one row per file and property.
- [ ] AC5: On this milestone's pull request, `gh pr checks --json name,workflow,state` lists seven rows with a non-empty `workflow`, each once and each passing. They are `macos-latest (release)`, `windows-latest (release)`, `ubuntu-latest (release)`, `ubuntu-latest (oldrel-1)`, `source-tree-tests`, `test-coverage`, and `pkgdown`. It lists no other row with a non-empty `workflow`.

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T2
- AC4 → T3
- AC5 → T1, T2, T3

## Tasks

- [x] T1: Create `.github/workflows/R-devel-check.yaml` from the check job of `R-CMD-check.yaml`, with one `ubuntu-latest` R-devel config (`http-user-agent: release`) and the triggers of AC2. A header comment says why R-devel runs outside the PR gate and what to do on a red run (D-040). Remove the devel row from the `R-CMD-check.yaml` matrix (line 26).
- [x] T2: `git mv` `test-headless.yaml` to `test-source-tree.yaml`. Set the workflow name and job id of AC3, remove the `env` block, and add `branches: [main, master]` to `push`. Write the header comment from observed output. It names the test files whose `skip_if()` fires under R CMD check, read from a same-session run and not from this list. Today they are `test-name-faults.R:123`, `test-token-hint.R:102`, and `test-vignette-knit.R:25`.
- [x] T3: In all five workflow files, set `actions/checkout@v6`. Today `pkgdown.yaml`, `test-coverage.yaml`, and `test-headless.yaml` use `@v4`. Add `workflow_dispatch` where it is missing, and add the AC4 `concurrency` block to every file but `pkgdown.yaml`. Write the AC4 evidence script in the scratchpad, not the repo. R `yaml` reads the `on:` key as `TRUE`, so the script reads that name.
- [x] T4: Records. Correct the DESIGN Platforms line (`cairn/DESIGN.md:23`) to name R-devel's weekly workflow and the Ubuntu release and oldrel-1 PR rows. Delete the headless Known issues line (`cairn/DESIGN.md:92`), marked `corrected M078`. Rename the job in the M002 line of `cairn/LESSONS.md`. AC5 evidence exists only after the PR opens at the review gate (M011 lesson), and a red check there returns the milestone to implement.

## Work log

- 2026-10-01: created by /milestone-plan, from two candidate rows: the R-devel disposition (M002 review finding 6) and the CI workflow cleanups (M002 findings 7 and 8, DESIGN Known issues).
- 2026-10-01: criteria audit, reduced mode (internal tier), by a fresh Opus reader. Four criteria passed all three questions. Three fixes at the gate. AC5 now reads `gh pr checks --json` and counts only rows with a workflow. AC2 evidence adds the cron value and `runs-on`. The goal no longer counts four workflows.
- 2026-10-01: plan gate chose a separate weekly R-devel workflow over an allowed-to-fail PR job, a still-blocking job, and no R-devel CI. An allowed-to-fail job can still show red in `gh pr checks`, and the other two keep merges waiting or lose early warning. Falsified by an R-devel break that the package caused and that reached a CRAN release before a weekly run showed it.
- 2026-10-01: plan gate chose to rename and keep the headless job over deleting it or installing LM Studio in it. A delete leaves three source-reading test files with no CI run, and an install needs its own milestone. Falsified by a CI run where the source-tree job catches nothing that the check jobs miss across a release cycle.
- 2026-10-01: implement started on branch `m078-ci-gate-setup`. No question gate, because the plan left nothing open. The weekly run is Monday 06:00 UTC.
- 2026-10-01: T1 done. `R-devel-check.yaml` added, and the devel row removed from the `R-CMD-check.yaml` matrix. The parsed files show 4 matrix rows, and triggers `schedule` (`0 6 * * 1`), `push`, and `workflow_dispatch` on `ubuntu-latest` R-devel.
- 2026-10-01: T2 done. `test-headless.yaml` renamed to `test-source-tree.yaml`, with name `Source-tree tests`, job `source-tree-tests`, no `env` block, and push limited to `main` or `master`. A same-session `rcmdcheck` run (0 errors, 0 warnings, 7 skips) skipped `test-vignette-knit.R:25`, `test-name-faults.R:123`, and `test-token-hint.R:102` for absent sources, and the header names those three. The live-server claim reads `skip_if_no_server()` in `helper-skips.R`. `git grep RLMSTUDIO_TEST_HEADLESS -- ':!cairn'` finds nothing.
- 2026-10-01: T3 done. All five workflows use `actions/checkout@v6` and have `workflow_dispatch`. The four besides `pkgdown.yaml` have the workflow-level group. The scratchpad script `ac4-check.R` printed TRUE in every cell. A copy with three planted faults (checkout v4, no dispatch, cancel always) printed FALSE in each of those 3 cells.
- 2026-10-01: T4 done. The DESIGN Platforms line names both check workflows. The headless Known issues line was rewritten rather than deleted, because CI still runs no live-server test, and it is marked `corrected M078`. The M002 lesson names the new job.
- 2026-10-01: claim audit: not owed — internal tier.
- 2026-10-01: verify. No R file changed. The T2 `rcmdcheck` run gave 0 errors, 0 warnings, and `[ FAIL 0 | WARN 0 | SKIP 7 | PASS 20216 ]`. Status set to review.

## Decisions

## Review

Evidence for AC1 to AC4 comes from one scratchpad script, `review-evidence.R`, run on 2026-10-01 at `8286f92`. It reads each workflow with `yaml::read_yaml()`.

- AC1: the parsed `strategy.matrix.config` list has four rows: `macos-latest` release, `windows-latest` release, `ubuntu-latest` release, `ubuntu-latest` oldrel-1.
- AC2: `R-devel-check.yaml` has the triggers `schedule`, `push` (branches `main`, `master`), and `workflow_dispatch`, and no `pull_request`. The cron value is `0 6 * * 1`. Its one job runs on `ubuntu-latest`, sets `r-version: devel`, and runs `check-r-package@v2`.
- AC3: `test-headless.yaml` is gone, and `test-source-tree.yaml` has the name `Source-tree tests` and the one job id `source-tree-tests`. Its push branches are `main` and `master`. The header comment says it runs `devtools::test()` from the source tree and installs no LM Studio. `git grep -n RLMSTUDIO_TEST_HEADLESS -- ':!cairn'` printed nothing and exited 1.
- AC4: the script looped over the 5 files that `ls .github/workflows/*.yaml` lists. Each file parsed, had `workflow_dispatch`, and had one `actions/checkout` step at `@v6`. The 4 files besides `pkgdown.yaml` had the workflow-level group with `cancel-in-progress` set to the pull-request test. `pkgdown.yaml` had no workflow-level group and its job-level group unchanged, and `git diff main..HEAD` on it shows only the checkout line. A run on copies with 3 planted faults printed FALSE in exactly those 3 cells. The faults were checkout v4 in `test-coverage.yaml`, no dispatch in `R-devel-check.yaml`, and cancel always in `test-source-tree.yaml`.
- AC5: not yet verifiable. The PR opens only after the merge approval, so its checks are read at that step, before the merge.
- Gate: `cairn_validate.py` passed every check (exit 0). No DESIGN principle changed, so `cairn_impact` was skipped. `devtools::document()` left no diff. `pkgdown::check_pkgdown()` found no problems. The branch changes no file under `R/`, `tests/`, or `vignettes/`, and no `README`, `NEWS.md`, `DESCRIPTION`, or `.Rbuildignore` file. No NEWS entry is owed, because no package user sees the change. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.

Independent review, three fresh lenses: diff-bug (Opus), blame-history (Sonnet), prior-review (Sonnet). The PR-comment probe found no inline comments. Findings by rank, with the proposed disposition. The gate decides.

- R1 (diff): the `R-devel-check.yaml` header says an R-devel break "turned the checks red and blocked every merge". No failed run in `gh run list` was red on R-devel alone. Proposed: fix now, reword it as a risk.
- R2 (diff): each new workflow-level group keeps one running and one pending run. A third quick push to `main` cancels the pending run of the second. Proposed: reject. AC4 sets this group, and the newest run checks the newest tree.
- R3 (diff): a manual `workflow_dispatch` run on a PR branch adds duplicate rows, or an R-devel row, to `gh pr checks`. Proposed: reject. It needs a deliberate manual start on a PR branch.
- R4 (diff, prior-review): `cairn/LESSONS.md` M011 line says a non-Ubuntu fix cannot run before the PR exists. After this merge, `gh workflow run R-CMD-check.yaml --ref <branch>` can start it. Proposed: fix now, correct the lesson.
- R5 (diff): `cairn/LESSONS.md` M005 line says a test that greps `R/` "skips on CI". The source-tree job runs it on CI. Proposed: fix now, correct the lesson.
- R6 (diff): `tests/testthat/helper-mock-http.R:107` still says "the headless workflow". Proposed: fix now, a comment edit.
- R7 (diff): the PR cannot test the pkgdown deploy step under `actions/checkout@v6`, because the deploy skips on pull requests. Proposed: follow-up inside this review, read the first `pkgdown` run on `main` after the merge.
- R8 (diff): the `R-devel-check.yaml` header and `cairn/DESIGN.md:23` say R-devel runs "on each push", but a push that changes only `cairn/` files runs nothing. Proposed: fix now, reword both.
- R9 (diff): `test-source-tree.yaml` has no `permissions: read-all`, and the other four files do. Proposed: fix now, add it.
- R10 (diff, blame, prior-review): in `R-devel-check.yaml`, `cancel-in-progress` tests for a pull request, but the file has no `pull_request` trigger. Proposed: reject. AC4 requires the same block, and it does no harm.
- R11 (diff): `actions/checkout@v7` exists. Proposed: reject. v6 has a release from the same day, and the Scope moves no version without a staleness report.
- R12 (diff, blame): `R-devel-check.yaml` copies the check job instead of calling a shared one, and sets `use-public-rspm: true` against `always`. Proposed: reject. The plan chose a separate file, and the two values are the same on Ubuntu.
- R13 (diff): a manual `pkgdown.yaml` run on a non-default branch deploys that branch's site to `gh-pages`. This predates the branch. Proposed: follow-up candidate row.
- R14 (blame): `test-source-tree.yaml` push is now limited to `main` or `master`, so a branch push with no PR gets no run. Proposed: reject. AC3 asks for it.
- R15 (blame): the old `test-headless` check name is gone, and nothing outside the archive uses it. Proposed: noted.
