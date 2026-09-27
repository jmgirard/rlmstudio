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

# A bare `{}`, the example on the help page. It is a JSON object, so the
# message names the first field that the rule requires.
empty_body_fault <- function(field) {
  list(list(label = "body as {}", body = "{}", names = paste0("`", field, "`")))
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
    expect_shape_faults(
      c(top_level_faults(), empty_body_fault("status"), status_faults),
      load_call(echo),
      "API Load Failed"
    )
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
    empty_body_fault("status"),
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

test_that("a download reply with status failed aborts with rlmstudio_bad_response", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  # The failed check comes before the job id rule, so a reply whose job id
  # breaks that rule still gets the failed message. The message names a job id
  # only when it holds a character that is not whitespace.
  cases <- list(
    "job_id job-1" = list(job_id = '"job-1"', named = '"job-1"'),
    "job_id with braces" = list(job_id = '"{1 + 1}"', named = '"{1 + 1}"'),
    "job_id absent" = list(job_id = NULL, named = NULL),
    "job_id as number" = list(job_id = "1", named = NULL),
    "job_id empty" = list(job_id = '""', named = NULL),
    "job_id blank" = list(job_id = '" \\t"', named = NULL)
  )
  for (label in names(cases)) {
    case <- cases[[label]]
    fields <- c(status = '"failed"', job_id = case$job_id)
    local_request_sequence(list(mock_response(200L, shape_object(fields))))
    cnd <- shape_raised_by(download_call())
    expect_true(inherits(cnd, "rlmstudio_bad_response"), info = label)
    if (!inherits(cnd, "rlmstudio_bad_response")) next
    expect_identical(cnd$status, 200L, info = label)
    message <- conditionMessage(cnd)
    expect_match(message, "API Download Failed", fixed = TRUE, info = label)
    expect_match(
      message,
      "LM Studio reports that the download failed",
      fixed = TRUE,
      info = label
    )
    expect_no_match(message, "Something other than LM Studio", fixed = TRUE, info = label)
    expect_no_match(message, "is not a string", fixed = TRUE, info = label)
    if (is.null(case$named)) {
      expect_no_match(message, "Job ID", fixed = TRUE, info = label)
    } else {
      expect_match(message, paste("Job ID:", case$named), fixed = TRUE, info = label)
    }
  }
})

test_that("a blank job_id aborts lms_download() with rlmstudio_bad_response", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  blanks <- c('""', '" "', '"\\t"', '"\\n"', '" \\t\\n"')
  cases <- list()
  for (status in c('"downloading"', '"paused"', '"queued"')) {
    for (blank in blanks) {
      cases[[length(cases) + 1L]] <- list(
        label = paste("status", status, "job_id", blank),
        body = shape_object(c(status = status, job_id = blank)),
        names = "`job_id` is a string with no character that is not whitespace"
      )
    }
  }
  expect_shape_faults(cases, download_call, "API Download Failed")
})

test_that("each status but already_downloaded and failed returns the job id", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  # "queued" is a status the LM Studio docs do not list.
  for (status in c("downloading", "paused", "completed", "queued")) {
    body <- shape_object(c(status = paste0('"', status, '"'), job_id = '"job-1"'))
    local_request_sequence(list(mock_response(200L, body)))
    result <- withVisible(download_call())
    expect_identical(result$value, "job-1", info = status)
    expect_true(result$visible, info = status)
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
    empty_body_fault("job_id"),
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

test_that("print() shows progress and speed only for finite numbers above 0", {
  # jsonlite reads 1e400 as Inf. Each case lists total, downloaded, and speed,
  # then whether the Progress and Speed lines appear.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  cases <- list(
    "both sizes 0" = list(c("0", "0", "10"), progress = FALSE, speed = TRUE),
    "total 1e400" = list(c("1e400", "50", "10"), progress = FALSE, speed = TRUE),
    "downloaded 1e400" = list(c("100", "1e400", "10"), progress = FALSE, speed = TRUE),
    "total -1" = list(c("-1", "50", "10"), progress = FALSE, speed = TRUE),
    # Finite and above 0, but the downloaded size is above the total.
    "total 1e-300" = list(c("1e-300", "1e10", "10"), progress = FALSE, speed = TRUE),
    "speed 1e400" = list(c("100", "50", "1e400"), progress = TRUE, speed = FALSE),
    "speed 0" = list(c("100", "50", "0"), progress = TRUE, speed = FALSE),
    "speed -1" = list(c("100", "50", "-1"), progress = TRUE, speed = FALSE),
    "all finite and positive" = list(c("100", "50", "10"), progress = TRUE, speed = TRUE)
  )
  for (label in names(cases)) {
    case <- cases[[label]]
    fields <- replace(status_fields, number_fields, case[[1]])
    local_request_sequence(list(mock_response(200L, shape_object(fields))))
    status <- status_call()
    printed <- paste(capture_messages(print(status)), collapse = "")
    expect_identical(grepl("Progress:", printed, fixed = TRUE), case$progress, info = label)
    expect_identical(grepl("Speed:", printed, fixed = TRUE), case$speed, info = label)
    expect_no_match(printed, "NaN", fixed = TRUE, info = label)
    expect_no_match(printed, "Inf", fixed = TRUE, info = label)
  }
})

# Prints a status reply with the three number fields set to the given JSON
# numbers, and returns the printed text as one string.
print_status_numbers <- function(total, downloaded, speed) {
  fields <- replace(status_fields, number_fields, c(total, downloaded, speed))
  local_request_sequence(list(mock_response(200L, shape_object(fields))))
  paste(capture_messages(print(status_call())), collapse = "")
}

test_that("print() shows progress only for a downloaded size from 0 to the total", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  expect_no_match(print_status_numbers("100", "-1", "10"), "Progress:", fixed = TRUE)
  expect_no_match(print_status_numbers("100", "101", "10"), "Progress:", fixed = TRUE)
  expect_match(
    print_status_numbers("100", "0", "10"),
    "Progress: 0% (0 B / 100 B)",
    fixed = TRUE
  )
  expect_match(
    print_status_numbers("100", "100", "10"),
    "Progress: 100% (100 B / 100 B)",
    fixed = TRUE
  )
})

test_that("print() shows sizes and speed in a unit that keeps the value at 1 or more", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  speeds <- c(
    "1e-9" = "Speed: 1e-09 B/s",
    # A subnormal number, which signif() alone prints at full length.
    "5e-324" = "Speed: 4.94e-324 B/s",
    "1023" = "Speed: 1020 B/s",
    "1024" = "Speed: 1 KB/s",
    "1536" = "Speed: 1.5 KB/s",
    "1234567" = "Speed: 1.18 MB/s",
    "5242880" = "Speed: 5 MB/s",
    # 1024^4 is 1 TB, and 1024^5 stays in TB, the largest unit.
    "1099511627776" = "Speed: 1 TB/s",
    "1125899906842624" = "Speed: 1020 TB/s"
  )
  for (speed in names(speeds)) {
    expect_match(
      print_status_numbers("100", "50", speed),
      speeds[[speed]],
      fixed = TRUE,
      info = speed
    )
  }
  expect_match(
    print_status_numbers("100", "50", "10"),
    "Progress: 50% (50 B / 100 B)",
    fixed = TRUE
  )
})

test_that("print() rounds the percentage down to one decimal", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  cases <- list(
    list(c("10000", "9996"), "Progress: 99.9% "),
    list(c("100", "29"), "Progress: 29% "),
    list(c("3", "1"), "Progress: 33.3% "),
    list(c("10000", "10000"), "Progress: 100% ")
  )
  for (case in cases) {
    sizes <- case[[1]]
    expect_match(
      print_status_numbers(sizes[[1]], sizes[[2]], "10"),
      case[[2]],
      fixed = TRUE,
      info = paste(sizes[[2]], "of", sizes[[1]])
    )
  }
})

test_that("a status reply with status failed returns and prints", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  body <- shape_object(replace(status_fields, "status", '"failed"'))
  local_request_sequence(list(mock_response(200L, body)))
  status <- status_call()
  expect_s3_class(status, "lms_download_status")
  expect_identical(status[["status"]], "failed")
  printed <- paste(capture_messages(print(status)), collapse = "")
  expect_match(printed, "Status: failed", fixed = TRUE)
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
  expect_match(printed, "Progress: 100% (2.12 GB / 2.12 GB)", fixed = TRUE)
})
