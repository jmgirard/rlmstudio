# How lms_chat_batch() treats an input that fails. A live server does not fail
# on demand, so the server is mocked through the shared recorder (D-004).

batch_inputs <- c("first", "second", "third")
failure_classes <- c("rlmstudio_api_error", "rlmstudio_bad_response")

# A chat completions response that succeeds at position `i`: a score for a
# schema batch, text otherwise. Each position gets its own value, so a slot
# cannot pass by holding a neighbor's reply.
openai_ok <- function(i, schema = FALSE) {
  content <- if (schema) sprintf('{"score": %d}', i) else sprintf("reply %d", i)
  mock_response(200L, completion_body(quoted(content)))
}

# An OpenResponses response that succeeds at position `i`. With `logprobs`,
# the reply carries one token and its log probability.
openresponses_ok <- function(i, logprobs = FALSE) {
  lp <- if (logprobs) sprintf("[%s]", logprob_step("r")) else NULL
  mock_response(
    200L,
    output_body(responses_message(output_text(quoted(sprintf("reply %d", i)), lp)))
  )
}

# A response that makes lms_chat() raise `cls`. A parsed schema reply fails as
# text that is not JSON. A reply that is never parsed fails as a response with
# no `choices` field.
fail_response <- function(cls, parsed) {
  switch(
    cls,
    rlmstudio_api_error = mock_response(400L, '{"error": "bad request"}'),
    rlmstudio_bad_response = if (parsed) {
      mock_response(200L, completion_body(quoted("not json")))
    } else {
      mock_response(200L, '{"id": "chatcmpl-1"}')
    }
  )
}

# Run lms_chat_batch() over three inputs. The inputs at `fail_at` fail with
# the matching class in `cls`, and the others succeed with `ok(i)`. Returns
# the result, the warnings, and the number of requests sent.
run_failing_batch <- function(
  fail_at,
  cls,
  format,
  schema = FALSE,
  simplify = TRUE,
  logprobs = FALSE,
  api_type = "openai",
  quiet = TRUE,
  ok = function(i) openai_ok(i, schema)
) {
  parsed <- schema && simplify && !logprobs
  responses <- lapply(seq_along(batch_inputs), ok)
  responses[fail_at] <- lapply(cls, fail_response, parsed = parsed)

  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(responses)
  args <- list(
    "a-model",
    batch_inputs,
    format = format,
    simplify = simplify,
    quiet = quiet,
    api_type = api_type
  )
  if (schema) {
    args$schema <- score_schema
  }
  if (logprobs) {
    args$logprobs <- TRUE
  }
  warnings <- testthat::capture_warnings(
    out <- do.call(lms_chat_batch, args)
  )
  list(out = out, warnings = warnings, requests = length(recorder$requests))
}

# A stored condition has the class it was raised with and no backtrace, which
# would make each failed slot large.
expect_failed_slot <- function(x, cls, info = NULL) {
  expect_s3_class(x, cls)
  expect_null(x$trace, info = info)
  if (cls == "rlmstudio_api_error") {
    expect_identical(x$status, 400L, info = info)
  }
}

test_that("a failed input in any format does not end the batch", {
  for (cls in failure_classes) {
    for (schema in c(FALSE, TRUE)) {
      for (format in c("list", "vector", "data.frame")) {
        for (fail_at in 2:3) {
          info <- paste(cls, format, "schema:", schema, "fail_at:", fail_at)
          res <- run_failing_batch(fail_at, cls, format, schema = schema)
          expect_identical(res$requests, 3L, info = info)

          got <- if (format == "data.frame") res$out$output else res$out
          if (format == "data.frame") {
            expect_identical(res$out$input, batch_inputs, info = info)
          }
          holds_na <- !schema && format != "list"
          if (holds_na) {
            expected <- sprintf("reply %d", 1:3)
            expected[fail_at] <- NA_character_
            expect_identical(got, expected, info = info)
          } else {
            expect_type(got, "list")
            expect_length(got, 3L)
            for (i in setdiff(1:3, fail_at)) {
              expected <- if (schema) list(score = i) else sprintf("reply %d", i)
              expect_identical(got[[i]], expected, info = info)
            }
            expect_failed_slot(got[[fail_at]], cls, info = info)
          }

          # expect_length() takes no `info`, so the loop case would go unnamed.
          expect_identical(length(res$warnings), 1L, info = info)
          expect_match(
            res$warnings,
            sprintf("1 input failed, at position %d\\.", fail_at),
            info = info
          )
          if (holds_na) {
            expect_match(res$warnings, 'format = "list"', fixed = TRUE, info = info)
          } else {
            expect_no_match(res$warnings, 'format = "list"', fixed = TRUE, info = info)
          }
          # A vector batch that returns a list says why in the same warning.
          if (format == "vector" && schema) {
            expect_match(
              res$warnings,
              "cannot store replies parsed from .*schema.*Returning list\\.",
              info = info
            )
          }
        }
      }
    }
  }
})

test_that("a failed input does not end a batch with simplify = FALSE", {
  res <- run_failing_batch(2L, "rlmstudio_api_error", "list", simplify = FALSE)
  expect_identical(res$requests, 3L)
  # The raw response of each input that succeeded.
  expect_identical(res$out[[1]]$choices[[1]]$message$content, "reply 1")
  expect_failed_slot(res$out[[2]], "rlmstudio_api_error")
  expect_identical(res$out[[3]]$choices[[1]]$message$content, "reply 3")
  expect_length(res$warnings, 1L)
  expect_match(res$warnings, "1 input failed, at position 2\\.")
  expect_no_match(res$warnings, 'format = "list"', fixed = TRUE)
})

test_that("a failed input does not end a batch on the default api_type", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(
    openresponses_ok(1L),
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openresponses_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "list", quiet = TRUE),
    "1 input failed, at position 2\\."
  )
  expect_length(recorder$requests, 3L)
  # The route is the one the default api_type takes.
  expect_identical(request_target(recorder$requests[[3]])$path, "/v1/responses")
  expect_identical(out[[1]], "reply 1")
  expect_failed_slot(out[[2]], "rlmstudio_api_error")
  expect_identical(out[[3]], "reply 3")
})

test_that("a failed input leaves NULL logprobs in a data frame", {
  for (cls in failure_classes) {
    res <- run_failing_batch(2L, cls, "data.frame", logprobs = TRUE)
    expect_identical(res$requests, 3L, info = cls)
    expect_named(res$out, c("input", "output", "logprobs"))
    expect_identical(res$out$output, c("reply 1", NA, "reply 3"), info = cls)
    expect_null(res$out$logprobs[[2]])
    expect_length(res$warnings, 1L)
    expect_match(res$warnings, "1 input failed, at position 2\\.", info = cls)
    expect_match(res$warnings, 'format = "list"', fixed = TRUE, info = cls)
  }

  # The openai route leaves every logprobs slot NULL, so this route shows the
  # inputs that succeeded keep theirs.
  res <- run_failing_batch(
    2L,
    "rlmstudio_api_error",
    "data.frame",
    logprobs = TRUE,
    api_type = "openresponses",
    ok = function(i) openresponses_ok(i, logprobs = TRUE)
  )
  expect_identical(res$out$output, c("reply 1", NA, "reply 3"))
  expect_s3_class(res$out$logprobs[[1]], "data.frame")
  expect_null(res$out$logprobs[[2]])
  expect_s3_class(res$out$logprobs[[3]], "data.frame")
})

test_that("a batch in which every input fails keeps its logprobs column", {
  for (cls in failure_classes) {
    res <- run_failing_batch(1:3, rep(cls, 3), "data.frame", logprobs = TRUE)
    expect_identical(res$requests, 3L, info = cls)
    expect_named(res$out, c("input", "output", "logprobs"))
    expect_identical(res$out$output, rep(NA_character_, 3), info = cls)
    expect_identical(res$out$logprobs, list(NULL, NULL, NULL), info = cls)
    expect_length(res$warnings, 1L)
    expect_match(res$warnings, "3 inputs failed, at positions 1, 2, and 3\\.", info = cls)
  }
})

test_that("one warning names every failed input of either class", {
  withr::local_options(rlmstudio.quiet = TRUE)
  res <- run_failing_batch(
    c(1L, 3L),
    c("rlmstudio_api_error", "rlmstudio_bad_response"),
    "list",
    schema = TRUE,
    quiet = TRUE
  )
  expect_identical(res$requests, 3L)
  expect_failed_slot(res$out[[1]], "rlmstudio_api_error")
  expect_identical(res$out[[2]], list(score = 2L))
  expect_failed_slot(res$out[[3]], "rlmstudio_bad_response")
  expect_length(res$warnings, 1L)
  expect_match(res$warnings, "2 inputs failed, at positions 1 and 3\\.")
})

# Run a three-input batch in which the server goes away before input `k`. The
# batch probes the server once before the first input, and each input probes
# again, so input i makes probe i + 1. `responses` answers the inputs before
# `k`. Returns the caught condition and the counts.
run_lost_server_batch <- function(k, responses, format = "list") {
  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes <= k
  })
  recorder <- local_request_sequence(responses)
  cnd <- expect_error(
    lms_chat_batch("a-model", batch_inputs, format = format, quiet = TRUE, api_type = "openai"),
    class = "rlmstudio_no_server"
  )
  list(cnd = cnd, probes = probes, requests = length(recorder$requests))
}

test_that("a lost server aborts the batch with the replies so far", {
  res <- run_lost_server_batch(2L, list(openai_ok(1L)))
  expect_identical(res$probes, 3L)
  expect_identical(res$requests, 1L)
  expect_match(conditionMessage(res$cnd), "server")
  expect_identical(res$cnd$results, list("reply 1", NULL, NULL))

  # The field holds what format = "list" returns, whatever the format.
  res <- run_lost_server_batch(2L, list(openai_ok(1L)), format = "vector")
  expect_identical(res$cnd$results, list("reply 1", NULL, NULL))
})

test_that("a server lost before the first input leaves every result NULL", {
  res <- run_lost_server_batch(1L, list())
  expect_identical(res$probes, 2L)
  expect_identical(res$requests, 0L)
  expect_identical(res$cnd$results, list(NULL, NULL, NULL))
})

test_that("a server down before the batch starts adds no results field", {
  res <- run_lost_server_batch(0L, list())
  expect_identical(res$probes, 1L)
  expect_identical(res$requests, 0L)
  expect_false("results" %in% names(res$cnd))
})

test_that("a lost server keeps a stored failure in its results", {
  res <- run_lost_server_batch(
    3L,
    list(fail_response("rlmstudio_api_error", parsed = FALSE), openai_ok(2L))
  )
  expect_identical(res$requests, 2L)
  expect_length(res$cnd$results, 3L)
  expect_failed_slot(res$cnd$results[[1]], "rlmstudio_api_error")
  expect_identical(res$cnd$results[[2]], "reply 2")
  expect_null(res$cnd$results[[3]])
})

test_that("a reply with null content fails its input as NA in text results", {
  # The server answers input 1 with `"content": null`, which has no answer
  # text and so fails, and fails input 2 with an API error.
  null_reply <- mock_response(200L, completion_body("null"))
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  local_request_sequence(list(
    null_reply,
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openai_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "vector", quiet = TRUE, api_type = "openai"),
    "2 inputs failed, at positions 1 and 2\\."
  )
  expect_identical(out, c(NA, NA, "reply 3"))

  local_request_sequence(list(
    null_reply,
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openai_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "data.frame", quiet = TRUE, api_type = "openai"),
    "2 inputs failed, at positions 1 and 2\\."
  )
  expect_identical(out$output, c(NA, NA, "reply 3"))

  local_request_sequence(list(
    null_reply,
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openai_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "list", quiet = TRUE, api_type = "openai"),
    "2 inputs failed, at positions 1 and 2\\."
  )
  expect_s3_class(out[[1]], "rlmstudio_bad_response")
  expect_null(out[[1]]$content)
})

test_that("a logprobs data frame keeps its column when no reply carried logprobs", {
  # Replies with no logprobs, on the route that returns them as plain text,
  # and one with null text, which fails that input.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    openresponses_ok(1L),
    mock_response(200L, output_body(responses_message(output_text("null")))),
    openresponses_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch(
      "a-model",
      batch_inputs,
      format = "data.frame",
      logprobs = TRUE,
      quiet = TRUE,
      api_type = "openresponses"
    ),
    "1 input failed, at position 2\\."
  )
  expect_named(out, c("input", "output", "logprobs"))
  expect_identical(out$output, c("reply 1", NA, "reply 3"))
  expect_identical(out$logprobs, list(NULL, NULL, NULL))
})

test_that("named inputs keep their names in the result and in results", {
  named_inputs <- c(a = "first", b = "second", c = "third")
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  for (format in c("list", "vector")) {
    local_request_sequence(list(
      openai_ok(1L),
      fail_response("rlmstudio_api_error", parsed = FALSE),
      openai_ok(3L)
    ))
    expect_warning(
      out <- lms_chat_batch(
        "a-model",
        named_inputs,
        format = format,
        quiet = TRUE,
        api_type = "openai"
      ),
      "1 input failed"
    )
    expect_named(out, c("a", "b", "c"))
  }
  expect_identical(out, c(a = "reply 1", b = NA, c = "reply 3"))

  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes <= 2L
  })
  local_request_sequence(list(openai_ok(1L)))
  cnd <- expect_error(
    lms_chat_batch("a-model", named_inputs, quiet = TRUE, api_type = "openai"),
    class = "rlmstudio_no_server"
  )
  expect_identical(cnd$results, list(a = "reply 1", b = NULL, c = NULL))
})

test_that("a connection that fails after the check passes adds no results field", {
  # The check passes, but nothing listens on port 1, so the request itself
  # fails to connect, as it would for a server that stops mid-request.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  cnd <- expect_error(
    lms_chat_batch(
      "a-model",
      batch_inputs,
      host = "http://127.0.0.1:1",
      quiet = TRUE,
      api_type = "openai"
    ),
    class = "httr2_failure"
  )
  expect_false("results" %in% names(cnd))
})

# Stub lms_chat() so that its second call raises `cnd`. The stub counts its
# calls, because a stub that failed the test by raising would itself be
# caught by the tryCatch() below (LESSONS, M015).
test_that("an error of any other class still aborts the batch unchanged", {
  raised <- list(
    plain = simpleError("a plain R error"),
    other_class = structure(
      class = c("some_other_error", "rlang_error", "error", "condition"),
      list(message = "an error from elsewhere", trace = NULL, parent = NULL)
    )
  )
  for (name in names(raised)) {
    calls <- 0L
    testthat::local_mocked_bindings(
      is_server_running = function(...) TRUE,
      lms_chat = function(...) {
        calls <<- calls + 1L
        if (calls == 2L) {
          stop(raised[[name]])
        }
        "a reply"
      }
    )
    # tryCatch() rather than expect_error(), which adds a backtrace to the
    # condition it catches and so would never return the one raised.
    caught <- tryCatch(
      lms_chat_batch("a-model", batch_inputs, format = "list", quiet = TRUE),
      error = identity
    )
    expect_identical(caught, raised[[name]], info = name)
    expect_identical(calls, 2L, info = name)
  }
})

# Run a two-input batch whose first reply reads as "reply 1" and whose second
# is `body`. Returns the result and the warnings.
run_unreadable_batch <- function(ok, body, format, api_type, logprobs = FALSE) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(ok, mock_response(200L, body)))
  args <- list(
    "a-model",
    c("first", "second"),
    format = format,
    quiet = TRUE,
    api_type = api_type
  )
  if (logprobs) {
    args$logprobs <- TRUE
  }
  warnings <- testthat::capture_warnings(out <- do.call(lms_chat_batch, args))
  list(out = out, warnings = warnings)
}

test_that("a reply with no readable text fails only its own input on every route", {
  routes <- list(
    native = list(
      ok = mock_response(200L, output_body(native_message(quoted("reply 1")))),
      bodies = native_unreadable()
    ),
    openresponses = list(
      ok = openresponses_ok(1L),
      bodies = responses_unreadable()
    ),
    openai = list(
      ok = openai_ok(1L),
      bodies = lapply(openai_unreadable(), `[[`, "body")
    )
  )
  for (api_type in names(routes)) {
    route <- routes[[api_type]]
    for (label in names(route$bodies)) {
      for (format in c("list", "vector", "data.frame")) {
        info <- paste(api_type, format, label)
        res <- run_unreadable_batch(route$ok, route$bodies[[label]], format, api_type)
        expect_identical(length(res$warnings), 1L, info = info)
        expect_match(res$warnings[[1]], "1 input failed, at position 2\\.", info = info)
        if (format == "list") {
          expect_identical(length(res$out), 2L, info = info)
          expect_identical(res$out[[1]], "reply 1", info = info)
          expect_failed_slot(res$out[[2]], "rlmstudio_bad_response", info = info)
        } else if (format == "vector") {
          expect_identical(res$out, c("reply 1", NA), info = info)
        } else {
          expect_identical(res$out$output, c("reply 1", NA), info = info)
        }
      }
    }
  }
})

test_that("an OpenAI reply with null content fails its input in a logprobs data frame", {
  res <- run_unreadable_batch(
    openai_ok(1L),
    completion_body("null"),
    "data.frame",
    "openai",
    logprobs = TRUE
  )
  expect_length(res$warnings, 1L)
  expect_match(res$warnings[[1]], "1 input failed, at position 2\\.")
  expect_identical(res$out$output, c("reply 1", NA))
  expect_identical(res$out$logprobs, list(NULL, NULL))
})

test_that("a reply that breaks a logprobs rule fails only its own input", {
  bad <- mock_response(
    200L,
    output_body(responses_message(output_text(quoted("reply 2"), "[5]")))
  )
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    openresponses_ok(1L, logprobs = TRUE),
    bad,
    openresponses_ok(3L, logprobs = TRUE)
  ))
  warnings <- testthat::capture_warnings(
    out <- lms_chat_batch(
      "a-model",
      batch_inputs,
      format = "list",
      quiet = TRUE,
      api_type = "openresponses",
      logprobs = TRUE
    )
  )
  expect_length(warnings, 1L)
  expect_match(warnings[[1]], "1 input failed, at position 2\\.")
  expect_length(out, 3L)
  for (i in c(1L, 3L)) {
    expect_s3_class(out[[i]], "lms_chat_result")
    expect_identical(out[[i]]$text, sprintf("reply %d", i), info = i)
    expect_identical(out[[i]]$logprobs$step_token, "r", info = i)
  }
  expect_failed_slot(out[[2]], "rlmstudio_bad_response")
  expect_match(
    conditionMessage(out[[2]]),
    "A step in the `logprobs` of an `output_text` part is not a JSON object.",
    fixed = TRUE
  )
})
