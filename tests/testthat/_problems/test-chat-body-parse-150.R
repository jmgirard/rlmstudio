# Extracted from test-chat-body-parse.R:150

# prequel ----------------------------------------------------------------------
parse_single <- list(
  native = function(...) lms_chat_native("a-model", "hi", ...),
  openresponses = function(...) lms_chat_openresponses("a-model", "hi", ...),
  openai = function(...) {
    lms_chat_openai("a-model", list(list(role = "user", content = "hi")), ...)
  }
)
parse_ok <- list(
  native = function(text) native_reply(text),
  openresponses = function(text) responses_reply(text),
  openai = function(text) openai_reply(quoted(text))
)
unparseable_bodies <- list(
  html = list(body = "<html><body>Sign in</body></html>", type = "text/html"),
  "cut-off JSON" = list(body = '{"output": [{"type": "message", ', type = "application/json"),
  empty = list(body = "", type = "application/json")
)
raised_by <- function(expr) {
  tryCatch({
    expr
    NULL
  }, error = identity)
}

# test -------------------------------------------------------------------------
testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
for (api_type in names(parse_single)) {
    body <- parse_ok[[api_type]]("reply")
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(api_type, "simplify:", simplify)
      local_request_sequence(list(
        mock_response(200L, body, content_type = "application/json")
      ))
      expected <- parse_single[[api_type]](simplify = simplify)
      local_request_sequence(list(
        mock_response(200L, body, content_type = "text/plain")
      ))
      out <- parse_single[[api_type]](simplify = simplify)
      expect_identical(out, expected, info = info)
      if (simplify) {
        # The control: the reply really was read, not turned into a failure
        # on both runs alike.
        expect_identical(out, "reply", info = info)
      }
    }
  }
