test_that("lms_unload aborts with class rlmstudio_no_server when the server is down", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(lms_unload("test-model"), class = "rlmstudio_no_server")
})

test_that("lms_unload_all aborts with class rlmstudio_no_server when the server is down", {
  # list_models() runs its own server check, so it is mocked out here. The
  # abort can then only come from the call site in lms_unload_all() itself.
  local_mocked_bindings(
    is_server_running = function(...) FALSE,
    list_models = function(...) data.frame()
  )
  expect_error(lms_unload_all(), class = "rlmstudio_no_server")
})

test_that("lms_unload posts once to the unload path and returns the id invisibly", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, '{"status": "unloaded"}')
  )

  suppressMessages({
    result <- expect_invisible(lms_unload("test-model"))
  })

  expect_equal(result, "test-model")
  expect_length(recorder$requests, 1L)

  target <- request_target(recorder$requests[[1]])
  expect_equal(target$method, "POST")
  expect_equal(target$path, "/api/v1/models/unload")
})

test_that("lms_unload merges a named dots argument into the request body", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L))

  suppressMessages(lms_unload("test-model", ttl = 300))

  # Read the body back off the serialized request rather than off the
  # request object's own field, so the assertion covers what goes over the
  # wire rather than what the caller handed httr2.
  body <- request_target(recorder$requests[[1]])$body
  expect_equal(body$instance_id, "test-model")
  expect_equal(body$ttl, 300)
})

test_that("lms_unload reports the error message field of a JSON body", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(
    mock_response(400L, '{"error": {"message": "nested message"}}')
  )

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: nested message",
    fixed = TRUE
  )
})

test_that("lms_unload falls back to the status when the error object has no message", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(400L, '{"error": {"code": "E42"}}'))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: HTTP Status 400",
    fixed = TRUE
  )
})

test_that("lms_unload reports a JSON error field that is a string", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(400L, '{"error": "top level error"}'))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: top level error",
    fixed = TRUE
  )
})

test_that("lms_unload falls back to the status when the JSON has no error field", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(400L, '{"detail": "no error field"}'))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: HTTP Status 400",
    fixed = TRUE
  )
})

# A body reaches the raw-text fallback for either of two reasons: the response
# is not served as JSON at all, or it is served as JSON and does not parse.
# One test covering one of them leaves the other cause untested, so each cause
# gets its own test here.

test_that("lms_unload falls back to the body text when the response is not served as JSON", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(
    mock_response(502L, "Bad Gateway, not JSON", content_type = "text/plain")
  )

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: Bad Gateway, not JSON",
    fixed = TRUE
  )
})

test_that("lms_unload falls back to the body text when a JSON response does not parse", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(
    mock_response(
      502L,
      "Bad Gateway, not JSON",
      content_type = "application/json"
    )
  )

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: Bad Gateway, not JSON",
    fixed = TRUE
  )
})

test_that("lms_unload names the HTTP status when the extracted message is empty", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(503L, '{"error": {"message": ""}}'))

  expect_error(
    suppressMessages(lms_unload("test-model")),
    "API Unload Failed: HTTP Status 503",
    fixed = TRUE
  )
})

test_that("lms_unload_all returns early when list_models reports nothing loaded", {
  local_mocked_bindings(
    is_server_running = function(...) TRUE,
    list_models = function(...) data.frame()
  )
  recorder <- local_request_recorder()

  expect_message(
    result <- expect_invisible(lms_unload_all()),
    "No models are currently loaded"
  )

  expect_null(result)
  expect_length(recorder$requests, 0L)
})

# Build the one-row list_models() result that lms_unload_all() reads, with
# `instances` as the nested loaded_instances value for that row.
loaded_models_frame <- function(instances) {
  models <- data.frame(model_key = "model-a", stringsAsFactors = FALSE)
  models$loaded_instances <- list(instances)
  models
}

test_that("lms_unload_all unloads each reported instance in order and forwards dots", {
  local_mocked_bindings(
    is_server_running = function(...) TRUE,
    list_models = function(...) {
      loaded_models_frame(
        data.frame(identifier = c("inst-1", "inst-2"), stringsAsFactors = FALSE)
      )
    }
  )
  recorder <- local_request_recorder(mock_response(200L))

  suppressMessages({
    result <- expect_invisible(lms_unload_all(ttl = 60))
  })

  expect_equal(result, c("inst-1", "inst-2"))
  expect_length(recorder$requests, 2L)

  targets <- lapply(recorder$requests, request_target)

  bodies <- lapply(targets, function(t) t$body)
  expect_equal(
    vapply(bodies, function(b) b$instance_id, character(1)),
    c("inst-1", "inst-2")
  )
  expect_equal(vapply(bodies, function(b) b$ttl, numeric(1)), c(60, 60))

  expect_equal(
    vapply(targets, function(t) t$path, character(1)),
    rep("/api/v1/models/unload", 2L)
  )
})

test_that("lms_unload_all sends every unload request to the host it was given", {
  # lms_unload_all() passes its host down to each lms_unload() call. The
  # mocked transport answers whatever address it is handed, so a dropped
  # host is invisible unless a test reads the host header off the request.
  local_mocked_bindings(
    is_server_running = function(...) TRUE,
    list_models = function(...) {
      loaded_models_frame(
        data.frame(identifier = c("inst-1", "inst-2"), stringsAsFactors = FALSE)
      )
    }
  )
  recorder <- local_request_recorder(mock_response(200L))

  suppressMessages(lms_unload_all(host = "http://unload-all-test.invalid:9999"))

  expect_length(recorder$requests, 2L)
  hosts <- vapply(
    recorder$requests,
    function(req) request_target(req)$host,
    character(1)
  )
  expect_equal(hosts, rep("unload-all-test.invalid:9999", 2L))
})

# Run lms_unload_all() over one loaded_instances shape and return the ids it
# read, so each shape test states only its own shape and expected id.
ids_read_from <- function(instances) {
  testthat::local_mocked_bindings(
    is_server_running = function(...) TRUE,
    list_models = function(...) loaded_models_frame(instances),
    .package = "rlmstudio"
  )
  local_request_recorder(mock_response(200L))
  suppressMessages(lms_unload_all())
}

test_that("lms_unload_all reads the identifier column, not the first column", {
  ids <- ids_read_from(
    data.frame(
      decoy = "wrong-a",
      identifier = "inst-id-a",
      stringsAsFactors = FALSE
    )
  )
  expect_equal(ids, "inst-id-a")
})

test_that("lms_unload_all reads the id column, not the first column", {
  ids <- ids_read_from(
    data.frame(decoy = "wrong-b", id = "inst-id-b", stringsAsFactors = FALSE)
  )
  expect_equal(ids, "inst-id-b")
})

test_that("lms_unload_all falls back to the first column when neither name is present", {
  ids <- ids_read_from(
    data.frame(
      first_col = "inst-id-c",
      other = "ignored",
      stringsAsFactors = FALSE
    )
  )
  expect_equal(ids, "inst-id-c")
})

test_that("lms_unload_all reads a plain character vector of instance ids", {
  ids <- ids_read_from(c("inst-id-d", "inst-id-e"))
  expect_equal(ids, c("inst-id-d", "inst-id-e"))
})

test_that("lms_unload_all drops NA and empty ids and returns NULL when none remain", {
  local_mocked_bindings(
    is_server_running = function(...) TRUE,
    list_models = function(...) {
      loaded_models_frame(c(NA_character_, ""))
    }
  )
  recorder <- local_request_recorder(mock_response(200L))

  expect_message(
    result <- expect_invisible(lms_unload_all()),
    "No models are currently loaded"
  )

  expect_null(result)
  expect_length(recorder$requests, 0L)
})

test_that("lms_unload_all keeps the good ids when only some are NA or empty", {
  ids <- ids_read_from(c("inst-id-f", NA_character_, "", "inst-id-g"))
  expect_equal(ids, c("inst-id-f", "inst-id-g"))
})
