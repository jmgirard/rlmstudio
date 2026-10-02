# rlmstudio 0.3.0

## Breaking changes

* Each `TRUE`/`FALSE` argument now aborts on any other value, with a message that names the argument. Before, `NA`, `"yes"`, `1`, and `NULL` acted as `FALSE`. This covers `simplify`, `logprobs`, `force`, `echo_load_config`, `cors`, `loaded`, `detailed`, `json`, and `verbose`.
  * `flash_attention` and `offload_kv_cache_to_gpu` of `lms_load()` take `TRUE`, `FALSE`, or `NULL`. Before, the function sent the result of `as.logical()` for any value.

* `quiet` of `list_models()` and `lms_chat_batch()` now defaults to `NULL`, which follows the `rlmstudio.quiet` option. `TRUE` or `FALSE` overrides the option.

* If a character `input` holds more than one string, `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()` now abort. Use `lms_chat_batch()` to send several prompts.

* `lms_chat_batch()` no longer stops at a failed input. It stores the failure, goes on to the next input, and warns once at the end with the positions of the failed inputs. In a list result, the element of a failed input holds the condition. Where the result is text, it holds `NA`.
  * The batch still aborts on a lost server, on status 401, 403, or 404, and on a model that the server cannot find. The condition carries the replies so far in a `results` field.
  * With `api_type = "native"`, the batch ignores `logprobs = TRUE` and warns once.

* If no server answers, `list_models()`, `lms_download()`, and `lms_download_status()` now abort with `rlmstudio_no_server`. Before, they returned an empty data frame or `NULL`.

* `lms_download()` returns the job id string, or `"already_downloaded"` invisibly. A reply with no job id now aborts with `rlmstudio_bad_response`. Before, the call returned `TRUE`.

* `lms_server_start()` now waits up to 10 seconds for the REST API to answer before it returns. Set `wait = 0` to return as soon as the CLI does, as before.

* `lms_server_stop()` with no server running now prints a message and returns. Before, it aborted.

* The logprobs data frame has a new last column, `step`, that numbers the steps of the reply. `lms_score_expected()` now scores the first step alone. It also adds up candidates that give the same label, such as `"3"` and `" 3"`.

* With `simplify = TRUE`, a reply from `lms_chat_native()` and `lms_chat_openresponses()` now carries a `response_id` attribute. So `identical()` of such a reply and a plain string returns `FALSE`.

## New features

* New `lms_embed()` turns texts into embedding vectors. It returns a numeric matrix with one row per text. It sends the texts in batches of `batch_size` (default 100) and shows a progress bar for more than one batch.

* New `list_instances()` returns one row per loaded model instance, with a column for each field of its load configuration.

* New `lms_server_ready()` tells whether a host answers as an LM Studio server that you can use. It returns `TRUE` or `FALSE`, and it never aborts on a failed request.

* The package can now use an LM Studio server that requires an API token. Each function that reaches the REST API takes a `token` argument. Without it, the package reads the `rlmstudio.token` option, then the `RLMSTUDIO_API_TOKEN` environment variable. See `?rlmstudio_token`.

* Structured output: `lms_chat_openai()` and `lms_chat(api_type = "openai")` take a `schema` argument, a JSON Schema written as a named list. With `simplify = TRUE`, the reply comes back parsed into an R value. With `format = "data.frame"` and `logprobs = FALSE`, `lms_chat_batch()` adds one column per top-level property of an object schema.

* Chat threads: `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()` take `previous_response_id` to continue a stored thread. Pass the earlier reply itself, or its `response_id` attribute. A new `store` argument turns off the storage of a reply on the server.

* `lms_chat()`, `lms_chat_openai()`, and `lms_embed()` take a `ttl` argument. It sets the seconds that a model loaded by the request stays loaded with no request. `lms_chat()` takes it on the `"openai"` route only.

* `lms_server_start()` gains `wait`, `host`, and `token` arguments for its readiness check. It also checks `port` and `cors` before the CLI runs.

* With `format = "data.frame"`, `lms_chat_batch()` adds the reply id and token counts as columns. On the native route, it also adds the speed and timing columns from the reply `stats`.

* If `context_length` is larger than the maximum that the model list gives for the model, `lms_load()` warns with class `rlmstudio_context_above_max`.

* New condition classes let you catch each kind of failure with `tryCatch()`. They are `rlmstudio_no_server`, `rlmstudio_api_error`, `rlmstudio_bad_response`, and `rlmstudio_model_mismatch`. An `rlmstudio_api_error` carries the HTTP `status` and the error `code` of the reply. See `?rlmstudio-conditions`.

* Two new vignettes. `vignette("chat-options")` shows how to control a chat from an R script. `vignette("text-analysis")` shows how to analyze a data frame of texts. The `getting-started` and `headless-config` vignettes are rewritten.

* The vignettes now ship with output knitted ahead of time from a live LM Studio. A build or check of the package runs no vignette code.

## Bug fixes and new checks

* Each argument that names a model, a job, a thread, or a model type is now checked before the request. A bad value aborts with a message that names the argument. Text arguments that hold `NA` abort too.

* `lms_chat_openai()` now checks `messages` before the request. It aborts on a value that the server cannot read, with a message that names the fault.

* A `stream` in `...` of a chat function now aborts unless it is `FALSE` or `NULL`. The package reads a whole reply only.

* Each function now checks the shape of a reply before it reads it. A reply that the package cannot read aborts with `rlmstudio_bad_response`. Before, many such replies gave a base R error, or returned `NULL` or a wrong value.

* A reply body is now read as JSON text alone, whatever its `Content-Type` header says. Before, a body whose text was a URL or a file path made the package read that URL or file.

* `lms_chat_native()` and `lms_chat_openresponses()` now return the answer of a reasoning model. Before, they returned its reasoning.

* If a model other than the one asked for answers, `lms_chat_openai()` and `lms_chat_openresponses()` abort with `rlmstudio_model_mismatch`.

* If a length limit cut off a text reply, `lms_chat_openai()` warns with class `rlmstudio_reply_cut_off`. With a `schema`, a cut-off reply aborts.

* Every failed REST response now aborts with `rlmstudio_api_error` and the same message for the same response body. A 401 or 403 abort adds a hint about the API token.

* The server check now honors the `host` argument. Before, it always tried `localhost:1234`.

* `list_models()` no longer fails on a server with no models.

* `has_lms()` now finds `lms` in the same places as `lms_path()`.

* A failed run of the LM Studio CLI or the headless installer now quotes its output in the abort message.

* `print()` on a download status no longer shows `NaN`, `Inf`, or a percentage above 100. It prints each size in the unit that fits.

* A `POSIXlt` value in a request body no longer makes the call recurse with no end.

# rlmstudio 0.2.2

* Fix CRAN issues

# rlmstudio 0.2.1

* Submit to CRAN

# rlmstudio 0.2.0

* Improve list--load interaction
* Handle repeat model loading elegantly
* Add first set of unit testing
* Add headless vignette
* Add pkgdown website
* Add codecov and lifecycle badges

# rlmstudio 0.1.0

* Initial development version.
