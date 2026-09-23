# Every reply body the package parses is read as JSON text and nothing else.
# `jsonlite::fromJSON()` treats a text that is not valid JSON as a place to
# read from: a text that starts with http:// or https:// is fetched, and a
# text that names an existing file is read. A reply body must never get that
# treatment. The server is mocked through the shared recorder (D-004).

# The condition a call raises, or NULL when it returns.
raised_by <- function(expr) {
  tryCatch({
    expr
    NULL
  }, error = identity)
}

# Write `content` to a temp file that lives until the calling test ends, and
# return its path. A parse that reads the path as a file gets `content` back.
local_reply_file <- function(content, .env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".json", .local_envir = .env)
  writeLines(content, path)
  path
}

# Mock base::url() for the calling test and return a counter. A parse that
# fetches a URL body opens it through base::url(), so a count above zero
# means a fetch was tried. The mock raises, so nothing leaves the machine.
local_url_counter <- function(.env = parent.frame()) {
  counter <- new.env(parent = emptyenv())
  counter$calls <- 0L
  testthat::local_mocked_bindings(
    url = function(...) {
      counter$calls <- counter$calls + 1L
      stop("base::url() was called", call. = FALSE)
    },
    .package = "base",
    .env = .env
  )
  counter
}

# Two URL bodies, one per scheme that fromJSON() fetches.
url_bodies <- c(
  "http://127.0.0.1:9/reply.json",
  "https://127.0.0.1:9/reply.json"
)

# A valid embeddings reply for one input.
embed_ok_body <- paste0(
  '{"object": "list", "model": "m", "data": ',
  '[{"object": "embedding", "index": 0, "embedding": [0.1, 0.2]}]}'
)

# The functions that parse a status-200 body through parse_ok_body(). Each
# entry holds a call and a body that the call reads as a valid reply, so a
# parse that read the body's file would return rather than abort.
ok_body_sites <- list(
  lms_chat_native = list(
    call = function() lms_chat_native("a-model", "hi"),
    reply = native_reply("FROM FILE")
  ),
  lms_chat_openresponses = list(
    call = function() lms_chat_openresponses("a-model", "hi"),
    reply = responses_reply("FROM FILE")
  ),
  lms_chat_openai = list(
    call = function() {
      lms_chat_openai("a-model", list(list(role = "user", content = "hi")))
    },
    reply = openai_reply(quoted("FROM FILE"))
  ),
  lms_embed = list(
    call = function() lms_embed(model = "m", input = "x"),
    reply = embed_ok_body
  )
)

test_that("a 200 body that names a file aborts and does not read the file", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  for (name in names(ok_body_sites)) {
    site <- ok_body_sites[[name]]
    path <- local_reply_file(site$reply)
    local_request_sequence(list(mock_response(200L, path)))
    cnd <- raised_by(site$call())
    expect_s3_class(cnd, "rlmstudio_bad_response")
    expect_match(
      conditionMessage(cnd), "did not parse as JSON",
      fixed = TRUE, info = name
    )
  }
})

test_that("a 200 body that is a URL aborts and fetches nothing", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  counter <- local_url_counter()
  for (name in names(ok_body_sites)) {
    for (body in url_bodies) {
      info <- paste(name, body)
      local_request_sequence(list(mock_response(200L, body)))
      cnd <- raised_by(ok_body_sites[[name]]$call())
      expect_s3_class(cnd, "rlmstudio_bad_response")
      expect_match(
        conditionMessage(cnd), "did not parse as JSON",
        fixed = TRUE, info = info
      )
    }
  }
  expect_identical(counter$calls, 0L)
})

test_that("an error body that names a file does not reach the message", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  path <- local_reply_file('{"error": {"message": "FROM FILE"}}')
  local_request_sequence(list(mock_response(400L, path)))
  cnd <- raised_by(lms_chat_native("a-model", "hi"))
  expect_s3_class(cnd, "rlmstudio_api_error")
  expect_no_match(conditionMessage(cnd), "FROM FILE", fixed = TRUE)
  # The body is not JSON, so the message falls back to the body text.
  expect_match(conditionMessage(cnd), path, fixed = TRUE)
})

test_that("an error body that is a URL fetches nothing", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  counter <- local_url_counter()
  for (body in url_bodies) {
    local_request_sequence(list(mock_response(400L, body)))
    cnd <- raised_by(lms_chat_native("a-model", "hi"))
    expect_s3_class(cnd, "rlmstudio_api_error")
    expect_match(conditionMessage(cnd), body, fixed = TRUE, info = body)
  }
  expect_identical(counter$calls, 0L)
})

test_that("lms_server_ready does not read a file or fetch a URL body", {
  path <- local_reply_file('{"models": []}')
  local_request_sequence(list(mock_response(200L, path)))
  expect_identical(lms_server_ready(), FALSE)

  counter <- local_url_counter()
  for (body in url_bodies) {
    local_request_sequence(list(mock_response(200L, body)))
    expect_identical(lms_server_ready(), FALSE)
  }
  expect_identical(counter$calls, 0L)
})

test_that("lms_server_ready reads a model list sent as text/plain", {
  body <- '{"models": [{"type": "llm", "key": "a"}]}'
  results <- lapply(c("application/json", "text/plain"), function(type) {
    local_request_sequence(list(mock_response(200L, body, content_type = type)))
    lms_server_ready()
  })
  expect_identical(results[[1]], TRUE)
  expect_identical(results[[2]], results[[1]])
})

test_that("an error body sent as text/plain gives its message text", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(mock_response(
    400L, '{"error": {"message": "MARKER"}}',
    content_type = "text/plain"
  )))
  cnd <- raised_by(lms_load("a-model", force = TRUE))
  expect_s3_class(cnd, "rlmstudio_api_error")
  expect_match(conditionMessage(cnd), "MARKER", fixed = TRUE)
  # The whole body would carry its braces into the message.
  expect_no_match(conditionMessage(cnd), "{", fixed = TRUE)
})
