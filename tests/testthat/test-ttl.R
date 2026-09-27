# The `ttl` field of the request body, for each function that sends one. The
# argument checks live in test-arg-guards.R. The replies are written here
# rather than recorded, because a recording cannot show what the request body
# held.

# The request body as the JSON text that goes over the wire. The parsed form
# that request_target() returns cannot tell 300 from 300.0 (LESSONS, M008).
sent_json <- function(req) {
  require_httpuv()
  out <- httr2::req_dry_run(req, quiet = TRUE, redact_headers = FALSE)
  rawToChar(out$body)
}

embed_reply <- paste0(
  '{"object": "list", "model": "a-model", "data": ',
  '[{"object": "embedding", "index": 0, "embedding": [0.1, 0.2]}]}'
)

# completion_body() and quoted() live in helper-chat-bodies.R.
chat_reply <- completion_body(quoted("hi"))

# Each function that sends `ttl`, called with arguments that are valid apart
# from `ttl`.
ttl_senders <- list(
  lms_chat_openai = function(...) {
    lms_chat_openai("a-model", list(list(role = "user", content = "hi")), ...)
  },
  lms_embed = function(...) {
    lms_embed("a-model", "hi", ...)
  },
  lms_chat = function(...) {
    lms_chat("a-model", "hi", api_type = "openai", ...)
  },
  lms_chat_batch = function(...) {
    lms_chat_batch(
      "a-model",
      c("first", "second"),
      api_type = "openai",
      quiet = TRUE,
      ...
    )
  }
)

# Calls one sender against a mocked 200 reply and returns the JSON text of
# every request that was sent.
send_with_ttl <- function(name, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  reply <- if (name == "lms_embed") embed_reply else chat_reply
  recorder <- local_request_recorder(mock_response(200L, reply))
  ttl_senders[[name]](...)
  vapply(recorder$requests, sent_json, character(1))
}

test_that("ttl = NULL sends no ttl field", {
  for (name in names(ttl_senders)) {
    for (json in send_with_ttl(name)) {
      expect_false(
        "ttl" %in% names(jsonlite::parse_json(json)),
        info = name
      )
    }
    for (json in send_with_ttl(name, ttl = NULL)) {
      expect_false(
        "ttl" %in% names(jsonlite::parse_json(json)),
        info = name
      )
    }
  }
})

test_that("a ttl is sent as a JSON integer in each request", {
  expected_requests <- c(
    lms_chat_openai = 1L,
    lms_embed = 1L,
    lms_chat = 1L,
    lms_chat_batch = 2L
  )
  for (name in names(ttl_senders)) {
    # 300 and 1e5 are doubles, 300L an integer, and the largest R integer is
    # the upper end of the range.
    for (value in list(300, 300L, 1e5, .Machine$integer.max)) {
      jsons <- send_with_ttl(name, ttl = value)
      expect_identical(length(jsons), expected_requests[[name]], info = name)
      field <- paste0('"ttl":', format(as.integer(value)))
      for (json in jsons) {
        expect_match(json, field, fixed = TRUE, info = paste(name, field))
      }
    }
  }
})
