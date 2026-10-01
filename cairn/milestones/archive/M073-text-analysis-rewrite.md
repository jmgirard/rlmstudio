# M073: The text-analysis vignette scores a data frame of texts in plain code

**Status:** done (2026-10-01, PR #73 https://github.com/jmgirard/rlmstudio/pull/73).

**Goal:** A researcher can follow `text-analysis` from a data frame of texts
to new columns of summaries, labels, scores, and similarities.

**Outcome:** `vignettes/text-analysis.Rmd.orig` is rewritten and knitted. Six
reviews get summaries from `lms_chat_batch()`, and schema labels and stars.
A `logprobs` batch is scored by `lms_score_expected()` in a `for` loop. A
long input fails, and `lms_embed()` gives similarities through a helper. It
tells the reader to unload an already-loaded copy by its `list_instances()`
id. `test-vignette-claims.R` backs each package claim. NEWS has one entry.

**Decisions:** none cross-cutting. The gate kept the long review in every
section and compared each review with one query.

**Review:** One defect return. The context-length sentence counted the
reply, but a 128-token context gave a 299-token reply in a live probe. Pass 2
passed all 6 criteria with three lenses. The gate fixed 10 findings: the
load advice, six prose points, and two tests. Fourteen were rejected. A
scoring-function row was added. The reply fact went to the API reference.
