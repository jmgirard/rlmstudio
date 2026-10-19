# Regenerate the recorded responses behind the model-name stop tests of
# lms_embed() and lms_chat_batch().
#
# Provenance of tests/testthat/stop_live/:
#   Source:    a live LM Studio REST server at http://localhost:1234, with
#              just-in-time model loading on
#   Models:    text-embedding-nomic-embed-text-v1.5, loaded under its key and
#              then under the instance id "my-nomic"
#   Recorded:  2026-10-19, LM Studio 0.4.26+4
#   Requests:  the prompt below on /v1/chat/completions and /v1/responses with
#              temperature 0, the text below on /v1/embeddings, then
#              GET /api/v1/models
#   Seed:      none. The tests read the status, the error message, and the
#              `model` field of each reply, not the answer text or vectors.
#
# The script records three cases, each into its own directory, because the
# model list differs between them and httptest2 names a GET by its path alone:
#
#   none/           no model loaded, asked for "not-a-model" on the two chat
#                   routes and on /v1/embeddings
#   embed_unknown/  the embedding model loaded under its key, asked for
#                   "not-a-model" on /v1/embeddings
#   embed_alias/    the embedding model loaded as "my-nomic", asked for its key
#                   on /v1/embeddings
#
# Run this from the repository root with LM Studio running, no model loaded,
# the embedding model downloaded, the `lms` command on the PATH, and
# RLMSTUDIO_API_TOKEN set if your server requires a token:
#
#   Rscript data-raw/record-model-stop-cassette.R
#
# The calls are made with simplify = FALSE, and a condition that a call raises
# is caught, because httptest2 writes the response before the package reads
# it. The checks below read the recorded files.
#
# httptest2 records only when the target directory is absent, so the script
# records into a fresh directory beside it. The old cassettes are replaced only
# after every recording and check succeeds. Only the response bodies, and for a
# status other than 200 the request method and URL and the response status,
# headers, and timing, are written to disk. No request header, and therefore
# no API token, reaches the recorded files. The script loads the embedding
# model with `lms load`, because the REST load endpoint takes no instance id,
# and it unloads each instance that it loaded once that instance is recorded,
# or at once if a recording fails. None of these calls is recorded.
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
embedder <- "text-embedding-nomic-embed-text-v1.5"
embedder_id <- "my-nomic"
prompt <- "Reply with the word hi."
text <- "the first document"

# A short name, because R CMD check notes a path in the tarball longer than
# 100 bytes, and the recorded embedding paths are long.
target <- file.path("tests", "testthat", "stop_live")
fresh <- paste0(target, "_new")
unlink(fresh, recursive = TRUE)

loaded <- list_models(loaded = TRUE, quiet = TRUE, host = host)
if (nrow(loaded) > 0) {
  stop(
    "Unload every model first. Loaded now: ",
    paste(loaded$key, collapse = ", "),
    ".",
    call. = FALSE
  )
}

catch <- function(expr) {
  tryCatch(
    expr,
    rlmstudio_api_error = function(cnd) NULL,
    rlmstudio_bad_response = function(cnd) NULL
  )
}

# Records the calls that `chat` and `embed` name into `case_dir`, then the
# model list.
record_case <- function(case_dir, chat = NULL, embed = NULL) {
  withr::with_dir(file.path("tests", "testthat"), {
    httptest2::with_mock_dir(file.path(basename(fresh), case_dir), {
      if (!is.null(chat)) {
        catch(lms_chat_openai(
          model = chat,
          messages = list(list(role = "user", content = prompt)),
          host = host,
          simplify = FALSE,
          temperature = 0
        ))
        catch(lms_chat_openresponses(
          model = chat,
          input = prompt,
          host = host,
          simplify = FALSE,
          temperature = 0
        ))
      }
      if (!is.null(embed)) {
        catch(lms_embed(
          model = embed,
          input = text,
          host = host,
          simplify = FALSE
        ))
      }
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

# Unload an instance that this script loaded. A failed unload warns, so it
# does not skip the other unload or hide the error that ended the recording.
unload_quietly <- function(id) {
  tryCatch(
    lms_unload(id, host = host),
    error = function(e) {
      warning("Unloading ", id, " failed: ", conditionMessage(e), call. = FALSE)
    }
  )
}

# `on.exit()` at the top level of a script run by Rscript never runs, so the
# unloads sit in a `finally` clause instead. Each flag is set before its load,
# because a load can fail after the model is loaded.
key_loaded <- FALSE
alias_loaded <- FALSE
invisible(tryCatch(
  {
    record_case("none", chat = "not-a-model", embed = "not-a-model")
    key_loaded <- TRUE
    lms_cli("load", embedder, "-y")
    record_case("embed_unknown", embed = "not-a-model")
    # This unload stops on failure, so the alias case never records with a
    # second instance loaded, and the `finally` clause tries it again.
    lms_unload(embedder, host = host)
    key_loaded <- FALSE
    alias_loaded <- TRUE
    lms_cli("load", embedder, "--identifier", embedder_id, "-y")
    record_case("embed_alias", embed = embedder)
  },
  finally = {
    if (alias_loaded) {
      unload_quietly(embedder_id)
    }
    if (key_loaded) {
      unload_quietly(embedder)
    }
  }
))

# Read back one recorded POST. A status-200 JSON reply is saved as a `.json`
# body, and any other reply as a `.R` file that rebuilds the response.
recorded <- function(case_dir, route) {
  dir <- file.path(fresh, case_dir, "localhost-1234", "v1")
  path <- switch(route, openai = file.path(dir, "chat"), dir)
  pattern <- switch(
    route,
    openai = "^completions-.*-POST",
    openresponses = "^responses-.*-POST",
    embed = "^embeddings-.*-POST"
  )
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

# The error text of a body, from `error` as a string or `error.message`.
error_text <- function(body) {
  err <- body[["error"]]
  if (is.character(err)) err else err[["message"]]
}

expect_reply <- function(case_dir, route, status, model = NULL, starts = NULL) {
  got <- recorded(case_dir, route)
  message(
    case_dir,
    " ",
    route,
    ": status ",
    got$status,
    ", model ",
    format(got$body[["model"]]),
    ", error ",
    format(error_text(got$body))
  )
  if (
    !identical(got$status, status) ||
      (!is.null(model) && !identical(got$body[["model"]], model)) ||
      (!is.null(starts) && !startsWith(error_text(got$body), starts))
  ) {
    stop(
      "The ",
      case_dir,
      " case on the ",
      route,
      " route did not record the reply the tests expect.",
      call. = FALSE
    )
  }
}

for (route in c("openai", "openresponses", "embed")) {
  expect_reply("none", route, 400L, starts = "No models loaded")
}
expect_reply("embed_unknown", "embed", 200L, model = embedder)
expect_reply("embed_alias", "embed", 200L, model = embedder_id)

# Reached only when every recording above succeeded and passed its check.
unlink(target, recursive = TRUE)
if (!file.rename(fresh, target)) {
  stop("Could not move ", fresh, " to ", target, ".", call. = FALSE)
}
