# A status-200 reply of `lms_load()`, `lms_download()`, or
# `lms_download_status()` is read only when it has the shape that the function
# reads. Any other shape aborts with `rlmstudio_bad_response`. The bodies here
# are built as JSON text with the helpers in `helper-json-forms.R`. The server
# is mocked through the shared recorder (D-004).

# The body as each JSON form other than an object. Each function rejects all of
# them.
top_level_faults <- function() {
  forms <- setdiff(names(json_forms), c("empty object", "object"))
  cases <- lapply(forms, function(form) {
    list(label = paste("body as", form), body = json_forms[[form]], names = "not a JSON object")
  })
  cases
}

# The faults of one field that a rule requires. `ok_forms` names the JSON forms
# that the rule accepts. Every other form, the field absent, and the field under
# an extended name is a fault.
required_field_faults <- function(fields, field, ok_forms, extra = character(0)) {
  name <- paste0("`", field, "`")
  cases <- list(
    list(label = paste(field, "absent"), body = shape_object(fields, drop = field), names = name),
    list(label = paste(field, "extended"), body = shape_object(fields, extend = field), names = name)
  )
  for (form in setdiff(names(json_forms), ok_forms)) {
    cases[[length(cases) + 1L]] <- list(
      label = paste(field, "as", form),
      body = shape_object(replace(fields, field, json_forms[[form]])),
      names = name
    )
  }
  for (label in names(extra)) {
    cases[[length(cases) + 1L]] <- list(
      label = paste(field, "as", label),
      body = shape_object(replace(fields, field, extra[[label]])),
      names = name
    )
  }
  cases
}

# The faults and passes of one field that a rule lets be absent or `null`. The
# field absent, `null`, and under an extended name pass. Every other form but
# `ok_forms` is a fault.
optional_field_cases <- function(fields, field, ok_forms) {
  name <- paste0("`", field, "`")
  faults <- list()
  for (form in setdiff(names(json_forms), c(ok_forms, "null"))) {
    faults[[length(faults) + 1L]] <- list(
      label = paste(field, "as", form),
      body = shape_object(replace(fields, field, json_forms[[form]])),
      names = name
    )
  }
  passes <- list(
    shape_object(fields, drop = field),
    shape_object(replace(fields, field, "null")),
    shape_object(fields, extend = field)
  )
  names(passes) <- paste(field, c("absent", "null", "extended"))
  list(faults = faults, passes = passes)
}

# Run each fault case through `call` and check the condition it raises.
expect_shape_faults <- function(cases, call, label) {
  for (case in cases) {
    local_request_sequence(list(mock_response(200L, case$body)))
    cnd <- shape_raised_by(call())
    expect_true(inherits(cnd, "rlmstudio_bad_response"), info = case$label)
    if (!inherits(cnd, "rlmstudio_bad_response")) next
    expect_identical(cnd$status, 200L, info = case$label)
    message <- conditionMessage(cnd)
    first_line <- strsplit(message, "\n", fixed = TRUE)[[1]][[1]]
    expect_match(first_line, label, fixed = TRUE, info = case$label)
    for (text in case$names) {
      expect_match(message, text, fixed = TRUE, info = case$label)
    }
    expect_no_match(message, "simplify", fixed = TRUE, info = case$label)
  }
}

# Run each body through `call` and return the list of results, named by case.
shape_results <- function(bodies, call) {
  lapply(bodies, function(body) {
    local_request_sequence(list(mock_response(200L, body)))
    shape_raised_by(call())
  })
}

docs_example <- function(name) {
  paste(readLines(test_path("fixtures", name)), collapse = "\n")
}

# lms_load() ------------------------------------------------------------------

load_fields <- c(status = '"loaded"', load_config = '{"context_length": 4096}')
load_call <- function(echo = FALSE) {
  function() lms_load("a-model", echo_load_config = echo, force = TRUE)
}

test_that("each rule of the load reply aborts lms_load() with rlmstudio_bad_response", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)

  # `status` must be the string "loaded", so every JSON form is a fault.
  status_faults <- required_field_faults(
    load_fields, "status", character(0),
    extra = c('"pending"' = '"pending"', '"Loaded"' = '"Loaded"')
  )
  for (echo in c(FALSE, TRUE)) {
    expect_shape_faults(c(top_level_faults(), status_faults), load_call(echo), "API Load Failed")
  }

  # With `echo_load_config = TRUE`, `load_config` must be a JSON object.
  config_faults <- required_field_faults(
    load_fields, "load_config", c("empty object", "object")
  )
  expect_shape_faults(config_faults, load_call(TRUE), "API Load Failed")
})

test_that("a load reply that passes the rules returns the model or the config", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)

  # Without the echo, `load_config` is not read, so any form of it passes.
  bodies <- c(
    list(
      "load_config absent" = shape_object(load_fields, drop = "load_config"),
      "load_config extended" = shape_object(load_fields, extend = "load_config")
    ),
    lapply(json_forms, function(form) shape_object(replace(load_fields, "load_config", form)))
  )
  for (label in names(bodies)) {
    local_request_sequence(list(mock_response(200L, bodies[[label]])))
    result <- withVisible(load_call(FALSE)())
    expect_identical(result$value, "a-model", info = label)
    expect_false(result$visible, info = label)
  }

  for (form in c("empty object", "object")) {
    body <- shape_object(replace(load_fields, "load_config", json_forms[[form]]))
    local_request_sequence(list(mock_response(200L, body)))
    result <- withVisible(load_call(TRUE)())
    expected <- jsonlite::parse_json(json_forms[[form]])
    expect_identical(result$value, expected, info = form)
    expect_false(result$visible, info = form)
  }
})

test_that("the LM Studio docs example of the load reply reads", {
  # The "Response" block of lmstudio-ai/docs 1_developer/2_rest/load.md, as of
  # commit 2e643a417b.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  body <- docs_example("load-docs-example.json")

  local_request_sequence(list(mock_response(200L, body)))
  expect_identical(load_call(FALSE)(), "a-model")

  local_request_sequence(list(mock_response(200L, body)))
  expect_identical(
    load_call(TRUE)(),
    list(
      context_length = 16384L,
      eval_batch_size = 512L,
      flash_attention = TRUE,
      offload_kv_cache_to_gpu = TRUE,
      num_experts = 4L
    )
  )
})
