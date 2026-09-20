# Regenerate the recorded response behind the lms_embed() cassette test.
#
# Provenance of tests/testthat/embed_live/:
#   Source:    a live LM Studio REST server at http://localhost:1234
#   Model:     text-embedding-nomic-embed-text-v1.5
#   Recorded:  2026-09-20
#   Inputs:    the three strings in `texts` below, in that order
#   Seed:      none. The model is deterministic for a fixed input.
#
# Run this from the repository root with LM Studio running, the model above
# downloaded, and RLMSTUDIO_API_TOKEN set if your server requires a token:
#
#   Rscript data-raw/record-embed-cassette.R
#
# httptest2 records only when the target directory is absent, so the script
# deletes it first. Only the response bodies are written to disk. No request
# header, and therefore no API token, reaches the recorded files.
#
# The script needs pkgload, httptest2 and withr. httptest2 and withr are in
# Suggests because the test suite needs them. pkgload is a development tool
# that only this script uses, and this directory never ships, so it stays out
# of DESCRIPTION and the script names it here instead.

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

model <- "text-embedding-nomic-embed-text-v1.5"
host <- "http://localhost:1234"
texts <- c(
  "the first document",
  "the second document",
  "the third document"
)

target <- file.path("tests", "testthat", "embed_live")
unlink(target, recursive = TRUE)

withr::with_dir(file.path("tests", "testthat"), {
  httptest2::with_mock_dir("embed_live", {
    out <- lms_embed(model = model, input = texts, host = host)
    message("recorded a ", nrow(out), " by ", ncol(out), " matrix")
  })
})
