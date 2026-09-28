# Regenerate the recorded responses behind the model-check tests of
# lms_chat_openai(), lms_chat_openresponses(), and lms_chat_batch().
#
# Provenance of tests/testthat/model_mismatch_live/:
#   Source:    a live LM Studio REST server at http://localhost:1234
#   Models:    google/gemma-3-1b, and qwen/qwen3-4b-2507 loaded under the
#              instance id "my-qwen"
#   Recorded:  2026-09-28, LM Studio 0.4.25+1
#   Requests:  the prompt below on /v1/chat/completions and /v1/responses,
#              with temperature 0, then GET /api/v1/models
#   Seed:      none. The tests read the `model` field, the status, and the
#              error code of each reply, not the answer text.
#
# The script records four cases, each into its own directory, because the
# model list differs between them and httptest2 names a GET by its path alone:
#
#   unknown/    one chat model loaded, asked for "not-a-model"
#   case/       one chat model loaded, asked for "Google/Gemma-3-1B"
#   alias/      two chat models loaded, asked for "qwen/qwen3-4b-2507", whose
#               loaded instance has the id "my-qwen"
#   not_found/  two chat models loaded, asked for "not-a-model"
#
# Run this from the repository root with LM Studio running, both models
# downloaded, google/gemma-3-1b the only chat model loaded or none loaded, the
# `lms` command on the PATH, and RLMSTUDIO_API_TOKEN set if your server
# requires a token:
#
#   Rscript data-raw/record-model-mismatch-cassette.R
#
# The chat calls are made with simplify = FALSE, and a condition that a chat
# call raises is caught, because httptest2 writes the response before the
# package reads it. The checks below read the recorded files.
#
# httptest2 records only when the target directory is absent, so the script
# records into a fresh directory beside it. The old cassettes are replaced only
# after every recording and check succeeds. Only the response bodies, and for a
# status other than 200 the response status and headers, are written to disk.
# No request header, and therefore no API token, reaches the recorded files.
# The script loads google/gemma-3-1b if it is not loaded and unloads it at the
# end. It loads qwen/qwen3-4b-2507 as "my-qwen" with `lms load --identifier`,
# because the REST load endpoint takes no instance id, and it unloads that
# instance at the end. None of these calls is recorded.
#
# The script needs pkgload, httptest2 and withr, for the reasons that
# data-raw/record-embed-cassette.R gives.

for (pkg in c("pkgload", "httptest2", "withr")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      "This script needs the ", pkg, " package. ",
      "Install it with install.packages(\"", pkg, "\").",
      call. = FALSE
    )
  }
}

pkgload::load_all(quiet = TRUE)

host <- "http://localhost:1234"
first <- "google/gemma-3-1b"
second <- "qwen/qwen3-4b-2507"
second_id <- "my-qwen"
prompt <- "Reply with the word hi."

target <- file.path("tests", "testthat", "model_mismatch_live")
fresh <- paste0(target, "_new")
unlink(fresh, recursive = TRUE)

loaded <- list_models(loaded = TRUE, type = "llm", quiet = TRUE, host = host)
loaded_keys <- if (nrow(loaded) > 0) loaded$key else character()
if (length(setdiff(loaded_keys, first)) > 0) {
  stop(
    "Unload every chat model other than ", first, " first. ",
    "Loaded now: ", paste(loaded_keys, collapse = ", "), ".",
    call. = FALSE
  )
}
was_loaded <- first %in% loaded_keys

# Records one chat call on each route and the model list into `case_dir`.
record_case <- function(case_dir, model) {
  catch <- function(expr) {
    tryCatch(
      expr,
      rlmstudio_api_error = function(cnd) NULL,
      rlmstudio_bad_response = function(cnd) NULL
    )
  }
  withr::with_dir(file.path("tests", "testthat"), {
    httptest2::with_mock_dir(file.path(basename(fresh), case_dir), {
      catch(lms_chat_openai(
        model = model,
        messages = list(list(role = "user", content = prompt)),
        host = host,
        simplify = FALSE,
        temperature = 0
      ))
      catch(lms_chat_openresponses(
        model = model,
        input = prompt,
        host = host,
        simplify = FALSE,
        temperature = 0
      ))
      list_models(quiet = TRUE, host = host)
    })
  })
}

lms_cli <- function(...) {
  status <- system2("lms", c(...))
  if (!identical(status, 0L)) {
    stop("`lms ", paste(c(...), collapse = " "), "` failed.", call. = FALSE)
  }
}

# `on.exit()` at the top level of a script run by Rscript never runs, so the
# unloads sit in a `finally` clause instead.
second_loaded <- FALSE
invisible(tryCatch(
  {
    if (!was_loaded) {
      lms_load(first, host = host)
    }
    record_case("unknown", "not-a-model")
    record_case("case", "Google/Gemma-3-1B")
    lms_cli("load", second, "--identifier", second_id, "-y")
    second_loaded <- TRUE
    record_case("alias", second)
    record_case("not_found", "not-a-model")
  },
  finally = {
    if (second_loaded) {
      lms_unload(second_id, host = host)
    }
    if (!was_loaded) {
      lms_unload(first, host = host)
    }
  }
))

# Read back what each case recorded. A status-200 JSON reply is saved as a
# `.json` body, and any other reply as a `.R` file that rebuilds the response.
recorded <- function(case_dir, route) {
  dir <- file.path(fresh, case_dir, "localhost-1234", "v1")
  pattern <- if (route == "openai") "^completions-.*-POST" else "^responses-.*-POST"
  path <- if (route == "openai") file.path(dir, "chat") else dir
  file <- list.files(path, pattern = pattern, full.names = TRUE)
  if (length(file) != 1L) {
    stop("Expected one ", route, " file in ", path, ".", call. = FALSE)
  }
  if (endsWith(file, ".json")) {
    return(list(status = 200L, body = jsonlite::read_json(file)))
  }
  resp <- source(file)$value
  list(
    status = httr2::resp_status(resp),
    body = jsonlite::parse_json(httr2::resp_body_string(resp))
  )
}

expect_reply <- function(case_dir, status, model = NULL, code = NULL) {
  for (route in c("openai", "openresponses")) {
    got <- recorded(case_dir, route)
    message(case_dir, " ", route, ": status ", got$status,
            ", model ", format(got$body[["model"]]),
            ", error.code ", format(got$body[["error"]][["code"]]))
    if (!identical(got$status, status) ||
        (!is.null(model) && !identical(got$body[["model"]], model)) ||
        (!is.null(code) && !identical(got$body[["error"]][["code"]], code))) {
      stop("The ", case_dir, " case on the ", route, " route did not ",
           "record the reply the tests expect.", call. = FALSE)
    }
  }
}

expect_reply("unknown", 200L, model = first)
expect_reply("case", 200L, model = first)
expect_reply("alias", 200L, model = second_id)
expect_reply("not_found", 400L, code = "model_not_found")

# Reached only when every recording above succeeded and passed its check.
unlink(target, recursive = TRUE)
if (!file.rename(fresh, target)) {
  stop("Could not move ", fresh, " to ", target, ".", call. = FALSE)
}
