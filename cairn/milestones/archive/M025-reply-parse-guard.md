# M025: A model-management reply that does not parse as JSON aborts with rlmstudio_bad_response

**Status:** done (2026-09-23, PR #25 https://github.com/jmgirard/rlmstudio/pull/25)

**Goal:** Every reply parse reads JSON text only, so a status-200 body that is
not JSON aborts the model-management functions with `rlmstudio_bad_response`.

**Outcome:** `parse_json_body()` in `R/utils-api-error.R` reads the body as
UTF-8 and parses it with `jsonlite::parse_json()`. It never reads a file or
fetches a URL named by the body, and it ignores the `Content-Type` header.
`parse_ok_body()`, `api_error_message()`, and `lms_server_ready()` call it.
`list_models()`, `lms_load()`, `lms_download()`, and `lms_download_status()`
parse through `parse_ok_body()`. Through `list_models()`, `lms_unload_all()`
and `lms_load()` without `force` also abort. The help page names ten raisers, and NEWS has three entries.

**Decisions:** D-016 records the JSON-text-only parse by content.

**Review:** One pass, three-lens fan-out, user-facing tier. All seven criteria
passed, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. The
prior-review and blame-history lenses found nothing. The diff lens reported 9
findings. F2, F4, F5, F6, and F9 were fixed at the gate. F2 moved
`simplifyVector` after `...` in `parse_ok_body()`. F1 (UTF-8 only), F3 (URL counter tied to
jsonlite 2.0.0), F7, and F8 were rejected. The M008 and M012 lessons on
`resp_body_json()` retired into one M025 lesson, and the M005 and M017 lessons
were updated.
