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
