# Regenerate the recorded response behind the lms_chat_openai(schema =)
# cassette test.
#
# Provenance of tests/testthat/chat_schema_live/:
#   Source:    a live LM Studio REST server at http://localhost:1234
#   Model:     google/gemma-3-1b
#   Recorded:  2026-09-21
#   Request:   the `messages` and `schema` below, with temperature 0
#   Seed:      none. Temperature 0 makes the reply repeatable for a fixed
#              model and request, though a new LM Studio build can change it.
#
# Run this from the repository root with LM Studio running, the model above
# downloaded, and RLMSTUDIO_API_TOKEN set if your server requires a token:
#
#   Rscript data-raw/record-schema-cassette.R
#
# httptest2 records only when the target directory is absent, so the script
# deletes it first. Only the response bodies are written to disk. No request
# header, and therefore no API token, reaches the recorded files. The model is
# loaded before recording starts and unloaded after it ends, so neither call is
# recorded.
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
    content = "Rate how positive this review is from 1 to 5: 'Great value.'"
  )
)
schema <- list(
  type = "object",
  properties = list(score = list(type = "integer")),
  required = list("score")
)

target <- file.path("tests", "testthat", "chat_schema_live")
unlink(target, recursive = TRUE)

# `on.exit()` at the top level of a script run by Rscript never runs, so the
# unload sits in a `finally` clause instead.
lms_load(model, host = host)
tryCatch(
  withr::with_dir(file.path("tests", "testthat"), {
    httptest2::with_mock_dir("chat_schema_live", {
      out <- lms_chat_openai(
        model = model,
        messages = messages,
        host = host,
        temperature = 0,
        schema = schema
      )
      message("recorded a reply that parsed to: ", deparse(out))
    })
  }),
  finally = lms_unload(model, host = host)
)
