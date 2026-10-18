# M082: The pkgdown deploy runs in its own job, and only that job can write or queue

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — a CI workflow that builds and deploys the package site, which no package user runs
- **Branch/PR:** m082-pkgdown-deploy-job, https://github.com/jmgirard/rlmstudio/pull/84

## Goal

A run of `pkgdown.yaml` that does not deploy the site can neither cancel a queued deploy nor get write access to the repository.

## Scope

**In:** Split the one `pkgdown` job of `.github/workflows/pkgdown.yaml` into a `build` job and a `deploy` job. The `build` job builds the site and uploads it as the artifact `site`, under the read-only workflow permissions. The `deploy` job runs only under the M080 deploy condition and alone holds `contents: write`. A workflow-level concurrency group puts each run that meets that condition in the group `pkgdown-deploy`, one run at a time. Every other run gets a group of its own. The comments in the file change to match. After the merge, the review records the first push run on `main`, which is the only run that can show a real deploy. If that run does not deploy, the fix goes to `/hotfix`.

**Out:** A prerelease that deploys and a release of an old tag that deploys an older site stay as they are, because M080 review findings F4 and F6 kept them. A move of the Pages source to GitHub Actions deployment is not planned (work log, plan gate). The other workflows keep their concurrency groups, because no candidate row names a fault in them.

## Acceptance criteria

- [x] AC1: `.github/workflows/pkgdown.yaml` has a job `build` that builds the site and uploads the `docs` folder as the artifact `site`, hidden files included (`include-hidden-files: true`). The job has no `permissions` key of its own, so it runs under the workflow-level `permissions: read-all`. A read of the file with `yaml::read_yaml()` shows this.
- [x] AC2: The same file has a job `deploy` with `needs: build` and `permissions: contents: write`. Its job-level `if:` is `github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`. Its steps check out the repository, then download the artifact `site` into `docs`, then run `JamesIves/github-pages-deploy-action@v4.5.0` with `clean: true`, `branch: gh-pages`, and `folder: docs`. A read of the file with `yaml::read_yaml()` shows this.
- [x] AC3: Of the jobs that `yaml::read_yaml()` returns for the file, only `deploy` carries a `permissions` key, and no job carries a `concurrency` key. The top-level `concurrency` key holds only the key `group`, with the value `pkgdown-${{ (github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)) && 'deploy' || github.run_id }}`. A loop over every job and a read of the top-level key show this.
- [x] AC4: A manual run on the milestone branch (`gh workflow run pkgdown.yaml --ref <branch>`) ends with the conclusion `success` for the `build` job and `skipped` for the `deploy` job. `gh run view <id> --json jobs` shows the two conclusions. `gh run download <id> -n site -D <dir>` puts `index.html` and `.nojekyll` directly in `<dir>`.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2, T4
- AC3 → T1, T2, T4
- AC4 → T3, T4

## Tasks

- [x] T1: Rewrite `.github/workflows/pkgdown.yaml` as AC1 to AC3 state. Keep the triggers, the workflow-level `permissions: read-all`, and the build steps of the `pkgdown` job (`pkgdown.yaml:28-49`) in `build`. Use `actions/upload-artifact@v4`, the version `test-coverage.yaml:66` uses, and the matching `actions/download-artifact`. Before the edit, read the GitHub Actions docs on whether a job that its `if:` skips takes its concurrency group, and record the answer in the work log. Replace the comment `# Only restrict concurrency for non-PR jobs` and move the deploy comment to the `deploy` job.
- [x] T2: Read the edited file with `yaml::read_yaml()` in a scratch script, not committed, and print the keys that AC1 to AC3 name for each job. Record the result in the work log.
- [x] T3: Push the branch and start a manual run with `gh workflow run pkgdown.yaml --ref m082-pkgdown-deploy-job`. Wait for it, then read the job conclusions and download the artifact as AC4 states. Record the run id in the work log.
- [x] T4: Remove the job-level group from `deploy` and add the top-level `concurrency` group that the amended AC3 states. Repeat the T2 parse check and the T3 manual run, and record the new run id.

## Work log

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: what to work on — "pkgdown workflow fixes", the candidate row "Two follow-ups to `pkgdown.yaml`", absorbed in full (M080 review findings F1 and F2).
- 2026-10-18: collision sweep: M080 (done) shipped the deploy condition, and this milestone extends it. No D-entry covers the pkgdown workflow. No other candidate row overlaps.
- 2026-10-18: inbox sweep: 0 open issues and 0 open pull requests on jmgirard/rlmstudio. No `Resolves:` entry.
- 2026-10-18: lessons: the M011 lesson says a manual run on a branch uses that branch's workflow file, so T3 gives pre-merge evidence. The M080 review says only a run after a merge can check the group, so the post-merge push run is recorded at review.
- 2026-10-18: plan gate chose a separate `deploy` job over one job with a read-only token and a personal access token for the deploy step, because GitHub sets token permissions per job and the token would need a new repository secret; falsified by GitHub adding per-step token permissions.
- 2026-10-18: plan gate chose the gh-pages branch deploy from an artifact over `actions/deploy-pages`, because the Pages source is the `gh-pages` branch (`gh api repos/jmgirard/rlmstudio/pages`, build_type `legacy`, read 2026-10-18) and a move changes a repository setting; falsified by GitHub ending branch-based Pages builds.
- 2026-10-18: `actions/download-artifact` is a CI action of the family `test-coverage.yaml` already uses, not a package dependency, so no D-entry. No NEWS entry, because no package behavior changes.
- 2026-10-18: criteria audit (reduced mode, fresh Opus reader): no bounded-promise, proportionality, or instrument finding. Five wording findings, all taken: upload-artifact v4 leaves out hidden files and would drop `.nojekyll` (AC1 now names `include-hidden-files: true`), the artifact is named `site` (AC1, AC2), the deploy job needs a checkout before the download (AC2), the file has no top-level concurrency key (AC3), and `gh run download` puts each artifact in a folder of its name unless `-n` and `-D` are given (AC4 now names them and checks `.nojekyll`).
- 2026-10-18: implement started on branch `m082-pkgdown-deploy-job`, cut from `main` at 171e449.
- 2026-10-18: T1 docs read: the GitHub workflow-syntax page and the concurrency page do not say whether a job that its `if:` skips takes its concurrency group. The `deploy` job keeps the literal group `pkgdown-deploy`, as AC2 states. Falsified by a branch or pull-request run whose skipped `deploy` job holds or cancels a pending deploy.
- 2026-10-18: T1 done: `pkgdown` job split into `build` and `deploy`. The comments were checked against the upload-artifact v4 README (hidden files left out from v4.4), the checkout v6 `clean` input (`git clean -ffdx` before fetch), and `pkgdown:::build_github_pages()` (writes `.nojekyll`). `actions/download-artifact@v4` matches the upload major.
- 2026-10-18: T2 done: a scratch `yaml::read_yaml()` script printed each job's keys. `build` has no `permissions` or `concurrency` key and uploads `docs` as `site` with `include-hidden-files: true`. `deploy` has `needs: build`, the M080 `if:`, `contents: write`, group `pkgdown-deploy`, and the steps checkout, download `site` into `docs`, and the deploy action with `clean`, `branch: gh-pages`, and `folder: docs`. The file has no top-level `concurrency` key.
- 2026-10-18: T3 done: manual run 39149477796 on 1a943f5 ended `success`, with `build` `success` and `deploy` `skipped`. `gh run download 39149477796 -n site -D <scratch>` put `index.html` and `.nojekyll` directly in the folder.
- 2026-10-18: verify: `devtools::test()` on 1a943f5 gave 0 failed, 0 errors, 3 skipped. The diff changes no R code. Status set to `review`.
- 2026-10-18: claim audit: not owed — internal tier.
- 2026-10-18: amendment routed: AC2 — diff-bug #1 and #2: a job-level group on `deploy` lets an older build deploy last, and a skipped `deploy` may hold the fixed group. The repair is a workflow-level group `pkgdown-deploy` under the deploy condition and a per-run group otherwise, with no job-level group, which AC2's `concurrency: group: pkgdown-deploy` on `deploy` forbids.
- 2026-10-18: amendment routed: AC3 — same findings. AC3 forbids a top-level `concurrency` key, which the repair needs.
- 2026-10-18: review fixes ea9aaaa for diff-bug #3 to #5: `retention-days: 1`, `overwrite: true`, and the checkout comment. Status set to `in-progress` for the AC2 and AC3 amendment alone.
- 2026-10-18: re-audit: AC2 (reduced) — nothing.
- 2026-10-18: re-audit: AC3 (reduced) — the wording did not rule out `cancel-in-progress: true`, which would break "one run at a time". Narrowed to "holds only the key `group`".
- 2026-10-18: re-audit: AC3 (reduced) — nothing. The reader noted that the group condition and the `deploy` `if:` can drift apart. AC2 and AC3 each pin the same condition string exactly, and AC1 pins `permissions: read-all`.
- 2026-10-18: amendment return: AC2 — "The same file has a job `deploy` with `needs: build` and `permissions: contents: write`."
- 2026-10-18: amendment return: AC3 — "Of the jobs that `yaml::read_yaml()` returns for the file, only `deploy` carries a `permissions` key, and no job carries a `concurrency` key. The top-level `concurrency` key holds only the key `group`, with the value `pkgdown-${{ (github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)) && 'deploy' || github.run_id }}`." The Scope In sentence on the group changed to match, and T4 was added for the work.
- 2026-10-18: T4 done in d353754: top-level group added, job-level group removed, comments updated. The parse check showed no job with a `concurrency` key, `deploy` alone with `permissions`, and a top-level `concurrency` of only `group`, identical to the AC3 value. Manual run 39150570451 on d353754 ended `success`, with `build` `success` and `deploy` `skipped`. Its `site` artifact held `index.html` and `.nojekyll` and expires 2026-10-19, one day after upload.
- 2026-10-18: verify: no R code changed since the clean `devtools::test()` on 1a943f5 and `devtools::check()` on e936d95. Status set to `review`.
- 2026-10-18: step-7 approval: m082-pkgdown-deploy-job approved for merge.
- 2026-10-18: PR #84 opened. CI red on three Ubuntu checks (test-coverage, R-CMD-check release and oldrel-1), all at `test-mock-http-helper.R:184`, where runner curl says "Out of memory" and the test expects "Malformed input to a URL function". The same failure is on `main` at 3ccfc28 (test-coverage run 39086632850), and the branch changes no R or test file. The user chose a hotfix first. Resume with `/milestone-review M082` after it merges, which brings `main` into this branch and re-runs CI.

## Decisions

## Review

Evidence gathered 2026-10-18 on e5f5f85. `main` at 171e449, the branch base, so no sync was needed.

- AC1: a scratch `yaml::read_yaml()` script read the file. Job `build` has no `permissions` key, the workflow `permissions` is `read-all`, step "Build site" runs `pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)`, and one `actions/upload-artifact@v4` step has `name: site`, `path: docs`, and `include-hidden-files: true`. Pass.
- AC2: the same script read job `deploy`: `needs` is `build`, `if` is identical to the stated condition, `permissions` is identical to `list(contents = "write")`, and `concurrency` is identical to `list(group = "pkgdown-deploy")`. The steps in order are `actions/checkout@v6`, `actions/download-artifact@v4` with `name: site` and `path: docs`, and `JamesIves/github-pages-deploy-action@v4.5.0` with `clean: true`, `branch: gh-pages`, and `folder: docs`. Pass.
- AC3: a loop over the 2 jobs the file holds (`build`, `deploy`) found `permissions` or `concurrency` on `deploy` alone. The file has no top-level `concurrency` key. Pass.
- AC4: run 39149477796 (`workflow_dispatch`, branch `m082-pkgdown-deploy-job`, head 1a943f5) ended `success`, with `build` `success` and `deploy` `skipped` (`gh run view --json jobs`, re-read at review). `git diff 1a943f5 HEAD -- .github` is empty, so the run used the workflow file under review. A fresh `gh run download 39149477796 -n site -D <scratch>` put `index.html` and `.nojekyll` directly in the folder. Pass.

Consistency gate on e936d95: `cairn_validate.py` all checks passed. `devtools::check()` 0 errors, 0 warnings, 0 notes, and the tree stayed clean, so `document()` made no diff. `pkgdown::check_pkgdown()` no problems. No principle changed, so no `cairn_impact` run. No changelog entry is owed, because no package behavior changes. README untouched.

spawned: diff-bug, blame-history, prior-review

- diff-bug #1: builds now run in parallel and a deploy joins `pkgdown-deploy` only when its build ends, so an older build that ends later deploys an older site last. The old job held its group from the start — amendment routed (AC2, AC3): AC3 forbids a concurrency key outside `deploy`, which the repair needs.
- diff-bug #2: if GitHub puts a job in its group before it reads the job's `if:`, a skipped `deploy` on a branch or pull-request run takes the fixed group `pkgdown-deploy` and can cancel a pending deploy. The docs do not settle it (work log, T1) — amendment routed (AC2, AC3), same repair as #1.
- diff-bug #3: every run keeps the `site` artifact for the default 90 days, and only the same run's `deploy` reads it — fix now, `retention-days: 1` (upload-artifact v4 README, Retention Period, 1 to 90 allowed), fixed ea9aaaa.
- diff-bug #4: a re-run of all jobs uploads `site` again into the same run, and v4 artifacts are immutable — fix now, `overwrite: true` (README, "Overwriting an Artifact"), fixed ea9aaaa.
- diff-bug #5: the comment "because it cleans the workspace" is imprecise. On a folder that holds no git repository, checkout deletes the folder contents before it clones (`src/git-directory-helper.ts:118-123` at v6) — fix now, comment reworded, fixed ea9aaaa.
- diff-bug #6 to #8: the handoff keeps `.nojekyll`, no CNAME is needed, nothing the old job did is lost, and the other comments are accurate — noted, no defect.
- blame-history #1: deploys can land out of order — amendment routed, same as diff-bug #1.
- blame-history #2: the real deploy path has not run under this file. Only a run on `main` can run it — reject, planned change: Scope names the first push run on `main` after the merge as the check, with `/hotfix` on failure.
- blame-history #3: the build job has no concurrency group, as M078 recorded pkgdown as the exception to the group pattern — reject, false as a defect: consistent with the record, and the amendment for #1 sets a workflow-level group.
- blame-history #4: a fixed artifact name conflicts on a re-run — fix now, same as diff-bug #4, fixed ea9aaaa.
- prior-review: no finding. The diff keeps the M080 F1, F2, and F5 fixes, the M078 manual-run guard, and the M075 CLAUDE.md step. The PR-comment probe returned no threads.

Pass 2, after the AC2 and AC3 amendment. Evidence gathered 2026-10-18 on 5514b4c. `main` is still at 171e449, the branch base.

- AC1: the scratch `yaml::read_yaml()` script read job `build`: no `permissions` key, workflow `permissions` `read-all`, step "Build site" runs `pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)`, and one `actions/upload-artifact@v4` step with `name: site`, `path: docs`, and `include-hidden-files: true` (plus `retention-days: 1` and `overwrite: true`). Pass.
- AC2: job `deploy`: `needs` is `build`, `if` is identical to the stated condition, and `permissions` is identical to `list(contents = "write")`. Steps in order: `actions/checkout@v6`, `actions/download-artifact@v4` with `name: site` and `path: docs`, then `JamesIves/github-pages-deploy-action@v4.5.0` with `clean: true`, `branch: gh-pages`, and `folder: docs`. Pass.
- AC3: a loop over the 2 jobs found `permissions` on `deploy` alone and `concurrency` on no job. The top-level `concurrency` has the one key `group`, identical to the stated value. Pass.
- AC4: run 39150570451 (`workflow_dispatch`, branch `m082-pkgdown-deploy-job`, head d353754) ended `success`, with `build` `success` and `deploy` `skipped`. `git diff d353754 HEAD -- .github` is empty. A fresh `gh run download 39150570451 -n site -D <scratch>` put `index.html` and `.nojekyll` directly in the folder. Pass.

spawned: diff-bug, blame-history, prior-review

- diff-bug #1: the `deploy` steps have not run, because both manual runs skipped `deploy` — reject, planned change: Scope names the first push run on `main` after the merge as the check.
- diff-bug #2: with `retention-days: 1`, re-running only `deploy` more than a day after the build fails at the download. Re-running all jobs works, because of `overwrite: true` — fix now, the comment above the upload says to re-run all jobs after one day, fixed 8e7c724.
- diff-bug #3: a pending release run and a pending push run on `main` share one slot, so a release of an older tag can replace a newer pending push and deploy an older site. The old group `pkgdown-true` did the same, and M080 review finding F6 kept old-tag deploys — follow-up, `[low]` candidate row written at hygiene.
- diff-bug #4: the deploy condition is written twice, in the group and in the `deploy` `if:`, and only a comment ties them — reject, planned change: amended AC2 and AC3 pin both strings, and a workflow-level group cannot read a job's `if:`.
- diff-bug #5: the expression is valid at workflow level, and no other workflow can produce `pkgdown-deploy` — noted, no defect.
- diff-bug #6: pull-request runs get their own group with no `cancel-in-progress`, so a stale pull-request run is not cancelled, unlike the other workflows. The old file did the same — follow-up, same `[low]` candidate row as #3.
- diff-bug #7: the checkout comment leaves implicit that the checkout would wipe a site downloaded first — fix now, comment says so, fixed 8e7c724.
- diff-bug #8 to #11: the handoff is correct, the token permissions suffice, `main` has no branch protection that names the old check, and nothing the old job did is lost — noted, no defect.
- blame-history #1: a re-run of `deploy` alone fails after one day — fix now, same as diff-bug #2, fixed 8e7c724.
- blame-history #2: a manual branch run can now run beside a queued deploy. It writes nothing — reject, planned change: the M080 F1 fix.
- blame-history #3: `build` drops `contents: write` — reject, planned change: the M080 F2 fix.
- blame-history #4: the condition is written twice — reject, same as diff-bug #4.
- blame-history #5: a re-run of a run that does not deploy keeps its run-id group — reject, false as a defect: a re-run starts after the first attempt ends, so nothing waits on the first attempt.
- prior-review #1: the pkgdown group differs in shape from the other four workflows, which M078 set to `${{ github.workflow }}-${{ github.ref }}` — reject, planned change: M080 F1 needs a deploy-only group, and the lens itself calls it a deliberate divergence.
- After 8e7c724: `git diff d353754 HEAD -- .github` changes comment lines only, and the parse check still passes AC1 to AC3, so the AC4 run stands for the file.

Resume after the hotfix, 2026-10-18. PR #84 was open with every box ticked and an approval recorded, so route (c) re-ran step 1. `main` had moved to 8b7ad16 (PR #85, the test fix), and merge f0605b5 brought it into the branch. The merge changed only `tests/testthat/test-mock-http-helper.R`.

- AC1 to AC3: the parse check on f0605b5 gives the same results as pass 2. Pass.
- AC4: `git diff d353754 f0605b5 -- .github` changes comment lines only, so run 39150570451 stands for the file. Pass.
- `devtools::test()` on f0605b5: 0 failed, 0 errors, 3 skipped.
