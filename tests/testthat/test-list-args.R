# The argument checks of `list_models()` and `list_instances()`. A bad `type`
# or `quiet`, and a bad `loaded` or `detailed` of `list_models()`, abort before
# the server probe and before any request, with no rlmstudio_ class (D-008).

list_calls <- list(
  list_models = function(...) list_models(...),
  list_instances = function(...) list_instances(...)
)

type_probes <- list(
  list(label = "a number", value = 1, match = "You gave a numeric value"),
  list(label = "a logical NA", value = NA, match = "You gave a logical value"),
  list(label = "NULL", value = NULL, match = "You gave NULL"),
  list(
    label = "a factor",
    value = factor("llm"),
    match = "You gave a factor value"
  ),
  list(
    label = "no values",
    value = character(0),
    match = "You gave an empty character vector"
  ),
  list(label = "an NA element", value = c("llm", NA), match = "Element 2 is NA"),
  list(
    label = "an empty string",
    value = "",
    match = "Element 1 is an empty string"
  ),
  list(
    label = "a later empty string",
    value = c("llm", ""),
    match = "Element 2 is an empty string"
  ),
  list(
    label = "a space",
    value = " ",
    match = "Element 1 holds only whitespace"
  ),
  list(
    label = "a form feed",
    value = "\f",
    match = "Element 1 holds only whitespace"
  )
)

flag_probes <- list(
  list(label = "NA", value = NA, match = "You gave NA"),
  list(
    label = "no values",
    value = logical(0),
    match = "You gave 0 values rather than one"
  ),
  list(
    label = "two values",
    value = c(TRUE, FALSE),
    match = "You gave 2 values rather than one"
  ),
  list(label = "a string", value = "yes", match = "You gave a character value"),
  list(label = "a number", value = 1, match = "You gave a numeric value")
)

null_probe <- list(label = "NULL", value = NULL, match = "You gave NULL")

# Force the server probe to report a running server and make any request
# raise, so an abort carrying a check's detail can only come from the check.
local_guard_only <- function(.env = parent.frame()) {
  local_mocked_bindings(is_server_running = function(...) TRUE, .env = .env)
  local_no_request_allowed(.env = .env)
}

# Report a stopped server and count the probe calls. An argument abort under
# this mock shows that the check runs before the probe.
local_stopped_server <- function(.env = parent.frame()) {
  probe <- new.env(parent = emptyenv())
  probe$calls <- 0L
  local_mocked_bindings(
    is_server_running = function(...) {
      probe$calls <- probe$calls + 1L
      FALSE
    },
    .env = .env
  )
  local_no_request_allowed(.env = .env)
  probe
}

# Call `fun` with `arg` set to each probe value and assert the argument abort.
# `args` wraps the value in list() so that a NULL probe is passed, not dropped.
expect_arg_aborts <- function(fun, name, arg, probes, rule) {
  for (p in probes) {
    args <- stats::setNames(list(p$value), arg)
    info <- paste0(name, "(", arg, " = ", p$label, ")")
    err <- expect_error(do.call(fun, args), p$match, info = info)
    expect_match(conditionMessage(err), rule, fixed = TRUE, info = info)
    expect_false(any(grepl("^rlmstudio_", class(err))), info = info)
  }
}

test_that("a bad type aborts, named, before any request", {
  local_guard_only()
  for (name in names(list_calls)) {
    expect_arg_aborts(
      list_calls[[name]],
      name,
      "type",
      type_probes,
      "`type` must be one or more model types, given as a character vector."
    )
  }
})

test_that("a bad quiet aborts, named, before any request", {
  local_guard_only()
  for (name in names(list_calls)) {
    expect_arg_aborts(
      list_calls[[name]],
      name,
      "quiet",
      flag_probes,
      "`quiet` must be `TRUE`, `FALSE`, or `NULL`."
    )
  }
})

test_that("a bad loaded or detailed aborts list_models, NULL included", {
  local_guard_only()
  for (arg in c("loaded", "detailed")) {
    expect_arg_aborts(
      list_calls$list_models,
      "list_models",
      arg,
      c(flag_probes, list(null_probe)),
      paste0("`", arg, "` must be `TRUE` or `FALSE`.")
    )
  }
})

test_that("an argument abort comes before the probe of a stopped server", {
  bad <- list(
    list(name = "list_models", arg = "type", value = 1),
    list(name = "list_instances", arg = "type", value = 1),
    list(name = "list_models", arg = "quiet", value = NA),
    list(name = "list_instances", arg = "quiet", value = NA),
    list(name = "list_models", arg = "loaded", value = NULL),
    list(name = "list_models", arg = "detailed", value = NULL)
  )
  for (case in bad) {
    probe <- local_stopped_server()
    info <- paste0(case$name, "(", case$arg, ")")
    args <- stats::setNames(list(case$value), case$arg)
    err <- expect_error(
      do.call(list_calls[[case$name]], args),
      paste0("`", case$arg, "` must be"),
      info = info
    )
    expect_false(inherits(err, "rlmstudio_no_server"), info = info)
    expect_identical(probe$calls, 0L, info = info)
  }
})

# One llm model with one loaded instance. A `type` of "vlm" matches no model
# in it, and "llm" matches the one model.
one_loaded_llm <- paste0(
  '{"models": [{"type": "llm", "key": "m1", "display_name": "M1", ',
  '"size_bytes": 1073741824, "loaded_instances": [{"id": "i1"}]}]}'
)

local_one_loaded_llm <- function(.env = parent.frame()) {
  local_mocked_bindings(is_server_running = function(...) TRUE, .env = .env)
  local_request_recorder(mock_response(200L, one_loaded_llm), .env = .env)
}

test_that("a named type and a 1-by-1 character matrix pass", {
  withr::local_options(rlmstudio.quiet = NULL)
  for (name in names(list_calls)) {
    for (value in list(c(a = "llm"), matrix("llm"))) {
      local_one_loaded_llm()
      info <- paste(name, "with", class(value)[[1]])
      res <- list_calls[[name]](type = value)
      expect_identical(nrow(res), 1L, info = info)
      expect_identical(res$key, "m1", info = info)
    }
  }
})

no_match_messages <- c(
  list_models = "No models found matching criteria",
  list_instances = "No loaded model instances"
)

test_that("quiet = NULL prints the no-match message unless the option is TRUE", {
  for (name in names(list_calls)) {
    local_one_loaded_llm()
    withr::with_options(list(rlmstudio.quiet = NULL), {
      expect_message(
        list_calls[[name]](type = "vlm", quiet = NULL),
        no_match_messages[[name]],
        info = name
      )
    })
    withr::with_options(list(rlmstudio.quiet = TRUE), {
      expect_no_message(list_calls[[name]](type = "vlm", quiet = NULL))
    })
  }
})

test_that("quiet = TRUE prints no no-match message with the option unset", {
  withr::local_options(rlmstudio.quiet = NULL)
  for (name in names(list_calls)) {
    local_one_loaded_llm()
    expect_no_message(list_calls[[name]](type = "vlm", quiet = TRUE))
    local_one_loaded_llm()
    expect_message(
      list_calls[[name]](type = "vlm", quiet = FALSE),
      no_match_messages[[name]],
      info = name
    )
  }
})

test_that("an unknown type returns the empty frame and a message, with no abort", {
  withr::local_options(rlmstudio.quiet = NULL)
  local_one_loaded_llm()

  expect_message(
    out <- withVisible(list_models(type = "vlm")),
    no_match_messages[["list_models"]]
  )
  expect_false(out$visible)
  expect_identical(out$value, data.frame())

  expect_message(
    out <- withVisible(list_instances(type = "vlm")),
    no_match_messages[["list_instances"]]
  )
  expect_false(out$visible)
  expect_identical(
    out$value,
    data.frame(
      id = character(),
      key = character(),
      type = character(),
      display_name = character()
    )
  )
})
