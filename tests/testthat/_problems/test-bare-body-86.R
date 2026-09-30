# Extracted from test-bare-body.R:86

# prequel ----------------------------------------------------------------------
bare_single <- list(
  native = function(...) lms_chat_native("a-model", "hi", ...),
  openresponses = function(...) lms_chat_openresponses("a-model", "hi", ...),
  openai = function(...) {
    lms_chat_openai("a-model", list(list(role = "user", content = "hi")), ...)
  }
)
null_details <- c(
  native = "The response holds no `output` array of reply items.",
  openresponses = "The response holds no `output` array of reply items.",
  openai = "The response holds no readable reply in its `choices` field."
)
bare_ok <- list(
  native = function(text) output_body(native_message(quoted(text))),
  openresponses = function(text) output_body(responses_message(output_text(quoted(text)))),
  openai = function(text) completion_body(quoted(text))
)

# test -------------------------------------------------------------------------
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
          detail <- if (kind == "null") {
            null_details[[api_type]]
          } else {
            "The response body is not a JSON object."
          }
          expect_match(conditionMessage(got[[2]]), detail, fixed = TRUE, info = info)
          expect_identical(got[[3]], "reply 3", info = info)
        } else {
          expect_identical(got, c("reply 1", NA, "reply 3"), info = info)
        }
      }
    }
  }
