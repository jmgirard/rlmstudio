# Regenerate the recorded response behind the list_instances() cassette test.
#
# Provenance of tests/testthat/list_instances/:
#   Source:    a live LM Studio REST server at http://localhost:1234
#   Models:    google/gemma-3-1b, loaded with a ttl, and
#              text-embedding-nomic-embed-text-v1.5, loaded with none, each
#              with one loaded instance. The list also holds the other
#              models on the recording machine, with no instance.
#   Recorded:  2026-10-19, LM Studio 0.4.26+4
#   Requests:  GET /api/v1/models
#   Seed:      none. The model list holds no generated text.
#
# Run this from the repository root with LM Studio running, the two models
# above loaded and no other model loaded, and RLMSTUDIO_API_TOKEN set if your
# server requires a token. The REST load endpoint rejected `ttl` when probed
# on 2026-09-27, so load the two models with the CLI first:
#
#   lms load google/gemma-3-1b --ttl 600
#   lms load text-embedding-nomic-embed-text-v1.5
#   Rscript data-raw/record-list-instances-cassette.R
#
# The script loads and unloads nothing. It stops before it records if the
# loaded llm and embedding instances are not the two above, one each, or if
# the gemma instance has no remaining ttl. It does not see a loaded instance
# of another model type.
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
if (is.na(loaded$remaining_ttl_seconds[loaded$key == expected[[1]]])) {
  stop(
    "Load ", expected[[1]], " with a ttl, such as `lms load ",
    expected[[1]], " --ttl 600`, before you record.",
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
