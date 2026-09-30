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

# completion_body(), quoted(), and score_schema live in helper-chat-bodies.R.

# A finish reason of "length" comes from either limit, so the message of a
# cut-off reply names both of them.
expect_length_limit_message <- function(cnd, info = NULL) {
  message <- gsub("\\s+", " ", conditionMessage(cnd))
  expect_match(message, "max_tokens", fixed = TRUE, info = info)
  expect_match(message, "context length", fixed = TRUE, info = info)
}

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

test_that("a nested empty object is sent as {} when written with empty names", {
  schema <- list(type = "object", properties = setNames(list(), character()))
  out <- call_with_reply(completion_body(quoted("{}")), schema = schema)
  expect_match(sent_json(out$requests[[1]]), '"properties":{}', fixed = TRUE)

  # The documented reason: a bare list() goes out as an array.
  schema <- list(type = "object", properties = list())
  out <- call_with_reply(completion_body(quoted("{}")), schema = schema)
  expect_match(sent_json(out$requests[[1]]), '"properties":[]', fixed = TRUE)
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

test_that("a choices field that is not an array of objects aborts as a bad response", {
  bodies <- list(
    list(label = "a JSON object", body = '{"choices": {"a": {"message": {"content": "{}"}}}}'),
    list(label = "an array of numbers", body = '{"choices": [1]}'),
    list(label = "an array of strings", body = '{"choices": ["{}"]}'),
    list(label = "an array of arrays", body = '{"choices": [[{"message": {"content": "{}"}}]]}'),
    list(label = "an array of empty arrays", body = '{"choices": [[]]}'),
    list(label = "a message that is a string", body = '{"choices": [{"message": "x"}]}'),
    list(label = "a message that is a number", body = '{"choices": [{"message": 5}]}'),
    list(label = "a message that is null", body = '{"choices": [{"message": null}]}'),
    list(label = "a choice with no message", body = '{"choices": [{"index": 0}]}'),
    list(label = "an empty choice", body = '{"choices": [{}]}'),
    list(label = "a field that only starts with choices", body = '{"choicesX": [{"message": {"content": "{}"}}]}'),
    list(label = "a field that only starts with message", body = '{"choices": [{"messageX": {"content": "{}"}}]}')
  )
  settings <- list(
    list(schema = NULL),
    list(schema = score_schema),
    list(logprobs = TRUE)
  )
  for (body in bodies) {
    for (setting in settings) {
      err <- expect_error(
        do.call(call_with_reply, c(list(body$body), setting)),
        class = "rlmstudio_bad_response",
        info = body$label
      )
      expect_identical(err$status, 200L, info = body$label)
      expect_match(conditionMessage(err), "choices", info = body$label)
      expect_null(err$content, info = body$label)
    }
  }
})

test_that("an unreadable reply carries its content and finish reason", {
  cases <- list(
    list(
      label = "invalid JSON text",
      json = quoted("a score of"),
      content = "a score of",
      hint = "reply content is in the content field"
    ),
    list(
      label = "a JSON null content",
      json = "null",
      content = NULL,
      hint = "reply has no text"
    )
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
    # A NULL content gets a hint that does not point at text that is not there.
    message <- gsub("\\s+", " ", conditionMessage(err))
    expect_match(message, case$hint, info = case$label)
    if (is.null(case$content)) {
      expect_no_match(message, "reply content is in", info = case$label)
    }
    expect_match(message, "finish_reason field", info = case$label)
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
    # The hint does not point at a finish_reason field that is NULL.
    message <- gsub("\\s+", " ", conditionMessage(err))
    expect_no_match(message, "finish_reason field", info = case$label)
  }
})

test_that("reply fields are read by their exact names", {
  # R's `$` would read a field that only starts with the name asked for.
  body <- paste0(
    '{"choices": [{"message": {"content_parts": "{}"}, ',
    '"finish_reasonX": "length"}]}'
  )
  err <- expect_error(
    call_with_reply(body, schema = score_schema),
    class = "rlmstudio_bad_response"
  )
  expect_null(err$content)
  expect_null(err$finish_reason)
  expect_no_match(conditionMessage(err), "max_tokens")
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
    expect_length_limit_message(cut, info = case$label)
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

test_that("a schema reply cut off at the token limit aborts even when it parses", {
  cut_body <- completion_body(quoted("3"), finish_reason = "length")
  calls <- list(
    "lms_chat_openai()" = function(body) {
      call_with_reply(body, schema = score_schema)$value
    },
    "lms_chat()" = function(body) {
      testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
      local_request_recorder(mock_response(200L, body))
      lms_chat("a-model", "Rate this.", api_type = "openai", schema = score_schema)
    }
  )
  for (label in names(calls)) {
    call <- calls[[label]]
    err <- expect_error(call(cut_body), class = "rlmstudio_bad_response", info = label)
    expect_identical(err$status, 200L, info = label)
    expect_identical(err$content, "3", info = label)
    expect_identical(err$finish_reason, "length", info = label)
    expect_match(conditionMessage(err), "OpenAI API Failed", info = label)
    expect_length_limit_message(err, info = label)

    # The same reply that the model ended on its own is a whole answer.
    done <- call(completion_body(quoted("3"), finish_reason = "stop"))
    expect_identical(done, 3L, info = label)
  }
})

test_that("a text reply cut off at the token limit warns and keeps its value", {
  settings <- list(
    list(label = "no schema", args = list()),
    list(label = "logprobs", args = list(logprobs = TRUE)),
    list(label = "a schema and logprobs", args = list(schema = score_schema, logprobs = TRUE))
  )
  text <- quoted('{"score": 3}')
  for (setting in settings) {
    info <- setting$label
    call <- function(finish_reason) {
      body <- completion_body(text, finish_reason = finish_reason)
      collect_warnings(do.call(call_with_reply, c(list(body), setting$args)))
    }
    cut <- call("length")
    done <- call("stop")
    expect_identical(cut$value$value, done$value$value, info = info)
    expect_identical(length(cut$warnings), 1L, info = info)
    expect_s3_class(cut$warnings[[1]], "rlmstudio_reply_cut_off")
    expect_length_limit_message(cut$warnings[[1]], info = info)
    # A reply that the model ended on its own, or with no finish reason,
    # gives no warning.
    expect_identical(length(done$warnings), 0L, info = info)
    expect_identical(length(call(NULL)$warnings), 0L, info = info)
  }
  # Stated apart from the call with "stop": the text comes back as sent.
  expect_identical(
    collect_warnings(call_with_reply(completion_body(text, "length")))$value$value,
    '{"score": 3}'
  )

  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, completion_body(quoted("a"), "length")))
  res <- collect_warnings(lms_chat("a-model", "Say a.", api_type = "openai"))
  expect_identical(res$value, "a")
  expect_identical(length(res$warnings), 1L)
  expect_s3_class(res$warnings[[1]], "rlmstudio_reply_cut_off")
  expect_length_limit_message(res$warnings[[1]])
})

test_that("the cut-off warning shows with quiet on", {
  withr::local_options(rlmstudio.quiet = TRUE)
  w <- expect_warning(
    out <- call_with_reply(completion_body(quoted("a"), "length")),
    class = "rlmstudio_reply_cut_off"
  )
  expect_length_limit_message(w)
  expect_identical(out$value, "a")
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

test_that("a reply that LM Studio cut off at the token limit names max_tokens", {
  # The cassette in chat_cutoff_live/ was recorded against a real LM Studio
  # server running google/gemma-3-1b with max_tokens 5. Regenerate it with
  # data-raw/record-cutoff-cassette.R, which carries the full provenance. The
  # request below must match the script's request byte for byte.
  local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = NA)
  withr::local_options(rlmstudio.token = NULL)

  live_call <- function(simplify) {
    lms_chat_openai(
      model = "google/gemma-3-1b",
      messages = list(
        list(
          role = "user",
          content = paste(
            "Rate how positive this review is from 1 to 5 and explain why:",
            "'Great value.'"
          )
        )
      ),
      host = "http://localhost:1234",
      simplify = simplify,
      temperature = 0,
      max_tokens = 5,
      schema = list(
        type = "object",
        properties = list(
          why = list(type = "string"),
          score = list(type = "integer")
        ),
        required = list("why", "score")
      )
    )
  }

  httptest2::with_mock_dir("chat_cutoff_live", {
    raw <- live_call(simplify = FALSE)
    err <- expect_error(live_call(simplify = TRUE), class = "rlmstudio_bad_response")
  })

  # The value comes from LM Studio, not from a hand-written body.
  expect_identical(raw$choices[[1]]$finish_reason, "length")
  expect_length_limit_message(err)
  expect_identical(err$finish_reason, "length")
  expect_identical(err$content, raw$choices[[1]]$message$content)
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

# Run lms_chat_batch() over `inputs` against a mocked server that answers
# every request with a reply whose content is `reply_text`.
batch_with_reply <- function(
  reply_text,
  format,
  schema = score_schema,
  inputs = c("first", "second")
) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, completion_body(quoted(reply_text))))
  lms_chat_batch(
    "a-model",
    inputs,
    format = format,
    quiet = TRUE,
    api_type = "openai",
    schema = schema
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

# Run lms_chat_batch() over `inputs` against a mocked server that answers
# them with `responses`, in order.
batch_with_sequence <- function(
  responses,
  format = "list",
  quiet = TRUE,
  schema = score_schema,
  inputs = c("first", "second", "third")
) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  lms_chat_batch(
    "a-model",
    inputs,
    format = format,
    quiet = quiet,
    api_type = "openai",
    schema = schema
  )
}

invalid_valid_invalid <- function() {
  list(
    mock_response(200L, completion_body(quoted("not json one"))),
    mock_response(200L, completion_body(quoted('{"score": 3}'))),
    mock_response(200L, completion_body(quoted("not json three")))
  )
}

# The elements a batch returns for invalid_valid_invalid(), checked by
# identity: the conditions carry their own reply text, and the middle element
# is the parsed reply.
expect_failed_slots <- function(elements) {
  expect_length(elements, 3L)
  expect_s3_class(elements[[1]], "rlmstudio_bad_response")
  expect_identical(elements[[1]]$content, "not json one")
  expect_identical(elements[[2]], list(score = 3L))
  expect_s3_class(elements[[3]], "rlmstudio_bad_response")
  expect_identical(elements[[3]]$content, "not json three")
  # A stored condition keeps no backtrace, which would make each failed slot
  # large.
  expect_null(elements[[1]]$trace)
  expect_null(elements[[3]]$trace)
}

test_that("a batch keeps going past a structured reply that does not parse", {
  for (format in c("list", "vector")) {
    warnings <- testthat::capture_warnings(
      out <- batch_with_sequence(invalid_valid_invalid(), format)
    )
    # One warning only, and the vector format does not add its own.
    expect_length(warnings, 1L)
    expect_match(warnings, "2 inputs", info = format)
    expect_match(warnings, "positions 1 and 3", info = format)
    expect_match(warnings, "any reply content", info = format)
    # The one warning also says that a vector batch came back as a list.
    if (format == "vector") {
      expect_match(warnings, "Returning list", info = format)
    } else {
      expect_no_match(warnings, "Returning list", info = format)
    }
    expect_type(out, "list")
    expect_failed_slots(out)
  }

  warnings <- testthat::capture_warnings(
    out <- batch_with_sequence(invalid_valid_invalid(), "data.frame")
  )
  expect_length(warnings, 1L)
  expect_match(warnings, "positions 1 and 3")
  expect_s3_class(out, "data.frame")
  expect_identical(out$input, c("first", "second", "third"))
  expect_failed_slots(out$output)
})

test_that("a batch keeps going past a message that is not an object", {
  responses <- list(
    mock_response(200L, completion_body(quoted('{"score": 3}'))),
    mock_response(200L, '{"choices": [{"message": "x"}]}'),
    mock_response(200L, completion_body(quoted('{"score": 3}')))
  )
  expect_warning(
    out <- batch_with_sequence(responses),
    "position 2"
  )
  expect_identical(out[[1]], list(score = 3L))
  expect_s3_class(out[[2]], "rlmstudio_bad_response")
  expect_identical(out[[3]], list(score = 3L))
})

test_that("the failed reply warning ignores quiet", {
  # With the option on, `quiet = NULL` reads the option and hides the bar,
  # `quiet = FALSE` decides over it, and `quiet = TRUE` hides the bar too. The
  # warning shows in each case.
  withr::local_options(rlmstudio.quiet = TRUE)
  expect_warning(
    batch_with_sequence(invalid_valid_invalid(), "list", quiet = NULL),
    "positions 1 and 3"
  )
  expect_warning(
    batch_with_sequence(invalid_valid_invalid(), "list", quiet = FALSE),
    "positions 1 and 3"
  )
  expect_warning(
    batch_with_sequence(invalid_valid_invalid(), "list", quiet = TRUE),
    "positions 1 and 3"
  )
})

test_that("the progress bar moves past a failed input", {
  withr::local_options(rlmstudio.quiet = FALSE)
  updates <- 0L
  testthat::local_mocked_bindings(
    cli_progress_update = function(...) updates <<- updates + 1L,
    .package = "cli"
  )
  expect_warning(
    out <- batch_with_sequence(invalid_valid_invalid(), "list", quiet = FALSE),
    "positions 1 and 3"
  )
  # One update per input, the two failed ones included.
  expect_identical(updates, 3L)
  expect_failed_slots(out)
})

test_that("the failed reply warning names every position past 20", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, completion_body(quoted("not json"))))
  warnings <- testthat::capture_warnings(
    lms_chat_batch(
      "a-model",
      as.character(1:25),
      format = "list",
      quiet = TRUE,
      api_type = "openai",
      schema = score_schema
    )
  )
  expect_length(warnings, 1L)
  # cli wraps a long message, so the line breaks are read as spaces.
  text <- gsub("\\s+", " ", warnings)
  expect_match(text, "25 inputs")
  expect_match(text, paste0("positions ", toString(1:24), ", and 25"), fixed = TRUE)
  expect_no_match(text, "…", fixed = TRUE)
  expect_no_match(text, "...", fixed = TRUE)
})

test_that("a batch with no failed reply keeps the vector format warning", {
  valid <- mock_response(200L, completion_body(quoted('{"score": 3}')))
  warnings <- testthat::capture_warnings(
    out <- batch_with_sequence(list(valid, valid, valid), "vector")
  )
  expect_length(warnings, 1L)
  expect_match(warnings, "cannot store replies parsed")
  expect_identical(out, rep(list(list(score = 3L)), 3L))
})

test_that("a batch with a schema fails an input whose reply was cut off", {
  responses <- function() {
    list(
      mock_response(200L, completion_body(quoted("3"))),
      mock_response(200L, completion_body(quoted("3"), finish_reason = "length")),
      mock_response(200L, completion_body(quoted("3")))
    )
  }
  for (format in c("list", "data.frame")) {
    res <- collect_warnings(batch_with_sequence(responses(), format))
    out <- if (format == "list") res$value else res$value$output
    expect_identical(out[[1]], 3L, info = format)
    expect_s3_class(out[[2]], "rlmstudio_bad_response")
    expect_identical(out[[2]]$content, "3", info = format)
    expect_identical(out[[2]]$finish_reason, "length", info = format)
    expect_identical(out[[3]], 3L, info = format)

    # The failed-inputs warning alone, and no cut-off warning.
    expect_identical(length(res$warnings), 1L, info = format)
    expect_match(
      conditionMessage(res$warnings[[1]]),
      "1 input failed, at position 2\\.",
      info = format
    )
    cut_off <- warnings_of_class(res$warnings, "rlmstudio_reply_cut_off")
    expect_identical(length(cut_off), 0L, info = format)
  }
})

test_that("simplify = FALSE returns a cut-off reply unchanged", {
  body <- completion_body(quoted("3"), finish_reason = "length")
  for (schema in list(NULL, score_schema)) {
    info <- if (is.null(schema)) "no schema" else "a schema"
    res <- collect_warnings(
      call_with_reply(body, schema = schema, simplify = FALSE)
    )
    expect_identical(res$value$value, jsonlite::parse_json(body), info = info)
    # Stated apart from the parser.
    expect_identical(res$value$value$choices[[1]]$message$content, "3", info = info)
    expect_identical(res$value$value$choices[[1]]$finish_reason, "length", info = info)
    expect_identical(length(res$warnings), 0L, info = info)
  }

  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    mock_response(200L, completion_body(quoted("a"))),
    mock_response(200L, body)
  ))
  res <- collect_warnings(
    lms_chat_batch(
      "a-model",
      c("first", "second"),
      format = "list",
      simplify = FALSE,
      quiet = TRUE,
      api_type = "openai"
    )
  )
  expect_identical(res$value[[2]], jsonlite::parse_json(body))
  expect_identical(res$value[[2]]$choices[[1]]$finish_reason, "length")
  expect_identical(res$value[[1]]$choices[[1]]$message$content, "a")
  expect_identical(length(res$warnings), 0L)
})

test_that("a server that stops during a batch still aborts", {
  # The batch probes once before the loop, and each call probes again. The
  # third probe is the second call's, so the server goes away mid-batch.
  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes < 3L
  })
  valid <- mock_response(200L, completion_body(quoted('{"score": 3}')))
  recorder <- local_request_sequence(list(valid, valid, valid))

  expect_error(
    lms_chat_batch(
      "a-model",
      c("first", "second", "third"),
      format = "list",
      quiet = TRUE,
      api_type = "openai",
      schema = score_schema
    ),
    class = "rlmstudio_no_server"
  )
  expect_identical(probes, 3L)
  expect_length(recorder$requests, 1L)
})

# The columns of an OpenAI data-frame batch before the property columns.
frame_columns <- c(
  "input",
  "output",
  "response_id",
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens"
)

# An object schema whose properties are the arguments.
object_schema <- function(...) {
  list(type = "object", properties = list(...))
}

# One response per reply text, in order, each holding that text as content.
reply_sequence <- function(reply_texts) {
  lapply(reply_texts, function(text) {
    mock_response(200L, completion_body(quoted(text)))
  })
}

test_that("a schema data frame adds one column per property after the reply columns", {
  out <- batch_with_reply('{"score": 3}', "data.frame")
  expect_identical(names(out), c(frame_columns, "score"))
  expect_identical(out$score, c(3L, 3L))

  # Three properties out of alphabetical order, and reply fields in yet
  # another order. The columns follow `properties`.
  schema <- object_schema(
    zeta = list(type = "string"),
    alpha = list(type = "integer"),
    mid = list(type = "boolean")
  )
  responses <- list(
    mock_response(200L, openai_reply(
      quoted('{"mid": true, "alpha": 1, "zeta": "a"}'),
      usage = openai_usage("10", "5", json_object(reasoning_tokens = "2")),
      id = quoted("id_a")
    )),
    mock_response(200L, openai_reply(
      quoted('{"alpha": 2, "zeta": "b", "mid": false}'),
      usage = openai_usage("20", "6", json_object(reasoning_tokens = "3")),
      id = quoted("id_b")
    ))
  )
  out <- batch_with_sequence(
    responses,
    "data.frame",
    schema = schema,
    inputs = c("first", "second")
  )
  expect_identical(names(out), c(frame_columns, "zeta", "alpha", "mid"))
  expect_identical(out$input, c("first", "second"))
  expect_identical(
    out$output,
    list(
      list(mid = TRUE, alpha = 1L, zeta = "a"),
      list(alpha = 2L, zeta = "b", mid = FALSE)
    )
  )
  expect_identical(out$response_id, c("id_a", "id_b"))
  expect_identical(out$input_tokens, c(10, 20))
  expect_identical(out$total_output_tokens, c(5, 6))
  expect_identical(out$reasoning_output_tokens, c(2, 3))
  expect_identical(out$zeta, c("a", "b"))
  expect_identical(out$alpha, c(1L, 2L))
  expect_identical(out$mid, c(TRUE, FALSE))
})

test_that("a schema type written as a one-string list adds the columns too", {
  schema <- list(
    type = list("object"),
    properties = list(score = list(type = "integer"))
  )
  out <- batch_with_reply('{"score": 3}', "data.frame", schema = schema)
  expect_identical(names(out), c(frame_columns, "score"))
  expect_identical(out$score, c(3L, 3L))
})

# Each form of a property `type` that gives the column type of `type`: the
# string, a one-string list, and the pair with "null" in both orders, as a
# character vector and as a list.
type_forms <- function(type) {
  list(
    string = type,
    list = list(type),
    null_after = c(type, "null"),
    null_before = c("null", type),
    list_null_after = list(type, "null"),
    list_null_before = list("null", type)
  )
}

test_that("a property column's type follows the property type", {
  # A JSON value of each type, and the R value it gives.
  types <- list(
    string = list(column = "character", json = '"s"', value = "s"),
    integer = list(column = "integer", json = "2", value = 2L),
    number = list(column = "double", json = "1.5", value = 1.5),
    boolean = list(column = "logical", json = "true", value = TRUE)
  )
  properties <- list()
  fields <- character()
  for (type in names(types)) {
    forms <- type_forms(type)
    for (form in names(forms)) {
      name <- paste(type, form, sep = "_")
      properties[[name]] <- list(type = forms[[form]])
      fields[[name]] <- types[[type]]$json
    }
  }
  # Every other type, no type, and a property that is not a list give a
  # list-column. A nested object's own properties get no columns.
  properties$nested <- list(
    type = "object",
    properties = list(inner = list(type = "integer"))
  )
  properties$array <- list(type = "array")
  properties$mixed <- list(type = c("string", "integer"))
  properties$untyped <- list(description = "no type")
  properties$bare <- "integer"
  fields[["nested"]] <- '{"inner": 1}'
  fields[["array"]] <- "[1, 2]"
  fields[["mixed"]] <- '"m"'
  fields[["untyped"]] <- '"x"'
  fields[["bare"]] <- "5"
  reply <- sprintf(
    "{%s}",
    paste(sprintf('"%s": %s', names(fields), fields), collapse = ", ")
  )

  out <- batch_with_reply(
    reply,
    "data.frame",
    schema = list(type = "object", properties = properties)
  )
  expect_identical(names(out), c(frame_columns, names(properties)))
  for (type in names(types)) {
    for (form in names(type_forms(type))) {
      name <- paste(type, form, sep = "_")
      expect_identical(typeof(out[[name]]), types[[type]]$column, info = name)
      expect_identical(out[[name]], rep(types[[type]]$value, 2L), info = name)
    }
  }
  for (name in c("nested", "array", "mixed", "untyped", "bare")) {
    expect_identical(typeof(out[[name]]), "list", info = name)
  }
  expect_identical(out$nested, list(list(inner = 1L), list(inner = 1L)))
  expect_false("inner" %in% names(out))
  expect_identical(out$array, list(c(1L, 2L), c(1L, 2L)))
  expect_identical(out$mixed, list("m", "m"))
  expect_identical(out$untyped, list("x", "x"))
  expect_identical(out$bare, list(5L, 5L))
})

# Run a data-frame batch over one input per case, with the one property `v`
# of `type`. A case is the JSON text of the `v` field, or NULL to leave the
# field out. Returns the value, the warnings, and the reply texts.
cell_batch <- function(type, cases) {
  replies <- vapply(
    cases,
    function(json) if (is.null(json)) "{}" else sprintf('{"v": %s}', json),
    character(1)
  )
  res <- collect_warnings(batch_with_sequence(
    reply_sequence(replies),
    "data.frame",
    schema = object_schema(v = list(type = type)),
    inputs = paste("input", seq_along(cases))
  ))
  c(res, list(replies = replies))
}

test_that("a property cell holds one value of its column type, and NA otherwise", {
  big <- .Machine$integer.max
  # Each case is the JSON text of the field, or NULL for an absent field, and
  # the cell it gives.
  cases <- list(
    string = list(
      list(NULL, NA_character_),
      list("null", NA_character_),
      list("1", NA_character_),
      list("true", NA_character_),
      list('["a", "b"]', NA_character_),
      list('{"w": "a"}', NA_character_),
      list('"a"', "a"),
      list('["x"]', "x"),
      list('""', "")
    ),
    integer = list(
      list(NULL, NA_integer_),
      list("null", NA_integer_),
      list('"1"', NA_integer_),
      list("true", NA_integer_),
      list("[1, 2]", NA_integer_),
      list('{"w": 1}', NA_integer_),
      list("3", 3L),
      list("[3]", 3L),
      list("3.0", 3L),
      list("3.5", NA_integer_),
      list("2147483647", big),
      list("-2147483647", -big),
      list("2147483648", NA_integer_),
      list("-2147483648", NA_integer_)
    ),
    number = list(
      list(NULL, NA_real_),
      list("null", NA_real_),
      list('"1"', NA_real_),
      list("true", NA_real_),
      list("[1.5, 2.5]", NA_real_),
      list('{"w": 1.5}', NA_real_),
      list("1.5", 1.5),
      list("3", 3),
      list("[1.5]", 1.5)
    ),
    boolean = list(
      list(NULL, NA),
      list("null", NA),
      list("1", NA),
      list('"true"', NA),
      list("[true, false]", NA),
      list('{"w": true}', NA),
      list("true", TRUE),
      list("false", FALSE),
      list("[true]", TRUE)
    )
  )
  for (type in names(cases)) {
    json <- lapply(cases[[type]], `[[`, 1L)
    expected <- do.call(c, lapply(cases[[type]], `[[`, 2L))
    res <- cell_batch(type, json)
    expect_identical(res$value$v, expected, info = type)
    expect_identical(length(res$warnings), 0L, info = type)
    # A value that does not fit stays in `output`.
    expect_identical(
      res$value$output,
      lapply(unname(res$replies), jsonlite::parse_json, simplifyVector = TRUE),
      info = type
    )
  }
  # Stated apart from the parser.
  res <- cell_batch("integer", list("3.5"))
  expect_identical(res$value$output, list(list(v = 3.5)))
  expect_identical(res$value$v, NA_integer_)
})

test_that("a list property cell holds the parsed field, and NULL when it is absent or null", {
  schema <- object_schema(
    n = list(type = "integer"),
    tags = list(type = "array"),
    meta = list(type = "object")
  )
  # An array of one object, a number, and null are not JSON objects. The
  # fourth reply fails its input.
  replies <- c(
    '{"n": 1, "tags": ["a", "b"], "meta": {"k": 1}}',
    '{"n": 2}',
    '{"n": 3, "tags": null, "meta": null}',
    "not json",
    '[{"n": 4}]',
    "4",
    "null"
  )
  res <- collect_warnings(batch_with_sequence(
    reply_sequence(replies),
    "data.frame",
    schema = schema,
    inputs = paste("input", seq_along(replies))
  ))
  out <- res$value
  expect_identical(names(out), c(frame_columns, "n", "tags", "meta"))
  expect_identical(out$n, c(1L, 2L, 3L, NA, NA, NA, NA))
  expect_identical(out$tags, c(list(c("a", "b")), rep(list(NULL), 6L)))
  expect_identical(out$meta, c(list(list(k = 1L)), rep(list(NULL), 6L)))
  expect_s3_class(out$output[[4]], "rlmstudio_bad_response")
  expect_s3_class(out$output[[5]], "data.frame")
  expect_identical(out$output[[6]], 4L)
  expect_null(out$output[[7]])
  expect_identical(length(res$warnings), 1L)
  expect_match(
    conditionMessage(res$warnings[[1]]),
    "1 input failed, at position 4\\."
  )
})

test_that("a schema that is not an object schema adds no column", {
  schemas <- list(
    "the empty list" = list(),
    "an array type" = list(type = "array", items = list(type = "integer")),
    "an object or null type" = list(
      type = c("object", "null"),
      properties = list(score = list(type = "integer"))
    ),
    "no properties" = list(type = "object"),
    "empty properties" = list(
      type = "object",
      properties = structure(list(), names = character())
    ),
    "properties with no names" = list(
      type = "object",
      properties = list(list(type = "integer"))
    )
  )
  for (label in names(schemas)) {
    out <- batch_with_reply('{"score": 3}', "data.frame", schema = schemas[[label]])
    expect_identical(names(out), frame_columns, info = label)
    expect_identical(out$output, list(list(score = 3L), list(score = 3L)), info = label)
  }
})

test_that("an object schema adds no column with logprobs or outside a data frame", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, completion_body(quoted('{"score": 3}'))))
  out <- lms_chat_batch(
    "a-model",
    c("first", "second"),
    format = "data.frame",
    quiet = TRUE,
    api_type = "openai",
    logprobs = TRUE,
    schema = score_schema
  )
  expect_identical(
    names(out),
    c("input", "output", "logprobs", frame_columns[-(1:2)])
  )
  # The reply is text with logprobs, so it is not parsed.
  expect_identical(out$output, c('{"score": 3}', '{"score": 3}'))

  schema <- object_schema(
    zeta = list(type = "string"),
    alpha = list(type = "integer")
  )
  reply <- '{"zeta": "a", "alpha": 1}'
  parsed <- list(zeta = "a", alpha = 1L)
  out <- batch_with_reply(reply, "list", schema = schema)
  expect_identical(out, list(parsed, parsed))
  expect_warning(
    out <- batch_with_reply(reply, "vector", schema = schema),
    "cannot store replies parsed"
  )
  expect_identical(out, list(parsed, parsed))
})

test_that("the property columns keep their types when every input failed", {
  schema <- object_schema(
    s = list(type = "string"),
    i = list(type = "integer"),
    d = list(type = "number"),
    b = list(type = "boolean"),
    l = list(type = "array")
  )
  for (n in c(1L, 3L)) {
    info <- paste(n, "inputs")
    res <- collect_warnings(batch_with_reply(
      "not json",
      "data.frame",
      schema = schema,
      inputs = paste("input", seq_len(n))
    ))
    out <- res$value
    expect_identical(names(out), c(frame_columns, "s", "i", "d", "b", "l"), info = info)
    expect_identical(out$s, rep(NA_character_, n), info = info)
    expect_identical(out$i, rep(NA_integer_, n), info = info)
    expect_identical(out$d, rep(NA_real_, n), info = info)
    expect_identical(out$b, rep(NA, n), info = info)
    expect_identical(out$l, rep(list(NULL), n), info = info)
    expect_identical(length(res$warnings), 1L, info = info)
  }
})

test_that("a reply that does not parse is returned as text without a schema", {
  out <- call_with_reply(completion_body(quoted("a score of three")))
  expect_identical(out$value, "a score of three")
})

test_that("content that is not one string names max_tokens at the token limit without a schema", {
  for (logprobs in c(FALSE, TRUE)) {
    info <- paste("logprobs:", logprobs)
    cut <- expect_error(
      call_with_reply(completion_body("null", "length"), logprobs = logprobs),
      class = "rlmstudio_bad_response",
      info = info
    )
    expect_length_limit_message(cut, info = info)
    expect_identical(cut$finish_reason, "length", info = info)

    # A finish reason of "stop" keeps the not-one-string detail.
    done <- expect_error(
      call_with_reply(completion_body("null", "stop"), logprobs = logprobs),
      class = "rlmstudio_bad_response",
      info = info
    )
    expect_match(conditionMessage(done), "is not one string", info = info)
    expect_no_match(conditionMessage(done), "max_tokens")
  }
})

test_that("reply content that is not one string aborts as a bad response", {
  contents <- openai_unreadable()
  # A schema with logprobs = FALSE parses the reply instead, which the tests
  # above cover.
  settings <- list(
    list(label = "no schema", args = list()),
    list(label = "logprobs", args = list(logprobs = TRUE)),
    list(label = "a schema and logprobs", args = list(schema = score_schema, logprobs = TRUE))
  )
  for (label in names(contents)) {
    case <- contents[[label]]
    for (setting in settings) {
      info <- paste(label, "with", setting$label)
      err <- expect_error(
        do.call(call_with_reply, c(list(case$body), setting$args)),
        class = "rlmstudio_bad_response",
        info = info
      )
      expect_identical(err$status, 200L, info = info)
      expect_match(conditionMessage(err), "OpenAI API Failed", info = info)
      expect_true("content" %in% names(err), info = info)
      expect_identical(err$content, case$content, info = info)
      expect_identical(err$finish_reason, "stop", info = info)
    }
  }
})
