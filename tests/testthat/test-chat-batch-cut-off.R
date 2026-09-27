# lms_chat_batch(api_type = "openai") over text replies that a length limit
# cut off. Each input's own cut-off warning is muffled, and the batch gives one
# warning of the same class that names the positions (D-021).
# completion_body() and quoted() live in helper-chat-bodies.R, and
# collect_warnings() lives in helper-conditions.R.

# Four replies, "one" to "four". The second and fourth were cut off. An entry
# of `fail` is answered with status 500 instead.
cut_off_replies <- function(fail = integer()) {
  texts <- c("one", "two", "three", "four")
  reasons <- c("stop", "length", "stop", "length")
  lapply(seq_along(texts), function(i) {
    if (i %in% fail) {
      return(mock_response(500L, '{"error": {"message": "boom"}}'))
    }
    mock_response(200L, completion_body(quoted(texts[[i]]), reasons[[i]]))
  })
}

# Run the batch over four inputs against `responses`, in order.
run_cut_off_batch <- function(responses, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  collect_warnings(
    lms_chat_batch(
      "a-model",
      c("a", "b", "c", "d"),
      api_type = "openai",
      ...
    )
  )
}

# The one cut-off warning of `warnings`, checked for its count and positions.
expect_one_cut_off_warning <- function(warnings, info) {
  cut_off <- warnings_of_class(warnings, "rlmstudio_reply_cut_off")
  expect_identical(length(cut_off), 1L, info = info)
  message <- gsub("\\s+", " ", conditionMessage(cut_off[[1]]))
  expect_match(message, "2 inputs", fixed = TRUE, info = info)
  expect_match(message, "positions 2 and 4", fixed = TRUE, info = info)
  expect_match(message, "max_tokens", fixed = TRUE, info = info)
  expect_match(message, "context length", fixed = TRUE, info = info)
}

test_that("a text batch gives one cut-off warning and keeps every reply", {
  texts <- c("one", "two", "three", "four")
  for (format in c("vector", "list", "data.frame")) {
    res <- run_cut_off_batch(cut_off_replies(), format = format, quiet = TRUE)
    expect_identical(length(res$warnings), 1L, info = format)
    expect_one_cut_off_warning(res$warnings, format)
    out <- switch(
      format,
      vector = res$value,
      list = unlist(res$value),
      data.frame = res$value$output
    )
    expect_identical(out, texts, info = format)
    if (format == "list") {
      expect_type(res$value, "list")
    }
  }

  res <- run_cut_off_batch(cut_off_replies(), format = "list", logprobs = TRUE, quiet = TRUE)
  expect_identical(length(res$warnings), 1L)
  expect_one_cut_off_warning(res$warnings, "logprobs")
  for (i in seq_along(texts)) {
    expect_s3_class(res$value[[i]], "lms_chat_result")
    expect_identical(res$value[[i]]$text, texts[[i]], info = paste("logprobs", i))
  }
})

test_that("the batch cut-off warning shows with quiet off", {
  # The runs above cover `quiet = TRUE`. `lms_chat_batch()` defaults to
  # `quiet = FALSE`, so it never reads the `rlmstudio.quiet` option.
  withr::local_options(rlmstudio.quiet = FALSE)
  res <- run_cut_off_batch(cut_off_replies(), format = "vector", quiet = FALSE)
  expect_one_cut_off_warning(res$warnings, "quiet = FALSE")
})

test_that("a failed input and a cut-off reply give one warning each", {
  res <- run_cut_off_batch(cut_off_replies(fail = 3L), format = "vector", quiet = TRUE)
  expect_identical(res$value, c("one", "two", NA_character_, "four"))
  expect_identical(length(res$warnings), 2L)
  # The failed-inputs warning comes first.
  expect_match(conditionMessage(res$warnings[[1]]), "1 input failed, at position 3\\.")
  expect_false(inherits(res$warnings[[1]], "rlmstudio_reply_cut_off"))
  expect_s3_class(res$warnings[[2]], "rlmstudio_reply_cut_off")
  expect_one_cut_off_warning(res$warnings, "a failed input")
})

test_that("a batch that aborts still warns about the cut-off inputs before it", {
  # Status 401 at the third input aborts the batch. The abort's `results`
  # keep the cut-off reply at position 2, so the warning must name it.
  replies <- cut_off_replies()[1:2]
  replies[[3]] <- mock_response(401L, '{"error": {"message": "no"}}')
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(replies)
  warnings <- list()
  err <- expect_error(
    withCallingHandlers(
      lms_chat_batch("a-model", c("a", "b", "c", "d"), api_type = "openai", quiet = TRUE),
      warning = function(w) {
        warnings[[length(warnings) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    ),
    class = "rlmstudio_api_error"
  )
  expect_identical(err$status, 401L)
  expect_identical(err$results[1:2], list("one", "two"))
  expect_identical(length(warnings), 1L)
  cut_off <- warnings_of_class(warnings, "rlmstudio_reply_cut_off")
  expect_identical(length(cut_off), 1L)
  message <- gsub("\\s+", " ", conditionMessage(cut_off[[1]]))
  expect_match(message, "1 input", fixed = TRUE)
  expect_match(message, "position 2", fixed = TRUE)

  # A lost server aborts the same way. The batch probes once before the
  # loop, and each call probes again, so the fourth probe is the third call's.
  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes < 4L
  })
  local_request_sequence(cut_off_replies())
  warnings <- list()
  err <- expect_error(
    withCallingHandlers(
      lms_chat_batch("a-model", c("a", "b", "c", "d"), api_type = "openai", quiet = TRUE),
      warning = function(w) {
        warnings[[length(warnings) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    ),
    class = "rlmstudio_no_server"
  )
  expect_identical(err$results[1:2], list("one", "two"))
  cut_off <- warnings_of_class(warnings, "rlmstudio_reply_cut_off")
  expect_identical(length(cut_off), 1L)
  expect_match(conditionMessage(cut_off[[1]]), "position 2", fixed = TRUE)

  # A batch that aborts before any cut-off reply gives no such warning.
  local_request_sequence(list(mock_response(401L, '{"error": {"message": "no"}}')))
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  warnings <- list()
  expect_error(
    withCallingHandlers(
      lms_chat_batch("a-model", c("a", "b"), api_type = "openai", quiet = TRUE),
      warning = function(w) {
        warnings[[length(warnings) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    ),
    class = "rlmstudio_api_error"
  )
  expect_identical(length(warnings_of_class(warnings, "rlmstudio_reply_cut_off")), 0L)
})

test_that("a batch with no cut-off reply gives no cut-off warning", {
  replies <- lapply(c("one", "two"), function(text) {
    mock_response(200L, completion_body(quoted(text)))
  })
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(replies)
  res <- collect_warnings(
    lms_chat_batch("a-model", c("a", "b"), api_type = "openai", quiet = TRUE)
  )
  expect_identical(res$value, c("one", "two"))
  expect_identical(length(res$warnings), 0L)
})
