# Which exported functions must guard which argument is read from the package
# NAMESPACE rather than from a list written here. A wrapper added later joins
# the domain on its own, which a hand-written list of names would not do.

guarded_exports <- function(arg_names) {
  exports <- sort(getNamespaceExports("rlmstudio"))
  out <- Filter(
    function(name) {
      obj <- get(name, envir = asNamespace("rlmstudio"))
      is.function(obj) && any(arg_names %in% names(formals(obj)))
    },
    exports
  )
  out
}

# A stand-in value for every formal that has no default. The table is keyed by
# formal name, and a name it does not carry is a test failure rather than a
# skip: a silent skip would let a whole function leave the domain unnoticed.
arg_placeholders <- list(
  model = "a-model",
  job_id = "a-job",
  input = "a prompt",
  inputs = c("first", "second"),
  messages = list(list(role = "user", content = "a prompt"))
)

required_formals <- function(name) {
  formal_args <- formals(get(name, envir = asNamespace("rlmstudio")))
  needed <- vapply(
    formal_args,
    function(default) identical(default, quote(expr = )),
    logical(1)
  )
  setdiff(names(formal_args)[needed], "...")
}

# The table is an argument so a test can drive the missing-placeholder branch
# without mocking, the way httpuv_absence_action() takes both of its inputs.
baseline_args <- function(name, table = arg_placeholders) {
  needed <- required_formals(name)
  missing_from_table <- setdiff(needed, names(table))
  if (length(missing_from_table) > 0) {
    testthat::fail(paste0(
      "No placeholder for the required argument(s) ",
      paste(missing_from_table, collapse = ", "),
      " of ",
      name,
      "(). Add one to arg_placeholders, or the guard for that ",
      "function goes untested."
    ))
  }
  table[needed]
}

# Force the server probe to succeed and make any request raise. What is left is
# the guard: an abort that names the argument can only have come from it.
local_guard_only <- function(.env = parent.frame()) {
  testthat::local_mocked_bindings(
    is_server_running = function(...) TRUE,
    .env = .env
  )
  local_no_request_allowed(.env = .env)
}

id_probes <- list(
  list(label = "two values", value = c("a", "b"), match = "2 values rather than one"),
  list(label = "no values", value = character(0), match = "0 values rather than one"),
  list(label = "NA", value = NA_character_, match = "You gave NA"),
  list(label = "empty string", value = "", match = "an empty string"),
  list(label = "whitespace", value = "   ", match = "whitespace only"),
  list(label = "NULL", value = NULL, match = "You gave NULL"),
  list(label = "a number", value = 42, match = "a numeric value"),
  list(label = "a logical", value = TRUE, match = "a logical value"),
  list(label = "a list", value = list("a"), match = "a list value"),
  list(label = "a factor", value = factor("a"), match = "a factor value")
)

test_that("the guarded domains are read from NAMESPACE and are not empty", {
  id_domain <- guarded_exports(c("model", "job_id"))
  text_domain <- guarded_exports(c("input", "inputs"))

  expect_gt(length(id_domain), 0)
  expect_gt(length(text_domain), 0)
  # Named here as a record of what the enumeration found on the day this was
  # written, never as the source of the domain. A new wrapper turns this red,
  # which is the signal to check that it carries a guard.
  expect_setequal(
    id_domain,
    c(
      "lms_chat",
      "lms_chat_batch",
      "lms_chat_native",
      "lms_chat_openai",
      "lms_chat_openresponses",
      "lms_download",
      "lms_download_status",
      "lms_embed",
      "lms_load",
      "lms_unload"
    )
  )
  expect_setequal(
    text_domain,
    c(
      "lms_chat",
      "lms_chat_batch",
      "lms_chat_native",
      "lms_chat_openresponses",
      "lms_embed"
    )
  )
})

test_that("every enumerated function has a placeholder for each required argument", {
  for (name in guarded_exports(c("model", "job_id", "input", "inputs"))) {
    expect_type(baseline_args(name), "list")
  }
})

test_that("a missing placeholder fails the test rather than skipping it", {
  expect_failure(
    baseline_args("lms_embed", table = list(model = "a-model")),
    "No placeholder for the required argument"
  )
  expect_failure(baseline_args("lms_embed", table = list()))
})

test_that("a bad model or job id aborts, named, before any request", {
  local_guard_only()

  for (name in guarded_exports(c("model", "job_id"))) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- baseline_args(name)
    target <- intersect(c("model", "job_id"), names(args))[[1]]

    for (probe in id_probes) {
      bad <- args
      bad[target] <- list(probe$value)
      expect_error(
        do.call(fn, bad),
        probe$match,
        info = paste(name, "with", probe$label, "by name")
      )
      expect_error(
        do.call(fn, bad),
        target,
        info = paste(name, "with", probe$label, "names the argument")
      )

      # The same value supplied positionally. Every function in this domain
      # carries the guarded argument first.
      expect_identical(names(formals(fn))[[1]], target)
      positional <- c(list(probe$value), bad[setdiff(names(bad), target)])
      expect_error(
        do.call(fn, positional),
        probe$match,
        info = paste(name, "with", probe$label, "positionally")
      )
    }
  }
})

test_that("omitting the guarded identifier aborts with a message naming it", {
  local_guard_only()

  for (name in guarded_exports(c("model", "job_id"))) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- baseline_args(name)
    target <- intersect(c("model", "job_id"), names(args))[[1]]
    expect_error(
      do.call(fn, args[setdiff(names(args), target)]),
      target,
      info = paste(name, "without", target)
    )
  }
})
