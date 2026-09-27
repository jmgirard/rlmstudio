# A chat completions reply with two choices is read from its first choice
# alone, with `simplify = TRUE` (D-022). The two choices hold different
# content, so a test can tell which one was read. two_choice_body(), quoted(),
# and score_schema live in helper-chat-bodies.R, and collect_warnings() and
# warnings_of_class() live in helper-conditions.R.

# Call lms_chat_openai() once against `body`, and collect its warnings.
call_two_choices <- function(body, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, body))
  collect_warnings(
    lms_chat_openai(
      "a-model",
      list(list(role = "user", content = "Say something.")),
      ...
    )
  )
}

cut_off_count <- function(out) {
  length(warnings_of_class(out$warnings, "rlmstudio_reply_cut_off"))
}

test_that("a text reply is read from its first choice", {
  settings <- list(
    "no schema" = list(),
    "logprobs" = list(logprobs = TRUE),
    "schema with logprobs" = list(schema = score_schema, logprobs = TRUE)
  )
  contents <- c(quoted("first"), quoted("second"))
  for (label in names(settings)) {
    args <- settings[[label]]
    text_of <- function(value) {
      if (isTRUE(args$logprobs)) {
        expect_s3_class(value, "lms_chat_result")
        value$text
      } else {
        value
      }
    }

    # A second choice cut off, the first one whole: no warning.
    out <- do.call(
      call_two_choices,
      c(list(two_choice_body(contents, c("stop", "length"))), args)
    )
    expect_identical(text_of(out$value), "first", info = label)
    expect_identical(cut_off_count(out), 0L, info = label)

    # The first choice cut off: one warning, and still the first text.
    out <- do.call(
      call_two_choices,
      c(list(two_choice_body(contents, c("length", "stop"))), args)
    )
    expect_identical(text_of(out$value), "first", info = label)
    expect_identical(cut_off_count(out), 1L, info = label)
  }
})

test_that("a schema reply is read from its first choice", {
  contents <- c(quoted('{"score": 3}'), quoted('{"score": 4}'))

  out <- call_two_choices(
    two_choice_body(contents, c("stop", "length")),
    schema = score_schema
  )
  expect_identical(out$value, list(score = 3L))
  expect_identical(cut_off_count(out), 0L)

  err <- expect_error(
    call_two_choices(
      two_choice_body(contents, c("length", "stop")),
      schema = score_schema
    ),
    class = "rlmstudio_bad_response"
  )
  expect_identical(err$content, '{"score": 3}')
  expect_identical(err$finish_reason, "length")
})

test_that("a batch reads each reply from its first choice", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    mock_response(200L, completion_body(quoted("one"))),
    mock_response(
      200L,
      two_choice_body(c(quoted("two"), quoted("other")), c("stop", "length"))
    )
  ))
  out <- collect_warnings(
    lms_chat_batch("a-model", c("a", "b"), api_type = "openai", quiet = TRUE)
  )
  expect_identical(out$value[[2]], "two")
  expect_identical(cut_off_count(out), 0L)
})
