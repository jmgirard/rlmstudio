# The failure-message table.
#
# Every REST wrapper that handles a failed response reports it through one
# abort path. This file holds the table of response bodies that path has to
# cope with, and drives every wrapper through every row. `text` is the message
# the abort must carry after the wrapper's own label; the sentinel
# `"<status>"` means the message falls back to `HTTP Status <n>`.

api_error_table <- list(
  list(
    name = "nested error message",
    body = '{"error": {"message": "boom"}}',
    text = "boom"
  ),
  list(
    name = "string error",
    body = '{"error": "boom"}',
    text = "boom"
  ),
  list(
    name = "non-JSON body",
    body = "plain text failure",
    text = "plain text failure"
  ),
  list(
    name = "non-JSON body served as HTML",
    body = "<html>502 Bad Gateway</html>",
    content_type = "text/html",
    text = "<html>502 Bad Gateway</html>"
  ),
  list(
    name = "message holding curly braces",
    body = '{"error": {"message": "bad field {temp}"}}',
    text = "bad field {temp}"
  ),
  list(
    name = "whole body is a JSON string",
    body = '"boom"',
    text = "\"boom\""
  ),
  list(
    name = "whole body is a JSON array",
    body = '["a", "b"]',
    text = "<status>"
  ),
  list(
    name = "error object with no message field",
    body = '{"error": {"code": "E42"}}',
    text = "<status>"
  ),
  list(
    name = "JSON with no error key",
    body = '{"status": "bad"}',
    text = "<status>"
  ),
  list(
    name = "empty body",
    body = "",
    text = "<status>"
  ),
  list(
    name = "error is an empty array",
    body = '{"error": []}',
    text = "<status>"
  ),
  list(
    name = "error is an empty object",
    body = '{"error": {}}',
    text = "<status>"
  ),
  list(
    name = "message is an empty array",
    body = '{"error": {"message": []}}',
    text = "<status>"
  ),
  list(
    name = "error is an array of strings",
    body = '{"error": ["a", "b"]}',
    text = "<status>"
  ),
  list(
    name = "message is an empty string",
    body = '{"error": {"message": ""}}',
    text = "<status>"
  ),
  list(
    name = "error is null",
    body = '{"error": null}',
    text = "<status>"
  ),
  list(
    name = "message is null",
    body = '{"error": {"message": null}}',
    text = "<status>"
  )
)

# The seven wrappers the table runs against, each with the label it opens its
# abort with. `lms_load()` gets `force = TRUE` because without it the call
# checks the loaded models first, and that check throws on the mocked failure
# before the load request goes out.
api_error_callers <- list(
  lms_load = list(
    label = "API Load Failed",
    call = function() lms_load("m", force = TRUE)
  ),
  lms_unload = list(
    label = "API Unload Failed",
    call = function() lms_unload("m")
  ),
  lms_download = list(
    label = "API Download Failed",
    call = function() lms_download("m")
  ),
  lms_download_status = list(
    label = "API Status Request Failed",
    call = function() lms_download_status("j1")
  ),
  lms_chat_openresponses = list(
    label = "OpenResponses Failed",
    call = function() lms_chat_openresponses("m", "hi")
  ),
  lms_chat_openai = list(
    label = "OpenAI API Failed",
    call = function() lms_chat_openai("m", "hi")
  ),
  lms_chat_native = list(
    label = "Native API Failed",
    call = function() lms_chat_native("m", "hi")
  )
)

# The statuses every row runs at, so the fallback's `<n>` is never fixed by a
# single run.
api_error_statuses <- c(400L, 503L)

# Send one wrapper one row at one status and return the condition it raised.
# Both mocks are bound to this function's own frame, so they come off when it
# returns. Binding them to a detached environment instead leaves the server
# check mocked for every test that runs afterwards.
catch_api_error <- function(caller, row, status) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(
    mock_response(
      status,
      row$body,
      content_type = row$content_type %||% "application/json"
    )
  )
  tryCatch(
    {
      suppressMessages(caller$call())
      NULL
    },
    error = function(cnd) cnd
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

for (row in api_error_table) {
  local({
    row <- row

    test_that(paste0("every wrapper reports the same text: ", row$name), {
      for (status in api_error_statuses) {
        expected <- if (identical(row$text, "<status>")) {
          paste("HTTP Status", status)
        } else {
          row$text
        }

        seen <- vapply(
          names(api_error_callers),
          function(nm) {
            caller <- api_error_callers[[nm]]
            cnd <- catch_api_error(caller, row, status)
            if (is.null(cnd)) {
              return("<no error raised>")
            }
            if (!inherits(cnd, "rlmstudio_api_error")) {
              return(paste0(
                "<wrong class: ",
                paste(class(cnd), collapse = "/"),
                "> ",
                conditionMessage(cnd)
              ))
            }
            if (!identical(cnd$status, status)) {
              return(paste0("<wrong status field: ", cnd$status, ">"))
            }
            fragment <- paste0(caller$label, ": ", expected)
            if (grepl(fragment, conditionMessage(cnd), fixed = TRUE)) {
              "ok"
            } else {
              conditionMessage(cnd)
            }
          },
          character(1)
        )

        expect_equal(seen, stats::setNames(rep("ok", 7L), names(seen)))
      }
    })
  })
}

test_that("the table covers every wrapper that handles a failed response", {
  r_dir <- testthat::test_path("..", "..", "R")
  sources <- list.files(r_dir, pattern = "[.]R$", full.names = TRUE)
  # In an R CMD check the installed package sits where the sources would be,
  # so there is nothing to grep. Skip rather than pass over an empty domain.
  skip_if(length(sources) == 0L, "package sources are not available")

  hits <- unlist(lapply(sources, function(f) {
    grep("req_error(is_error", readLines(f, warn = FALSE), fixed = TRUE)
  }))

  expect_length(hits, 7L)
  expect_length(api_error_callers, 7L)
})
