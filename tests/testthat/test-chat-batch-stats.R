# The reply id and the stats columns of a native data-frame batch. The server is
# mocked through the shared recorder (D-004).

stats_columns <- c(
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens",
  "tokens_per_second",
  "time_to_first_token_seconds",
  "model_load_time_seconds"
)
reply_columns <- c("response_id", stats_columns)

# Run a data-frame batch whose input i is answered by `responses[[i]]`, a
# response or a body string. Returns the result and the warnings.
run_stats_batch <- function(
  responses,
  inputs = paste("input", seq_along(responses)),
  api_type = "native",
  logprobs = FALSE,
  ...
) {
  responses <- lapply(responses, function(r) {
    if (is.character(r)) mock_response(200L, r) else r
  })
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  args <- list(
    "a-model",
    inputs,
    format = "data.frame",
    quiet = TRUE,
    api_type = api_type,
    ...
  )
  if (logprobs) {
    args$logprobs <- TRUE
  }
  warnings <- testthat::capture_warnings(out <- do.call(lms_chat_batch, args))
  list(out = out, warnings = warnings)
}

# The seven reply columns of a native data frame are character and double
# whatever the rows hold.
expect_reply_column_types <- function(df, info = NULL) {
  expect_type(df$response_id, "character")
  for (col in stats_columns) {
    expect_identical(typeof(df[[col]]), "double", info = paste(info, col))
  }
}

test_that("a native data-frame batch adds the reply id and stats of each reply", {
  replies <- list(
    native_reply(
      "reply 1",
      native_stats("21", "3", "0", "284.5", "0.237", "1.5"),
      quoted("resp_a")
    ),
    native_reply(
      "reply 2",
      native_stats("42", "7", "2", "150", "0.5", "2.75"),
      quoted("resp_b")
    )
  )
  expected <- list(
    response_id = c("resp_a", "resp_b"),
    input_tokens = c(21, 42),
    total_output_tokens = c(3, 7),
    reasoning_output_tokens = c(0, 2),
    tokens_per_second = c(284.5, 150),
    time_to_first_token_seconds = c(0.237, 0.5),
    model_load_time_seconds = c(1.5, 2.75)
  )

  for (logprobs in c(FALSE, TRUE)) {
    info <- paste("logprobs:", logprobs)
    res <- run_stats_batch(replies, logprobs = logprobs)
    leading <- if (logprobs) c("input", "output", "logprobs") else c("input", "output")
    expect_identical(names(res$out), c(leading, reply_columns), info = info)
    expect_identical(res$out$output, c("reply 1", "reply 2"), info = info)
    for (col in reply_columns) {
      expect_identical(res$out[[col]], expected[[col]], info = paste(info, col))
    }
    if (logprobs) {
      # The native route ignores logprobs and says so once per input.
      expect_identical(length(res$warnings), 2L, info = info)
      for (w in res$warnings) {
        expect_match(w, "does not support logprobs", info = info)
      }
    } else {
      expect_identical(res$warnings, character(), info = info)
    }
  }
})

test_that("a native data frame keeps the row names that named inputs give", {
  inputs <- c(a = "first", b = "second")
  native <- run_stats_batch(list(native_reply("x"), native_reply("y")), inputs)
  openai <- run_stats_batch(
    list(completion_body(quoted("x")), completion_body(quoted("y"))),
    inputs,
    api_type = "openai"
  )
  expect_identical(row.names(openai$out), c("a", "b"))
  expect_identical(row.names(native$out), row.names(openai$out))
})

# Values that are not one JSON string or one JSON number. `other_scalar` is
# the scalar of the wrong type for the field.
bad_values <- function(other_scalar) {
  list(
    absent = NULL,
    null = "null",
    `the other scalar type` = other_scalar,
    boolean = "true",
    array = "[5]",
    object = '{"a": 1}'
  )
}

test_that("a field that is not one value of its column type gives NA", {
  # A number where a string belongs, and a string where a number belongs.
  fields <- list(
    response_id = "5",
    input_tokens = quoted("5"),
    tokens_per_second = quoted("5")
  )
  for (field in names(fields)) {
    for (label in names(bad_values(fields[[field]]))) {
      info <- paste(field, label)
      value <- bad_values(fields[[field]])[label]
      body <- if (field == "response_id") {
        native_reply("kept", response_id = value[[1]])
      } else {
        stats_args <- stats::setNames(value, field)
        native_reply("kept", stats = do.call(native_stats, stats_args))
      }
      res <- run_stats_batch(list(body))
      expect_identical(res$warnings, character(), info = info)
      expect_identical(res$out$output, "kept", info = info)
      na <- if (field == "response_id") NA_character_ else NA_real_
      expect_identical(res$out[[field]], na, info = info)
      # The other fields of the reply still read.
      if (field != "response_id") {
        expect_identical(res$out$response_id, "resp_1", info = info)
      }
      if (field != "total_output_tokens") {
        expect_identical(res$out$total_output_tokens, 3, info = info)
      }
    }
  }
})

test_that("an empty reply id is kept as an empty string", {
  res <- run_stats_batch(list(native_reply("kept", response_id = quoted(""))))
  expect_identical(res$out$response_id, "")
})

test_that("a stats value that is not an object gives NA in all six columns", {
  shapes <- list(
    absent = NULL,
    null = "null",
    array = "[1]",
    string = quoted("s"),
    number = "5",
    `empty object` = "{}"
  )
  for (label in names(shapes)) {
    res <- run_stats_batch(list(native_reply("kept", stats = shapes[[label]])))
    expect_identical(res$warnings, character(), info = label)
    expect_identical(res$out$output, "kept", info = label)
    expect_identical(res$out$response_id, "resp_1", info = label)
    for (col in stats_columns) {
      expect_identical(res$out[[col]], NA_real_, info = paste(label, col))
    }
  }
})

# A failed second input: a 400, or a reply with no message item that still
# carries a readable id and stats.
failing_native <- list(
  rlmstudio_api_error = mock_response(400L, '{"error": "bad request"}'),
  rlmstudio_bad_response = mock_response(
    200L,
    json_object(
      output = json_array(),
      stats = native_stats(),
      response_id = quoted("resp_bad")
    )
  )
)

test_that("a failed input holds NA in every reply column", {
  for (cls in names(failing_native)) {
    for (logprobs in c(FALSE, TRUE)) {
      info <- paste(cls, "logprobs:", logprobs)
      res <- run_stats_batch(
        list(native_reply("reply 1"), failing_native[[cls]]),
        logprobs = logprobs
      )
      expect_identical(res$out$output, c("reply 1", NA), info = info)
      expect_reply_column_types(res$out, info)
      expect_identical(res$out$response_id, c("resp_1", NA), info = info)
      for (col in stats_columns) {
        expect_true(is.na(res$out[[col]][2]), info = paste(info, col))
        expect_false(is.na(res$out[[col]][1]), info = paste(info, col))
      }
      failure <- grep("input failed", res$warnings, value = TRUE)
      expect_identical(length(failure), 1L, info = info)
      expect_match(failure, "at position 2\\.", info = info)
    }
  }
})

test_that("the reply columns are there when every input failed", {
  for (cls in names(failing_native)) {
    for (logprobs in c(FALSE, TRUE)) {
      info <- paste(cls, "logprobs:", logprobs)
      res <- run_stats_batch(
        list(failing_native[[cls]], failing_native[[cls]]),
        logprobs = logprobs
      )
      expect_true(all(reply_columns %in% names(res$out)), info = info)
      expect_reply_column_types(res$out, info)
      for (col in reply_columns) {
        expect_true(all(is.na(res$out[[col]])), info = paste(info, col))
      }
    }
  }
})
