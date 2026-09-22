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

score_schema <- list(
  type = "object",
  properties = list(score = list(type = "integer")),
  required = list("score")
)
