# Response bodies and a schema shared by the chat test files. The server is
# mocked through helper-mock-http.R, and these build what it answers with.

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

# Bodies for the native and OpenResponses routes. Each builder takes its values
# as JSON text, so a test can put `null`, a number, or an array where a string
# belongs. Real LM Studio replies carry a `type` on every item and part.

# A response whose `output` array holds the given items.
output_body <- function(...) {
  sprintf('{"output": [%s]}', paste(c(...), collapse = ", "))
}

# A native message item. Its `content` is the answer text.
native_message <- function(content_json) {
  sprintf('{"type": "message", "content": %s}', content_json)
}

# An OpenResponses message item holding the given parts.
responses_message <- function(...) {
  sprintf(
    '{"type": "message", "role": "assistant", "content": [%s]}',
    paste(c(...), collapse = ", ")
  )
}

# An OpenResponses `output_text` part. `logprobs_json` is a JSON array, or
# `NULL` to leave the field out.
output_text <- function(text_json, logprobs_json = NULL) {
  lp <- if (is.null(logprobs_json)) "" else paste0(', "logprobs": ', logprobs_json)
  sprintf('{"type": "output_text", "text": %s%s}', text_json, lp)
}

# One logprobs step for `token`, with no candidates.
logprob_step <- function(token, logprob = -0.5) {
  sprintf(
    '{"token": %s, "logprob": %s, "top_logprobs": []}',
    quoted(token),
    logprob
  )
}

# A logprobs step as a JSON object. Each field is given as JSON text, and
# `NULL` leaves the field out.
step_json <- function(token = quoted("t"), logprob = "-0.5", top = "[]") {
  json_object(token = token, logprob = logprob, top_logprobs = top)
}

# A `top_logprobs` candidate as a JSON object, built like step_json().
candidate_json <- function(token = quoted("c"), logprob = "-1") {
  json_object(token = token, logprob = logprob)
}

# A JSON object from fields given as JSON text. A `NULL` field is left out.
json_object <- function(...) {
  fields <- Filter(Negate(is.null), list(...))
  pairs <- sprintf('"%s": %s', names(fields), unlist(fields))
  sprintf("{%s}", paste(pairs, collapse = ", "))
}

# A JSON array of the given JSON texts.
json_array <- function(...) sprintf("[%s]", paste(c(...), collapse = ", "))

# `logprobs` values that break one rule each, two JSON types per rule. R1
# entries are whole values. The other entries are one bad step, which a test
# places in an array. The R6 entries put the bad candidate after a good one.
logprobs_breaks <- function() {
  list(
    list(rule = "R1", label = "an object", value = '{"a": 1}'),
    list(rule = "R1", label = "a number", value = "5"),
    list(rule = "R2", label = "a number step", step = "5"),
    list(rule = "R2", label = "an array step", step = "[]"),
    list(rule = "R3", label = "a number token", step = step_json(token = "5")),
    list(rule = "R3", label = "a boolean token", step = step_json(token = "true")),
    list(rule = "R4", label = "a string logprob", step = step_json(logprob = quoted("-0.5"))),
    list(rule = "R4", label = "a boolean logprob", step = step_json(logprob = "true")),
    list(rule = "R5", label = "an object top_logprobs", step = step_json(top = candidate_json())),
    list(rule = "R5", label = "a number candidate", step = step_json(top = json_array(candidate_json(), "5"))),
    list(
      rule = "R6", label = "a number candidate token",
      step = step_json(top = json_array(candidate_json(), candidate_json(token = "5")))
    ),
    list(
      rule = "R6", label = "a string candidate logprob",
      step = step_json(top = json_array(candidate_json(), candidate_json(logprob = quoted("x"))))
    )
  )
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

# An OpenResponses reasoning item, in the shape of the OpenAI Responses API.
responses_reasoning_item <- paste0(
  '{"type": "reasoning", "summary": [], ',
  '"content": [{"type": "reasoning_text", "text": "thinking"}]}'
)
refusal_part <- '{"type": "refusal", "refusal": "no"}'

# Reply text values that are not one string, as JSON.
not_a_string <- c(
  number = "5",
  boolean = "true",
  array = '["p", "q"]',
  object = '{"a": 1}',
  null = "null"
)

# The shapes with no readable answer text that the native and OpenResponses
# routes share. `message` builds a message item from one JSON text value.
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

# Native replies with no readable answer text, named by their shape.
native_unreadable <- function() {
  shapes <- shared_unreadable(native_message)
  shapes[["a message with no content field"]] <- output_body('{"type": "message"}')
  shapes
}

# OpenResponses replies with no readable answer text, named by their shape.
responses_unreadable <- function() {
  shapes <- shared_unreadable(function(value) {
    responses_message(output_text(value))
  })
  shapes[["a message with no content field"]] <-
    output_body('{"type": "message", "role": "assistant"}')
  shapes[["a message content that is a string"]] <-
    output_body('{"type": "message", "content": "a"}')
  shapes[["a message content that is an object"]] <-
    output_body(sprintf('{"type": "message", "content": %s}', output_text(quoted("a"))))
  shapes[["a part that is a string"]] <- output_body(responses_message('"a"'))
  shapes[["a part that is a number"]] <- output_body(responses_message("5"))
  shapes[["an empty content array"]] <- output_body(responses_message())
  shapes[["no output_text part"]] <- output_body(responses_message(refusal_part))
  shapes[["an output_text part with no text field"]] <-
    output_body(responses_message('{"type": "output_text"}'))
  shapes
}

# Chat completions replies whose content is not one string. Each entry holds
# the body and the `content` value the abort carries, as httr2 parses it.
openai_unreadable <- function() {
  absent <- paste0(
    '{"id": "chatcmpl-1", "choices": [{"index": 0, ',
    '"message": {"role": "assistant"}, "finish_reason": "stop"}]}'
  )
  list(
    "null" = list(body = completion_body("null"), content = NULL),
    "absent" = list(body = absent, content = NULL),
    "a number" = list(body = completion_body("5"), content = 5L),
    "a boolean" = list(body = completion_body("true"), content = TRUE),
    "an array" = list(body = completion_body('["p", "q"]'), content = list("p", "q")),
    "an object" = list(body = completion_body('{"a": 1}'), content = list(a = 1L))
  )
}

score_schema <- list(
  type = "object",
  properties = list(score = list(type = "integer")),
  required = list("score")
)
