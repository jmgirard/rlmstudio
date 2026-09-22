# A 200 chat body that is a bare JSON value, such as `5`, on each route. The
# server is mocked through the shared recorder (D-004).

# The single-call function of each route, called with one input.
bare_single <- list(
  native = function(...) lms_chat_native("a-model", "hi", ...),
  openresponses = function(...) lms_chat_openresponses("a-model", "hi", ...),
  openai = function(...) {
    lms_chat_openai("a-model", list(list(role = "user", content = "hi")), ...)
  }
)

# The message each route gives a `null` body today, which the new check leaves
# alone.
null_details <- c(
  native = "The response holds no `output` array of reply items.",
  openresponses = "The response holds no `output` array of reply items.",
  openai = "The response holds no readable reply in its `choices` field."
)

# A reply that reads as `text` on each route.
bare_ok <- list(
  native = function(text) output_body(native_message(quoted(text))),
  openresponses = function(text) output_body(responses_message(output_text(quoted(text)))),
  openai = function(text) completion_body(quoted(text))
)

test_that("a bare-value body raises rlmstudio_bad_response on every route", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  for (api_type in names(bare_single)) {
    for (kind in names(bare_bodies)) {
      info <- paste(api_type, kind)
      local_request_sequence(list(mock_response(200L, bare_bodies[[kind]])))
      cnd <- expect_error(bare_single[[api_type]](), class = "rlmstudio_bad_response")
      detail <- if (kind == "null") {
        null_details[[api_type]]
      } else {
        "The response body is not a JSON object."
      }
      expect_match(conditionMessage(cnd), detail, fixed = TRUE, info = info)
      expect_identical(cnd$status, 200L, info = info)
      if (kind != "null") {
        expect_no_match(conditionMessage(cnd), "subscript", info = info)
      }
    }
  }
})

test_that("a bare-value body comes back unchanged with simplify = FALSE", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  parsed <- list(number = 5L, string = "s", boolean = TRUE, null = NULL)
  for (api_type in names(bare_single)) {
    for (kind in names(bare_bodies)) {
      local_request_sequence(list(mock_response(200L, bare_bodies[[kind]])))
      out <- bare_single[[api_type]](simplify = FALSE)
      expect_identical(out, parsed[[kind]], info = paste(api_type, kind))
    }
  }
})

test_that("a bare-value body fails only its own input in every batch format", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  for (api_type in names(bare_single)) {
    for (kind in names(bare_bodies)) {
      for (format in c("vector", "list", "data.frame")) {
        info <- paste(api_type, kind, format)
        recorder <- local_request_sequence(list(
          mock_response(200L, bare_ok[[api_type]]("reply 1")),
          mock_response(200L, bare_bodies[[kind]]),
          mock_response(200L, bare_ok[[api_type]]("reply 3"))
        ))
        warnings <- testthat::capture_warnings(
          out <- lms_chat_batch(
            "a-model",
            c("a", "b", "c"),
            format = format,
            quiet = TRUE,
            api_type = api_type
          )
        )
        expect_identical(length(recorder$requests), 3L, info = info)
        expect_identical(length(warnings), 1L, info = info)
        expect_match(warnings, "1 input failed, at position 2\\.", info = info)
        got <- switch(
          format,
          vector = out,
          list = out,
          data.frame = out$output
        )
        if (format == "list") {
          expect_identical(got[[1]], "reply 1", info = info)
          expect_s3_class(got[[2]], "rlmstudio_bad_response")
          expect_identical(got[[3]], "reply 3", info = info)
        } else {
          expect_identical(got, c("reply 1", NA, "reply 3"), info = info)
        }
      }
    }
  }
})
