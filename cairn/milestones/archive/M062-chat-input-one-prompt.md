# M062: A chat call aborts on a text input that is not one prompt

**Status:** done (2026-09-30, PR #62 https://github.com/jmgirard/rlmstudio/pull/62).

**Goal:** A chat call stops in R when a character `input` does not hold
exactly one prompt, and the message points to `lms_chat_batch()`.

**Outcome:** After `rlm_check_no_na(input, "input")`, three functions call
`rlm_check_one_prompt()` from R/utils-args.R. They are `lms_chat()`,
`lms_chat_native()`, and `lms_chat_openresponses()`. The server probe comes
later. A character `input` of length other than one aborts, with no condition
class. The message names `input`, the count, and `lms_chat_batch()`. A list
`input` is sent as given. The 2026-09-30 probes of the 400 replies are in
cairn/references/lmstudio-api-surface.md. Tests: test-input-length.R.

**Decisions:** D-036 (a character chat input must be one string).

**Review:** Three lenses, all five criteria passed on the first pass.
17 findings. The gate fixed D-003 citations in a code comment and the test
header, Air drift in the new test file, and a missing `info =`. A work-log line
corrected the T2 line. Four findings went to one candidate row. They are a
one-string matrix or `I()` input, a factor input, and an input with a class
jsonlite cannot write. The fourth is a two-string `content` in
`lms_chat_openai()`. Nine were rejected.
