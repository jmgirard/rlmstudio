test_that("lms_chat aborts if server is off", {
  local_mocked_bindings(is_server_running = function() FALSE)

  expect_error(
    lms_chat("model-id", "Hello"),
    "The LM Studio server is not running"
  )
})

test_that("lms_chat_batch handles data.frame format correctly", {
  local_mocked_bindings(is_server_running = function() TRUE)

  local_mocked_bindings(lms_chat = function(...) "Mocked output")

  res <- lms_chat_batch(
    model = "test-model",
    inputs = c("prompt 1", "prompt 2"),
    format = "data.frame",
    quiet = TRUE
  )

  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 2)
  expect_equal(res$output, c("Mocked output", "Mocked output"))
})

test_that("lms_chat_batch errors on empty input", {
  local_mocked_bindings(is_server_running = function() TRUE)
  expect_error(
    lms_chat_batch("model", character(0)),
    "must be a non-empty character vector"
  )
})
