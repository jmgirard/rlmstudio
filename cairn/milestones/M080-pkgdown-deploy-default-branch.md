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

- [x] AC1: The `if:` line of the "Deploy to GitHub pages" step in `.github/workflows/pkgdown.yaml` is true in two cases only. The first case is the event `release`. The second case is a `github.ref` equal to `refs/heads/` joined to `github.event.repository.default_branch`. Evidence: the line as read from the branch.
- [x] AC2: A manual run of `pkgdown.yaml` on the milestone branch ends with the "Build site" step `success` and the "Deploy to GitHub pages" step `skipped`, as `gh run view <id> --json jobs` reports.

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

- AC1 evidence (2026-10-01, HEAD 0467147): `git show HEAD:.github/workflows/pkgdown.yaml` line 55, the deploy step `if:`, reads `github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`. The line is an OR of two equality tests. It is true for the event `release` and for a ref equal to `refs/heads/<default branch>`, and for nothing else. `yaml::read_yaml()` returns the same text for step 7 of 7.
- AC2 evidence (2026-10-01): `gh run view 36946984849` reports a `workflow_dispatch` run on `m080-pkgdown-deploy-default-branch` at f25259b, conclusion `success`. Its "Build site" step is `success` and its "Deploy to GitHub pages" step is `skipped`. `git diff f25259b HEAD -- .github` is empty, so the run used the workflow file that HEAD carries.
- Gate: `cairn_validate` passed all checks. `devtools::document()` left no diff. `pkgdown::check_pkgdown()` found no problems. The diff changes no user-visible behavior, so NEWS needs no entry. It adds no top-level file.
- Review fan-out: three fresh reviewers (Opus diff-bug, Sonnet blame-history, Sonnet prior-review). All three found the condition correct for each trigger. The prior-review lens found no regression of M075 or M078 review findings and no GitHub review comments. Findings, merged across lenses, most severe first:
  - F1 (all three lenses): the job concurrency group `pkgdown-${{ github.event_name != 'pull_request' || github.run_id }}` (line 22) is `pkgdown-true` for every run that is not a pull request. GitHub keeps one pending run per group, and a newer pending run cancels the older one. So a manual run on another branch can cancel a queued deploy from `main` or a release. This predates M080, but branch runs no longer deploy, so they no longer need the group.
  - F2 (diff-bug): the job grants `contents: write` to every run, which most runs no longer use. This predates M080.
  - F3 (all three lenses): the push trigger still lists `master`. A push to `master` would now build and skip the deploy. The repo has no `master` branch.
  - F4 (diff-bug): `release: types: [published]` includes prereleases, so a prerelease deploys. The comment says "a published release", and a prerelease is one. Unchanged behavior.
  - F5 (diff-bug): the comment names two skip cases and omits a manual run on a tag and a push to another branch. Nothing it states is false.
  - F6 (blame-history): a release of an old tag replaces the site with an older build. Unchanged behavior, and the plan keeps the release deploy.
