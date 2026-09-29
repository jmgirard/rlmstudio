skip_if_no_lms <- function() {
  if (!has_lms()) {
    testthat::skip("LM Studio CLI is not installed.")
  }
}

skip_if_no_server <- function() {
  if (!is_server_running()) {
    testthat::skip("LM Studio local server is not running.")
  }
}

# The loaded embedding models, as list_models() returns them. The calling test
# skips when `model` is not among them. An error from list_models() is not
# caught, so a server that answers but rejects the list fails the test rather
# than skipping it.
loaded_embedding_models <- function(model, detailed = FALSE) {
  models <- list_models(
    loaded = TRUE,
    type = "embedding",
    detailed = detailed,
    quiet = TRUE
  )
  if (!model %in% models$key) {
    testthat::skip(paste(model, "is not loaded."))
  }
  models
}
