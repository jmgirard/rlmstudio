# How lms_embed() treats a reply from a model other than the one asked for,
# how lms_chat_batch() and lms_embed() stop at a 400 "No models loaded", and
# how one call keeps the reply ids that a lookup accepted (D-046).
#
# The recorded replies in stop_live/ come from a live LM Studio server.
# Regenerate them with data-raw/record-model-stop-cassette.R, which carries the
# full provenance. The requests below must match the script's requests byte
# for byte. Cases that a live server does not produce are mocked through the
# shared recorder (D-004).

# Run `expr` against the recorded case `case_dir` with no token and a server
# probe that always passes.
with_stop_case <- function(case_dir, expr, .env = parent.frame()) {
  local_mocked_bindings(is_server_running = function(...) TRUE, .env = .env)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = NA, .local_envir = .env)
  withr::local_options(rlmstudio.token = NULL, .local_envir = .env)
  httptest2::with_mock_dir(file.path("stop_live", case_dir), expr)
}

recorded_embedder <- "text-embedding-nomic-embed-text-v1.5"
recorded_text <- "the first document"

# The vector served for input `i` of a mocked call.
row_for <- function(i) c(i, i + 0.5)

# The body text of an embeddings reply of one row, for input `i`, from the
# model `model_json`, a JSON value, or with no `model` field when it is NULL.
embed_text <- function(model_json, i = 1L) {
  fields <- c(
    if (!is.null(model_json)) paste0('"model": ', model_json),
    sprintf(
      '"data": [{"object": "embedding", "index": 0, "embedding": [%s]}]',
      paste(row_for(i), collapse = ", ")
    )
  )
  paste0("{", paste(fields, collapse = ", "), "}")
}

embed_from <- function(model_json, i = 1L) {
  mock_response(200L, embed_text(model_json, i))
}

# The asked model, loaded under the id "x-instance", and another model.
embed_models_list <- function() {
  model_list_response(
    "org/embed-x" = "x-instance",
    "org/embed-y" = "org/embed-y"
  )
}

# lms_embed() for org/embed-x over three texts, one request each.
embed_three <- function(simplify) {
  lms_embed(
    "org/embed-x",
    c("a", "b", "c"),
    batch_size = 1,
    simplify = simplify,
    quiet = TRUE
  )
}

# The `results` that a call ends with after request 1 succeeded and request 2
# ended it.
results_after_one <- function(simplify) {
  if (simplify) {
    return(rbind(row_for(1L), c(NA, NA), c(NA, NA)))
  }
  list(jsonlite::parse_json(embed_text(quoted("org/embed-x"), 1L)), NULL, NULL)
}

# The embedding reply-model check --------------------------------------------

test_that("a recorded embedding reply from another model aborts lms_embed", {
  for (simplify in c(TRUE, FALSE)) {
    log <- local_request_log()
    err <- with_stop_case(
      "embed_unknown",
      expect_error(
        lms_embed(
          "not-a-model",
          recorded_text,
          host = "http://localhost:1234",
          simplify = simplify
        ),
        class = "rlmstudio_model_mismatch"
      )
    )
    expect_mismatch(err, "not-a-model", recorded_embedder, info = simplify)
    expect_null(err$results)
    expect_identical(
      count_requests(log$urls),
      c(chat = 0L, embed = 1L, lookup = 1L),
      info = simplify
    )
  }
})

test_that("a recorded embedding reply from an instance with another id is kept", {
  for (simplify in c(TRUE, FALSE)) {
    log <- local_request_log()
    out <- with_stop_case(
      "embed_alias",
      lms_embed(
        recorded_embedder,
        recorded_text,
        host = "http://localhost:1234",
        simplify = simplify
      )
    )
    if (simplify) {
      expect_identical(dim(out), c(1L, 768L))
    } else {
      expect_identical(out[[1]][["model"]], "my-nomic")
    }
    expect_identical(
      count_requests(log$urls),
      c(chat = 0L, embed = 1L, lookup = 1L),
      info = simplify
    )
  }
})

test_that("a mismatch at the first request aborts with no results", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (simplify in c(TRUE, FALSE)) {
    recorder <- local_request_sequence(list(
      embed_from(quoted("org/embed-y")),
      embed_models_list()
    ))
    err <- expect_error(
      embed_three(simplify),
      class = "rlmstudio_model_mismatch"
    )
    expect_mismatch(err, "org/embed-x", "org/embed-y", info = simplify)
    expect_false("results" %in% names(err), info = simplify)
    expect_identical(
      count_requests(recorder_urls(recorder)),
      c(chat = 0L, embed = 1L, lookup = 1L),
      info = simplify
    )
  }
})

test_that("a mismatch at the second request aborts with the results so far", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (simplify in c(TRUE, FALSE)) {
    recorder <- local_request_sequence(list(
      embed_from(quoted("org/embed-x"), 1L),
      embed_from(quoted("org/embed-y"), 2L),
      embed_models_list()
    ))
    err <- expect_error(
      embed_three(simplify),
      class = "rlmstudio_model_mismatch"
    )
    expect_mismatch(err, "org/embed-x", "org/embed-y", info = simplify)
    expect_identical(err$results, results_after_one(simplify), info = simplify)
    expect_identical(
      count_requests(recorder_urls(recorder)),
      c(chat = 0L, embed = 2L, lookup = 1L),
      info = simplify
    )
  }
})

test_that("a reply from another instance of the asked model is kept", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (simplify in c(TRUE, FALSE)) {
    recorder <- local_request_sequence(list(
      embed_from(quoted("x-instance")),
      embed_models_list()
    ))
    out <- lms_embed("org/embed-x", "a", simplify = simplify)
    if (simplify) {
      expect_identical(out, rbind(row_for(1L)), info = simplify)
    } else {
      expect_identical(out[[1]][["model"]], "x-instance", info = simplify)
    }
    expect_identical(
      count_requests(recorder_urls(recorder)),
      c(chat = 0L, embed = 1L, lookup = 1L),
      info = simplify
    )
  }
})

test_that("a reply with no model string that holds a character is not checked", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  forms <- list(NULL, "null", "42", quoted(""), quoted(" \t"), '["org/embed-y"]')
  for (simplify in c(TRUE, FALSE)) {
    for (form in forms) {
      info <- paste(simplify, format(form))
      recorder <- local_request_sequence(list(embed_from(form)))
      out <- lms_embed("org/embed-x", "a", simplify = simplify)
      if (simplify) {
        expect_identical(out, rbind(row_for(1L)), info = info)
      }
      expect_identical(length(recorder$requests), 1L, info = info)
    }
  }
})

test_that("a lookup that fails alone fails its request and the call goes on", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  lookups <- list(
    list(resp = mock_response(500L, '{"error": "boom"}'),
      class = "rlmstudio_api_error"),
    list(resp = mock_response(200L, '{"models": 3}'),
      class = "rlmstudio_bad_response")
  )
  for (simplify in c(TRUE, FALSE)) {
    for (lookup in lookups) {
      info <- paste(simplify, lookup$class)
      recorder <- local_request_sequence(list(
        embed_from(quoted("org/embed-x"), 1L),
        embed_from(quoted("org/embed-y"), 2L),
        lookup$resp,
        embed_from(quoted("org/embed-x"), 3L)
      ))
      expect_warning(
        out <- embed_three(simplify),
        "1 input failed, at position 2"
      )
      if (simplify) {
        expect_identical(
          out,
          rbind(row_for(1L), c(NA, NA), row_for(3L)),
          info = info
        )
      } else {
        expect_true(inherits(out[[2]], lookup$class), info = info)
        expect_false(
          inherits(out[[2]], "rlmstudio_model_mismatch"),
          info = info
        )
      }
      expect_identical(
        count_requests(recorder_urls(recorder)),
        c(chat = 0L, embed = 3L, lookup = 1L),
        info = info
      )
    }
  }
})

test_that("a lookup with no server ends the call with the results so far", {
  for (simplify in c(TRUE, FALSE)) {
    # The probes are the call's own check, the check before request 2, and
    # the check of the lookup.
    probes <- 0L
    local_mocked_bindings(is_server_running = function(...) {
      probes <<- probes + 1L
      probes < 3L
    })
    recorder <- local_request_sequence(list(
      embed_from(quoted("org/embed-x"), 1L),
      embed_from(quoted("org/embed-y"), 2L)
    ))
    err <- expect_error(embed_three(simplify), class = "rlmstudio_no_server")
    expect_identical(err$results, results_after_one(simplify), info = simplify)
    expect_identical(probes, 3L, info = simplify)
    expect_identical(
      count_requests(recorder_urls(recorder)),
      c(chat = 0L, embed = 2L, lookup = 0L),
      info = simplify
    )
  }
})

test_that("a lookup with status 401, 403, or 404 ends the call with the results so far", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (simplify in c(TRUE, FALSE)) {
    for (status in c(401L, 403L, 404L)) {
      info <- paste(simplify, status)
      recorder <- local_request_sequence(list(
        embed_from(quoted("org/embed-x"), 1L),
        embed_from(quoted("org/embed-y"), 2L),
        mock_response(status, '{"error": "no"}')
      ))
      err <- expect_error(embed_three(simplify), class = "rlmstudio_api_error")
      expect_identical(err$status, status, info = info)
      expect_identical(err$results, results_after_one(simplify), info = info)
      expect_identical(
        count_requests(recorder_urls(recorder)),
        c(chat = 0L, embed = 2L, lookup = 1L),
        info = info
      )
    }
  }
})

# The "No models loaded" stop -------------------------------------------------

stop_routes <- c("openai", "openresponses")
stop_formats <- c("vector", "list", "data.frame")

no_models_text <- paste(
  "No models loaded. Please load a model in the developer page or use the",
  "'lms load' command."
)

# The recorded "No models loaded" reply of `route`, as an httr2 response.
recorded_no_models <- function(route) {
  file <- switch(
    route,
    openai = c("chat", "completions-a2774c-POST.R"),
    openresponses = "responses-7adffa-POST.R",
    embed = "embeddings-e3ba6f-POST.R"
  )
  path <- do.call(
    test_path,
    as.list(c("stop_live", "none", "localhost-1234", "v1", file))
  )
  source(path)$value
}

# lms_chat_batch() for org/model-x over three inputs on `route`.
chat_three <- function(route, format) {
  lms_chat_batch(
    "org/model-x",
    c("first", "second", "third"),
    format = format,
    quiet = TRUE,
    api_type = route
  )
}

test_that("a recorded No models loaded reply stops a chat batch with its results", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in stop_routes) {
    for (format in stop_formats) {
      info <- paste(route, format)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-x")),
        recorded_no_models(route),
        reply_with_model(route, quoted("org/model-x"))
      ))
      err <- expect_error(chat_three(route, format), class = "rlmstudio_api_error")
      expect_identical(err$status, 400L, info = info)
      expect_null(err$code)
      expect_identical(err$server_message, no_models_text, info = info)
      expect_identical(err$results, list("reply", NULL, NULL), info = info)
      expect_identical(
        count_requests(recorder_urls(recorder)),
        c(chat = 2L, embed = 0L, lookup = 0L),
        info = info
      )
    }
  }
})

test_that("a recorded No models loaded reply stops lms_embed with its results", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (simplify in c(TRUE, FALSE)) {
    recorder <- local_request_sequence(list(
      embed_from(quoted("org/embed-x"), 1L),
      recorded_no_models("embed"),
      embed_from(quoted("org/embed-x"), 3L)
    ))
    err <- expect_error(embed_three(simplify), class = "rlmstudio_api_error")
    expect_identical(err$status, 400L, info = simplify)
    expect_identical(err$server_message, no_models_text, info = simplify)
    expect_identical(err$results, results_after_one(simplify), info = simplify)
    expect_identical(
      count_requests(recorder_urls(recorder)),
      c(chat = 0L, embed = 2L, lookup = 0L),
      info = simplify
    )
  }
})

# The stop reads both shapes of the error text, so each function also stops
# at the shape that its own route did not send on 2026-10-19.
other_shape <- c(
  openai = '{"error": "No models loaded."}',
  openresponses = '{"error": "No models loaded."}',
  embed = '{"error": {"message": "No models loaded.", "code": null}}'
)

test_that("the stop reads the error text as a string and as error.message", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in stop_routes) {
    recorder <- local_request_sequence(list(
      reply_with_model(route, quoted("org/model-x")),
      mock_response(400L, other_shape[[route]])
    ))
    err <- expect_error(chat_three(route, "list"), class = "rlmstudio_api_error")
    expect_identical(err$server_message, "No models loaded.", info = route)
    expect_identical(length(recorder$requests), 2L, info = route)
  }
  recorder <- local_request_sequence(list(
    embed_from(quoted("org/embed-x"), 1L),
    mock_response(400L, other_shape[["embed"]])
  ))
  err <- expect_error(embed_three(TRUE), class = "rlmstudio_api_error")
  expect_identical(err$server_message, "No models loaded.")
  expect_identical(length(recorder$requests), 2L)
})

# Failures that come close to the stop and fail their own input alone.
near_misses <- list(
  list(status = 400L, body = '{"error": "no models loaded."}'),
  list(status = 400L, body = '{"error": {"message": " No models loaded."}}'),
  list(status = 400L, body = '{"error": {"message": "Model not loaded."}}'),
  list(status = 400L, body = '{"error": {"message": "boom", "code": null}}'),
  list(status = 500L, body = '{"error": "No models loaded."}')
)

test_that("a chat batch goes on past a failure that is not the stop", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in stop_routes) {
    for (miss in near_misses) {
      info <- paste(route, miss$status, miss$body)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("org/model-x")),
        mock_response(miss$status, miss$body),
        reply_with_model(route, quoted("org/model-x"))
      ))
      expect_warning(out <- chat_three(route, "list"), "1 input failed")
      expect_true(inherits(out[[2]], "rlmstudio_api_error"), info = info)
      expect_identical(out[c(1, 3)], list("reply", "reply"), info = info)
      expect_identical(length(recorder$requests), 3L, info = info)
    }
  }
})

test_that("lms_embed goes on past a failure that is not the stop", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (miss in near_misses) {
    info <- paste(miss$status, miss$body)
    recorder <- local_request_sequence(list(
      embed_from(quoted("org/embed-x"), 1L),
      mock_response(miss$status, miss$body),
      embed_from(quoted("org/embed-x"), 3L)
    ))
    expect_warning(
      out <- embed_three(TRUE),
      "1 input failed, at position 2"
    )
    expect_identical(
      out,
      rbind(row_for(1L), c(NA, NA), row_for(3L)),
      info = info
    )
    expect_identical(length(recorder$requests), 3L, info = info)
  }
})

test_that("an API error carries the error text of the body, or NULL", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  cases <- list(
    list(body = '{"error": "boom"}', text = "boom"),
    list(body = '{"error": {"message": "boom", "code": "E1"}}', text = "boom"),
    list(body = '{"error": {"message": 3}}', text = NULL),
    list(body = '{"error": 3}', text = NULL),
    list(body = '{"message": "boom"}', text = NULL),
    list(body = "<html>boom</html>", text = NULL),
    list(body = "", text = NULL)
  )
  for (case in cases) {
    local_request_recorder(mock_response(400L, case$body))
    err <- expect_error(
      lms_embed("org/embed-x", "a"),
      class = "rlmstudio_api_error"
    )
    expect_true("server_message" %in% names(err), info = case$body)
    expect_identical(err$server_message, case$text, info = case$body)
  }
})

# One lookup per kept reply id ------------------------------------------------

# org/model-x loaded under two ids, neither of them its key.
chat_ids_list <- function() {
  model_list_response(
    "org/model-x" = c("x-instance", "x-second"),
    "org/model-y" = "org/model-y"
  )
}

embed_ids_list <- function() {
  model_list_response(
    "org/embed-x" = c("x-instance", "x-second"),
    "org/embed-y" = "org/embed-y"
  )
}

test_that("a chat batch sends one lookup for replies that name one kept id", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in stop_routes) {
    for (format in c("list", "data.frame")) {
      info <- paste(route, format)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("x-instance")),
        chat_ids_list(),
        reply_with_model(route, quoted("x-instance")),
        reply_with_model(route, quoted("x-instance"))
      ))
      out <- chat_three(route, format)
      expect_identical(
        count_requests(recorder_urls(recorder)),
        c(chat = 3L, embed = 0L, lookup = 1L),
        info = info
      )
      replies <- if (format == "list") unlist(out) else out$output
      expect_identical(replies, rep("reply", 3), info = info)
    }
  }
})

test_that("a chat batch sends a second lookup for a second id", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in stop_routes) {
    for (format in c("list", "data.frame")) {
      info <- paste(route, format)
      recorder <- local_request_sequence(list(
        reply_with_model(route, quoted("x-instance")),
        chat_ids_list(),
        reply_with_model(route, quoted("x-instance")),
        reply_with_model(route, quoted("x-second")),
        chat_ids_list()
      ))
      chat_three(route, format)
      expect_identical(
        count_requests(recorder_urls(recorder)),
        c(chat = 3L, embed = 0L, lookup = 2L),
        info = info
      )
    }
  }
})

test_that("each chat batch and each single call sends its own lookup", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (route in stop_routes) {
    batch <- list(
      reply_with_model(route, quoted("x-instance")),
      chat_ids_list(),
      reply_with_model(route, quoted("x-instance")),
      reply_with_model(route, quoted("x-instance"))
    )
    recorder <- local_request_sequence(c(
      batch,
      batch,
      list(reply_with_model(route, quoted("x-instance")), chat_ids_list())
    ))
    chat_three(route, "list")
    chat_three(route, "list")
    lms_chat(
      "org/model-x",
      "first",
      api_type = route,
      quiet = TRUE
    )
    expect_identical(
      count_requests(recorder_urls(recorder)),
      c(chat = 7L, embed = 0L, lookup = 3L),
      info = route
    )
  }
})

test_that("lms_embed sends one lookup for replies that name one kept id", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (simplify in c(TRUE, FALSE)) {
    recorder <- local_request_sequence(list(
      embed_from(quoted("x-instance"), 1L),
      embed_ids_list(),
      embed_from(quoted("x-instance"), 2L),
      embed_from(quoted("x-instance"), 3L)
    ))
    out <- embed_three(simplify)
    if (simplify) {
      expect_identical(out, rbind(row_for(1L), row_for(2L), row_for(3L)))
    }
    expect_identical(
      count_requests(recorder_urls(recorder)),
      c(chat = 0L, embed = 3L, lookup = 1L),
      info = simplify
    )
  }
})

test_that("lms_embed sends a second lookup for a second id", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(
    embed_from(quoted("x-instance"), 1L),
    embed_ids_list(),
    embed_from(quoted("x-instance"), 2L),
    embed_from(quoted("x-second"), 3L),
    embed_ids_list()
  ))
  embed_three(TRUE)
  expect_identical(
    count_requests(recorder_urls(recorder)),
    c(chat = 0L, embed = 3L, lookup = 2L)
  )
})

test_that("each lms_embed call sends its own lookup", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  call <- list(
    embed_from(quoted("x-instance"), 1L),
    embed_ids_list(),
    embed_from(quoted("x-instance"), 2L),
    embed_from(quoted("x-instance"), 3L)
  )
  recorder <- local_request_sequence(c(call, call))
  embed_three(TRUE)
  embed_three(TRUE)
  expect_identical(
    count_requests(recorder_urls(recorder)),
    c(chat = 0L, embed = 6L, lookup = 2L)
  )
})
