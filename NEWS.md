# rlmstudio (development version)

* `list_instances()` has a new fifth column, `remaining_ttl_seconds`, so each load configuration column moves one position to the right. This double column holds the `remaining_ttl_seconds` that the model list gives for each instance. If the field is absent or `null`, the column holds `NA`. In LM Studio 0.4.26+4, an instance loaded with no ttl has no such field, so it holds `NA`. If `list_instances()` finds no instance, the zero-row frame also has this column. A load configuration field named `remaining_ttl_seconds` now gives the column `config.remaining_ttl_seconds`. The check covers loaded instances of a model whose type is in `type`. If such a `remaining_ttl_seconds` is not a number or `null`, the call aborts with `rlmstudio_bad_response`.

* A request to a `host` whose hostname is `localhost`, in any letter case, `127.0.0.1`, or `::1` no longer goes through a proxy. The proxy environment variables, such as `http_proxy` or `all_proxy`, set that proxy. Before, unless `no_proxy` listed the host, curl sent the request and its text to the proxy. The call then failed, or got its answer from the proxy and not straight from the server. A request that starts at any other host follows the proxy variables as before.

* `vignette("getting-started")` now tells you to open the LM Studio app once after the install. The vignette starts the server with `port = 1234`, because LM Studio otherwise uses the port that it used last time. It shows how to find a model key in the LM Studio model catalog. It also names the `status` of a finished download, `"completed"`.

* `lms_server_start()` with no `port` now says that the server started "on the port that LM Studio used last", not "on the default port". The README, the other vignettes, and the help examples, apart from one that shows another port, now start the server with `port = 1234`. The other functions that send requests ask that port by default, and the `port` help now says so.

* `install_lmstudio(method = "browser")` now tells you to open the LM Studio app once before you restart R.

* With `options(rlmstudio.quiet = TRUE)`, `check_lms_version()`, `install_lmstudio(method = "browser")`, and the print of a chat result now show no alerts. Before, `check_lms_version()` showed an alert for a missing CLI, for version output that did not parse, and for a version that was too old. `install_lmstudio()` showed its request to install the software, and the print showed that log probability data was empty or missing. The function results do not change.

* Two cases that cannot return what you asked for now give a warning with its own class. The `rlmstudio.quiet` option does not hide either warning.
  * `lms_load(echo_load_config = TRUE)` on a model that is already loaded, with `force = FALSE`, returns the model key, and now warns with the class `rlmstudio_no_load_config`. Before, it showed an alert with no class.
  * `lms_chat_openai(logprobs = TRUE)` and `lms_chat(api_type = "openai", logprobs = TRUE)` return a result whose `logprobs` is `NULL`, and now warn with the class `rlmstudio_no_logprobs`. If `simplify = TRUE` and the batch reads at least one reply, `lms_chat_batch(api_type = "openai", logprobs = TRUE)` gives one such warning for the whole batch. If `simplify = TRUE` and `format = "vector"`, a `logprobs = TRUE` batch on that route that does not abort returns the list, as before. Its warning now says that the vector format "cannot store the `<lms_chat_result>` replies of the `"openai"` route". Before, it said that the vector format "cannot store logprobs dataframes".

* When no server answers, the `rlmstudio_no_server` error now says how to start the server. The hostname `localhost` can be in any letter case. If the hostname of `host` is `localhost` or `127.0.0.1`, the error says to run `lms_server_start()` with the port of `host`. If `host` names no port, that port is 1234. For any other `host`, the error names that host and says to start the server there. The headless `install_lmstudio()` message now names `lms_server_start(port = 1234)`, and the "Server not running" help section gives the same hint.

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

* The help of `lms_server_ready()` no longer quotes one exact libcurl message for an empty `host`. The wording depends on the libcurl version, and the tests now pass with each wording.

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
