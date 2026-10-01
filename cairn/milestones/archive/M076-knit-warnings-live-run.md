# M076: The vignette knit fails on an unmarked warning and stale output, and a release has live-run steps

**Status:** done (2026-10-01, PR #76 https://github.com/jmgirard/rlmstudio/pull/76).

**Goal:** Before a release, a written live run checks the tests, cassettes,
and vignettes against LM Studio. The vignette knit refuses a warning that no
chunk expects and output older than its source.

**Outcome:** `data-raw/knit-vignettes.R` wraps the knitr `warning` hook. If a
chunk without `expect_warning = TRUE` shows a warning, the source fails and
its `.Rmd` is not written. The last line of each `.Rmd` holds the MD5 of its
source. `tests/testthat/test-vignette-knit.R` fails for each source whose sum
differs or is absent, and skips with no source. The 4 warning chunks of
`text-analysis.Rmd.orig` carry the option. `data-raw/README.md` gives the
release live-run steps, maps the 10 tracked `tests/testthat` directories to a
recorder or a remove-and-rerun route, and names 3 models. PROFILE points to it.

**Decisions:** none cross-cutting. The plan gate chose a failing knit over a
warning list with exit 0, and a README with a PROFILE pointer over a script.

**Review:** AC5 took one amendment return, to directories from `git ls-tree`
and models from the recorder headers. Three lenses gave 17 findings. The gate
fixed D2 (`warning = NA` passes, now stated), D7 (plural message), and D9
(PROFILE step list). D1 and D3 went to one candidate row. The CI wait hit its
time limit once. Two lessons extended (M009, M011).
