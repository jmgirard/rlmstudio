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
- [ ] AC3: The diff of this milestone against the default branch changes
      exactly one file under `.github/workflows/`, and that file is
      `R-CMD-check.yaml`. Evidence: `git diff --name-only <base>...HEAD`
      filtered to that path.
- [ ] AC4: `.github/workflows/R-CMD-check.yaml` carries a comment naming why
      the macOS-only step exists and the condition under which it is removed.
      Evidence: the comment quoted from the file on the merged tree.
- [ ] AC5: `Rscript -e 'devtools::test()'` and `Rscript -e 'devtools::check()'`
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

## Decisions

## Review
