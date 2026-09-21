# M017: The OpenAI chat call takes a JSON schema and returns the parsed answer

**Status:** done (2026-09-21, PR #17 https://github.com/jmgirard/rlmstudio/pull/17,
every check green, squash 8c2289b)

**Goal:** `lms_chat_openai()` takes a JSON schema, sends the structured-output
request that LM Studio documents, and returns the reply as a parsed R value.

**Outcome:** `lms_chat_openai()`, `lms_chat()`, and `lms_chat_batch()` take
`schema`. `schema_response_format()` builds the `response_format` body.
`parse_schema_reply()` parses the content with `jsonlite::parse_json()`. It
aborts through `rlm_abort_bad_response()`. `rlm_check_schema()` and
`rlm_check_schema_route()` run above the server probe. `rlm_chat_dots()` reads
the batch dots as `lms_chat()` matches them. The `chat_schema_live` cassette
comes from `data-raw/record-schema-cassette.R`.

**Decisions:** D-009 narrows the DESIGN contract boundary. The plan gate chose
a parsed reply, an abort on a non-openai `api_type`, and a fixed schema name.

**Review:** Three-lens fan-out, user-facing tier, 13 findings. Four were fixed
at the gate: shortened `api_type` and `logprobs` names in the batch call, the
`lms_chat()` return docs, and the recorder order. Four went to three candidate
rows. Five were rejected, among them a NEWS blank line that follows the file's
convention. All CI checks passed.
