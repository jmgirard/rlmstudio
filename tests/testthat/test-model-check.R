# How the chat functions treat a reply from a model other than the one asked
# for, and a model the server cannot find.
#
# The recorded replies in mismatch_live/ come from a live LM Studio
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
  httptest2::with_mock_dir(file.path("mismatch_live", case_dir), expr)
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

# The model check -------------------------------------------------------------

# A status-200 reply on `route` whose `model` field is `model_json`, JSON
# text, or absent when `NULL`. `text_json` is the answer text, and `NULL`
# gives a reply with no answer text.
reply_with_model <- function(route, model_json, text_json = quoted("reply")) {
  if (route == "openai") {
    content <- if (is.null(text_json)) "null" else text_json
    choice <- json_object(
      index = "0",
      message = json_object(role = quoted("assistant"), content = content),
      finish_reason = quoted("stop")
    )
    body <- json_object(
      id = quoted("chatcmpl-1"),
      model = model_json,
      choices = json_array(choice)
    )
  } else {
    items <- if (is.null(text_json)) {
      character()
    } else {
      responses_message(output_text(text_json))
    }
    body <- json_object(model = model_json, output = json_array(items))
  }
  mock_response(200L, body)
}

# A model list whose entries are given as `key = c(instance ids)`.
model_list_response <- function(...) {
  entries <- list(...)
  models <- lapply(names(entries), function(key) {
    list(
      type = "llm",
      key = key,
      loaded_instances = lapply(entries[[key]], \(id) list(id = id))
    )
  })
  mock_response(
    200L,
    as.character(jsonlite::toJSON(list(models = models), auto_unbox = TRUE))
  )
}

# Two models: org/model-x loaded under the id "x-instance", and org/model-y
# loaded under its key.
two_models_list <- function() {
  model_list_response(
    "org/model-x" = "x-instance",
    "org/model-y" = "org/model-y"
  )
}

# The label that opens each route's messages.
route_label <- c(
  openai = "OpenAI API Failed",
  openresponses = "OpenResponses Failed"
)

# Assert that `err` reports a reply from `reply_model` to a call for `asked`.
expect_mismatch <- function(err, asked, reply_model, info = NULL) {
  expect_true(inherits(err, "rlmstudio_model_mismatch"), info = info)
  expect_true(inherits(err, "rlmstudio_bad_response"), info = info)
  expect_identical(err$model, asked, info = info)
  expect_identical(err$reply_model, reply_model, info = info)
  expect_identical(err$status, 200L, info = info)
  msg <- gsub("[[:space:]]+", " ", cli::ansi_strip(conditionMessage(err)))
  expect_true(grepl(asked, msg, fixed = TRUE), info = info)
  expect_true(grepl(reply_model, msg, fixed = TRUE), info = info)
  expect_false(grepl("simplify", msg, fixed = TRUE), info = info)
}

# Log every request that reaches the real req_perform(), so a test can count
# the requests of a recorded playback.
local_request_log <- function(.env = parent.frame()) {
  log <- new.env(parent = emptyenv())
  log$urls <- character()
  real <- httr2::req_perform
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      log$urls <- c(log$urls, req$url)
      real(req, ...)
    },
    .package = "httr2",
    .env = .env
  )
  log
}

test_that("a recorded reply to an unknown model name aborts with either simplify", {
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(route, simplify)
      err <- with_recorded_case(
        "unknown",
        expect_error(
          recorded_call(route, "not-a-model", simplify),
          class = "rlmstudio_model_mismatch"
        )
      )
      expect_mismatch(err, "not-a-model", "google/gemma-3-1b", info)
    }
  }
})

test_that("a reply from another model aborts when the asked name differs in case from a key", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(route, simplify)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-y")),
        model_list_response(
          "org/model-x" = "org/model-x",
          "org/model-y" = "org/model-y"
        )
      ))
      err <- expect_error(
        mocked_call(route, "Org/Model-X", simplify),
        class = "rlmstudio_model_mismatch"
      )
      expect_mismatch(err, "Org/Model-X", "org/model-y", info)
      expect_identical(length(recorder$requests), 2L, info = info)
    }
  }
})

test_that("a reply from another model aborts when the asked name is an instance id", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(route, simplify)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-y")),
        two_models_list()
      ))
      err <- expect_error(
        mocked_call(route, "x-instance", simplify),
        class = "rlmstudio_model_mismatch"
      )
      expect_mismatch(err, "x-instance", "org/model-y", info)
      expect_identical(length(recorder$requests), 2L, info = info)
    }
  }
})

test_that("the OpenAI mismatch carries the content and finish_reason fields", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    reply_with_model("openai", quoted("org/model-y")),
    two_models_list()
  ))
  err <- expect_error(
    mocked_call("openai", "org/model-x"),
    class = "rlmstudio_model_mismatch"
  )
  expect_true(all(c("content", "finish_reason") %in% names(err)))
})

test_that("the check runs with logprobs and with a schema", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    local_request_sequence(list(
      reply_with_model(route, quoted("org/model-y")),
      two_models_list()
    ))
    err <- expect_error(
      mocked_call(route, "org/model-x", logprobs = TRUE),
      class = "rlmstudio_model_mismatch"
    )
    expect_mismatch(err, "org/model-x", "org/model-y", paste(route, "logprobs"))
  }
  local_request_sequence(list(
    reply_with_model("openai", quoted("org/model-y"), quoted('{"score": 3}')),
    two_models_list()
  ))
  err <- expect_error(
    mocked_call("openai", "org/model-x", schema = score_schema),
    class = "rlmstudio_model_mismatch"
  )
  expect_mismatch(err, "org/model-x", "org/model-y", "schema")
})

test_that("a mismatched reply with no answer text aborts as a mismatch", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    local_request_sequence(list(
      reply_with_model(route, quoted("org/model-y"), text_json = NULL),
      two_models_list()
    ))
    err <- expect_error(
      mocked_call(route, "org/model-x"),
      class = "rlmstudio_model_mismatch"
    )
    expect_mismatch(err, "org/model-x", "org/model-y", route)
  }
})

test_that("lms_chat() raises the mismatch on the default route and the openai route", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    local_request_sequence(list(
      reply_with_model(route, quoted("org/model-y")),
      two_models_list()
    ))
    err <- if (route == "openai") {
      expect_error(
        lms_chat("org/model-x", "Hi", api_type = "openai"),
        class = "rlmstudio_model_mismatch"
      )
    } else {
      expect_error(
        lms_chat("org/model-x", "Hi"),
        class = "rlmstudio_model_mismatch"
      )
    }
    expect_mismatch(err, "org/model-x", "org/model-y", route)
  }
})

test_that("a reply whose model equals the asked name sends no other request", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(route, simplify)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-x"))
      ))
      expect_no_error(mocked_call(route, "org/model-x", simplify))
      expect_identical(length(recorder$requests), 1L, info = info)
    }
  }
})

test_that("a named or classed model string that the same model answers sends no other request", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  asked <- list(
    named = c(a = "org/model-x"),
    classed = structure("org/model-x", class = c("glue", "character"))
  )
  for (kind in names(asked)) {
    for (route in chat_routes) {
      for (simplify in c(TRUE, FALSE)) {
        info <- paste(kind, route, simplify)
        recorder <- local_request_sequence(list(
          reply_with_model(route, quoted("org/model-x"))
        ))
        expect_no_error(mocked_call(route, asked[[kind]], simplify))
        expect_identical(length(recorder$requests), 1L, info = info)
      }
    }
  }
})

test_that("an S4 model string that the same model answers sends no other request", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  s4_env <- new.env()
  s4_string <- methods::setClass(
    "rlmstudioM049String",
    contains = "character",
    where = s4_env
  )
  asked <- s4_string("org/model-x")
  expect_true(isS4(asked))
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(route, simplify)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-x"))
      ))
      expect_no_error(mocked_call(route, asked, simplify))
      expect_identical(length(recorder$requests), 1L, info = info)
    }
  }
})

test_that("a recorded reply to a key in other letter case is accepted after one lookup", {
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(route, simplify)
      log <- local_request_log()
      value <- with_recorded_case(
        "case",
        recorded_call(route, "Google/Gemma-3-1B", simplify)
      )
      if (simplify) {
        expect_true(is_one_string(value), info = info)
      } else {
        expect_identical(value$model, "google/gemma-3-1b", info = info)
      }
      expect_identical(length(log$urls), 2L, info = info)
      expect_identical(
        log$urls[[2]],
        "http://localhost:1234/api/v1/models",
        info = info
      )
    }
  }
})

test_that("a recorded reply from an instance with another id is accepted after one lookup", {
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      info <- paste(route, simplify)
      log <- local_request_log()
      value <- with_recorded_case(
        "alias",
        recorded_call(route, "qwen/qwen3-4b-2507", simplify)
      )
      if (simplify) {
        expect_true(is_one_string(value), info = info)
      } else {
        expect_identical(value$model, "my-qwen", info = info)
      }
      expect_identical(length(log$urls), 2L, info = info)
      expect_identical(
        log$urls[[2]],
        "http://localhost:1234/api/v1/models",
        info = info
      )
    }
  }
})

test_that("a reply with no model string is not checked", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  models <- list(NULL, "null", "5", '["org/model-y"]', '""', '"  \\t"')
  for (route in chat_routes) {
    for (simplify in c(TRUE, FALSE)) {
      for (model_json in models) {
        info <- paste(route, simplify, format(model_json))
        recorder <- local_request_sequence(list(
          reply_with_model(route, model_json)
        ))
        expect_no_error(mocked_call(route, "org/model-x", simplify))
        expect_identical(length(recorder$requests), 1L, info = info)
      }
    }
  }
})

test_that("a status-200 body that is not a JSON object is not checked", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  bodies <- c("5", '"org/model-y"', '["org/model-y"]', "null")
  for (route in chat_routes) {
    for (body in bodies) {
      info <- paste(route, body)
      recorder <- local_request_sequence(list(mock_response(200L, body)))
      expect_identical(
        mocked_call(route, "org/model-x", simplify = FALSE),
        jsonlite::parse_json(body),
        info = info
      )
      expect_identical(length(recorder$requests), 1L, info = info)

      recorder <- local_request_sequence(list(mock_response(200L, body)))
      err <- expect_error(
        mocked_call(route, "org/model-x", simplify = TRUE),
        class = "rlmstudio_bad_response",
        info = info
      )
      expect_false(inherits(err, "rlmstudio_model_mismatch"), info = info)
      expect_identical(length(recorder$requests), 1L, info = info)
    }
  }
})

# A failed lookup ---------------------------------------------------------------

# Assert that `err` names the chat label and the failed lookup. cli wraps the
# message at spaces, so runs of whitespace are joined first.
expect_lookup_message <- function(err, route) {
  msg <- gsub("[[:space:]]+", " ", cli::ansi_strip(conditionMessage(err)))
  expect_true(
    grepl(
      paste0(route_label[[route]], ", because the model-list lookup failed:"),
      msg,
      fixed = TRUE
    ),
    info = route
  )
}

test_that("a failed status of the lookup raises an API error", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    local_request_sequence(list(
      reply_with_model(route, quoted("org/model-y")),
      mock_response(401L, '{"error": {"message": "no", "code": "bad_token"}}')
    ))
    err <- expect_error(
      mocked_call(route, "org/model-x"),
      class = "rlmstudio_api_error"
    )
    expect_identical(err$status, 401L, info = route)
    expect_identical(err$code, "bad_token", info = route)
    expect_lookup_message(err, route)
  }
})

test_that("a lookup body that does not parse raises a bad response", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    local_request_sequence(list(
      reply_with_model(route, quoted("org/model-y")),
      mock_response(200L, "<html>not json</html>", content_type = "text/html")
    ))
    err <- expect_error(
      mocked_call(route, "org/model-x"),
      class = "rlmstudio_bad_response"
    )
    expect_false(inherits(err, "rlmstudio_model_mismatch"), info = route)
    expect_lookup_message(err, route)
    expect_true(
      grepl("did not parse as JSON", conditionMessage(err)),
      info = route
    )
    expect_false(
      any(c("content", "finish_reason") %in% names(err)),
      info = route
    )
  }
})

test_that("a lookup body that fails a model-list check raises a bad response", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    local_request_sequence(list(
      reply_with_model(route, quoted("org/model-y")),
      mock_response(200L, '{"models": 5}')
    ))
    err <- expect_error(
      mocked_call(route, "org/model-x"),
      class = "rlmstudio_bad_response"
    )
    expect_false(inherits(err, "rlmstudio_model_mismatch"), info = route)
    expect_lookup_message(err, route)
    expect_true(
      grepl("`models` is not an array", conditionMessage(err)),
      info = route
    )
  }
})

test_that("a lookup that cannot reach the server raises no_server", {
  for (route in chat_routes) {
    probes <- 0L
    local_mocked_bindings(is_server_running = function(...) {
      probes <<- probes + 1L
      probes == 1L
    })
    recorder <- local_request_sequence(list(
      reply_with_model(route, quoted("org/model-y"))
    ))
    err <- expect_error(
      mocked_call(route, "org/model-x"),
      class = "rlmstudio_no_server"
    )
    expect_lookup_message(err, route)
    expect_identical(probes, 2L, info = route)
    expect_identical(length(recorder$requests), 1L, info = route)
  }
})

test_that("the lookup sends the call's token to the same host and prints nothing", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    recorder <- local_request_sequence(list(
      reply_with_model(route, quoted("x-instance")),
      two_models_list()
    ))
    expect_silent(mocked_call(
      route,
      "org/model-x",
      host = "http://example.com:9999",
      token = "lookup-token"
    ))
    target <- request_target(recorder$requests[[2]])
    expect_identical(target$method, "GET", info = route)
    expect_identical(target$path, "/api/v1/models", info = route)
    expect_identical(target$host, "example.com:9999", info = route)
    expect_identical(
      target$headers$authorization,
      "Bearer lookup-token",
      info = route
    )
  }
})

# `list_models()` prints a message only when it has no model to return, as
# for an empty list, so this case would catch a lookup that went through it
# with `quiet = FALSE`.
test_that("a lookup that gets an empty model list prints nothing", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    recorder <- local_request_sequence(list(
      reply_with_model(route, quoted("x-instance")),
      model_list_response()
    ))
    expect_silent(
      err <- tryCatch(
        mocked_call(route, "org/model-x"),
        rlmstudio_model_mismatch = identity
      )
    )
    expect_mismatch(err, "org/model-x", "x-instance", route)
    expect_identical(length(recorder$requests), 2L, info = route)
  }
})

# The batch stops ---------------------------------------------------------------

batch_formats <- c("vector", "list", "data.frame")

# The value that `format = "list"` holds for the good reply of the batch.
good_value <- "reply"

test_that("a batch aborts with its results at the first mismatched input", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    for (format in batch_formats) {
      info <- paste(route, format)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-x")),
        reply_with_model(route, quoted("org/model-y")),
        two_models_list(),
        reply_with_model(route, quoted("org/model-x"))
      ))
      err <- expect_error(
        lms_chat_batch(
          "org/model-x",
          c("first", "second", "third"),
          format = format,
          quiet = TRUE,
          api_type = route
        ),
        class = "rlmstudio_model_mismatch"
      )
      expect_true(inherits(err, "rlmstudio_bad_response"), info = info)
      expect_identical(err$results, list(good_value, NULL, NULL), info = info)
      expect_identical(length(recorder$requests), 3L, info = info)
    }
  }
})

test_that("a recorded model_not_found reply aborts a batch with its results", {
  for (route in chat_routes) {
    log <- local_request_log()
    err <- with_recorded_case(
      "not_found",
      expect_error(
        lms_chat_batch(
          "not-a-model",
          c(mismatch_prompt, mismatch_prompt),
          host = "http://localhost:1234",
          quiet = TRUE,
          api_type = route,
          temperature = 0
        ),
        class = "rlmstudio_api_error"
      )
    )
    expect_identical(err$status, 400L, info = route)
    expect_identical(err$code, "model_not_found", info = route)
    expect_identical(err$results, list(NULL, NULL), info = route)
    expect_identical(length(log$urls), 1L, info = route)
  }
})

test_that("a batch keeps going past a 400 with another code or no code", {
  bodies <- c(
    '{"error": {"message": "boom", "code": "E42"}}',
    '{"error": {"message": "boom"}}',
    '{"error": "boom"}'
  )
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in chat_routes) {
    for (body in bodies) {
      info <- paste(route, body)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-x")),
        mock_response(400L, body),
        reply_with_model(route, quoted("org/model-x"))
      ))
      expect_warning(
        out <- lms_chat_batch(
          "org/model-x",
          c("first", "second", "third"),
          format = "list",
          quiet = TRUE,
          api_type = route
        ),
        "1 input failed"
      )
      expect_true(inherits(out[[2]], "rlmstudio_api_error"), info = info)
      expect_identical(out[c(1, 3)], list(good_value, good_value), info = info)
      expect_identical(length(recorder$requests), 3L, info = info)
    }
  }
})
