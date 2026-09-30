# Regenerate the recorded responses behind the thread tests of
# lms_chat_native(), lms_chat_openresponses(), and lms_chat_batch().
#
# Provenance of tests/testthat/thread_live/:
#   Source:    a live LM Studio REST server at http://localhost:1234
#   Model:     google/gemma-3-1b
#   Recorded:  see the git log of this directory, LM Studio 0.4.25+1
#   Requests:  six chat calls, each with temperature 0:
#              1. /api/v1/chat, the first prompt below.
#              2. /v1/responses, the second prompt below, with the
#                 `previous_response_id` that call 1 returned.
#              3. /api/v1/chat, the first prompt, with `store` false.
#              4. /v1/responses, the first prompt, with `store` false.
#              5. /api/v1/chat, the first prompt, with the unknown id below.
#              6. /v1/responses, the first prompt, with the unknown id below.
#   Seed:      none. The tests read the ids, the status, and the error code
#              of each reply, not the answer text.
#
# The id that call 1 returns goes into the body of call 2, so the file name
# httptest2 gives call 2 depends on it. The tests read that id from the
# recorded reply of call 1 and send the same body again.
#
# Run this from the repository root with LM Studio installed, google/gemma-3-1b
# downloaded, the `lms` command on the PATH, and RLMSTUDIO_API_TOKEN set if
# your server requires a token:
#
#   Rscript data-raw/record-thread-cassette.R
#
# The chat calls are made with simplify = FALSE. Calls 5 and 6 keep the
# rlmstudio_api_error that they raise. httptest2 writes the response before
# the package reads it.
#
# httptest2 records only when the target directory is absent, so the script
# records into a fresh directory beside it. The old cassettes are replaced only
# after every recording and check succeeds. Only the response bodies, and for a
# status other than 200 the request method and URL and the response status,
# headers, and timing, are written to disk.
# No request header, and therefore no API token, reaches the recorded files.
# The script starts the server if it is not running and stops it at the end.
# It loads google/gemma-3-1b if it is not loaded and unloads it at the end.
# None of these calls is recorded.
#
# The script needs pkgload, httptest2 and withr, for the reasons that
# data-raw/record-embed-cassette.R gives.

for (pkg in c("pkgload", "httptest2", "withr")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      "This script needs the ",
      pkg,
      " package. ",
      "Install it with install.packages(\"",
      pkg,
      "\").",
      call. = FALSE
    )
  }
}

pkgload::load_all(quiet = TRUE)

host <- "http://localhost:1234"
model <- "google/gemma-3-1b"
first_prompt <- "Reply with the word hi."
second_prompt <- "Now reply with the word bye."
unknown_id <- "resp_not_a_stored_reply"

# A short name, because R CMD check notes a path in the tarball longer than
# 100 bytes, and the recorded chat paths are long.
target <- file.path("tests", "testthat", "thread_live")
fresh <- paste0(target, "_new")
unlink(fresh, recursive = TRUE)

# The six calls. Calls 5 and 6 return the API error that they raise.
record_thread <- function() {
  keep <- function(expr) {
    tryCatch(expr, rlmstudio_api_error = identity)
  }
  withr::with_dir(file.path("tests", "testthat"), {
    httptest2::with_mock_dir(basename(fresh), {
      native <- lms_chat_native(
        model = model,
        input = first_prompt,
        host = host,
        simplify = FALSE,
        temperature = 0
      )
      continued <- lms_chat_openresponses(
        model = model,
        input = second_prompt,
        host = host,
        simplify = FALSE,
        temperature = 0,
        previous_response_id = native[["response_id"]]
      )
      native_no_store <- lms_chat_native(
        model = model,
        input = first_prompt,
        host = host,
        simplify = FALSE,
        temperature = 0,
        store = FALSE
      )
      responses_no_store <- lms_chat_openresponses(
        model = model,
        input = first_prompt,
        host = host,
        simplify = FALSE,
        temperature = 0,
        store = FALSE
      )
      native_unknown <- keep(lms_chat_native(
        model = model,
        input = first_prompt,
        host = host,
        simplify = FALSE,
        temperature = 0,
        previous_response_id = unknown_id
      ))
      responses_unknown <- keep(lms_chat_openresponses(
        model = model,
        input = first_prompt,
        host = host,
        simplify = FALSE,
        temperature = 0,
        previous_response_id = unknown_id
      ))
    })
  })
  list(
    native = native,
    continued = continued,
    native_no_store = native_no_store,
    responses_no_store = responses_no_store,
    native_unknown = native_unknown,
    responses_unknown = responses_unknown
  )
}

# Unload the model or stop the server that this script started. A failure
# warns, so it does not skip the next step or hide the error that ended the
# recording.
restore_quietly <- function(label, expr) {
  tryCatch(
    expr,
    error = function(e) {
      warning(label, " failed: ", conditionMessage(e), call. = FALSE)
    }
  )
}

# `on.exit()` at the top level of a script run by Rscript never runs, so the
# restore steps sit in a `finally` clause instead. Each flag is set before its
# step, because a step can fail after it took effect.
server_started <- FALSE
model_loaded <- FALSE
got <- NULL
invisible(tryCatch(
  {
    if (!is_server_running(host)) {
      server_started <- TRUE
      lms_server_start()
    }
    loaded <- list_models(loaded = TRUE, type = "llm", quiet = TRUE, host = host)
    if (!(model %in% loaded$key)) {
      model_loaded <- TRUE
      lms_load(model, host = host)
    }
    got <- record_thread()
  },
  finally = {
    if (model_loaded) {
      restore_quietly("Unloading the model", lms_unload(model, host = host))
    }
    if (server_started) {
      restore_quietly("Stopping the server", lms_server_stop())
    }
  }
))

# Check what the calls returned. Each check names the fact the tests rely on.
check <- function(ok, what) {
  message(if (ok) "ok: " else "FAILED: ", what)
  if (!ok) {
    stop("The recording does not show that ", what, ".", call. = FALSE)
  }
}
is_one_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

check(is_one_string(got$native[["response_id"]]), "a native reply has an id")
check(is_one_string(got$continued[["id"]]), "a continued reply has an id")
check(
  is.null(got$native_no_store[["response_id"]]),
  "a native reply sent with store false has no id"
)
check(
  is_one_string(got$responses_no_store[["id"]]),
  "an OpenResponses reply sent with store false has an id"
)
for (route in c("native", "responses")) {
  cnd <- got[[paste0(route, "_unknown")]]
  code <- if (route == "native") "invalid_value" else "previous_response_not_found"
  check(
    inherits(cnd, "rlmstudio_api_error") &&
      identical(cnd$status, 400L) &&
      identical(cnd$code, code),
    paste("an unknown id on the", route, "route gives 400 with the code", code)
  )
}

# One file for each call: three on each path.
files <- list.files(fresh, recursive = TRUE)
check(
  sum(grepl("api/v1/chat-", files, fixed = TRUE)) == 3L &&
    sum(grepl("v1/responses-", files, fixed = TRUE)) == 3L &&
    length(files) == 6L,
  "each of the six calls wrote its own file"
)

# Reached only when every recording above succeeded and passed its check.
unlink(target, recursive = TRUE)
if (!file.rename(fresh, target)) {
  stop("Could not move ", fresh, " to ", target, ".", call. = FALSE)
}
