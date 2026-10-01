# M068: A vignette shows batch chat, structured output, logprobs scores, and embeddings

**Status:** done (2026-09-30, PR #68 https://github.com/jmgirard/rlmstudio/pull/68).

**Goal:** A new vignette shows the text-analysis features that the two other
vignettes leave out, built live against LM Studio as they are.

**Outcome:** `vignettes/text-analysis.Rmd` shows a data-frame batch and schema
columns on the openai route. It scores `lms_chat()` logprobs with
`lms_score_expected()`. It also shows `lms_embed()`, `list_instances()`,
`lms_unload_all()`, and `rlmstudio.quiet`. It has four gates and pasted `#>`
output. If the build found no model loaded, the teardown unloads all.
Otherwise it unloads only its own instances. `test-vignette-claims.R` adds
four claim tests. NEWS has one entry.

**Decisions:** none cross-cutting. The plan gate chose a gated live
`lms_unload_all()` and a live build with pasted output. AC1 was amended to
read the `inst/doc/*.R` that `devtools::build()` writes.

**Review:** Three lenses, 5 of 5 criteria verified, no criterion failing.
The gate fixed two build breaks. An embed chunk used chat-gated text, and an
instances chunk failed with nothing loaded. It also fixed route and host
conditions in the prose and three claim tests. Two candidate rows were added
or extended, and nine findings were rejected. LESSONS M009 was corrected and
extended with the knit and purl gotchas.
