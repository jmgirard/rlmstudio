# Regenerate the recorded response behind the cut-off reply test for
# lms_chat_openai(schema =).
#
# Provenance of tests/testthat/chat_cutoff_live/:
#   Source:    a live LM Studio REST server at http://localhost:1234
#   Model:     google/gemma-3-1b
#   Recorded:  2026-09-21
#   Request:   the `messages` and `schema` below, with temperature 0 and
#              max_tokens 5, so the server stops the reply at the token limit
#              before the JSON is complete
#   Seed:      none. Temperature 0 makes the reply repeatable for a fixed
#              model and request, though a new LM Studio build can change it.
#
# Run this from the repository root with LM Studio running, the model above
# downloaded, and RLMSTUDIO_API_TOKEN set if your server requires a token:
#
#   Rscript data-raw/record-cutoff-cassette.R
#
# The recorded call is made with simplify = FALSE, because with
# simplify = TRUE the cut-off reply aborts before httptest2 can finish the
# recording. The script then checks that the reply was in fact cut off.
#
# httptest2 records only when the target directory is absent, so the script
# records into a fresh directory beside it. The old cassette is replaced only
# after the new recording succeeds. Only the response bodies are written to
# disk. No request header, and therefore no API token, reaches the recorded
# files. If the model is not loaded, the script loads it before recording
# starts and unloads it after recording ends. If it is already loaded, the
# script leaves it loaded. Neither call is recorded.
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

model <- "google/gemma-3-1b"
host <- "http://localhost:1234"
messages <- list(
  list(
    role = "user",
    content = paste(
      "Rate how positive this review is from 1 to 5 and explain why:",
      "'Great value.'"
    )
  )
)
schema <- list(
  type = "object",
  properties = list(
    why = list(type = "string"),
    score = list(type = "integer")
  ),
  required = list("why", "score")
)

target <- file.path("tests", "testthat", "chat_cutoff_live")
fresh <- paste0(target, "_new")
unlink(fresh, recursive = TRUE)

loaded <- list_models(loaded = TRUE, quiet = TRUE, host = host)
was_loaded <- nrow(loaded) > 0 && model %in% loaded$key

# `on.exit()` at the top level of a script run by Rscript never runs, so the
# unload sits in a `finally` clause instead.
if (!was_loaded) {
  lms_load(model, host = host)
}
invisible(tryCatch(
  withr::with_dir(file.path("tests", "testthat"), {
    httptest2::with_mock_dir(basename(fresh), {
      out <- lms_chat_openai(
        model = model,
        messages = messages,
        host = host,
        simplify = FALSE,
        temperature = 0,
        max_tokens = 5,
        schema = schema
      )
    })
  }),
  finally = if (!was_loaded) lms_unload(model, host = host)
))

finish_reason <- out$choices[[1]]$finish_reason
message("recorded finish_reason: ", finish_reason)
message("recorded content: ", out$choices[[1]]$message$content)
if (!identical(finish_reason, "length")) {
  unlink(fresh, recursive = TRUE)
  stop(
    "The reply was not cut off at the token limit. ",
    "Lower max_tokens or lengthen the requested answer.",
    call. = FALSE
  )
}

# Reached only when the recording above succeeded and was cut off.
unlink(target, recursive = TRUE)
if (!file.rename(fresh, target)) {
  stop("Could not move ", fresh, " to ", target, ".", call. = FALSE)
}
