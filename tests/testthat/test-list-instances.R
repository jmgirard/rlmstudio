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

# Run `list_instances()` over one llm model whose instances carry `configs`,
# JSON literals in instance order. An `NA` leaves the `config` field out.
config_frame <- function(configs, .env = parent.frame()) {
  instances <- vapply(
    seq_along(configs),
    function(i) {
      config <- if (is.na(configs[[i]])) NULL else configs[[i]]
      instance_json(paste0("i", i), config)
    },
    character(1)
  )
  body <- instances_body(instances_model("llm", "m1", instances = instances))
  run_list_instances(body, quiet = TRUE, .env = .env)$value
}

test_that("each configuration field gets a column, in order of first appearance", {
  res <- config_frame(c(
    '{"b": 1, "a": "x"}',
    '{"c": true, "a": "y"}'
  ))
  expect_identical(names(res), c(fixed_columns, "b", "a", "c"))
  expect_identical(res$b, c(1, NA))
  expect_identical(res$a, c("x", "y"))
  expect_identical(res$c, c(NA, TRUE))
})

test_that("a field of strings, numbers, or booleans gives an atomic column", {
  res <- config_frame(c(
    '{"s": "a", "n": 8192, "f": 0.5, "b": true, "z": null}',
    '{"s": null, "n": 4, "f": null, "b": false, "z": null}'
  ))
  expect_identical(res$s, c("a", NA))
  expect_identical(res$n, c(8192, 4))
  expect_identical(typeof(res$n), "double")
  expect_identical(res$f, c(0.5, NA))
  expect_identical(res$b, c(TRUE, FALSE))
  expect_identical(res$z, c(NA, NA))
})

test_that("a field present in one instance only is NA in the others", {
  res <- config_frame(c('{"parallel": 4}', '{}', NA))
  expect_identical(names(res), c(fixed_columns, "parallel"))
  expect_identical(res$parallel, c(4, NA, NA))
})

test_that("an object, an array, or mixed kinds give a list-column", {
  res <- config_frame(c(
    '{"o": {"k": 1}, "arr": [1, "a"], "mix": 1, "on": {"k": 2}}',
    '{"o": null, "arr": [], "mix": "a"}',
    '{"mix": true}'
  ))
  expect_type(res$o, "list")
  expect_identical(res$o[[1]], list(k = 1L))
  expect_null(res$o[[2]])
  expect_null(res$o[[3]])
  expect_identical(res$arr, list(list(1L, "a"), list(), NULL))
  expect_identical(res$mix, list(1L, "a", TRUE))
  expect_identical(res$on[[1]], list(k = 2L))
  expect_null(res$on[[2]])
  expect_null(res$on[[3]])
})

test_that("a configuration field keeps its name unless it clashes", {
  res <- config_frame(c('{"a-b": 1, "id": "x", "config.id": "y", "": 2}'))
  expect_identical(
    names(res),
    c(fixed_columns, "a-b", "config.id", "config.config.id", "config.")
  )
  expect_identical(res$id, "i1")
  expect_identical(res[["a-b"]], 1)
  expect_identical(res[["config.id"]], "x")
  expect_identical(res[["config.config.id"]], "y")
  expect_identical(res[["config."]], 2)

  res <- config_frame(c('{"config.id": "y", "id": "x"}'))
  expect_identical(
    names(res),
    c(fixed_columns, "config.id", "config.config.id")
  )
  expect_identical(res[["config.id"]], "y")
  expect_identical(res[["config.config.id"]], "x")
})

test_that("the first of two equal keys in one configuration counts", {
  res <- config_frame(c('{"k": 1, "k": "a"}', '{"k": 2}'))
  expect_identical(names(res), c(fixed_columns, "k"))
  expect_identical(res$k, c(1, 2))
})

# The condition that `list_instances()` raises on `body`, or NULL.
instances_raised_by <- function(body, ..., .env = parent.frame()) {
  local_mocked_bindings(is_server_running = function(...) TRUE, .env = .env)
  local_request_recorder(mock_response(200L, body), .env = .env)
  shape_raised_by(list_instances(quiet = TRUE, ...))
}

# Assert that `cnd` is a bad response whose message names every text of
# `names`.
expect_bad_instances <- function(cnd, names, label) {
  expect_true(inherits(cnd, "rlmstudio_bad_response"), info = label)
  if (!inherits(cnd, "rlmstudio_bad_response")) {
    return(invisible())
  }
  expect_identical(cnd$status, 200L, info = label)
  message <- conditionMessage(cnd)
  expect_match(message, "API List Failed", fixed = TRUE, info = label)
  for (text in names) {
    expect_match(message, text, fixed = TRUE, info = label)
  }
}

loaded_llm <- instances_model("llm", "m0", instances = instance_json("i0"))

test_that("a display_name that is not a string aborts with rlmstudio_bad_response", {
  for (form in setdiff(names(json_forms), c("string", "null"))) {
    bad <- instances_model(
      "llm", "m1", json_forms[[form]],
      instances = instance_json("i1")
    )
    cnd <- instances_raised_by(instances_body(c(loaded_llm, bad)))
    expect_bad_instances(
      cnd,
      c("`display_name` of entry 2 of `models` is not a string."),
      paste("display_name as", form)
    )
  }
})

test_that("a config that is not a JSON object aborts with rlmstudio_bad_response", {
  for (form in setdiff(names(json_forms), c("empty object", "object", "null"))) {
    bad <- instances_model(
      "llm", "m1",
      instances = c(instance_json("i1"), instance_json("i2", json_forms[[form]]))
    )
    cnd <- instances_raised_by(instances_body(c(loaded_llm, bad)))
    expect_bad_instances(
      cnd,
      c(
        paste(
          "`config` of entry 2 of `loaded_instances` in entry 2 of `models`",
          "is not a JSON object."
        )
      ),
      paste("config as", form)
    )
  }
})

test_that("the two new checks skip a model outside `type` or with no instance", {
  bad_name <- json_forms[["number"]]
  bad_config <- instance_json("i3", json_forms[["array"]])
  body <- instances_body(c(
    loaded_llm,
    instances_model("llm", "m1", bad_name),
    instances_model("other", "m2", bad_name, instances = bad_config)
  ))
  expect_null(instances_raised_by(body))
  res <- run_list_instances(body, quiet = TRUE)$value
  expect_identical(res$id, "i0")
})

test_that("an absent or null display_name or config gives NA", {
  body <- instances_body(c(
    instances_model(
      "llm", "m1", "null",
      instances = c(
        instance_json("i1", '{"a": 1, "b": "x"}'),
        instance_json("i2", "null")
      )
    ),
    instances_model(
      "llm", "m2",
      drop = "display_name",
      instances = instance_json("i3")
    )
  ))
  res <- run_list_instances(body, quiet = TRUE)$value
  expect_identical(res$display_name, c(NA_character_, NA_character_, NA_character_))
  expect_identical(res$a, c(1, NA, NA))
  expect_identical(res$b, c("x", NA, NA))
})

test_that("a fault of the model list rules aborts with rlmstudio_bad_response", {
  cnd <- instances_raised_by('{"models": {}}')
  expect_bad_instances(cnd, "`models` is not an array", "models as object")
})

test_that("list_instances aborts with rlmstudio_no_server and sends no request", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  local_no_request_allowed()
  expect_error(list_instances(), class = "rlmstudio_no_server")
})

test_that("a reply with a status other than 200 aborts with rlmstudio_api_error", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(500L, '{"error": "boom"}'))
  cnd <- expect_error(list_instances(), class = "rlmstudio_api_error")
  expect_identical(cnd$status, 500L)
})


# A recorded reply and a live server -------------------------------------------

test_that("a recorded model list gives one row per loaded instance", {
  local_mocked_bindings(is_server_running = function(...) TRUE)

  # The reply was recorded on 2026-09-28 from LM Studio 0.4.25+1 by
  # data-raw/record-list-instances-cassette.R. The cassette carries no
  # request header. The test clears both token sources, so it runs the same
  # way whatever token this machine has set.
  withr::local_envvar(RLMSTUDIO_API_TOKEN = NA)
  withr::local_options(rlmstudio.token = NULL)

  httptest2::with_mock_dir("list_instances", {
    res <- list_instances(host = "http://localhost:1234")
  })

  expect_identical(
    res$id,
    c("google/gemma-3-1b", "text-embedding-nomic-embed-text-v1.5")
  )
  expect_identical(res$type, c("llm", "embedding"))
  expect_identical(res$context_length, c(8192, 2048))
})

test_that("live: the id column holds the instance ids of the model list", {
  testthat::skip_on_cran()
  skip_if_no_server()

  # The test loads and unloads nothing. A server that refuses the request, as
  # one that requires a token does when none is set, skips it as well.
  models <- tryCatch(
    list_models(detailed = TRUE, quiet = TRUE),
    rlmstudio_api_error = function(cnd) {
      testthat::skip("the server refused the model list request.")
    }
  )
  ids <- unlist(lapply(models$loaded_instances, function(x) {
    if (is.data.frame(x)) x$id else character()
  }))
  if (length(ids) == 0) {
    testthat::skip("no model is loaded.")
  }

  expect_identical(list_instances(quiet = TRUE)$id, ids)
})
