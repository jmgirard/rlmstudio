# A status-200 chat body that does not parse as JSON, on each route. The
# server is mocked through the shared recorder (D-004).

# The single-call function of each route, called with one input.
parse_single <- list(
  native = function(...) lms_chat_native("a-model", "hi", ...),
  openresponses = function(...) lms_chat_openresponses("a-model", "hi", ...),
  openai = function(...) {
    lms_chat_openai("a-model", list(list(role = "user", content = "hi")), ...)
  }
)

# A reply that reads as `text` on each route.
parse_ok <- list(
  native = function(text) native_reply(text),
  openresponses = function(text) responses_reply(text),
  openai = function(text) openai_reply(quoted(text))
)

# Bodies that do not parse as JSON, each under the content type it is served
# with. The cut-off body is a valid reply up to where it stops.
unparseable_bodies <- list(
  html = list(body = "<html><body>Sign in</body></html>", type = "text/html"),
  "cut-off JSON" = list(body = '{"output": [{"type": "message", ', type = "application/json"),
  empty = list(body = "", type = "application/json")
)

# The condition a call raises, or NULL when it returns.
raised_by <- function(expr) {
  tryCatch({
    expr
    NULL
  }, error = identity)
}

test_that("a 200 body that does not parse raises rlmstudio_bad_response", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  for (api_type in names(parse_single)) {
    for (kind in names(unparseable_bodies)) {
      for (simplify in c(TRUE, FALSE)) {
        info <- paste(api_type, kind, "simplify:", simplify)
        case <- unparseable_bodies[[kind]]
        local_request_sequence(list(
          mock_response(200L, case$body, content_type = case$type)
        ))
        cnd <- raised_by(parse_single[[api_type]](simplify = simplify))
        expect_s3_class(cnd, "rlmstudio_bad_response")
        expect_identical(cnd$status, 200L, info = info)
        message <- conditionMessage(cnd)
        expect_match(message, "did not parse as JSON", fixed = TRUE, info = info)
        # The parse runs before the `simplify` branch, so that advice would
        # send the caller down a path that fails the same way.
        expect_no_match(message, "simplify = FALSE", fixed = TRUE, info = info)
        expect_match(message, "may be answering on this host", fixed = TRUE, info = info)
        if (api_type == "openai") {
          # Every OpenAI condition carries these two fields, NULL here.
          expect_true(all(c("content", "finish_reason") %in% names(cnd)), info = info)
          expect_null(cnd$content)
          expect_null(cnd$finish_reason)
        }
      }
    }
  }
})

test_that("the message leaves out the body text", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  # jsonlite quotes the text around the point where it stops, so a message
  # built from its error would carry MARKER.
  for (api_type in names(parse_single)) {
    local_request_sequence(list(
      mock_response(200L, "<html>MARKER</html>")
    ))
    cnd <- raised_by(parse_single[[api_type]]())
    expect_s3_class(cnd, "rlmstudio_bad_response")
    expect_no_match(conditionMessage(cnd), "MARKER", fixed = TRUE, info = api_type)
  }
})

test_that("a JSON reply under text/plain reads as it does under application/json", {
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
})
