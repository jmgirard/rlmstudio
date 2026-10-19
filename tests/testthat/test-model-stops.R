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
