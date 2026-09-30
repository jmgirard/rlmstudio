# Extracted from test-bare-body.R:34

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
      if (api_type == "openai") {
        # Every OpenAI condition carries these two fields, NULL here.
        expect_true(all(c("content", "finish_reason") %in% names(cnd)), info = info)
        expect_null(cnd$content)
        expect_null(cnd$finish_reason)
      }
    }
  }
