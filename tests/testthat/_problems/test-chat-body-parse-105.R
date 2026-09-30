# Extracted from test-chat-body-parse.R:105

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
    for (kind in c("html", "empty")) {
      for (format in c("vector", "list", "data.frame")) {
        info <- paste(api_type, kind, format)
        case <- unparseable_bodies[[kind]]
        recorder <- local_request_sequence(list(
          mock_response(200L, parse_ok[[api_type]]("reply 1")),
          mock_response(200L, case$body, content_type = case$type),
          mock_response(200L, parse_ok[[api_type]]("reply 3"))
        ))
        warnings <- testthat::capture_warnings(
          out <- lms_chat_batch(
            "a-model",
            c("a", "b", "c"),
            format = format,
            quiet = TRUE,
            api_type = api_type
          )
        )
        expect_identical(length(recorder$requests), 3L, info = info)
        expect_identical(length(warnings), 1L, info = info)
        expect_match(warnings, "1 input failed, at position 2\\.", info = info)
        if (format == "list") {
          expect_identical(out[[1]], "reply 1", info = info)
          expect_s3_class(out[[2]], "rlmstudio_bad_response")
          expect_match(
            conditionMessage(out[[2]]),
            "did not parse as JSON",
            fixed = TRUE,
            info = info
          )
          expect_identical(out[[3]], "reply 3", info = info)
        } else if (format == "vector") {
          expect_identical(out, c("reply 1", NA, "reply 3"), info = info)
        } else {
          expect_identical(out$output, c("reply 1", NA, "reply 3"), info = info)
          reply_cols <- setdiff(names(out), c("input", "output"))
          # The route's reply columns are there, so the row check below has
          # something to read.
          expect_true(length(reply_cols) > 0L, info = info)
          for (col in reply_cols) {
            expect_true(is.na(out[[col]][[2]]), info = paste(info, col))
            expect_false(is.na(out[[col]][[1]]), info = paste(info, col))
          }
        }
      }
    }
  }
