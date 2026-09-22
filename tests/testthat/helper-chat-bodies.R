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

score_schema <- list(
  type = "object",
  properties = list(score = list(type = "integer")),
  required = list("score")
)
