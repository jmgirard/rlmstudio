<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M011: The macOS check job installs its dependencies again

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal. It changes one CI workflow file and ships no package code
- **Branch/PR:** `m011-macos-check-job`

## Goal

The `macos-latest (release)` job of `R-CMD-check.yaml` installs its
dependencies and runs the check while CRAN serves zstd macOS binaries.

## Scope

**In:** `.github/workflows/R-CMD-check.yaml`. The `setup-r` step gets
`use-public-rspm: always`. A macOS-only step sets `PKG_CRAN_MIRROR` to
`https://packagemanager.posit.co/cran/latest` and blocks `mac.cran.dev` in
`/etc/hosts`. Comments name the cause and the condition to remove the step.
The M009 lesson, which names the wrong cause, is corrected in place.

**Out:** `pkgdown.yaml`, `test-coverage.yaml`, and `test-headless.yaml`. All
three run on Ubuntu only, so the zstd binaries never reach them. Pinning macOS
to R 4.5 is the rejected alternative and keeps a candidate row. Removing this
workaround keeps its own candidate row. Merging M010 happens at M010's own gate
once this lands. Unifying the four workflow files stays a candidate row.

## Acceptance criteria

- [ ] AC1: The `macos-latest (release)` job on this milestone's pull request
      passes. Evidence: the `gh pr checks` line naming that job, with its run
      URL.
- [ ] AC2: The dependency-install step of that passing job logs no
      `unknown archive type` failure. Evidence: a grep of that job's log for
      that string, returning nothing.
- [x] AC3: The diff of this milestone against the default branch changes
      exactly one file under `.github/workflows/`, and that file is
      `R-CMD-check.yaml`. Evidence: `git diff --name-only <base>...HEAD`
      filtered to that path.
- [x] AC4: `.github/workflows/R-CMD-check.yaml` carries a comment naming why
      the macOS-only step exists and the condition under which it is removed.
      Evidence: the comment quoted from the file on the merged tree.
- [x] AC5: `Rscript -e 'devtools::test()'` and `Rscript -e 'devtools::check()'`
      are clean on the branch. Evidence: the reported failure, error, warning,
      and note counts.

## Coverage

- AC1 → T1, T3
- AC2 → T1, T3
- AC3 → T1
- AC4 → T1
- AC5 → T3

## Tasks

- [x] T1: Edit `.github/workflows/R-CMD-check.yaml`. Add
      `use-public-rspm: always` to the `setup-r` step. Add a macOS-only step
      after it that sets `PKG_CRAN_MIRROR` to
      `https://packagemanager.posit.co/cran/latest` and appends
      `127.0.0.1 mac.cran.dev` to `/etc/hosts`. Comment both edits with the
      cause and the revert condition. Change no other workflow file.
- [x] T2: Correct the 2026-09-20 (M009) lesson in `cairn/LESSONS.md` in place,
      marked `corrected M011`. It names the mirror lag as the cause. The real
      cause is that CRAN's macOS R 4.6 binaries are zstd. The installed pak
      cannot extract them. `mac.cran.dev` races the primary download rather
      than only lagging it.
- [x] T3: Run the local checks and record the reported counts. The pull
      request is opened at the review gate, so the macOS job evidence for AC1
      and AC2 is read there: the run URL, the reported state, and the grep for
      `unknown archive type`.

## Work log

- 2026-09-20: created by /milestone-plan.
- 2026-09-20: plan gate chose the circumplex fix over routing to Package Manager alone. That repo's comment records the installer still reaching CRAN for two packages. Falsified by a macOS job that fails with the full fix in place.
- 2026-09-20: plan gate chose the circumplex fix over pinning macOS to R 4.5. D-002 commits the project to the release R on macOS. Falsified by Package Manager dropping its gzip macOS binaries or its R 4.6 path.
- 2026-09-20: plan gate chose a separate milestone over folding the fix into M010's branch. M010 already passed its review gate. Falsified by the fix proving unverifiable apart from that branch.
- 2026-09-20: the macOS job runs on the `pull_request` trigger only. The `push` trigger is filtered to the default branch. AC1 and AC2 therefore take their evidence at the review gate.
- 2026-09-20: evidence pinned 2026-09-20. `knitr_1.52.tgz` begins `28 b5 2f fd` at `cran.rstudio.com` and at `cloud.r-project.org`. It begins `1f 8b` at `packagemanager.posit.co`. The R 4.5 macOS build is `1f 8b`. jmgirard/circumplex#174 merged the same fix and its macOS job passed.
- 2026-09-20: criteria audit, reduced mode. A fresh reader read all five criteria and returned no findings.
- 2026-09-20: T1 done. `R-CMD-check.yaml` sets `use-public-rspm: always` and adds a macOS-only step that sets `PKG_CRAN_MIRROR` to Package Manager and points `mac.cran.dev` at `127.0.0.1`. Both edits carry the cause and the revert condition. `yaml.safe_load` parses the file and places the new step between `setup-r` and `setup-r-dependencies`.
- 2026-09-20: T2 done. The M009 lesson is corrected in place, marked `corrected M011`. LESSONS.md is 34 lines and 6119 bytes, inside both caps.
- 2026-09-20: T3 done. `devtools::test()` reports 0 failures, 0 warnings, 0 skips, 281 passes. `devtools::check()` reports 0 errors, 0 warnings, 0 notes. The first check run died at vignette build because the local server requires a token that the environment did not carry. The user chose to supply it, and the run above carries it.
- 2026-09-20: minor amendment. T3 reworded. The local checks stay with implement. The pull request evidence for AC1 and AC2 is read at the review gate, as the trigger line above already recorded. No criterion, scope, or task count changed.
- 2026-09-20: claim audit: not owed, internal tier.
- 2026-09-20: the writing lint counts the five empty header slots as violations. `cairn_validate` requires that character in them. The validator is the machine reader and wins, as recorded in M010.
- 2026-09-20: review checkpoint, partial. AC3, AC4, and AC5 verified against fresh evidence and ticked. AC1 and AC2 stay unticked and wait on the pull request's macOS job. The consistency gate is green. The independent review is still running.
- 2026-09-20: step-7 approval: m011-macos-check-job approved for merge.
- 2026-09-20: review checkpoint. Three lenses ran. Two returned no findings. The diff-bug lens returned six, none of them a floor return. Four were fixed now in the workflow comment and the hosts lines, one was rejected as a duplicate of an existing candidate row, and one was noted. Status stays `review`.

## Decisions

## Review

- AC1: pending. The `macos-latest (release)` job runs on the `pull_request`
  trigger only, and no pull request exists before the review gate. Evidence is
  read at step 8, from the `gh pr checks` line and its run URL.
- AC2: pending, for the same reason. The grep of the job log runs against the
  same run.
- [x] AC3: `git diff --name-only origin/main...HEAD` returns four paths:
  `.github/workflows/R-CMD-check.yaml`, `cairn/LESSONS.md`, `cairn/ROADMAP.md`,
  and `cairn/milestones/M011-macos-check-job.md`. Filtered to
  `.github/workflows/`, it returns exactly one path, and that path is
  `R-CMD-check.yaml`. The other three are tracking files.
- [x] AC4: the file carries both. The cause: CRAN serves its macOS R 4.6
  binaries as zstd archives under the `.tgz` name, and the pak that
  `setup-r-dependencies` installs rejects them as `unknown archive type`
  (`r-lib/pkgdepends#485`). The revert condition, quoted from the file: "Drop
  this step, and set use-public-rspm back to true, once a released pak extracts
  zstd."
- [x] AC5: run on the branch head with `RLMSTUDIO_API_TOKEN` set.
  `devtools::test()` reports 0 failures, 0 warnings, 0 skips, 281 passes.
  `devtools::check()` reports 0 errors, 0 warnings, 0 notes, status OK, on
  rlmstudio 0.2.2.9000.

### Consistency gate

- `cairn_validate.py`: exit 0, all checks passed.
- `cairn_impact.py`: not run. The milestone touches no DESIGN principle
  (`Principles touched: —`).
- `devtools::document()`: produces no diff. The working tree stays clean after
  the run.
- Generated files: the diff touches no `R/`, `man/`, `NAMESPACE`, `DESCRIPTION`,
  or `data/` path, and the no-diff `document()` run confirms no drift.
- README: `README.Rmd` and `README.md` were last written by the same commit and
  this diff touches neither, so they stay in sync.
- pkgdown: no `_pkgdown.yml` in the repo, so `check_pkgdown()` does not apply.
- `NEWS.md`: no entry owed. The milestone changes one CI workflow and ships no
  user-visible change.
- `.Rbuildignore`: no new top-level file, and `check()` reports no notes.

### Independent review

Three fresh-context lenses. The diff touches an executable surface, a CI
workflow with a shell `run:` block, so the full fan-out ran rather than the
single-lens internal-tier route.

- Blame-history lens: no findings. It confirms the `LESSONS.md` edit follows
  that file's own in-place correction rule, that `git log` shows
  `use-public-rspm` was never set before, so `always` reverts no earlier
  choice, and that nothing in `DECISIONS.md` is contradicted. It adds one
  non-blocking observation: the step edits `/etc/hosts` under `sudo`, which is
  a real system change on the runner and is worth the maintainer's eye.
- Prior-review-record lens: no findings. The `gh api` probe for inline review
  comments returned an empty array, so no walk ran. The archived `M002` and
  `M009` review sections hold the only prior findings on these files, and this
  diff reintroduces or contradicts none of them.
- Diff-bug lens: six findings, triaged below. It verified the mechanism
  against the upstream `setup-r` and `pkgcache` sources and reports no
  blocking correctness bug: `always` changes nothing for the Ubuntu and
  Windows jobs, `PKG_CRAN_MIRROR` is the correct pak variable, the step
  ordering and the `runner.os` literal are right, and a refused connection to
  `127.0.0.1` fails fast rather than hanging.

Findings and their disposition. The claims in findings 2 and 3 were checked
against the `pkgcache` 2.2.5.9000 sources that the installed pak carries,
not against the reviewer's account of them. `cmc__get_repos()` does assign
`repos[["CRAN"]] <- cran_mirror`, strip trailing slashes, and then keep the
first of any duplicated URLs, and both `packages_make_sources()` gates read
`type == "cran"`. Both findings hold.

1. "The hosts block is IPv4-only, and `mac.cran.dev` publishes an AAAA
   record." Fixed now. The step writes an `::1` line beside the `127.0.0.1`
   one.
2. "The comment asserts a mechanism that the other half of the fix has
   already disabled, which will mislead a reader deciding whether the hosts
   line is still needed." Fixed now. The comment now states that the hosts
   lines are a backstop, that no `cran`-typed repo survives while the two
   URLs match exactly, and that the row returns if they ever differ.
3. "The CRAN source-Archive fallback goes away on macOS, gated on the same
   `cran` type." Rejected as a separate follow-up, and fixed as a
   documentation gap. The consequence is now named in the comment. Its only
   remedy is removing the workaround, which the existing candidate row
   already carries, so a second row would duplicate it.
4. "Package Manager becomes a single point of failure for the macOS job, and
   the comment does not say so." Fixed now, as documentation. The comment
   names the outage case. The plan gate already recorded Package Manager
   dropping its gzip macOS binaries as the falsifier, and the candidate row
   for pinning macOS to R 4.5 carries that case.
5. "The revert instruction says to set `use-public-rspm` back to true, but
   the default branch has no such line." Fixed now. The comment says to set
   it to true rather than back to true, and the `setup-r` comment states what
   the default does.
6. "AC1 and AC2 remain unverified, and the gate should not close before the
   pull request's macOS job is read." Noted, not a defect. This is what the
   plan chose and what the Review section above records. Step 8 reads that
   job, and the merge does not proceed on a red or unread macOS check.

No finding demonstrates an acceptance criterion failing, and none is a
load-bearing defect in what the package does for its users, so the return
floor does not fire and the status stays `review`.
