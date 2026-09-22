# lms_chat_openai(schema =) is driven through the shared recorder in
# helper-mock-http.R. A live server returns valid JSON for a schema request, so
# the replies that fail to parse are written here rather than recorded
# (D-004). The recorded happy path lives in the chat_schema_live directory.

# The request body as the JSON text that goes over the wire. The parsed form
# that request_target() returns turns `["score"]` into `"score"`, which hides
# the one-element array this file exists to check (LESSONS, M008).
sent_json <- function(req) {
  require_httpuv()
  out <- httr2::req_dry_run(req, quiet = TRUE, redact_headers = FALSE)
  rawToChar(out$body)
}

# A chat completions response whose reply content is `content_json`, a JSON
# value written out as text: a quoted string, or `null`. `finish_reason` is
# written as a JSON string, and `NULL` leaves the field out.
completion_body <- function(content_json, finish_reason = "stop") {
  finish <- if (is.null(finish_reason)) {
    ""
  } else {
    sprintf(', "finish_reason": "%s"', finish_reason)
  }
  sprintf(
    paste0(
      '{"id": "chatcmpl-1", "object": "chat.completion", "choices": ',
      '[{"index": 0, "message": {"role": "assistant", "content": %s}%s}]}'
    ),
    content_json,
    finish
  )
}

# The reply content as the JSON string the server would send for `text`.
quoted <- function(text) {
  as.character(jsonlite::toJSON(text, auto_unbox = TRUE))
}

score_schema <- list(
  type = "object",
  properties = list(score = list(type = "integer")),
  required = list("score")
)

# Call lms_chat_openai() against a mocked server that answers every request
# with `body`. Returns the value and the captured requests.
call_with_reply <- function(body, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L, body))
  value <- lms_chat_openai(
    "a-model",
    list(list(role = "user", content = "Rate this.")),
    ...
  )
  list(value = value, requests = recorder$requests)
}

test_that("a schema is sent as the documented response_format", {
  out <- call_with_reply(completion_body(quoted('{"score": 3}')), schema = score_schema)
  expect_length(out$requests, 1L)
  expect_identical(request_target(out$requests[[1]])$path, "/v1/chat/completions")

  json <- sent_json(out$requests[[1]])
  sent <- jsonlite::parse_json(json)
  expect_identical(sent$response_format$type, "json_schema")
  expect_identical(sent$response_format$json_schema$name, "response")
  expect_identical(sent$response_format$json_schema$strict, TRUE)
  expect_identical(sent$response_format$json_schema$schema, score_schema)
  # The one-element `required` field stays an array on the wire.
  expect_match(json, '"required":["score"]', fixed = TRUE)
})

test_that("no schema sends no response_format", {
  out <- call_with_reply(completion_body(quoted("plain text")))
  sent <- jsonlite::parse_json(sent_json(out$requests[[1]]))
  expect_false("response_format" %in% names(sent))
  expect_identical(out$value, "plain text")
})

test_that("an empty schema is sent as an empty JSON object", {
  out <- call_with_reply(completion_body(quoted("{}")), schema = list())
  expect_match(sent_json(out$requests[[1]]), '"schema":{}', fixed = TRUE)
})

test_that("the reply is parsed with jsonlite::parse_json() and simplified", {
  replies <- list(
    list(label = "object", text = '{"score": 3, "why": "clear"}'),
    list(label = "array", text = "[1, 2, 3]"),
    list(label = "scalar", text = "3"),
    list(label = "array of objects", text = '[{"a": 1}, {"a": 2}]'),
    list(label = "the string null", text = "null")
  )
  for (reply in replies) {
    out <- call_with_reply(completion_body(quoted(reply$text)), schema = score_schema)
    expect_identical(
      out$value,
      jsonlite::parse_json(reply$text, simplifyVector = TRUE),
      info = reply$label
    )
  }
  # The expectations above are derived from the parser itself, so one value is
  # also stated on its own.
  out <- call_with_reply(completion_body(quoted('{"score": 3}')), schema = score_schema)
  expect_identical(out$value, list(score = 3L))
  out <- call_with_reply(completion_body(quoted("null")), schema = score_schema)
  expect_null(out$value)
})

test_that("simplify = FALSE returns the response with the reply unparsed", {
  out <- call_with_reply(
    completion_body(quoted('{"score": 3}')),
    schema = score_schema,
    simplify = FALSE
  )
  expect_type(out$value, "list")
  expect_identical(out$value$choices[[1]]$message$content, '{"score": 3}')
})

test_that("logprobs = TRUE returns a chat result holding the unparsed reply", {
  out <- call_with_reply(
    completion_body(quoted('{"score": 3}')),
    schema = score_schema,
    logprobs = TRUE
  )
  expect_s3_class(out$value, "lms_chat_result")
  expect_identical(out$value$text, '{"score": 3}')
})

test_that("a reply that is not one JSON string aborts as a bad response", {
  bad <- list(
    list(label = "invalid text", content = quoted("a score of three")),
    list(label = "an empty string", content = quoted("")),
    list(label = "a JSON null content", content = "null"),
    # `jsonlite::fromJSON()` would try to fetch this. `parse_json()` reads it
    # as text and fails, which is the fault the abort names.
    list(label = "a URL", content = quoted("https://example.com/score.json"))
  )
  for (case in bad) {
    err <- expect_error(
      call_with_reply(completion_body(case$content), schema = score_schema),
      class = "rlmstudio_bad_response",
      info = case$label
    )
    expect_identical(err$status, 200L, info = case$label)
    expect_match(conditionMessage(err), "OpenAI API Failed", info = case$label)
  }
})

test_that("a 200 with no reply in choices aborts as a bad response", {
  bodies <- list(
    list(label = "no choices field", body = '{"id": "chatcmpl-1"}'),
    list(label = "an empty choices list", body = '{"id": "chatcmpl-1", "choices": []}')
  )
  settings <- list(
    list(label = "no schema", args = list()),
    list(label = "a schema", args = list(schema = score_schema)),
    list(label = "logprobs", args = list(logprobs = TRUE))
  )
  for (body in bodies) {
    for (setting in settings) {
      info <- paste(body$label, "with", setting$label)
      err <- expect_error(
        do.call(call_with_reply, c(list(body$body), setting$args)),
        class = "rlmstudio_bad_response",
        info = info
      )
      expect_identical(err$status, 200L, info = info)
      expect_match(conditionMessage(err), "choices", info = info)
      expect_true(all(c("content", "finish_reason") %in% names(err)), info = info)
      expect_null(err$content, info = info)
      expect_null(err$finish_reason, info = info)
    }
  }
})

test_that("an unreadable reply carries its content and finish reason", {
  cases <- list(
    list(label = "invalid JSON text", json = quoted("a score of"), content = "a score of"),
    list(label = "a JSON null content", json = "null", content = NULL)
  )
  for (case in cases) {
    err <- expect_error(
      call_with_reply(completion_body(case$json), schema = score_schema),
      class = "rlmstudio_bad_response",
      info = case$label
    )
    expect_true(all(c("content", "finish_reason") %in% names(err)), info = case$label)
    expect_identical(err$content, case$content, info = case$label)
    expect_identical(err$finish_reason, "stop", info = case$label)
    # The hint points at the field and no longer sends the user back to call.
    expect_match(conditionMessage(err), "content field", info = case$label)
    expect_no_match(conditionMessage(err), "Call again", info = case$label)
    expect_no_match(conditionMessage(err), "simplify = FALSE", info = case$label)

    # A response without a finish reason gives the field as NULL.
    err <- expect_error(
      call_with_reply(completion_body(case$json, finish_reason = NULL), schema = score_schema),
      class = "rlmstudio_bad_response",
      info = case$label
    )
    expect_true("finish_reason" %in% names(err), info = case$label)
    expect_null(err$finish_reason, info = case$label)
  }
})

test_that("a reply cut off at the token limit names max_tokens", {
  cases <- list(
    list(label = "not one string", json = "null", detail = "is not one string"),
    list(label = "not valid JSON", json = quoted('{"score": '), detail = "is not valid JSON")
  )
  for (case in cases) {
    cut <- expect_error(
      call_with_reply(completion_body(case$json, "length"), schema = score_schema),
      class = "rlmstudio_bad_response",
      info = case$label
    )
    expect_match(conditionMessage(cut), "token limit cut the reply off", info = case$label)
    expect_match(conditionMessage(cut), "max_tokens", info = case$label)
    expect_identical(cut$finish_reason, "length", info = case$label)

    # The same content with another finish reason keeps the existing detail.
    done <- expect_error(
      call_with_reply(completion_body(case$json, "stop"), schema = score_schema),
      class = "rlmstudio_bad_response",
      info = case$label
    )
    expect_match(conditionMessage(done), case$detail, info = case$label)
    expect_no_match(conditionMessage(done), "max_tokens", info = case$label)
  }
})

test_that("a reply naming a file is not read from disk", {
  # `jsonlite::fromJSON()` would read this file and return its contents as the
  # answer. The URL case above cannot show the difference offline, because a
  # failed fetch also ends in the abort. A file that holds valid JSON can.
  path <- withr::local_tempfile(fileext = ".json")
  writeLines('{"score": 9}', path)
  expect_identical(jsonlite::fromJSON(path), list(score = 9L))

  err <- expect_error(
    call_with_reply(completion_body(quoted(path)), schema = score_schema),
    class = "rlmstudio_bad_response"
  )
  expect_identical(err$status, 200L)
})

test_that("a structured reply recorded from a live server parses", {
  # The cassette in chat_schema_live/ was recorded against a real LM Studio
  # server running google/gemma-3-1b. Regenerate it with
  # data-raw/record-schema-cassette.R, which carries the full provenance. The
  # request below must match the script's request byte for byte, because
  # httptest2 finds the cassette by a hash of the request body.
  local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = NA)
  withr::local_options(rlmstudio.token = NULL)

  live_call <- function(simplify) {
    lms_chat_openai(
      model = "google/gemma-3-1b",
      messages = list(
        list(
          role = "user",
          content = "Rate how positive this review is from 1 to 5: 'Great value.'"
        )
      ),
      host = "http://localhost:1234",
      simplify = simplify,
      temperature = 0,
      schema = score_schema
    )
  }

  httptest2::with_mock_dir("chat_schema_live", {
    parsed <- live_call(simplify = TRUE)
    raw <- live_call(simplify = FALSE)
  })

  content <- raw$choices[[1]]$message$content
  expect_type(content, "character")
  expect_identical(parsed, jsonlite::parse_json(content, simplifyVector = TRUE))
  # Stated apart from the parser: the recorded reply is `{ "score": 3 }`.
  expect_identical(parsed, list(score = 3L))
})

test_that("lms_chat() forwards a schema on the openai route", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, completion_body(quoted('{"score": 4}')))
  )
  value <- lms_chat("a-model", "Rate this.", api_type = "openai", schema = score_schema)

  expect_identical(value, list(score = 4L))
  sent <- jsonlite::parse_json(sent_json(recorder$requests[[1]]))
  expect_identical(sent$response_format$json_schema$schema, score_schema)
})

# Run lms_chat_batch() over two inputs against a mocked server that answers
# every request with a reply whose content is `reply_text`.
batch_with_reply <- function(reply_text, format) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, completion_body(quoted(reply_text))))
  lms_chat_batch(
    "a-model",
    c("first", "second"),
    format = format,
    quiet = TRUE,
    api_type = "openai",
    schema = score_schema
  )
}

test_that("batch format list returns one parsed reply per input", {
  out <- batch_with_reply('{"score": 3}', "list")
  expect_identical(out, list(list(score = 3L), list(score = 3L)))
})

test_that("batch format vector warns and returns the list for any reply", {
  expect_warning(
    out <- batch_with_reply('{"score": 3}', "vector"),
    "cannot store replies parsed"
  )
  expect_identical(out, list(list(score = 3L), list(score = 3L)))

  # A scalar reply would fit a vector, and still comes back as a list.
  expect_warning(
    out <- batch_with_reply("3", "vector"),
    "cannot store replies parsed"
  )
  expect_identical(out, list(3L, 3L))
})

test_that("batch format data.frame holds parsed replies in a list-column", {
  out <- batch_with_reply('{"score": 3}', "data.frame")
  expect_s3_class(out, "data.frame")
  expect_identical(out$input, c("first", "second"))
  expect_type(out$output, "list")
  expect_identical(out$output, list(list(score = 3L), list(score = 3L)))
})

test_that("batch reads shortened argument names as lms_chat() does", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, completion_body(quoted('{"score": 3}'))))

  # `api` is how lms_chat() would take `api_type`, so the route check passes.
  out <- lms_chat_batch(
    "a-model",
    "first",
    format = "list",
    quiet = TRUE,
    api = "openai",
    schema = score_schema
  )
  expect_identical(out, list(list(score = 3L)))

  # `log` is how lms_chat() would take `logprobs`, so the reply is not parsed
  # and the vector format names logprobs, not the schema.
  expect_warning(
    lms_chat_batch(
      "a-model",
      "first",
      quiet = TRUE,
      api_type = "openai",
      log = TRUE,
      schema = score_schema
    ),
    "cannot store logprobs"
  )
})

test_that("a reply that does not parse is returned as text without a schema", {
  out <- call_with_reply(completion_body(quoted("a score of three")))
  expect_identical(out$value, "a score of three")
})
