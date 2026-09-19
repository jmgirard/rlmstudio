# LM Studio API surface, and what rlmstudio does not wrap

Synthesis note. Read on 2026-09-19 from the official LM Studio documentation
(`lmstudio.ai/docs`) and its source repository (`github.com/lmstudio-ai/docs`,
branch `main`). Package coverage read from `R/` and `NAMESPACE` at commit
c747098.

This page records the API surface as documented. It proposes nothing. A
feature that the project decides to build becomes a ROADMAP candidate or a
milestone.

## Sources

- REST overview and endpoint list: `https://lmstudio.ai/docs/developer/rest`
- Native endpoint pages: `1_developer/2_rest/{chat,list,load,unload,download,download-status,stateful-chats,streaming-events}.md` in `lmstudio-ai/docs`
- OpenAI compatible pages: `1_developer/3_openai-compat/{chat-completions,completions,embeddings,models,responses,structured-output,tools}.md`
- Anthropic compatible page: `1_developer/4_anthropic-compat/messages.md`
- Core pages: `1_developer/0_core/{authentication,ttl-and-auto-evict,mcp,headless,lmlink}.mdx`
- API changelog: `1_developer/api-changelog.md`
- CLI reference: `https://lmstudio.ai/docs/cli`

## Endpoint coverage

| Endpoint | Method | rlmstudio | Notes |
|---|---|---|---|
| `/api/v1/models` | GET | `list_models()` | Returns six core columns by default. `detailed = TRUE` returns every field. |
| `/api/v1/models/load` | POST | `lms_load()` | |
| `/api/v1/models/unload` | POST | `lms_unload()`, `lms_unload_all()` | |
| `/api/v1/models/download` | POST | `lms_download()` | |
| `/api/v1/models/download/status/:job_id` | GET | `lms_download_status()` | |
| `/api/v1/chat` | POST | `lms_chat_native()` | |
| `/v1/chat/completions` | POST | `lms_chat_openai()` | |
| `/v1/responses` | POST | `lms_chat_openresponses()` | |
| `/v1/embeddings` | POST | none | No wrapper exists. |
| `/v1/completions` | POST | none | Legacy text completion from a bare prompt. |
| `/v1/models` | GET | none | `list_models()` uses the native list instead. |
| `/v1/messages` | POST | none | Anthropic compatible. Added in LM Studio 0.4.1. |
| `/api/v0/*` | mixed | none | The superseded v0 REST API. |

## Features inside endpoints the package already calls

These need no new endpoint. They are fields or behaviors the package does not
name, so a user reaches them only through `...` (GP4), or cannot reach them at
all.

- **API token authentication.** LM Studio 0.4.0 added API tokens. The server
  setting "Require authentication" makes every REST call need an
  `Authorization: Bearer <token>` header. `lms_client()` in `R/chat.R` sets
  `Content-Type` and `Accept` only. With authentication on, every wrapper in
  the package fails. A user cannot fix this through `...`, because `...` goes
  into the request body, not the headers.
- **Stateful chat.** `/api/v1/chat` stores the conversation by default and
  returns a `response_id`. A later call continues the thread with
  `previous_response_id`. A caller who wants no stored thread sends
  `store: false`. The package returns text and drops the `response_id`, so the
  thread is unreachable.
- **Per-call statistics.** A `/api/v1/chat` response carries a `stats` object
  with `input_tokens`, `total_output_tokens`, `reasoning_output_tokens`,
  `tokens_per_second`, `time_to_first_token_seconds`, and
  `model_load_time_seconds`. A batch run over many items can report throughput
  from these numbers.
- **Idle TTL.** A `ttl` field in a chat request sets how long a model stays
  loaded without a request. `lms load --ttl <seconds>` does the same from the
  command line. `lms_load()` names no `ttl` argument.
- **Load configuration.** `/api/v1/models/load` accepts `context_length`,
  `eval_batch_size`, `flash_attention`, `num_experts`,
  `offload_kv_cache_to_gpu`, and `echo_load_config`. `lms_load()` names all
  six already. The documented load field it does not name is `ttl`.
- **Reasoning control.** `/api/v1/chat` accepts a `reasoning` field with the
  values off, on, low, medium, and high. `/v1/responses` accepts
  `reasoning.effort`. A model states its allowed values in the
  `capabilities.reasoning` block of the model list.
- **Sampling fields.** `/api/v1/chat` names `temperature`, `top_p`, `top_k`,
  `min_p`, `repeat_penalty`, and `max_output_tokens`. None is a named argument
  in the package.
- **Structured output.** `/v1/chat/completions` accepts `response_format` with
  a JSON schema and returns JSON that matches it. A scoring run that wants one
  number per item can constrain the output this way instead of parsing prose.
- **Model list fields.** `GET /api/v1/models` returns `key`, `display_name`,
  `publisher`, `architecture`, `quantization`, `size_bytes`, `params_string`,
  `max_context_length`, `format`, `variants`, `selected_variant`, a
  `capabilities` block (`vision`, `trained_for_tool_use`, `reasoning`), and
  `loaded_instances` with each instance's configuration. `list_models()`
  returns all of this when `detailed = TRUE`, and it derives a `state` column
  from `loaded_instances`. It does not flatten the per-instance configuration
  into rows, which is the table `lms ps` prints.
- **Streaming.** A chat request with `stream: true` returns Server Sent Events.
  The named event types are `chat.start`, `model_load.start`,
  `model_load.progress`, `model_load.end`, `prompt_processing.start`,
  `prompt_processing.progress`, `prompt_processing.end`, `reasoning.start`,
  `reasoning.delta`, `reasoning.end`, `tool_call.start`,
  `tool_call.arguments`, `tool_call.success`, `tool_call.failure`,
  `message.start`, `message.delta`, `message.end`, `error`, and `chat.end`.
  The `chat.end` event carries the same aggregate result as a non-streaming
  call.
- **MCP integrations.** `/api/v1/chat` accepts an `integrations` array. An
  entry is either a configured plugin (`{"type": "plugin", "id": ...,
  "allowed_tools": [...]}`) or an ephemeral MCP server (`{"type":
  "ephemeral_mcp", "server_url": ..., "server_label": ...}`). MCP is the Model
  Context Protocol, a standard way for a model to call outside tools.
- **Image input.** The `input` field of `/api/v1/chat` accepts structured
  objects, and the documentation states that text and image inputs are both
  supported. A model reports image support as `capabilities.vision`.

## CLI commands the package does not wrap

The package wraps `lms server start|stop|status`, `lms daemon up|down`, and
`lms status`. The CLI reference lists these others.

- Local models: `lms chat`, `lms get`, `lms import`, `lms load`, `lms ls`,
  `lms ps`, `lms unload`. The REST API covers load, unload, list, and
  download. It does not cover `lms import`, which brings a model file on disk
  into LM Studio.
- Serve: `lms log stream`. Flags are `--source server`, `--source model`,
  `--filter input,output`, `--json`, and `--stats`.
- Daemon: `lms daemon update`.
- Link: `lms link enable|disable|status|set-device-name|set-preferred-device`.
  LM Link connects LM Studio across machines.
- Runtime and hub: `lms runtime`, `lms clone`, `lms dev`, `lms login`,
  `lms push`.
- Estimation: `lms load --estimate-only <model>` prints the estimated GPU and
  total memory before a load. It honors `--context-length` and `--gpu`.
- Reporting: `lms ps --json` reports each model's generation status and the
  number of queued prediction requests.

## Fit against the design boundary

DESIGN states GP1, one wrapper per LM Studio feature, plus analysis that
serves scoring at scale. Every item above wraps an LM Studio feature, so GP1
admits all of them. The order below reflects the core user, a researcher who
scores many items.

1. Token authentication in `lms_client()`. Without it the package cannot talk
   to a server that requires a token, and `...` offers no way around it.
2. Embeddings. `/v1/embeddings` is a whole endpoint with no wrapper, and text
   embeddings serve the research workflow directly.
3. A `ttl` argument on `lms_load()` and on the chat wrappers. It is the one
   documented load field the package does not name.
4. Per-call statistics from the native chat response, for throughput reporting
   over a batch.
5. Structured output on `/v1/chat/completions`, for one parsed score per item.
6. A loaded-instance table, the `lms ps` view, flattened from the
   `loaded_instances` field that `list_models(detailed = TRUE)` already
   returns.
7. Stateful chat through `response_id` and `previous_response_id`.
8. Streaming. This changes the return shape, so it needs its own design work.

Out of scope under the current boundary: `lms clone`, `lms push`, `lms dev`,
and `lms login` serve the LM Studio Hub and plugin authoring, not local
inference from R.
