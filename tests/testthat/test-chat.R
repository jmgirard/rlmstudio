test_that("Full Integration: Download, Load, and Rate", {
  local_mocked_bindings(
    has_lms = function() TRUE,
    is_server_running = function(...) TRUE
  )

  skip_if_no_lms()
  skip_if_no_server()

  target_model <- "google/gemma-3-1b"

  # Safe teardown fallback (silences the error if it runs unmocked)
  on.exit(
    {
      try(lms_unload(target_model), silent = TRUE)
    },
    add = TRUE
  )

  httptest2::with_mock_dir("chat_integration", {
    lms_download(target_model)
    lms_load(target_model, flash_attention = TRUE)

    reviews <- c(
      "The food was absolutely incredible!",
      "Terrible service, I will never go back."
    )
    sys_prompt <- "Rate on a scale of 1 to 5. Respond with ONLY the integer."

    results_df <- lms_chat_batch(
      model = target_model,
      inputs = reviews,
      system_prompt = sys_prompt,
      format = "data.frame",
      api_type = "openresponses",
      logprobs = TRUE,
      top_logprobs = 5,
      temperature = 1.0,
      quiet = TRUE
    )

    # Explicitly unload inside the mock so httptest2 records it
    try(lms_unload(target_model), silent = TRUE)
  })

  expect_s3_class(results_df, "data.frame")
  expect_true("logprobs" %in% names(results_df))
  expect_s3_class(results_df$logprobs[[1]], "data.frame")

  results_df$expected_rating <- sapply(results_df$logprobs, function(lp_df) {
    if (is.null(lp_df)) {
      return(NA_real_)
    }

    candidates <- lp_df[lp_df$step_token == lp_df$step_token[1], ]

    nums <- suppressWarnings(as.numeric(candidates$candidate_token))
    valid <- !is.na(nums) & nums %in% 1:5

    if (!any(valid)) {
      return(NA_real_)
    }

    vals <- nums[valid]
    probs <- exp(candidates$candidate_logprob[valid])
    probs <- probs / sum(probs)

    sum(vals * probs)
  })

  expect_true(all(
    results_df$expected_rating >= 1 & results_df$expected_rating <= 5
  ))
})

test_that("lms_chat routes correctly to openresponses and creates S3 class", {
  local_mocked_bindings(is_server_running = function(...) TRUE)

  fake_body <- list(
    output = list(list(
      type = "message",
      content = list(list(
        type = "output_text",
        text = "5",
        logprobs = list(
          list(
            token = "5",
            logprob = 0,
            top_logprobs = list(list(token = "5", logprob = 0))
          )
        )
      ))
    ))
  )

  local_request_recorder(
    mock_response(
      200L,
      as.character(jsonlite::toJSON(fake_body, auto_unbox = TRUE))
    )
  )

  res <- lms_chat(
    model = "test-model",
    input = "test input",
    api_type = "openresponses",
    logprobs = TRUE
  )

  expect_s3_class(res, "lms_chat_result")
  expect_equal(res$text, "5")
})

test_that("lms_chat_openresponses aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_chat_openresponses(model = "test-model", input = "test input"),
    class = "rlmstudio_no_server"
  )
})

test_that("lms_chat_openai aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_chat_openai(
      model = "test-model",
      messages = list(list(role = "user", content = "test input"))
    ),
    class = "rlmstudio_no_server"
  )
})

test_that("lms_chat_native aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_chat_native(model = "test-model", input = "test input"),
    class = "rlmstudio_no_server"
  )
})

test_that("lms_chat_batch aborts with class rlmstudio_no_server when the server is down", {
  # lms_chat() reaches a second server check further down, so it is mocked out
  # here. The abort can then only come from the call site in lms_chat_batch().
  local_mocked_bindings(
    is_server_running = function(...) FALSE,
    lms_chat = function(...) "mocked"
  )
  expect_error(
    lms_chat_batch(model = "test-model", inputs = "test input"),
    class = "rlmstudio_no_server"
  )
})

test_that("lms_chat passes rlmstudio_no_server through for api_type openresponses", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_chat(
      model = "test-model",
      input = "test input",
      api_type = "openresponses"
    ),
    class = "rlmstudio_no_server"
  )
})

test_that("lms_chat passes rlmstudio_no_server through for api_type openai", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_chat(model = "test-model", input = "test input", api_type = "openai"),
    class = "rlmstudio_no_server"
  )
})

test_that("lms_chat passes rlmstudio_no_server through for api_type native", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_chat(model = "test-model", input = "test input", api_type = "native"),
    class = "rlmstudio_no_server"
  )
})

# Call `fun` once against a mocked server that answers with `body`.
call_with_body <- function(fun, body, ...) {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, body))
  fun("a-model", "hi", ...)
}

# Items that carry no answer text. The native docs list `tool_call`,
# `reasoning`, and `invalid_tool_call` beside `message`.
reasoning_item <- '{"type": "reasoning", "content": "thinking"}'
tool_call_item <- paste0(
  '{"type": "tool_call", "tool": "t", "arguments": {}, "output": "x"}'
)
invalid_tool_call_item <- paste0(
  '{"type": "invalid_tool_call", "reason": "r", ',
  '"metadata": {"type": "invalid_name", "tool_name": "t"}}'
)
unknown_item <- '{"type": "something_new", "content": "not the answer"}'
untyped_item <- '{"content": "not the answer"}'

# Reply text values that are not one string, as JSON.
not_a_string <- c(
  number = "5",
  boolean = "true",
  array = '["p", "q"]',
  object = '{"a": 1}',
  null = "null"
)

test_that("lms_chat_native returns the text of every message item in order", {
  bodies <- list(
    list(
      label = "reasoning before the message",
      body = output_body(reasoning_item, native_message(quoted("answer"))),
      text = "answer"
    ),
    list(
      label = "a tool call between two messages",
      body = output_body(
        native_message(quoted("a")),
        tool_call_item,
        native_message(quoted("b"))
      ),
      text = "ab"
    ),
    list(
      label = "other item types between two messages",
      body = output_body(
        native_message(quoted("a")),
        invalid_tool_call_item,
        unknown_item,
        untyped_item,
        native_message(quoted("b"))
      ),
      text = "ab"
    ),
    list(
      label = "one message alone",
      body = output_body(native_message(quoted("answer"))),
      text = "answer"
    ),
    list(
      label = "an empty string",
      body = output_body(native_message(quoted(""))),
      text = ""
    )
  )
  for (case in bodies) {
    expect_identical(
      call_with_body(lms_chat_native, case$body),
      case$text,
      info = case$label
    )
  }
})

# The shapes with no readable answer text that both routes share. `message`
# builds a message item from one JSON text value.
shared_unreadable <- function(message) {
  shapes <- list(
    "no output field" = "{}",
    "an empty output array" = output_body(),
    "an output object" = sprintf('{"output": %s}', message(quoted("a"))),
    "an output string" = '{"output": "a"}',
    "an item that is a string" = output_body('"a"'),
    "an item that is a number" = output_body("5"),
    "no message item" = output_body(reasoning_item, tool_call_item)
  )
  for (kind in names(not_a_string)) {
    value <- not_a_string[[kind]]
    shapes[[paste("text that is", kind, "alone")]] <- output_body(message(value))
    shapes[[paste("text that is", kind, "beside a readable message")]] <-
      output_body(message(quoted("a")), message(value))
  }
  shapes
}

native_unreadable <- function() {
  shapes <- shared_unreadable(native_message)
  shapes[["a message with no content field"]] <- output_body('{"type": "message"}')
  shapes
}

test_that("lms_chat_native aborts as a bad response when a reply has no readable text", {
  shapes <- native_unreadable()
  for (label in names(shapes)) {
    err <- expect_error(
      call_with_body(lms_chat_native, shapes[[label]]),
      class = "rlmstudio_bad_response",
      info = label
    )
    expect_match(conditionMessage(err), "Native API Failed", info = label)
    expect_identical(err$status, 200L, info = label)
  }
})

test_that("lms_chat_native returns an unreadable reply unchanged with simplify = FALSE", {
  shapes <- native_unreadable()
  for (label in names(shapes)) {
    out <- call_with_body(lms_chat_native, shapes[[label]], simplify = FALSE)
    expect_identical(
      out,
      jsonlite::parse_json(shapes[[label]]),
      info = label
    )
  }
})
