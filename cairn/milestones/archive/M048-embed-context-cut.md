# M048: The embedding help page describes the cut of a text longer than the context

**Status:** done (2026-09-28, PR #48 https://github.com/jmgirard/rlmstudio/pull/48)

**Goal:** The `lms_embed()` help page says that LM Studio embeds only the
start of a text longer than the loaded context. It says how to avoid the cut.

**Outcome:** A details paragraph on the `lms_embed()` page states the cut on
LM Studio 0.4.25+1: no error or warning, and `usage` of 0 tokens. It names
where the loaded `context_length` shows, and two ways to avoid the cut. One is
to split the text. The other is `lms_unload()` then `lms_load()` with a larger
`context_length`. A live test sends four texts in one request and pins the cut
between the midpoint and the end of the context. The probe record is in
`cairn/references/lmstudio-api-surface.md`. NEWS has a bullet.

**Decisions:** none. The plan gate chose documenting over a warning or
splitting. The candidate row names the evidence that reopens it.

**Review:** All three criteria passed. The prior-review lens found nothing,
the history lens 3 findings, the diff lens 9. The gate fixed seven: the unload
step, a lower bound in the test, a one-instance skip, NEWS wording and order,
and a test comment. A live probe refuted O2. O8 and O9 were rejected, and O4
became a candidate row.
