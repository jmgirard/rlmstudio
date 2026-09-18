# M002: R CMD check on macOS, Windows, and Ubuntu in CI

**Status:** done (2026-09-17, PR #3 https://github.com/jmgirard/rlmstudio/pull/3)

**Goal:** Automate the all-platform commitment (D-002) with the standard `R CMD check` workflow on macOS, Windows, and Ubuntu.

**Outcome:** `.github/workflows/R-CMD-check.yaml` from the `usethis::use_github_action("check-standard")` template, unmodified except for one added `paths-ignore`. Its `strategy.matrix.config` holds five entries: `macos-latest` release, `windows-latest` release, and `ubuntu-latest` on release, devel, and oldrel-1. The `push` trigger carries `branches: [main, master]` plus `paths-ignore: ['cairn/**']`, matching `test-coverage.yaml` and `pkgdown.yaml`. The `pull_request` trigger carries no filter, so the matrix runs on every PR. An R-CMD-check badge was added to `README.Rmd` and README.md was re-knitted. The DESIGN Platforms line, which said CI ran on Ubuntu only, was corrected. First run on PR #3 was green on all five entries: windows 2m35s, macos 1m53s, ubuntu release 1m33s, ubuntu devel 7m10s, ubuntu oldrel-1 2m27s. The cross-platform risk in the loopback-socket and PATH-replacing tests did not fire.

**Decisions:** none. The plan gate chose "workflow runs to completion, platform bugs route to a hotfix" under D-002, recorded in the work log.

**Review:** three-lens fan-out, because the diff touches a CI workflow. Prior-review lens: no prior-review evidence, zero findings. History lens: one finding, folded in. Diff-bug lens: nine findings. Fixed now: the stale DESIGN Platforms line. Follow-up candidate rows: how a red R-devel-only job is dispositioned, and unifying the four workflow files on a `workflow_dispatch` trigger, a `concurrency` group, and one `actions/checkout` version. Three rejected and three noted, with reasons in git history. No return floor trigger. Hygiene retired nothing and graduated nothing.
