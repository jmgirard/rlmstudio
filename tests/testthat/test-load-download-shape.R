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

# Run each body through `call` and return the list of return values, or of
# conditions for a call that raised, named by case.
shape_results <- function(bodies, call) {
  lapply(bodies, function(body) {
    local_request_sequence(list(mock_response(200L, body)))
    tryCatch(call(), error = identity)
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

# lms_download() ---------------------------------------------------------------

download_fields <- c(job_id = '"job-1"', status = '"downloading"')
download_call <- function() lms_download("a-model")

test_that("each rule of the download reply aborts lms_download() with rlmstudio_bad_response", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  cases <- c(
    top_level_faults(),
    required_field_faults(download_fields, "status", "string"),
    # With `status` "downloading", `job_id` must be a string.
    required_field_faults(download_fields, "job_id", "string")
  )
  expect_shape_faults(cases, download_call, "API Download Failed")
})

test_that("a download reply that passes the rules returns the job id or already_downloaded", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)

  local_request_sequence(list(mock_response(200L, shape_object(download_fields))))
  result <- withVisible(download_call())
  expect_identical(result$value, "job-1")
  expect_true(result$visible)

  # With `status` "already_downloaded", `job_id` is not read.
  already <- list(
    "no job_id" = '{"status": "already_downloaded"}',
    "job_id as number" = '{"status": "already_downloaded", "job_id": 1}'
  )
  for (label in names(already)) {
    local_request_sequence(list(mock_response(200L, already[[label]])))
    result <- withVisible(download_call())
    expect_identical(result$value, "already_downloaded", info = label)
    expect_false(result$visible, info = label)
  }
})

test_that("the LM Studio docs example of the download reply reads", {
  # The "Response" block of lmstudio-ai/docs 1_developer/2_rest/download.md,
  # as of commit 2e643a417b.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  local_request_sequence(list(mock_response(200L, docs_example("download-docs-example.json"))))
  expect_identical(download_call(), "job_493c7c9ded")
})

# lms_download_status() -------------------------------------------------------

status_fields <- c(
  job_id = '"job-1"',
  status = '"downloading"',
  total_size_bytes = "100",
  downloaded_bytes = "50",
  bytes_per_second = "10"
)
status_call <- function() lms_download_status("job-1")
number_fields <- c("total_size_bytes", "downloaded_bytes", "bytes_per_second")

test_that("each rule of the status reply aborts lms_download_status() with rlmstudio_bad_response", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  cases <- c(
    top_level_faults(),
    required_field_faults(status_fields, "job_id", "string"),
    required_field_faults(status_fields, "status", "string")
  )
  for (field in number_fields) {
    cases <- c(cases, optional_field_cases(status_fields, field, "number")$faults)
  }
  expect_shape_faults(cases, status_call, "API Status Request Failed")
})

test_that("a status reply that passes the rules returns its fields", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  bodies <- list("all fields" = shape_object(status_fields))
  for (field in number_fields) {
    bodies <- c(bodies, optional_field_cases(status_fields, field, "number")$passes)
  }
  results <- shape_results(bodies, status_call)
  for (label in names(results)) {
    result <- results[[label]]
    expect_true(inherits(result, "lms_download_status"), info = label)
    expect_identical(result[["job_id"]], "job-1", info = label)
    expect_identical(result[["status"]], "downloading", info = label)
  }
})

test_that("print() reads each number field by its exact name", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  for (field in number_fields) {
    # The field itself is absent, and a field whose name extends it holds a
    # string. A read by `$` matches the extended name and fails on the string.
    fields <- replace(status_fields, field, '"a"')
    body <- shape_object(fields, extend = field)
    local_request_sequence(list(mock_response(200L, body)))
    status <- status_call()
    expect_null(status[[field]], info = field)
    result <- shape_raised_by(suppressMessages(print(status)))
    expect_null(result, info = field)
  }
})

test_that("print() shows the status text and does not run it", {
  # Run as code, the status would print as "2".
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  body <- shape_object(replace(status_fields, "status", '"{1 + 1}"'))
  local_request_sequence(list(mock_response(200L, body)))
  status <- status_call()
  printed <- paste(capture_messages(print(status)), collapse = "")
  expect_match(printed, "Status: {1 + 1}", fixed = TRUE)
})

test_that("the LM Studio docs example of the status reply reads and prints", {
  # The "Response" block of lmstudio-ai/docs
  # 1_developer/2_rest/download-status.md, as of commit 2e643a417b.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    mock_response(200L, docs_example("download-status-docs-example.json"))
  ))
  status <- status_call()
  expect_s3_class(status, "lms_download_status")
  expect_identical(
    unclass(status),
    list(
      job_id = "job_493c7c9ded",
      status = "completed",
      total_size_bytes = 2279145003,
      downloaded_bytes = 2279145003,
      started_at = "2025-10-03T15:33:23.496Z",
      completed_at = "2025-10-03T15:43:12.102Z"
    )
  )
  printed <- paste(capture_messages(print(status)), collapse = "")
  expect_match(printed, "Progress: 100%", fixed = TRUE)
})
