# A status-200 model list is read only when it has the shape that the package
# reads. `list_models()` aborts with `rlmstudio_bad_response` on any other
# shape, and `lms_server_ready()` reports FALSE for it. Both apply the rules in
# `model_list_fault()`. The bodies here are built as JSON text, so each fault
# keeps the exact JSON form under test. The server is mocked through the shared
# recorder (D-004).

# JSON literals, one per form a field can take.
json_forms <- c(
  number = "1",
  string = '"a"',
  boolean = "true",
  "empty array" = "[]",
  array = '["a"]',
  "empty object" = "{}",
  object = '{"a": 1}',
  null = "null"
)

# Build a JSON object from a named character vector of JSON literals. `drop`
# leaves a field out. `extend` writes the field under its name plus "X".
json_object <- function(fields, drop = NULL, extend = NULL) {
  keys <- names(fields)
  keys[keys %in% extend] <- paste0(keys[keys %in% extend], "X")
  keep <- !names(fields) %in% drop
  if (!any(keep)) {
    return("{}")
  }
  paste0(
    "{",
    paste0('"', keys[keep], '": ', fields[keep], collapse = ", "),
    "}"
  )
}

json_array <- function(items) paste0("[", paste(items, collapse = ", "), "]")

instance_fields <- c(id = '"inst-1"')
valid_instance <- json_object(instance_fields)

model_fields <- function(type = '"llm"', key = '"m"', instances = "[]") {
  c(
    type = type,
    key = key,
    display_name = '"M"',
    size_bytes = "1073741824",
    loaded_instances = instances
  )
}
valid_model <- json_object(model_fields())
loaded_model <- json_object(model_fields(instances = json_array(valid_instance)))

list_body <- function(models) json_object(c(models = json_array(models)))

# The three places an entry fault sits: the only entry, the first of two
# entries, and the second after a valid entry.
entry_places <- function(bad, good) {
  list(
    "only entry" = bad,
    "first of two" = c(bad, good),
    "second of two" = c(good, bad)
  )
}

# Every fault body, as a list of cases. Each case holds the body, the text the
# message must name, and a label.
fault_cases <- function() {
  cases <- list()
  add <- function(label, body, names) {
    cases[[length(cases) + 1L]] <<- list(label = label, body = body, names = names)
  }

  # The body itself, as each JSON form other than an object.
  for (form in setdiff(names(json_forms), c("empty object", "object"))) {
    add(paste("body as", form), json_forms[[form]], "not a JSON object")
  }

  # L1: `models` must be an array.
  top <- c(models = json_array(valid_model))
  add("models absent", json_object(top, drop = "models"), "`models`")
  add("models extended", json_object(top, extend = "models"), "`models`")
  for (form in setdiff(names(json_forms), c("empty array", "array"))) {
    add(paste("models as", form), json_object(c(models = json_forms[[form]])), "`models`")
  }

  # L2 and L3: the fields of a model entry, in each of the three places.
  model_faults <- list()
  for (field in c("type", "key")) {
    model_faults[[paste(field, "absent")]] <- list(json_object(model_fields(), drop = field), field)
    model_faults[[paste(field, "extended")]] <- list(json_object(model_fields(), extend = field), field)
    for (form in setdiff(names(json_forms), "string")) {
      fields <- model_fields()
      fields[[field]] <- json_forms[[form]]
      model_faults[[paste(field, "as", form)]] <- list(json_object(fields), field)
    }
  }
  field <- "loaded_instances"
  model_faults[[paste(field, "absent")]] <- list(json_object(model_fields(), drop = field), field)
  model_faults[[paste(field, "extended")]] <- list(json_object(model_fields(), extend = field), field)
  for (form in setdiff(names(json_forms), c("empty array", "array"))) {
    model_faults[[paste(field, "as", form)]] <- list(
      json_object(model_fields(instances = json_forms[[form]])), field
    )
  }
  for (form in setdiff(names(json_forms), c("number", "null"))) {
    fields <- model_fields()
    fields[["size_bytes"]] <- json_forms[[form]]
    model_faults[[paste("size_bytes as", form)]] <- list(json_object(fields), "size_bytes")
  }
  for (form in setdiff(names(json_forms), c("empty object", "object"))) {
    model_faults[[paste("model entry as", form)]] <- list(json_forms[[form]], "models")
  }
  for (name in names(model_faults)) {
    fault <- model_faults[[name]]
    places <- entry_places(fault[[1]], valid_model)
    for (place in names(places)) {
      add(
        paste(name, "in", place),
        list_body(places[[place]]),
        paste0("`", fault[[2]], "`")
      )
    }
  }

  # L4: the fields of an instance entry. Each fault sits in three places among
  # the instances, and the model holding it sits in three places among models.
  instance_faults <- list(
    "id absent" = json_object(instance_fields, drop = "id"),
    "id extended" = json_object(instance_fields, extend = "id"),
    "id empty" = json_object(c(id = '""')),
    "id blank" = json_object(c(id = '" "'))
  )
  for (form in setdiff(names(json_forms), "string")) {
    instance_faults[[paste("id as", form)]] <- json_object(c(id = json_forms[[form]]))
  }
  instance_names <- rep("id", length(instance_faults))
  for (form in setdiff(names(json_forms), c("empty object", "object"))) {
    instance_faults[[paste("instance entry as", form)]] <- json_forms[[form]]
    instance_names <- c(instance_names, "loaded_instances")
  }
  for (k in seq_along(instance_faults)) {
    inner <- entry_places(instance_faults[[k]], valid_instance)
    for (inner_place in names(inner)) {
      bad_model <- json_object(model_fields(instances = json_array(inner[[inner_place]])))
      outer <- entry_places(bad_model, loaded_model)
      for (outer_place in names(outer)) {
        add(
          paste(names(instance_faults)[[k]], "in", inner_place, "instance,", outer_place, "model"),
          list_body(outer[[outer_place]]),
          paste0("`", instance_names[[k]], "`")
        )
      }
    }
  }

  cases
}

# Bodies that pass: `size_bytes` absent, `null`, or under an extended name, an
# empty model list, and a list with a loaded model.
pass_cases <- function() {
  list(
    "size_bytes absent" = list_body(json_object(model_fields(), drop = "size_bytes")),
    "size_bytes null" = list_body(json_object(replace(model_fields(), "size_bytes", "null"))),
    "size_bytes extended" = list_body(json_object(model_fields(), extend = "size_bytes")),
    "no models" = list_body(character(0)),
    "one loaded model" = list_body(c(valid_model, loaded_model))
  )
}

# The condition a call raises, or NULL when it returns.
shape_raised_by <- function(expr) {
  tryCatch({
    expr
    NULL
  }, error = identity)
}

test_that("each rule of the model list aborts list_models() with rlmstudio_bad_response", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  for (case in fault_cases()) {
    local_request_sequence(list(mock_response(200L, case$body)))
    cnd <- shape_raised_by(list_models(quiet = TRUE))
    expect_true(inherits(cnd, "rlmstudio_bad_response"), info = case$label)
    if (!inherits(cnd, "rlmstudio_bad_response")) next
    expect_identical(cnd$status, 200L, info = case$label)
    message <- conditionMessage(cnd)
    first_line <- strsplit(message, "\n", fixed = TRUE)[[1]][[1]]
    expect_match(first_line, "API List Failed", fixed = TRUE, info = case$label)
    expect_match(message, case$names, fixed = TRUE, info = case$label)
    expect_no_match(message, "simplify", fixed = TRUE, info = case$label)
  }
})

test_that("a model list that passes the rules returns without error", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  for (label in names(pass_cases())) {
    local_request_sequence(list(mock_response(200L, pass_cases()[[label]])))
    result <- shape_raised_by(list_models(quiet = TRUE))
    expect_null(result, label = label)
  }
})

test_that("a fault in an entry that the filters drop still aborts", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)

  # The bad entry is an embedding model, and the call asks for LLMs only.
  bad_embedding <- json_object(model_fields(type = '"embedding"'), drop = "key")
  local_request_sequence(list(mock_response(200L, list_body(c(loaded_model, bad_embedding)))))
  expect_error(list_models(type = "llm"), class = "rlmstudio_bad_response")

  # The bad entry is not loaded, and the call asks for loaded models only.
  bad_unloaded <- json_object(model_fields(key = "1"))
  local_request_sequence(list(mock_response(200L, list_body(c(loaded_model, bad_unloaded)))))
  expect_error(list_models(loaded = TRUE), class = "rlmstudio_bad_response")
})

test_that("each fault body makes lms_server_ready() report FALSE", {
  for (case in fault_cases()) {
    local_request_sequence(list(mock_response(200L, case$body)))
    expect_identical(lms_server_ready(), FALSE, info = case$label)
  }
  for (label in names(pass_cases())) {
    local_request_sequence(list(mock_response(200L, pass_cases()[[label]])))
    expect_identical(lms_server_ready(), TRUE, info = label)
  }
})

test_that("an empty model list returns an empty data frame and informs", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(mock_response(200L, '{"models": []}')))
  expect_message(
    result <- withVisible(list_models()),
    "No models found on host"
  )
  expect_identical(result$value, data.frame())
  expect_false(result$visible)

  local_request_sequence(list(mock_response(200L, '{"models": []}')))
  expect_no_message(list_models(quiet = TRUE))
})

test_that("the LM Studio docs example of the model list reads as a data frame", {
  # The "Response" block of lmstudio-ai/docs 1_developer/2_rest/list.md, as
  # of commit 2e643a417b.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  body <- paste(readLines(test_path("fixtures", "list-docs-example.json")), collapse = "\n")
  local_request_sequence(list(mock_response(200L, body)))
  result <- list_models(quiet = TRUE)
  expect_identical(
    result$key,
    c(
      "google/gemma-4-26b-a4b",
      "deepseek-r1",
      "text-embedding-nomic-embed-text-v1.5-embedding"
    )
  )
  expect_identical(result$state, c("loaded", "unloaded", "unloaded"))
  expect_identical(result$type, c("llm", "llm", "embedding"))
  expect_identical(result$size_gb, round(c(17990911801, 40492610355, 274290560) / 1024^3, 2))

  local_request_sequence(list(mock_response(200L, body)))
  expect_identical(lms_server_ready(), TRUE)
})

test_that("an empty model list reaches the callers as nothing loaded", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  recorder <- local_request_sequence(list(mock_response(200L, '{"models": []}')))
  expect_message(lms_unload_all(), "No models are currently loaded", fixed = TRUE)
  expect_identical(length(recorder$requests), 1L)

  # With nothing loaded, lms_load() goes on to the load request.
  recorder <- local_request_sequence(list(
    mock_response(200L, '{"models": []}'),
    mock_response(200L, '{"status": "loaded"}')
  ))
  result <- suppressMessages(lms_load("a-model"))
  expect_identical(result, "a-model")
  expect_identical(length(recorder$requests), 2L)
  expect_identical(
    request_target(recorder$requests[[2]])$path,
    "/api/v1/models/load"
  )
})

test_that("a model list with the wrong shape aborts the callers before any other request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  withr::local_options(rlmstudio.quiet = TRUE)
  callers <- list(
    lms_load = function() lms_load("a-model"),
    lms_unload_all = function() lms_unload_all()
  )
  bad_list <- list_body(json_object(model_fields(), drop = "key"))
  for (name in names(callers)) {
    # One response only: a second request raises a plain error from the mock,
    # which is not the class asserted here.
    recorder <- local_request_sequence(list(mock_response(200L, bad_list)))
    cnd <- shape_raised_by(callers[[name]]())
    expect_true(inherits(cnd, "rlmstudio_bad_response"), info = name)
    expect_match(conditionMessage(cnd), "API List Failed", fixed = TRUE, info = name)
    expect_match(conditionMessage(cnd), "`key`", fixed = TRUE, info = name)
    expect_identical(length(recorder$requests), 1L, info = name)
  }
})

test_that("lms_unload_all unloads each instance by its id, in body order", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  unloaded <- character(0)
  testthat::local_mocked_bindings(
    lms_unload = function(model, ...) {
      unloaded <<- c(unloaded, model)
      invisible(model)
    }
  )
  # Each instance carries a decoy field before `id`, so a read of the first
  # field gives the wrong ids.
  two_instances <- json_array(c(
    '{"decoy": "wrong-1", "id": "a-1"}',
    '{"decoy": "wrong-2", "id": "a-2"}'
  ))
  body <- list_body(c(
    json_object(model_fields(key = '"a"', instances = two_instances)),
    valid_model,
    json_object(model_fields(key = '"b"', instances = '[{"id": "b-1"}]'))
  ))
  local_request_sequence(list(mock_response(200L, body)))
  result <- suppressMessages(lms_unload_all())
  expect_identical(unloaded, c("a-1", "a-2", "b-1"))
  expect_identical(result, c("a-1", "a-2", "b-1"))
})
