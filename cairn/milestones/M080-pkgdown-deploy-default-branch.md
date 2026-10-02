<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M080: A pkgdown run deploys the site only from the default branch or a release

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal, because no package user relies on the GitHub Actions workflows
- **Branch/PR:** m080-pkgdown-deploy-default-branch

## Goal

A run of `pkgdown.yaml` deploys the site to `gh-pages` only from the default branch or from a published release.

## Scope

**In:** The `if:` condition of the "Deploy to GitHub pages" step in `.github/workflows/pkgdown.yaml`, and a comment above that step that says which runs deploy. A manual run on another branch still builds the site, so it stays a build check. A manual run on the default branch still deploys.

**Out:** The triggers of `pkgdown.yaml` stay as they are, `workflow_dispatch` included (M078 gave every workflow a manual start). The other four workflows have no deploy step. The check that a push to `main` deploys after the merge belongs to the post-merge hygiene of `/milestone-review`, because no run before the merge can show it.

## Acceptance criteria

- [ ] AC1: The `if:` line of the "Deploy to GitHub pages" step in `.github/workflows/pkgdown.yaml` is true in two cases only. The first case is the event `release`. The second case is a `github.ref` equal to `refs/heads/` joined to `github.event.repository.default_branch`. Evidence: the line as read from the branch.
- [ ] AC2: A manual run of `pkgdown.yaml` on the milestone branch ends with the "Build site" step `success` and the "Deploy to GitHub pages" step `skipped`, as `gh run view <id> --json jobs` reports.

## Coverage

- AC1 → T1
- AC2 → T2

## Tasks

- [x] T1: Replace `if: github.event_name != 'pull_request'` at `.github/workflows/pkgdown.yaml:52` with `if: github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`. A pull request run has the ref `refs/pull/<n>/merge`, so it stays skipped. Add a comment above the step that says which runs deploy. Checkpoint-commit and push the branch.
- [x] T2: Start a manual run with `gh workflow run pkgdown.yaml --ref <branch>`, wait for it to end, and record the run id and both step results in the work log. If the deploy step shows `success`, the branch site reached `gh-pages`. Then re-run the latest pkgdown run on `main` to restore the site, and return to T1.

## Work log

- 2026-10-01: created by /milestone-plan. Absorbs the M078 review finding R13 candidate row. That row said only a run after a merge can check the fix. A manual run uses the workflow file of its branch, so a run on the milestone branch shows the skip before the merge.
- 2026-10-01: criteria audit (reduced mode, internal tier) by a fresh Opus reader returned no findings on AC1 or AC2. It noted one limit: when the site build fails for a reason outside this change, AC2 also fails.
- 2026-10-01: plan gate chose a deploy-step condition over removing `workflow_dispatch`, because the removal drops the branch build check and the manual redeploy; falsified by a branch run that deploys under the new condition.
- 2026-10-01: plan chose `github.event.repository.default_branch` over a literal `refs/heads/main`, because tracking names no branch; falsified by a post-merge push run on `main` that skips the deploy.
- 2026-10-01: status in-progress on branch `m080-pkgdown-deploy-default-branch`. Plan left no implementation choice open, so the question gate was skipped.
- 2026-10-01: T1 done. The deploy step `if:` now reads `github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`, with a comment above it. `yaml::read_yaml()` parses the file and returns that line for step 7 of 7.
- 2026-10-01: T2 done. Manual run 36946984849 (`workflow_dispatch` on the branch at f25259b) ended `success`, with "Build site" `success` and "Deploy to GitHub pages" `skipped`.
- 2026-10-01: verify slot: `devtools::test()` gave 0 failures and 0 errors, with 3 skips. The diff changes no R code.
- 2026-10-01: claim audit: not owed — internal tier
- 2026-10-01: status review.

## Decisions

## Review
