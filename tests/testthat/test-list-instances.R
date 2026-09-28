# `list_instances()` reads the model list and returns one row per loaded
# instance. The server is mocked through the shared recorder (D-004), and the
# bodies are built as JSON text with the helpers in `helper-json-forms.R`.

# One model entry as JSON text. `instances` is a character vector of instance
# objects, and `display_name` is a JSON literal, so a test can drop or change it.
instances_model <- function(
  type = "llm",
  key = "m",
  display_name = '"M"',
  instances = character(),
  drop = NULL
) {
  shape_object(
    c(
      type = paste0('"', type, '"'),
      key = paste0('"', key, '"'),
      display_name = display_name,
      size_bytes = "1073741824",
      loaded_instances = shape_array(instances)
    ),
    drop = drop
  )
}

# One loaded instance as JSON text. `config` is a JSON literal, or NULL to
# leave the field out.
instance_json <- function(id, config = NULL) {
  fields <- c(id = paste0('"', id, '"'))
  if (!is.null(config)) {
    fields <- c(fields, config = config)
  }
  shape_object(fields)
}

instances_body <- function(models) shape_object(c(models = shape_array(models)))

# Run `list_instances()` against one mocked reply and return the value and the
# requests it sent.
run_list_instances <- function(body, ..., .env = parent.frame()) {
  local_mocked_bindings(is_server_running = function(...) TRUE, .env = .env)
  recorder <- local_request_recorder(mock_response(200L, body), .env = .env)
  value <- list_instances(...)
  list(value = value, requests = recorder$requests)
}

fixed_columns <- c("id", "key", "type", "display_name")

# Four models. The first has two instances that share an id. The second has
# none. The third has an instance and a type outside the default `type`. The
# fourth has one instance and the key of the first.
four_models <- instances_body(c(
  instances_model(
    "llm", "m1", '"Model One"',
    c(instance_json("i1"), instance_json("i1"))
  ),
  instances_model("embedding", "m2", '"Model Two"'),
  instances_model("other", "m3", '"Model Three"', instance_json("i3")),
  instances_model("embedding", "m1", '"Model Four"', instance_json("i4"))
))

test_that("list_instances returns one row per loaded instance of a listed type", {
  got <- run_list_instances(four_models, quiet = TRUE)
  res <- got$value

  expect_length(got$requests, 1L)
  target <- request_target(got$requests[[1]])
  expect_equal(target$method, "GET")
  expect_equal(target$path, "/api/v1/models")

  expect_s3_class(res, "data.frame")
  expect_identical(names(res), fixed_columns)
  expect_identical(res$id, c("i1", "i1", "i4"))
  expect_identical(res$key, c("m1", "m1", "m1"))
  expect_identical(res$type, c("llm", "llm", "embedding"))
  expect_identical(res$display_name, c("Model One", "Model One", "Model Four"))
})

test_that("list_instances keeps only the models whose type is in `type`", {
  res <- run_list_instances(four_models, type = "other", quiet = TRUE)$value
  expect_identical(res$id, "i3")
  expect_identical(res$key, "m3")
  expect_identical(res$type, "other")
  expect_identical(res$display_name, "Model Three")

  res <- run_list_instances(
    four_models,
    type = c("embedding", "other"),
    quiet = TRUE
  )$value
  expect_identical(res$id, c("i3", "i4"))
  expect_identical(res$type, c("other", "embedding"))
})

test_that("list_instances returns the visible frame when it finds an instance", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, four_models))
  expect_visible(list_instances(quiet = TRUE))
})

# The three bodies that hold no instance to return.
empty_cases <- list(
  "no models" = instances_body(character()),
  "no instances" = instances_body(c(
    instances_model("llm", "m1"),
    instances_model("embedding", "m2")
  )),
  "no instance of a listed type" = instances_body(c(
    instances_model("llm", "m1"),
    instances_model("other", "m3", instances = instance_json("i3"))
  ))
)

expect_empty_instances <- function(res) {
  expect_s3_class(res, "data.frame")
  expect_identical(nrow(res), 0L)
  expect_identical(names(res), fixed_columns)
  for (column in fixed_columns) {
    expect_identical(res[[column]], character(), info = column)
  }
}

test_that("list_instances returns an empty frame and a message with no instance", {
  withr::local_options(rlmstudio.quiet = NULL)
  for (label in names(empty_cases)) {
    local_mocked_bindings(is_server_running = function(...) TRUE)
    local_request_recorder(mock_response(200L, empty_cases[[label]]))

    expect_message(
      value <- withVisible(list_instances()),
      "No loaded model instances",
      info = label
    )
    expect_false(value$visible, info = label)
    expect_empty_instances(value$value)
  }
})

test_that("quiet = TRUE and the rlmstudio.quiet option each stop the message", {
  for (label in names(empty_cases)) {
    local_mocked_bindings(is_server_running = function(...) TRUE)
    local_request_recorder(mock_response(200L, empty_cases[[label]]))

    withr::with_options(list(rlmstudio.quiet = NULL), {
      expect_no_message(res <- list_instances(quiet = TRUE))
      expect_empty_instances(res)
    })
    withr::with_options(list(rlmstudio.quiet = TRUE), {
      expect_no_message(res <- list_instances())
      expect_empty_instances(res)
    })
  }
})
