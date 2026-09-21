# Every exported function that reaches the REST API is driven through the
# recorder here, and the Authorization header is read off every request each
# one issues. A function that issues more than one request is listed with the
# count it must issue, so a dropped forwarding line shows up as a missing
# header rather than as a missing request.
#
# The token string is a dummy. request_target() reads headers with redaction
# off, so a failure prints the literal value.

wrapper_token <- "wrapper-token"

# One response body answers every request in this file. list_models() reads
# `models`, lms_load() reads `status`, and lms_download() reads `job_id`. The
# listed model key differs from the model the load test asks for, so lms_load()
# does not short-circuit on the already-loaded branch.
wrapper_body <- paste0(
  '{"status": "loaded", "job_id": "job-1", "models": [',
  '{"type": "llm", "key": "other-model", "display_name": "Other", ',
  '"size_bytes": 1073741824, ',
  '"loaded_instances": [{"identifier": "inst-1"}]}]}'
)

# The fourteen exported functions that can reach the REST API, with the number
# of requests each one issues under these arguments. `call` takes a list of
# extra arguments, which is either the token or nothing.
wrapper_table <- list(
  list(
    name = "list_models",
    requests = 1L,
    call = function(extra) do.call(list_models, c(list(quiet = TRUE), extra))
  ),
  list(
    name = "lms_load",
    requests = 2L,
    call = function(extra) do.call(lms_load, c(list("test-model"), extra))
  ),
  list(
    name = "lms_unload",
    requests = 1L,
    call = function(extra) do.call(lms_unload, c(list("test-model"), extra))
  ),
  list(
    name = "lms_unload_all",
    requests = 2L,
    call = function(extra) do.call(lms_unload_all, extra)
  ),
  list(
    name = "lms_download",
    requests = 1L,
    call = function(extra) do.call(lms_download, c(list("test-model"), extra))
  ),
  list(
    name = "lms_download_status",
    requests = 1L,
    call = function(extra) do.call(lms_download_status, c(list("job-1"), extra))
  ),
  list(
    name = "lms_chat",
    requests = 1L,
    call = function(extra) {
      do.call(lms_chat, c(list("m", "hello", simplify = FALSE), extra))
    }
  ),
  list(
    name = "lms_chat_batch",
    requests = 2L,
    call = function(extra) {
      do.call(
        lms_chat_batch,
        c(
          list(
            "m",
            c("one", "two"),
            format = "list",
            simplify = FALSE,
            quiet = TRUE
          ),
          extra
        )
      )
    }
  ),
  list(
    name = "lms_chat_openresponses",
    requests = 1L,
    call = function(extra) {
      do.call(
        lms_chat_openresponses,
        c(list("m", "hello", simplify = FALSE), extra)
      )
    }
  ),
  list(
    name = "lms_chat_openai",
    requests = 1L,
    call = function(extra) {
      do.call(
        lms_chat_openai,
        c(
          list("m", list(list(role = "user", content = "hello")),
            simplify = FALSE
          ),
          extra
        )
      )
    }
  ),
  list(
    name = "lms_chat_native",
    requests = 1L,
    call = function(extra) {
      do.call(lms_chat_native, c(list("m", "hello", simplify = FALSE), extra))
    }
  ),
  list(
    name = "lms_embed",
    requests = 1L,
    call = function(extra) {
      do.call(lms_embed, c(list("m", "hello", simplify = FALSE), extra))
    }
  ),
  # lms_server_ready() returns FALSE rather than aborting, so it is the one
  # entry here whose request can fail without the call failing. It still has to
  # carry the token, or a server that requires one reads as not ready.
  list(
    name = "lms_server_ready",
    requests = 1L,
    call = function(extra) do.call(lms_server_ready, extra)
  ),
  # lms_server_start() runs the CLI first, so the CLI is stubbed here. Its one
  # request is the readiness request, which the shared body answers as ready.
  list(
    name = "lms_server_start",
    requests = 1L,
    call = function(extra) {
      local_mocked_bindings(
        run = function(command, args, error_on_status) list(status = 0),
        .package = "processx"
      )
      do.call(lms_server_start, c(list(port = 8080), extra))
    }
  )
)

# Run one wrapper and return every request it sent. The mocks live in this
# function's own frame, so each wrapper runs against a fresh recorder.
#
# Nothing here mocks a delegate. A test that mocks list_models() to feed
# lms_unload_all() never sees the request list_models() itself sends, and the
# header on that request would go unasserted.
drive_wrapper <- function(entry, extra) {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L, wrapper_body))
  suppressMessages(entry$call(extra))
  recorder$requests
}

test_that("the wrapper table lists the fourteen functions that reach the API", {
  expect_setequal(
    vapply(wrapper_table, function(e) e$name, character(1)),
    c(
      "list_models",
      "lms_load",
      "lms_unload",
      "lms_unload_all",
      "lms_download",
      "lms_download_status",
      "lms_chat",
      "lms_chat_batch",
      "lms_chat_openresponses",
      "lms_chat_openai",
      "lms_chat_native",
      "lms_embed",
      "lms_server_ready",
      "lms_server_start"
    )
  )
})

test_that("token is a named-only argument wherever the function takes dots", {
  # An argument after `...` can only be matched by its full name, so adding it
  # there moved no existing argument. A function without dots takes `token`
  # last, which moves nothing either.
  for (name in vapply(wrapper_table, function(e) e$name, character(1))) {
    argument_names <- names(formals(get(name, envir = asNamespace("rlmstudio"))))

    expect_true("token" %in% argument_names, info = name)

    if ("..." %in% argument_names) {
      expect_gt(
        match("token", argument_names),
        match("...", argument_names)
      )
    } else {
      expect_identical(argument_names[length(argument_names)], "token")
    }
  }
})

test_that("every request a wrapper issues carries the token it was given", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  for (entry in wrapper_table) {
    requests <- drive_wrapper(entry, list(token = wrapper_token))

    expect_length(requests, entry$requests)

    headers <- vapply(
      requests,
      function(req) {
        value <- request_target(req)$headers$authorization
        if (is.null(value)) NA_character_ else value
      },
      character(1)
    )

    expect_identical(
      headers,
      rep(paste("Bearer", wrapper_token), entry$requests),
      info = entry$name
    )
  }
})

test_that("lms_chat forwards the token on each of its three routes", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  routes <- c("openresponses", "openai", "native")

  for (route in routes) {
    entry <- list(
      name = route,
      call = function(extra) {
        do.call(
          lms_chat,
          c(list("m", "hello", api_type = route, simplify = FALSE), extra)
        )
      }
    )

    requests <- drive_wrapper(entry, list(token = wrapper_token))

    expect_length(requests, 1L)
    expect_identical(
      request_target(requests[[1]])$headers$authorization,
      paste("Bearer", wrapper_token),
      info = route
    )
  }
})

test_that("no request a wrapper issues carries a header when no token resolves", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  for (entry in wrapper_table) {
    requests <- drive_wrapper(entry, list())

    expect_length(requests, entry$requests)

    present <- vapply(
      requests,
      function(req) !is.null(request_target(req)$headers$authorization),
      logical(1)
    )

    expect_identical(present, rep(FALSE, entry$requests), info = entry$name)
  }
})

test_that("lms_server_start sends its token, or the option, on the readiness request", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = "option-token")
  local_mocked_bindings(
    run = function(command, args, error_on_status) list(status = 0),
    .package = "processx"
  )

  # An explicit token wins over the option.
  recorder <- local_request_recorder(mock_response(200L, wrapper_body))
  suppressMessages(lms_server_start(port = 8080, token = "t"))
  expect_length(recorder$requests, 1L)
  expect_identical(
    request_target(recorder$requests[[1]])$headers$authorization,
    "Bearer t"
  )

  # With token = NULL, the request carries the option.
  recorder <- local_request_recorder(mock_response(200L, wrapper_body))
  suppressMessages(lms_server_start(port = 8080, token = NULL))
  expect_length(recorder$requests, 1L)
  expect_identical(
    request_target(recorder$requests[[1]])$headers$authorization,
    "Bearer option-token"
  )
})
