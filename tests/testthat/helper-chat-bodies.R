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

# A whole native reply whose one message item reads as `text`. `stats` and
# `response_id` are JSON text, and `NULL` leaves the field out.
native_reply <- function(
  text = "reply",
  stats = native_stats(),
  response_id = quoted("resp_1")
) {
  json_object(
    output = json_array(native_message(quoted(text))),
    stats = stats,
    response_id = response_id
  )
}

# A native `stats` object. Each field is JSON text, and `NULL` leaves it out.
# The token counts default to JSON integers, as a live reply sends them.
native_stats <- function(
  input_tokens = "21",
  total_output_tokens = "3",
  reasoning_output_tokens = "0",
  tokens_per_second = "284.5",
  time_to_first_token_seconds = "0.237",
  model_load_time_seconds = "1.5"
) {
  json_object(
    input_tokens = input_tokens,
    total_output_tokens = total_output_tokens,
    reasoning_output_tokens = reasoning_output_tokens,
    tokens_per_second = tokens_per_second,
    time_to_first_token_seconds = time_to_first_token_seconds,
    model_load_time_seconds = model_load_time_seconds
  )
}

# A whole OpenResponses reply whose one `output_text` part reads as `text`.
# `id` and `usage` are JSON text, and `NULL` leaves the field out.
# `logprobs_json` goes on the part, as in output_text().
responses_reply <- function(
  text = "reply",
  usage = responses_usage(),
  id = quoted("resp_1"),
  logprobs_json = NULL
) {
  json_object(
    id = id,
    output = json_array(responses_message(output_text(quoted(text), logprobs_json))),
    usage = usage
  )
}

# An OpenResponses `usage` object, in the shape a live reply sends. Each field
# is JSON text, and `NULL` leaves it out.
responses_usage <- function(
  input_tokens = "32",
  output_tokens = "2",
  details = json_object(reasoning_tokens = "0")
) {
  json_object(
    input_tokens = input_tokens,
    output_tokens = output_tokens,
    total_tokens = "34",
    input_tokens_details = json_object(cached_tokens = "0"),
    output_tokens_details = details
  )
}

# A whole chat completions reply whose content is `content_json`. `id` and
# `usage` are JSON text, and `NULL` leaves the field out.
openai_reply <- function(
  content_json = quoted("reply"),
  usage = openai_usage(),
  id = quoted("chatcmpl-1")
) {
  choice <- json_object(
    index = "0",
    message = json_object(role = quoted("assistant"), content = content_json),
    finish_reason = quoted("stop")
  )
  json_object(
    id = id,
    object = quoted("chat.completion"),
    choices = json_array(choice),
    usage = usage
  )
}

# A chat completions `usage` object, in the shape a live reply sends. Each
# field is JSON text, and `NULL` leaves it out.
openai_usage <- function(
  prompt_tokens = "29",
  completion_tokens = "4",
  details = json_object(reasoning_tokens = "0")
) {
  json_object(
    prompt_tokens = prompt_tokens,
    completion_tokens = completion_tokens,
    total_tokens = "33",
    completion_tokens_details = details
  )
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

# The detail sentence of the first check each unreadable shape fails, keyed by
# the shape names above. The checks run in this order: the `output` array, its
# items, the message items, the `content` of a message, its parts, the
# `output_text` parts, and the answer texts. The sentences are written out
# here, apart from the code, so a test fails if a shape reaches the wrong check.
unreadable_details <- c(
  output = "The response holds no `output` array of reply items.",
  item = "An item of the `output` array is not a JSON object.",
  message = "The reply holds no message item, so it has no answer text.",
  content = "The `content` of a message item is not an array of parts.",
  part = "A part of a message item is not a JSON object.",
  output_text = "The reply holds no `output_text` part, so it has no answer text.",
  native_text = "The `content` of a message item is not one string.",
  responses_text = "The `text` of an `output_text` part is not one string."
)

# The check each shared shape fails first, before the answer texts.
shared_unreadable_checks <- c(
  "no output field" = "output",
  "an empty output array" = "output",
  "an output object" = "output",
  "an output string" = "output",
  "an item that is a string" = "item",
  "an item that is a number" = "item",
  "no message item" = "message"
)

# The detail sentence for each shape of `shapes`. A shape that is not listed
# fails at the answer texts, which is `text_check`.
unreadable_detail_for <- function(shapes, checks, text_check) {
  # A misspelled label would otherwise fall to `text_check` unseen.
  unknown <- setdiff(names(checks), names(shapes))
  if (length(unknown) > 0L) {
    stop("No shape is named: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  vapply(
    names(shapes),
    function(label) {
      check <- if (label %in% names(checks)) checks[[label]] else text_check
      unreadable_details[[check]]
    },
    character(1)
  )
}

native_unreadable_details <- function() {
  unreadable_detail_for(native_unreadable(), shared_unreadable_checks, "native_text")
}

responses_unreadable_details <- function() {
  checks <- c(
    shared_unreadable_checks,
    "a message with no content field" = "content",
    "a message content that is a string" = "content",
    "a message content that is an object" = "content",
    "a part that is a string" = "part",
    "a part that is a number" = "part",
    "an empty content array" = "output_text",
    "no output_text part" = "output_text"
  )
  unreadable_detail_for(responses_unreadable(), checks, "responses_text")
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

# Chat completions bodies whose `choices` field holds no readable reply, named
# by their shape. `lms_chat_openai()` names each of them in one message.
openai_choices_faults <- function() {
  list(
    "no choices field" = '{"id": "chatcmpl-1"}',
    "an empty choices array" = '{"choices": []}',
    "a choices object" = '{"choices": {"a": 1}}',
    "a choices string" = '{"choices": "a"}',
    "a first choice that is a number" = '{"choices": [5]}',
    "a first choice that is an array" = '{"choices": [[1]]}',
    "a choice with no message" = '{"choices": [{"index": 0}]}',
    "a message that is a string" = '{"choices": [{"message": "a"}]}',
    "a message that is an array" = '{"choices": [{"message": ["a"]}]}'
  )
}

# Bodies that are a bare JSON value. `null` is here as the regression case,
# because each route already names it in a message of its own.
bare_bodies <- c(number = "5", string = '"s"', boolean = "true", null = "null")

score_schema <- list(
  type = "object",
  properties = list(score = list(type = "integer")),
  required = list("score")
)
