# loaded_embedding_models() reads the model list for the live embedding tests.
# A model list that fails must fail the test, not skip it, so these tests mock
# list_models() and read what the helper signals.
#
# A skip condition carries the class "skip" and not "error", so
# expect_error() and a tryCatch() error handler both let it through. The
# handler below catches each kind on its own.

skip_helper_model <- "embed-model"

# Run the helper and return the condition it signals, or its value.
skip_helper_outcome <- function() {
  tryCatch(
    loaded_embedding_models(skip_helper_model),
    skip = function(cnd) cnd,
    error = function(cnd) cnd
  )
}

test_that("an error from the model list passes through the helper unchanged", {
  raisers <- list(
    rlmstudio_api_error = function() {
      rlm_abort_api(mock_response(401L, '{"error": "Denied"}'), "Denied", FALSE)
    },
    rlmstudio_bad_response = function() {
      rlm_abort_bad_response(mock_response(200L), "Bad", "a planted fault")
    },
    simpleError = function() stop("a plain failure")
  )

  for (cls in names(raisers)) {
    local_mocked_bindings(list_models = function(...) raisers[[cls]]())

    outcome <- skip_helper_outcome()

    expect_true(inherits(outcome, cls), info = cls)
    expect_false(inherits(outcome, "skip"), info = cls)
  }

  local_mocked_bindings(list_models = function(...) raisers$rlmstudio_api_error())
  expect_identical(skip_helper_outcome()$status, 401L)
})

test_that("the helper skips when the model is absent and returns the list when present", {
  absent <- data.frame(key = "other-model")
  local_mocked_bindings(list_models = function(...) absent)
  outcome <- skip_helper_outcome()
  expect_s3_class(outcome, "skip")
  expect_match(conditionMessage(outcome), "embed-model is not loaded.", fixed = TRUE)

  present <- data.frame(key = c("other-model", skip_helper_model))
  local_mocked_bindings(list_models = function(...) present)
  expect_identical(skip_helper_outcome(), present)
})
