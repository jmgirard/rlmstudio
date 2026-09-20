# M011: The macOS check job installs its dependencies again

**Status:** done (2026-09-20, PR #12 https://github.com/jmgirard/rlmstudio/pull/12)

**Goal:** The `macos-latest (release)` job of `R-CMD-check.yaml` installs its
dependencies and runs the check while CRAN serves zstd macOS binaries.

**Outcome:** `R-CMD-check.yaml` routes the macOS job to Posit Package Manager.
`use-public-rspm: always` on `setup-r` puts it first. A macOS-only step sets
`PKG_CRAN_MIRROR` to that same URL, because `setup-r` keeps CRAN as a second
repo, and writes `127.0.0.1` and `::1` hosts entries for `mac.cran.dev`, which
pkgcache otherwise races as a second download URL. A comment names the cause,
the backstop, two macOS-only consequences, and the removal condition. No
package code changed. The `M009` lesson, which named mirror lag as the cause,
was corrected in place.

**Decisions:** none.

**Review:** three-lens fan-out. Two lenses found nothing. The diff-bug lens
found six, none a floor return. Four were fixed on the branch: an `::1` hosts
line, and a comment rewritten to call the hosts lines a backstop, to name the
lost source-Archive fallback and the single-source risk, and to correct a
revert instruction. One duplicated the existing removal row. The sixth, that
AC1 and AC2 were unverified, was answered at step 8: the macOS job passed on
run 35532181214 with no `unknown archive type` in its log.
