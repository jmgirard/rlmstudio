# M048: The embedding help page describes the cut of a text longer than the context

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — the help page of an exported function
- **Branch/PR:** —

## Goal

The `lms_embed()` help page says that LM Studio embeds only the start of a text longer than the loaded context.
It also says how to avoid the cut.

## Scope

**In:** a details paragraph on the `lms_embed()` help page and a live test that pins what it says. Also a NEWS
bullet and a dated record of the probe in `cairn/references/lmstudio-api-surface.md`.
The probe ran on LM Studio 0.4.25+1 on 2026-09-28 with text-embedding-nomic-embed-text-v1.5. At a 2048-token
context, a 5000-word text gave the same vector as its first 2500 words. At `context_length` 512, it gave the
same vector as its first 520 words. Its first 510 words gave a different vector. The reply carried status 200,
no error, and `usage` of 0 tokens. A short text also reports 0 tokens. `POST /v1/tokenize` and
`/api/v0/tokenize` answered "Unexpected endpoint or method".

**Out:** a warning from an estimated token count, and splitting a long text and combining the vectors. The
package cannot count tokens, so both go to one candidate row that names the evidence to promote it.

## Acceptance criteria

- [ ] AC1: The `lms_embed()` help page says that the server embeds only the first tokens of each text, up to the
      context length of the loaded model instance, as observed on LM Studio 0.4.25+1. It says that the server
      then returns a vector for the cut text with no error or warning. It says that the reply's `usage` field
      reported 0 tokens on that version, so the count does not show the cut. It names two ways to avoid the cut.
      The first is to split a long text before the call. The second is to load the model with a larger
      `context_length` through `lms_load()`, up to the `max_context_length` column of
      `list_models(detailed = TRUE)`.
- [ ] AC2: The cut that the `lms_embed()` help page describes holds on a live LM Studio server with
      text-embedding-nomic-embed-text-v1.5 loaded. Let N be the `context_length` of that loaded instance in
      `list_models(detailed = TRUE)`. One `lms_embed()` call sends three texts in one request. The first two texts
      share their first N words and differ only after them, and they get the same vector. The third text differs
      from the first only in its first word, and it gets a different vector. The call gives no warning. The same
      three texts with `simplify = FALSE` return a body whose `usage` reports 0 prompt tokens.
- [ ] AC3: `devtools::test()` and `devtools::check()` pass with 0 errors and 0 warnings, and
      `devtools::document()` leaves no diff.

## Coverage

- AC1 → T1, T3, T4
- AC2 → T2
- AC3 → T5

## Tasks

- [ ] T1: Record the probe facts from Scope in `cairn/references/lmstudio-api-surface.md` as a dated
      observation with the LM Studio version. Put it under the features of endpoints the package calls.
- [ ] T2: Add a live test after the existing live test in `tests/testthat/test-embed.R` (near line 1110). It skips
      as that test does and never loads a model. It reads N from the `loaded_instances` config of
      `list_models(detailed = TRUE)`. It builds the three texts from ordinary words, each at least one token.
      Assert the AC2 cases, with `expect_no_warning()` around the call. Run it live and record that it ran and did
      not skip, which is the review evidence for AC2. Plant a defect, such as a shared start of 10 words, and see
      it fail.
- [ ] T3: Add the AC1 paragraph to the `@details` of `R/embed.R`, written against the probe record from T1. Run
      `devtools::document()`.
- [ ] T4: Add a NEWS.md bullet under the development version that says what the help page now documents.
- [ ] T5: Run `devtools::test()`. Then run `devtools::check()` with `RLMSTUDIO_API_TOKEN` set and the server
      started (LESSONS, M009).

## Work log

- 2026-09-28: created by /milestone-plan.
- 2026-09-28: criteria audit (full) by a fresh [O] reader returned six findings. All six were fixed before the gate. The claims name LM Studio 0.4.25+1. N comes from the loaded instance. The third text differs in its first word. One request carries all texts. The test checks for no warning and for `usage`. AC2 states the server behavior, not the test.
- 2026-09-28: plan gate chose documenting the cut over a warning from an estimated token count. The server has no tokenize endpoint and reports 0 tokens, so an estimate fires wrongly in both directions. Falsified by an LM Studio reply or endpoint that gives a token count.
- 2026-09-28: plan gate chose documenting the cut over splitting a long text and averaging the vectors. That changes what a vector means and needs a token count that the package cannot get. Falsified by a user who needs one vector for a whole long document.

## Decisions

## Review
