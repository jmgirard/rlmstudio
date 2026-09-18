# rlmstudio (development version)

* Every failed REST response now aborts through one path. This affects `lms_load()`, `lms_unload()`, `lms_download()`, `lms_download_status()`, `lms_chat_openresponses()`, `lms_chat_openai()`, and `lms_chat_native()`. All seven now report the same message text for the same response body. Every one of these aborts carries the condition class `rlmstudio_api_error`. It also carries a `status` field, which holds the HTTP status as an integer. `lms_unload_all()` and `lms_chat_batch()` call these functions, so their failures change in the same way.
* Some failure messages changed as a result. A JSON body whose `error` field is a plain string now reports that string. Before, `lms_load()`, `lms_unload()`, `lms_download()`, and `lms_download_status()` printed the whole raw body, and `lms_chat_openresponses()` and `lms_chat_openai()` printed the status. A JSON body that carries no readable message now reports `HTTP Status <n>`. Before, such a body gave the raw body text, a fragment of the `error` object, or a crash, depending on the function and the shape. A body that is not JSON now reports its text at all seven functions. Before, the three chat functions printed the status instead.
* Response bodies that used to crash now abort with a message. Before, all seven functions raised a raw R error on at least one body shape. An `error` field holding an empty object, an empty array, or an array of strings raised errors such as `argument is of length zero`. At `lms_load()`, `lms_unload()`, `lms_download()`, and `lms_download_status()`, an empty response body raised `Can't retrieve empty body.`

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
