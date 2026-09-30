# The length rule on a character `input` in the three chat functions that
# take one. A character `input` must hold one prompt. Any other length aborts
# before the server probe, and the message points to `lms_chat_batch()`. A
# list `input`, the structured input form, is left to the server (D-036).

# native_reply(), responses_reply(), and openai_reply() live in
# helper-chat-bodies.R.
input_replies <- list(
  native = native_reply(),
  openresponses = responses_reply(),
  openai = openai_reply()
)

# A call to each function with `input` set, valid apart from it. `lms_chat()`
# runs on each of its three routes. On the openai route it is the only check
# on `input`, because `lms_chat_openai()` takes no `input` (LESSONS, M013).
input_calls <- list(
  lms_chat_native = function(input) lms_chat_native("a-model", input),
  lms_chat_openresponses = function(input) {
    lms_chat_openresponses("a-model", input)
  },
  "lms_chat native" = function(input) {
    lms_chat("a-model", input, api_type = "native")
  },
  "lms_chat openresponses" = function(input) {
    lms_chat("a-model", input, api_type = "openresponses")
  },
  "lms_chat openai" = function(input) {
    lms_chat("a-model", input, api_type = "openai")
  }
)

# The reply each call gets from the mocked server.
input_call_routes <- c(
  lms_chat_native = "native",
  lms_chat_openresponses = "openresponses",
  "lms_chat native" = "native",
  "lms_chat openresponses" = "openresponses",
  "lms_chat openai" = "openai"
)

# The length rule (AC1) -------------------------------------------------------

length_probes <- list(
  list(
    label = "no strings",
    value = character(0),
    match = "You gave 0 strings\\."
  ),
  list(
    label = "two strings",
    value = c("a", "b"),
    match = "You gave 2 strings\\."
  )
)

for (name in names(input_calls)) {
  test_that(
    paste0(name, " aborts on a character input that is not one string"),
    {
      for (p in length_probes) {
        label <- paste(name, "with", p$label)
        probe <- local_counting_probe()
        err <- tryCatch(input_calls[[name]](p$value), error = identity)

        expect_s3_class(err, "error")
        # No condition class: the argument aborts of the package are unclassed
        # (D-008).
        expect_identical(
          class(err),
          c("rlang_error", "error", "condition"),
          info = label
        )
        msg <- conditionMessage(err)
        expect_match(msg, "input", info = label)
        expect_match(msg, p$match, info = label)
        expect_match(msg, "lms_chat_batch()", fixed = TRUE, info = label)
        expect_identical(probe$calls, 0L, info = label)
      }
    }
  )
}

for (name in names(input_calls)) {
  test_that(
    paste0(name, " gives the NA message first for two strings with an NA"),
    {
      probe <- local_counting_probe()
      err <- tryCatch(input_calls[[name]](c("a", NA)), error = identity)

      expect_s3_class(err, "error")
      msg <- conditionMessage(err)
      expect_match(msg, "1 NA value\\.", info = name)
      expect_no_match(msg, "lms_chat_batch", fixed = TRUE, info = name)
      expect_identical(probe$calls, 0L, info = name)
    }
  )
}

# The forms that pass (AC2) ---------------------------------------------------

# Calls `name` against a mocked 200 reply and returns the JSON text of the one
# request it sent.
sent_input_body <- function(name, input) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, input_replies[[input_call_routes[[name]]]])
  )
  input_calls[[name]](input)
  expect_length(recorder$requests, 1L)
  request_body_text(recorder$requests[[1L]])
}

message_object <- list(type = "message", role = "user", content = "hi")
message_json <- '[{"type":"message","role":"user","content":"hi"}]'

for (name in names(input_calls)) {
  test_that(paste0(name, " sends one string and a list input as given"), {
    # The field that carries `input`. On the openai route `lms_chat()` puts it
    # in the `content` of the user message.
    field <- if (input_call_routes[[name]] == "openai") "content" else "input"

    json <- sent_input_body(name, "hi")
    expect_match(json, paste0('"', field, '":"hi"'), fixed = TRUE, info = name)

    json <- sent_input_body(name, list(message_object))
    expect_match(
      json,
      paste0('"', field, '":', message_json),
      fixed = TRUE,
      info = name
    )
  })
}

# The batch (AC3) -------------------------------------------------------------

test_that("lms_chat_batch() sends each of its inputs as one string", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L, responses_reply()))

  lms_chat_batch("a-model", c("a", "b"), quiet = TRUE)

  expect_length(recorder$requests, 2L)
  jsons <- vapply(recorder$requests, request_body_text, character(1))
  expect_match(jsons[[1L]], '"input":"a"', fixed = TRUE)
  expect_match(jsons[[2L]], '"input":"b"', fixed = TRUE)
})
