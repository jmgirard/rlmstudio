# Every function that sends a JSON body sends the text that jsonlite writes
# from it. httr2 1.3.0 req_body_json() rebuilt each list in the body first,
# and on a POSIXlt value that walk recursed with no end. The value reaches
# the body through `...` on each function below, and no argument check reads
# its value there (D-003 leaves dot fields to the server).

test_that("a POSIXlt value in the dots reaches each request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  lt <- as.POSIXlt("2020-01-01 10:00:00", tz = "UTC")
  calls <- list(
    lms_chat_native = function() lms_chat_native("a-model", "hi", when = lt),
    lms_chat_openresponses = function() {
      lms_chat_openresponses("a-model", "hi", when = lt)
    },
    lms_embed = function() lms_embed("a-model", "hi", when = lt),
    lms_load = function() lms_load("a-model", force = TRUE, when = lt),
    lms_download = function() lms_download("a-model", when = lt),
    lms_unload = function() lms_unload("a-model", when = lt)
  )

  for (name in names(calls)) {
    # The reply is not what these tests read, so any fault it raises after
    # the request is recorded is ignored.
    recorder <- local_request_recorder(mock_response(200L, "{}"))
    try(suppressWarnings(suppressMessages(calls[[name]]())), silent = TRUE)
    expect_identical(length(recorder$requests), 1L, info = name)
    sent <- tryCatch(
      request_body_text(recorder$requests[[1]], seconds = 10),
      error = function(e) paste("no body:", conditionMessage(e))
    )
    expect_match(sent, '"when":"2020-01-01 10:00:00"', fixed = TRUE, info = name)
  }
})

# httr2 revealed an obfuscated value when it rebuilt the body. jsonlite has
# no method for its class, so the write now fails, and no request is sent.
test_that("an obfuscated value in the dots aborts with the jsonlite error", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L, "{}"))
  expect_error(
    lms_unload("a-model", k = httr2::obfuscated("ZlWnhbI6ADhSZmQTw4PEnw")),
    "No method asJSON S3 class: httr2_obfuscated",
    fixed = TRUE
  )
  expect_identical(length(recorder$requests), 0L)
})
