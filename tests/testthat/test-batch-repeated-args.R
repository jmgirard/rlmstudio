# `lms_chat_batch()` passes its `...` to `lms_chat()`. Two dots that R
# matches to the same `lms_chat()` argument abort in the batch, with a message
# that names the argument, before every other check of `...` and before the
# server probe. The checks of `model` and `inputs` come first.

# The `lms_chat()` arguments that a dot of the batch can reach. The batch
# passes `input` by name itself, and its own formals take `model`,
# `system_prompt`, `host`, `simplify`, and `token` before `...` sees them.
batch_formals <- c("model", "system_prompt", "host", "simplify", "token")
repeat_domain <- setdiff(names(formals(lms_chat)), c("...", batch_formals))

# Run a batch with `dots` against a stopped server that counts its probes,
# and return the error with the probe count. `inputs` is the list of
# arguments that give `inputs`, by position unless named.
run_repeat_batch <- function(dots, inputs = list(c("a", "b"))) {
  probe <- local_counting_probe()
  err <- tryCatch(
    do.call(lms_chat_batch, c(list("a-model"), inputs, dots)),
    error = identity
  )
  list(err = err, probes = probe$calls)
}

expect_repeat_abort <- function(res, arg, info) {
  err <- res$err
  expect_identical(
    class(err),
    c("rlang_error", "error", "condition"),
    info = paste(info, "has no condition class")
  )
  msg <- cli::ansi_strip(conditionMessage(err))
  expect_match(
    msg,
    paste0("`", arg, "` is given more than once."),
    fixed = TRUE,
    info = info
  )
  expect_no_match(msg, "matched by multiple actual arguments", fixed = TRUE)
  expect_identical(res$probes, 0L, info = paste(info, "probed the server"))
}

test_that("the repeat domain holds the lms_chat() arguments that dots reach", {
  # A record of the domain on the day this was written, never its source. A
  # new `lms_chat()` argument turns this red, the signal to check it here.
  expect_setequal(
    repeat_domain,
    c("input", "api_type", "logprobs", "schema", "ttl", "previous_response_id")
  )
})

test_that("two exact-name dots for one lms_chat() argument abort", {
  for (arg in setdiff(repeat_domain, "input")) {
    # Values that most other checks reject, so for those arguments the repeat
    # abort must come first. A lone `previous_response_id = "a"` is valid, so
    # for it the message check, not the order of checks, shows the abort.
    dots <- list("a", "b")
    names(dots) <- c(arg, arg)
    expect_repeat_abort(run_repeat_batch(dots), arg, info = arg)
  }
})

test_that("two shortened-name dots for one lms_chat() argument abort", {
  # R matches a shortened name only to an argument before `...`.
  for (arg in c("api_type", "logprobs")) {
    prefixes <- substring(arg, 1, seq_len(nchar(arg) - 1L))
    for (k in seq_len(length(prefixes) - 1L)) {
      dots <- list(TRUE, FALSE)
      names(dots) <- prefixes[c(k, k + 1L)]
      info <- paste(names(dots), collapse = " and ")
      expect_repeat_abort(run_repeat_batch(dots), arg, info = info)
    }
  }
})

test_that("an input dot beside inputs aborts", {
  res <- run_repeat_batch(list(input = "y"), inputs = list(inputs = "x"))
  expect_repeat_abort(res, "input", info = "input")
  msg <- cli::ansi_strip(conditionMessage(res$err))
  expect_match(msg, "`inputs`", fixed = TRUE)
})

test_that("a repeated logprobs gets the repeat abort and not the flag abort", {
  res <- run_repeat_batch(list(logprobs = TRUE, logprobs = "yes"))
  expect_repeat_abort(res, "logprobs", info = "logprobs")
  msg <- cli::ansi_strip(conditionMessage(res$err))
  expect_no_match(msg, "must be `TRUE` or `FALSE`", fixed = TRUE)
})

test_that("an exact name and a shortened name for one argument pass the check", {
  # R matches the exact name first, so `log` goes to the `...` of
  # `lms_chat()` as a body field, and the batch reaches the server probe.
  res <- run_repeat_batch(list(log = TRUE, logprobs = FALSE))
  expect_s3_class(res$err, "rlmstudio_no_server")
  expect_identical(res$probes, 1L)
})

test_that("two dots that reach no lms_chat() argument pass the check", {
  res <- run_repeat_batch(list(temperature = 0.1, temperature = 0.2))
  expect_s3_class(res$err, "rlmstudio_no_server")
  expect_identical(res$probes, 1L)
})
