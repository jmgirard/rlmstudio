# rlmstudio (development version)

* The package can now authenticate to an LM Studio server that requires an API token. Eleven functions take a `token` argument. They are `list_models()`, `lms_load()`, `lms_unload()`, `lms_unload_all()`, `lms_download()`, `lms_download_status()`, `lms_chat()`, `lms_chat_batch()`, `lms_chat_openresponses()`, `lms_chat_openai()`, and `lms_chat_native()`. Each one sends the value as a bearer token in the `Authorization` header of every request it makes. When `token` is not given, the package reads the `rlmstudio.token` option, and then the `RLMSTUDIO_API_TOKEN` environment variable. When none of the three holds a value, the request carries no `Authorization` header. A new help topic, `rlmstudio_token`, is the source. On the nine of these functions that take `...`, `token` sits after the dots. It is therefore matched by name alone, and no existing argument moved position.
* A printed request shows the `Authorization` header as `<REDACTED>` rather than showing the token. The package never puts the token into the message of a failed REST call. That message does repeat the text the server sent. An R backtrace also repeats your own calling line. Neither one is under the package's control.
* A `token` argument that is not one character string and not `NULL` now aborts. Before, a value such as a vector of two strings was discarded without a message. The call then fell through to the option and the environment variable.
* A REST response with HTTP status 401 or 403 now adds a hint to the abort. If the request carried no token, the hint names `RLMSTUDIO_API_TOKEN` and the `token` argument. If the request carried a token, the hint says that the server rejected it. Other statuses gain no hint.

* The help pages now document the two error condition classes that this package raises. A new help topic, `rlmstudio-conditions`, is the source. It names the situation that raises `rlmstudio_no_server` and the situation that raises `rlmstudio_api_error`. It states that an `rlmstudio_api_error` condition carries a `status` field, which holds the HTTP status as an integer. It shows how to catch each class with `tryCatch()`. The same two sections now appear on the help page of every exported function that can raise one of these classes. The pages of `lms_chat()`, `lms_chat_batch()`, and `lms_unload_all()` also name the function that they reach the abort through.

* Every failed REST response now aborts through one path. This affects `lms_load()`, `lms_unload()`, `lms_download()`, `lms_download_status()`, `lms_chat_openresponses()`, `lms_chat_openai()`, and `lms_chat_native()`. All seven now report the same message text for the same response body. Every one of these aborts carries the condition class `rlmstudio_api_error`. It also carries a `status` field, which holds the HTTP status as an integer. `lms_unload_all()` and `lms_chat_batch()` call these functions, so their failures change in the same way. The aborts from `lms_download()` and `lms_download_status()` no longer print the call that raised them. The other five already suppressed it.
* Some failure messages changed as a result. A JSON body whose `error` field is a plain string now reports that string. Before, `lms_load()`, `lms_unload()`, `lms_download()`, and `lms_download_status()` printed the whole raw body, and `lms_chat_openresponses()` and `lms_chat_openai()` printed the status. A JSON body that carries no readable message now reports `HTTP Status <n>`. Before, such a body gave the raw body text, a fragment of the `error` object, or a crash, depending on the function and the shape. A body that is not JSON and holds text now reports that text at all seven functions. Before, the three chat functions printed the status instead. An empty body still reports `HTTP Status <n>`. If `lms_load()` gets a successful response that does not report the model as loaded, it now reports the response body.
* Response bodies that used to crash now abort with a message. Before, all seven functions raised a raw R error on at least one body shape. An `error` field holding an empty object, an empty array, or an array of strings raised errors such as `argument is of length zero`. At `lms_load()`, `lms_unload()`, `lms_download()`, and `lms_download_status()`, an empty response body raised `Can't retrieve empty body.`
* `list_models()` now reports a failed REST response through that same path. Before, it raised the raw httr2 error, such as `HTTP 400 Bad Request`. It now aborts with the message `API List Failed: ` followed by the text read out of the response body. The abort carries the condition class `rlmstudio_api_error`. It also carries a `status` field, which holds the HTTP status as an integer. If the status is 400 or above and the body carries no readable message, the abort reports `HTTP Status <n>`. Below status 400 it reports the body text instead. The call now aborts on every status other than 200. Before, only status 400 and above raised an error, so a status such as 201 or 302 reached the parser.

* The server probe now honors the `host` argument. This affects `list_models()`, `lms_load()`, `lms_unload()`, `lms_unload_all()`, `lms_download()`, `lms_download_status()`, `lms_chat_openai()`, `lms_chat_openresponses()`, `lms_chat_native()`, and `lms_chat_batch()`. Before, the probe always tried `localhost:1234`, so a server on another hostname or port was reported as not running.
* If the server is not running, `list_models()`, `lms_download()`, and `lms_download_status()` now abort instead of returning an empty data frame or `NULL`. Every server-down abort carries the condition class `rlmstudio_no_server`.
* `has_lms()` now uses the same lookup as `lms_path()`: the `RLMSTUDIO_LMS_PATH` environment variable, then the system `PATH`, then common installation directories. Before, it checked only the `PATH`, so the two functions did not always agree.

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
