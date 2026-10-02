# M080: A pkgdown run deploys the site only from the default branch or a release

**Status:** done (2026-10-01, PR #80 https://github.com/jmgirard/rlmstudio/pull/80)

**Goal:** A run of `pkgdown.yaml` deploys the site to `gh-pages` only from the default branch or from a published release.

**Outcome:** The "Deploy to GitHub pages" step of `.github/workflows/pkgdown.yaml` has the condition `github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`. The old condition skipped only pull requests. A comment above the step says that every other run builds the site and skips the deploy. The triggers did not change, and `workflow_dispatch` is still there. Manual run 36946984849 on the branch built the site and skipped the deploy. After the merge, push run 36948685057 on `main` built and deployed. This milestone absorbed the M078 review finding R13 candidate row.

**Decisions:** none. The plan chose a condition on the deploy step over removing `workflow_dispatch`, and `default_branch` over a literal `refs/heads/main`.

**Review:** Fan-out of three fresh reviewers, with 6 findings. None found a fault in the condition. F5 was fixed at the gate: the comment now covers every run that skips. F1 and F2 became one candidate row. In F1, a branch run shares the `pkgdown-true` concurrency group and can cancel a queued deploy. In F2, every run gets `contents: write`. F3, F4, and F6 were rejected. F3 (`master` in the push trigger) is harmless with no `master` branch. F4 (prereleases deploy) and F6 (a release of an old tag deploys an older site) are behavior the plan keeps. The M011 lesson was extended: a manual run on a branch uses that branch's workflow file.
