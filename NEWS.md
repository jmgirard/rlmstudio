# rlmstudio (development version)

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
