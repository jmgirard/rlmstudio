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

# The item bodies and the tables of unreadable replies live in
# helper-chat-bodies.R, which the batch tests share.

# Assert that `msg` carries the detail sentence `detail` and no other one from
# `unreadable_details`, so a shape that reaches the wrong check fails.
expect_detail <- function(msg, detail, info) {
  expect_match(msg, detail, fixed = TRUE, info = info)
  for (other in setdiff(unreadable_details, detail)) {
    expect_no_match(msg, other, fixed = TRUE, info = paste(info, "-", other))
  }
}

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

test_that("lms_chat_native aborts as a bad response when a reply has no readable text", {
  shapes <- native_unreadable()
  details <- native_unreadable_details()
  expect_identical(names(details), names(shapes))
  for (label in names(shapes)) {
    err <- expect_error(
      call_with_body(lms_chat_native, shapes[[label]]),
      class = "rlmstudio_bad_response",
      info = label
    )
    expect_match(conditionMessage(err), "Native API Failed", info = label)
    expect_detail(conditionMessage(err), details[[label]], info = label)
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

test_that("lms_chat_openresponses returns the text of every output_text part in order", {
  bodies <- list(
    list(
      label = "reasoning before the message",
      body = output_body(
        responses_reasoning_item,
        responses_message(output_text(quoted("answer")))
      ),
      text = "answer"
    ),
    list(
      label = "two message items",
      body = output_body(
        responses_message(output_text(quoted("a"))),
        tool_call_item,
        responses_message(output_text(quoted("b")))
      ),
      text = "ab"
    ),
    list(
      label = "a refusal part between two output_text parts",
      body = output_body(responses_message(
        output_text(quoted("a")),
        refusal_part,
        output_text(quoted("b"))
      )),
      text = "ab"
    )
  )
  for (case in bodies) {
    expect_identical(
      call_with_body(lms_chat_openresponses, case$body),
      case$text,
      info = case$label
    )
    # With no logprobs in the reply, logprobs = TRUE still returns the string.
    expect_identical(
      call_with_body(lms_chat_openresponses, case$body, logprobs = TRUE),
      case$text,
      info = paste(case$label, "with logprobs = TRUE")
    )
  }
})

test_that("lms_chat_openresponses takes logprobs from every output_text part in order", {
  body <- output_body(
    responses_reasoning_item,
    responses_message(
      output_text(quoted("a"), sprintf("[%s]", logprob_step("a"))),
      refusal_part,
      output_text(quoted("b"), sprintf("[%s]", logprob_step("b")))
    ),
    responses_message(
      output_text(quoted("c"), sprintf("[%s]", logprob_step("c")))
    )
  )
  res <- call_with_body(lms_chat_openresponses, body, logprobs = TRUE)
  expect_s3_class(res, "lms_chat_result")
  expect_identical(res$text, "abc")
  expect_identical(res$logprobs$step_token, c("a", "b", "c"))

  # A part without logprobs adds text but no rows.
  body <- output_body(responses_message(
    output_text(quoted("a")),
    output_text(quoted("b"), sprintf("[%s]", logprob_step("b")))
  ))
  res <- call_with_body(lms_chat_openresponses, body, logprobs = TRUE)
  expect_identical(res$text, "ab")
  expect_identical(res$logprobs$step_token, "b")
})

# The message for each rule a `logprobs` value can break. They are written out
# here, apart from the code, so a test fails if the code names the wrong rule.
logprobs_rule_messages <- c(
  R1 = "The `logprobs` of an `output_text` part is not an array.",
  R2 = "A step in the `logprobs` of an `output_text` part is not a JSON object.",
  R3 = "The `token` of a `logprobs` step is not a string.",
  R4 = "The `logprob` of a `logprobs` step is not a number.",
  R5 = "The `top_logprobs` of a `logprobs` step is not an array of JSON objects.",
  R6 = paste(
    "A candidate in `top_logprobs` has a `token` that is not a string",
    "or a `logprob` that is not a number."
  )
)

# Assert that `body` aborts with the message for `rule`, and no other rule.
expect_logprobs_rule <- function(body, rule, info) {
  err <- expect_error(
    call_with_body(lms_chat_openresponses, body, logprobs = TRUE),
    class = "rlmstudio_bad_response",
    info = info
  )
  msg <- conditionMessage(err)
  expect_match(msg, "OpenResponses Failed", fixed = TRUE, info = info)
  for (other in names(logprobs_rule_messages)) {
    expect_identical(
      grepl(logprobs_rule_messages[[other]], msg, fixed = TRUE),
      other == rule,
      info = paste(info, "- message for", other)
    )
  }
  expect_identical(err$status, 200L, info = info)
}

# The bodies that place one bad `logprobs` value at three locations: the first
# part, a later part, and a part of a later message item. `good` is a
# readable value for the parts around it.
logprobs_locations <- function(bad, good = json_array(step_json())) {
  list(
    "the first part" = output_body(responses_message(
      output_text(quoted("a"), bad),
      output_text(quoted("b"), good)
    )),
    "a later part" = output_body(responses_message(
      output_text(quoted("a"), good),
      refusal_part,
      output_text(quoted("b"), bad)
    )),
    "a part of a later message item" = output_body(
      responses_message(output_text(quoted("a"), good)),
      tool_call_item,
      responses_message(output_text(quoted("b"), bad))
    )
  )
}

test_that("lms_chat_openresponses names the first logprobs rule a reply breaks", {
  for (case in logprobs_breaks()) {
    # R1 entries are whole values. The others are a step, placed first and
    # after two good steps.
    values <- if (case$rule == "R1") {
      list("alone" = case$value)
    } else {
      list(
        "in the first step" = json_array(case$step),
        "after good steps" = json_array(step_json(), step_json(), case$step)
      )
    }
    for (where in names(values)) {
      bodies <- logprobs_locations(values[[where]])
      for (part in names(bodies)) {
        expect_logprobs_rule(
          bodies[[part]],
          case$rule,
          info = paste(case$rule, case$label, where, "in", part)
        )
      }
    }
  }
})

test_that("a bad logprobs candidate is caught first in the list and in a later step", {
  first <- step_json(top = json_array(candidate_json(token = "5"), candidate_json()))
  expect_logprobs_rule(
    output_body(responses_message(output_text(quoted("a"), json_array(first)))),
    "R6",
    info = "a bad first candidate"
  )
  expect_logprobs_rule(
    output_body(responses_message(output_text(
      quoted("a"),
      json_array(step_json(top = json_array(candidate_json())), first)
    ))),
    "R6",
    info = "a bad candidate in a step after a good step with candidates"
  )
})

test_that("the logprobs rules are checked in order within a step and across steps", {
  one_part <- function(logprobs) {
    output_body(responses_message(output_text(quoted("a"), logprobs)))
  }
  # One step that breaks R3 and R4 names R3.
  expect_logprobs_rule(
    one_part(json_array(step_json(token = "5", logprob = "true"))),
    "R3",
    info = "a step that breaks R3 and R4"
  )
  # One step that breaks R4 and R5 names R4.
  expect_logprobs_rule(
    one_part(json_array(step_json(logprob = "true", top = "5"))),
    "R4",
    info = "a step that breaks R4 and R5"
  )
  # The candidates of a step are checked one at a time, as the steps are, so
  # a bad candidate token comes before a later candidate that is not an object.
  expect_logprobs_rule(
    one_part(json_array(
      step_json(top = json_array(candidate_json(token = "5"), "5"))
    )),
    "R6",
    info = "a bad candidate token before a candidate that is not an object"
  )
  # A bad candidate in the first step comes before a bad second step.
  expect_logprobs_rule(
    one_part(json_array(
      step_json(top = json_array(candidate_json(token = "5"))),
      "5"
    )),
    "R6",
    info = "a bad candidate before a bad step"
  )
  # A bad step in the first part comes before a bad value in the second part.
  expect_logprobs_rule(
    output_body(responses_message(
      output_text(quoted("a"), json_array(step_json(token = "5"))),
      output_text(quoted("b"), "5")
    )),
    "R3",
    info = "a bad step before a bad later part"
  )
})

test_that("lms_chat_openresponses does not check logprobs outside output_text or with logprobs = FALSE", {
  refusal_with_logprobs <- '{"type": "refusal", "refusal": "no", "logprobs": {"a": 1}}'
  body <- output_body(responses_message(
    output_text(quoted("a"), json_array(step_json(token = quoted("a")))),
    refusal_with_logprobs
  ))
  res <- call_with_body(lms_chat_openresponses, body, logprobs = TRUE)
  expect_s3_class(res, "lms_chat_result")
  expect_identical(res$text, "a")
  expect_identical(res$logprobs$step_token, "a")

  for (case in logprobs_breaks()) {
    bad <- if (case$rule == "R1") case$value else json_array(case$step)
    bodies <- logprobs_locations(bad)
    for (part in names(bodies)) {
      expect_identical(
        call_with_body(lms_chat_openresponses, bodies[[part]], logprobs = FALSE),
        "ab",
        info = paste(case$rule, case$label, "in", part)
      )
    }
  }
})

test_that("lms_chat_openresponses reads logprobs fields by their exact names", {
  logprobs_of <- function(logprobs) {
    body <- output_body(responses_message(output_text(quoted("a"), logprobs)))
    call_with_body(lms_chat_openresponses, body, logprobs = TRUE)$logprobs
  }
  frame <- function(step_token, step_logprob, candidate_token, candidate_logprob) {
    data.frame(
      step_token = step_token,
      step_logprob = step_logprob,
      candidate_token = candidate_token,
      candidate_logprob = candidate_logprob,
      stringsAsFactors = FALSE
    )
  }

  # A readable value gives one row per candidate, or one row with NA
  # candidates for a step with none.
  expect_identical(
    logprobs_of(json_array(
      step_json(quoted("x"), "-0.25", json_array(
        candidate_json(quoted("x"), "-0.25"),
        candidate_json(quoted("y"), "-2")
      )),
      step_json(quoted("z"), "-1")
    )),
    frame(c("x", "x", "z"), c(-0.25, -0.25, -1), c("x", "y", NA), c(-0.25, -2, NA))
  )

  # A field whose name only starts with the one asked for is not read.
  expect_identical(
    logprobs_of(json_array(json_object(tokenX = quoted("x"), logprobX = "-1", top_logprobsX = "[]"))),
    frame(NA_character_, NA_real_, NA_character_, NA_real_)
  )
  expect_identical(
    logprobs_of(json_array(json_object(
      token = quoted("x"),
      logprob = "-1.5",
      top_logprobsX = json_array(candidate_json())
    ))),
    frame("x", -1.5, NA_character_, NA_real_)
  )
  expect_identical(
    logprobs_of(json_array(step_json(
      quoted("x"),
      "-1.5",
      json_array(json_object(tokenX = quoted("y"), logprobX = "-2"))
    ))),
    frame("x", -1.5, NA_character_, NA_real_)
  )

  # A null or absent token or logprob gives NA, and so does a null
  # top_logprobs.
  expect_identical(
    logprobs_of(json_array(
      step_json(token = "null", logprob = "null", top = "null"),
      step_json(token = NULL, logprob = NULL, top = json_array(
        candidate_json(token = "null", logprob = "null"),
        candidate_json(token = NULL, logprob = NULL)
      ))
    )),
    frame(
      rep(NA_character_, 3),
      rep(NA_real_, 3),
      rep(NA_character_, 3),
      rep(NA_real_, 3)
    )
  )
})

test_that("lms_chat_openresponses aborts as a bad response when a reply has no readable text", {
  shapes <- responses_unreadable()
  details <- responses_unreadable_details()
  expect_identical(names(details), names(shapes))
  for (logprobs in c(FALSE, TRUE)) {
    for (label in names(shapes)) {
      info <- paste(label, "logprobs:", logprobs)
      err <- expect_error(
        call_with_body(lms_chat_openresponses, shapes[[label]], logprobs = logprobs),
        class = "rlmstudio_bad_response",
        info = info
      )
      expect_match(conditionMessage(err), "OpenResponses Failed", info = info)
      expect_detail(conditionMessage(err), details[[label]], info = info)
      expect_identical(err$status, 200L, info = info)
    }
  }
})

test_that("lms_chat_openresponses returns an unreadable reply unchanged with simplify = FALSE", {
  shapes <- responses_unreadable()
  for (label in names(shapes)) {
    out <- call_with_body(lms_chat_openresponses, shapes[[label]], simplify = FALSE)
    expect_identical(out, jsonlite::parse_json(shapes[[label]]), info = label)
  }
})
