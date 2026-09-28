# M045: The OpenAI chat function refuses a number that jsonlite writes as a string or drops

**Status:** done (2026-09-28, PR #45 https://github.com/jmgirard/rlmstudio/pull/45)

**Goal:** `lms_chat_openai()` refuses, before the server probe, a number in
`messages` that jsonlite writes as a string or leaves out with no
missing-field reason.

**Outcome:** `has_unsendable_number()` in `R/utils-args.R` runs between the
non-vector rule and the trial write. It refuses an `NA`, `NaN`, `Inf`, or
`-Inf` in a double or integer vector with no class or the class `"AsIs"`.
In an atomic data-frame column with no `dim`, it refuses `Inf` and `-Inf`
alone. `written_as_list()` lets the walk enter a classed list that jsonlite
writes as a plain list. The help, the roxygen, NEWS, and tests match.

**Decisions:** two milestone-local entries. The second corrects the first.
The walk enters a classed list that jsonlite writes as the bare list. It
skips a `POSIXlt`.

**Review:** Defect return 1 at AC4, because two roxygen blocks did not state
the plain-column case. On the fix, the claim audit found the `c("foo",
"list")` gap, which was fixed with a test. Pass 2 was a three-lens fan-out,
and all five criteria passed. The gate fixed O5 to O7 (NEWS, roxygen, and
edge tests). O1 to O4 and O8 became or joined candidate rows. B1 was
rejected. No lessons changed.
