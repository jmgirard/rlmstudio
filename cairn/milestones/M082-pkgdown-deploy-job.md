# M082: The pkgdown deploy runs in its own job, and only that job can write or queue

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — a CI workflow that builds and deploys the package site, which no package user runs
- **Branch/PR:** m082-pkgdown-deploy-job

## Goal

A run of `pkgdown.yaml` that does not deploy the site can neither cancel a queued deploy nor get write access to the repository.

## Scope

**In:** Split the one `pkgdown` job of `.github/workflows/pkgdown.yaml` into a `build` job and a `deploy` job. The `build` job builds the site and uploads it as the artifact `site`, under the read-only workflow permissions. The `deploy` job runs only under the M080 deploy condition, alone holds `contents: write`, and alone joins the concurrency group `pkgdown-deploy`. The comments in the file change to match. After the merge, the review records the first push run on `main`, which is the only run that can show a real deploy. If that run does not deploy, the fix goes to `/hotfix`.

**Out:** A prerelease that deploys and a release of an old tag that deploys an older site stay as they are, because M080 review findings F4 and F6 kept them. A move of the Pages source to GitHub Actions deployment is not planned (work log, plan gate). The other workflows keep their concurrency groups, because no candidate row names a fault in them.

## Acceptance criteria

- [ ] AC1: `.github/workflows/pkgdown.yaml` has a job `build` that builds the site and uploads the `docs` folder as the artifact `site`, hidden files included (`include-hidden-files: true`). The job has no `permissions` key of its own, so it runs under the workflow-level `permissions: read-all`. A read of the file with `yaml::read_yaml()` shows this.
- [ ] AC2: The same file has a job `deploy` with `needs: build`, `permissions: contents: write`, and `concurrency: group: pkgdown-deploy`. Its job-level `if:` is `github.event_name == 'release' || github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`. Its steps check out the repository, then download the artifact `site` into `docs`, then run `JamesIves/github-pages-deploy-action@v4.5.0` with `clean: true`, `branch: gh-pages`, and `folder: docs`. A read of the file with `yaml::read_yaml()` shows this.
- [ ] AC3: Of the jobs that `yaml::read_yaml()` returns for the file, only `deploy` carries a `permissions` key or a `concurrency` key, and the file has no top-level `concurrency` key. A loop over every job shows this.
- [ ] AC4: A manual run on the milestone branch (`gh workflow run pkgdown.yaml --ref <branch>`) ends with the conclusion `success` for the `build` job and `skipped` for the `deploy` job. `gh run view <id> --json jobs` shows the two conclusions. `gh run download <id> -n site -D <dir>` puts `index.html` and `.nojekyll` directly in `<dir>`.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3

## Tasks

- [x] T1: Rewrite `.github/workflows/pkgdown.yaml` as AC1 to AC3 state. Keep the triggers, the workflow-level `permissions: read-all`, and the build steps of the `pkgdown` job (`pkgdown.yaml:28-49`) in `build`. Use `actions/upload-artifact@v4`, the version `test-coverage.yaml:66` uses, and the matching `actions/download-artifact`. Before the edit, read the GitHub Actions docs on whether a job that its `if:` skips takes its concurrency group, and record the answer in the work log. Replace the comment `# Only restrict concurrency for non-PR jobs` and move the deploy comment to the `deploy` job.
- [x] T2: Read the edited file with `yaml::read_yaml()` in a scratch script, not committed, and print the keys that AC1 to AC3 name for each job. Record the result in the work log.
- [ ] T3: Push the branch and start a manual run with `gh workflow run pkgdown.yaml --ref m082-pkgdown-deploy-job`. Wait for it, then read the job conclusions and download the artifact as AC4 states. Record the run id in the work log.

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

## Decisions

## Review
