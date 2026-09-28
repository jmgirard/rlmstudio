# Regenerate the recorded response behind the list_instances() cassette test.
#
# Provenance of tests/testthat/list_instances/:
#   Source:    a live LM Studio REST server at http://localhost:1234
#   Models:    google/gemma-3-1b and text-embedding-nomic-embed-text-v1.5,
#              each with one loaded instance
#   Recorded:  2026-09-28, LM Studio 0.4.25+1
#   Requests:  GET /api/v1/models
#   Seed:      none. The model list holds no generated text.
#
# Run this from the repository root with LM Studio running, the two models
# above loaded and no other model loaded, and RLMSTUDIO_API_TOKEN set if your
# server requires a token:
#
#   Rscript data-raw/record-list-instances-cassette.R
#
# The script loads and unloads nothing. It stops before it records if the
# loaded llm and embedding instances are not the two above, one each. It does
# not see a loaded instance of another model type.
#
# httptest2 records only when the target directory is absent, so the script
# deletes it first. Only the response body is written to disk. No request
# header, and therefore no API token, reaches the recorded file.
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
expected <- c("google/gemma-3-1b", "text-embedding-nomic-embed-text-v1.5")

loaded <- list_instances(host = host, quiet = TRUE)
if (!setequal(loaded$key, expected) || nrow(loaded) != length(expected)) {
  stop(
    "Load exactly one instance each of ",
    paste(expected, collapse = " and "),
    ", and no other model, before you record.",
    call. = FALSE
  )
}

target <- file.path("tests", "testthat", "list_instances")
unlink(target, recursive = TRUE)

withr::with_dir(file.path("tests", "testthat"), {
  httptest2::with_mock_dir("list_instances", {
    out <- list_instances(host = host)
    message("recorded ", nrow(out), " instances: ", paste(out$id, collapse = ", "))
  })
}) |>
  invisible()
