# How the chat functions treat a reply from a model other than the one asked
# for, and a model the server cannot find.
#
# The recorded replies in model_mismatch_live/ come from a live LM Studio
# server. Regenerate them with data-raw/record-model-mismatch-cassette.R,
# which carries the full provenance. The requests below must match the
# script's requests byte for byte. Cases that a live server does not produce
# are mocked through the shared recorder (D-004).

chat_routes <- c("openai", "openresponses")
mismatch_prompt <- "Reply with the word hi."

# The chat call of the recorder script on `route`, for `model`.
recorded_call <- function(route, model, simplify = TRUE) {
  if (route == "openai") {
    return(lms_chat_openai(
      model = model,
      messages = list(list(role = "user", content = mismatch_prompt)),
      host = "http://localhost:1234",
      simplify = simplify,
      temperature = 0
    ))
  }
  lms_chat_openresponses(
    model = model,
    input = mismatch_prompt,
    host = "http://localhost:1234",
    simplify = simplify,
    temperature = 0
  )
}

# Run `expr` against the recorded case `case_dir` with no token and a server
# probe that always passes.
with_recorded_case <- function(case_dir, expr, .env = parent.frame()) {
  local_mocked_bindings(is_server_running = function(...) TRUE, .env = .env)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = NA, .local_envir = .env)
  withr::local_options(rlmstudio.token = NULL, .local_envir = .env)
  httptest2::with_mock_dir(file.path("model_mismatch_live", case_dir), expr)
}

# A mocked chat call on `route` for the model `model`.
mocked_call <- function(route, model = "a-model", simplify = TRUE, ...) {
  if (route == "openai") {
    return(lms_chat_openai(
      model = model,
      messages = list(list(role = "user", content = "Hi")),
      simplify = simplify,
      ...
    ))
  }
  lms_chat_openresponses(model = model, input = "Hi", simplify = simplify, ...)
}

# The `code` field of an API error ------------------------------------------

test_that("a recorded model_not_found reply carries its code on both routes", {
  for (route in chat_routes) {
    err <- with_recorded_case(
      "not_found",
      expect_error(
        recorded_call(route, "not-a-model"),
        class = "rlmstudio_api_error"
      )
    )
    expect_identical(err$status, 400L, info = route)
    expect_identical(err$code, "model_not_found", info = route)
  }
})

test_that("an API error carries the code string of the body, or NULL", {
  bodies <- list(
    list(body = '{"error": {"message": "boom", "code": "E42"}}', code = "E42"),
    list(body = '{"error": {"message": "boom"}}', code = NULL),
    list(body = '{"error": "boom"}', code = NULL)
  )
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    for (case in bodies) {
      local_request_recorder(mock_response(400L, case$body))
      err <- expect_error(mocked_call(route), class = "rlmstudio_api_error")
      info <- paste(route, case$body)
      expect_true("code" %in% names(err), info = info)
      expect_identical(err$code, case$code, info = info)
    }
  }
})
