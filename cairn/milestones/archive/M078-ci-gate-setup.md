# M078: A pull request runs only the CI jobs that the package can turn red

**Status:** done (2026-10-01, PR #78 https://github.com/jmgirard/rlmstudio/pull/78)

**Goal:** A pull request runs only the CI jobs that the package can turn red, each job once, from workflow files that share one setup.

**Outcome:** The `R-CMD-check.yaml` matrix keeps four rows: macOS, Windows, and Ubuntu on R release, and Ubuntu on oldrel-1. R-devel runs in a new `R-devel-check.yaml` on `ubuntu-latest`. It runs weekly (Monday 06:00 UTC), on a manual start, and on a push to the default branch, never on a pull request. `test-headless.yaml` became `test-source-tree.yaml` (workflow `Source-tree tests`, job `source-tree-tests`). It lost the unread `RLMSTUDIO_TEST_HEADLESS` variable. Its push trigger is limited to `main` or `master`, so a PR runs it once. Its header names the three test files that skip under R CMD check. All five workflows use `actions/checkout@v6` and have `workflow_dispatch`. The four besides `pkgdown.yaml` have the group `${{ github.workflow }}-${{ github.ref }}`. It cancels a run in progress on pull requests only. The DESIGN Platforms line, a Known issues line, and the M002, M005, and M011 lessons were corrected. PR #78 showed the seven expected checks, each once, all passing.

**Decisions:** D-040 (R-devel weekly, outside the pull-request checks).

**Review:** Fan-out of three fresh reviewers, with 15 findings. Six were fixed at the gate. The R-devel header now states a risk and not a past event, and two "on each push" claims were reworded. The M005 and M011 lessons were corrected. A test comment lost "headless workflow", and `test-source-tree.yaml` gained `permissions: read-all`. At hygiene, the first `pkgdown` run on `main` under checkout v6 passed its deploy step. One finding became a candidate row: a manual pkgdown run on another branch deploys to `gh-pages`. Seven were rejected or noted with reasons in the Review section of the branch file. The CI wait hit its time limit once, and the merge took one resume.
