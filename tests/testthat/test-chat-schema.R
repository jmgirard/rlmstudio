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
# value written out as text: a quoted string, or `null`.
completion_body <- function(content_json) {
  sprintf(
    paste0(
      '{"id": "chatcmpl-1", "object": "chat.completion", "choices": ',
      '[{"index": 0, "message": {"role": "assistant", "content": %s}, ',
      '"finish_reason": "stop"}]}'
    ),
    content_json
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

test_that("a reply that does not parse is returned as text without a schema", {
  out <- call_with_reply(completion_body(quoted("a score of three")))
  expect_identical(out$value, "a score of three")
})
