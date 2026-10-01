# A dot of lms_chat() or lms_chat_batch() whose name lms_chat() also passes to
# the function of the route. Before, R raised "formal argument matched by
# multiple actual arguments", and in the batch only after the server check.

clash_cases <- list(
  list(
    label = "instructions on openresponses",
    route = list(api_type = "openresponses"),
    dot = list(instructions = "Be brief."),
    arg = "instructions",
    source = "`system_prompt`"
  ),
  list(
    label = "instructions with no route",
    route = list(),
    dot = list(instructions = "Be brief."),
    arg = "instructions",
    source = "`system_prompt`"
  ),
  list(
    label = "messages on openai",
    route = list(api_type = "openai"),
    dot = list(messages = list(list(role = "user", content = "hi"))),
    arg = "messages",
    source = "`system_prompt` and `input`"
  )
)

# The batch takes the route in `...`, also under the shortened name `api`.
batch_clash_cases <- c(
  clash_cases,
  list(
    list(
      label = "instructions on api = openresponses",
      route = list(api = "openresponses"),
      dot = list(instructions = "Be brief."),
      arg = "instructions",
      source = "`system_prompt`"
    ),
    list(
      label = "messages on api = openai",
      route = list(api = "openai"),
      dot = list(messages = list(list(role = "user", content = "hi"))),
      arg = "messages",
      source = "`system_prompt` and `input`"
    )
  )
)

expect_clash_abort <- function(call, case, info) {
  probe <- local_counting_probe()
  err <- tryCatch(call(), error = identity)
  expect_s3_class(err, "error")
  # An argument fault carries no condition class of the package (D-008).
  expect_identical(class(err), c("rlang_error", "error", "condition"), info = info)
  expect_identical(probe$calls, 0L, info = info)
  msg <- cli::ansi_strip(conditionMessage(err))
  expect_match(msg, paste0("`", case$arg, "` cannot be given in `...` on the \""), fixed = TRUE, info = info)
  expect_no_match(msg, "more than once", fixed = TRUE, info = info)
  expect_match(msg, case$source, fixed = TRUE, info = info)
  expect_no_match(msg, "matched by multiple actual arguments", fixed = TRUE, info = info)
}

test_that("lms_chat() aborts on a dot that it passes itself", {
  for (case in clash_cases) {
    call <- function() {
      do.call(lms_chat, c(list("a-model", "hi"), case$route, case$dot))
    }
    expect_clash_abort(call, case, paste("lms_chat() with", case$label))
  }
})

test_that("lms_chat_batch() aborts on that dot before the server check", {
  for (case in batch_clash_cases) {
    call <- function() {
      do.call(
        lms_chat_batch,
        c(list("a-model", c("first", "second"), quiet = TRUE), case$route, case$dot)
      )
    }
    expect_clash_abort(call, case, paste("lms_chat_batch() with", case$label))
  }
})

# The same dot on a route that does not set it goes to the server as a field.
passing_cases <- list(
  list(route = "openai", dot = list(instructions = "Be brief."), reply = openai_reply()),
  list(route = "native", dot = list(instructions = "Be brief."), reply = native_reply()),
  list(
    route = "openresponses",
    dot = list(messages = list(list(role = "user", content = "hi"))),
    reply = responses_reply()
  ),
  list(
    route = "native",
    dot = list(messages = list(list(role = "user", content = "hi"))),
    reply = native_reply()
  )
)

# A clashing dot and one other fault. The other fault names its own argument,
# so the headline names it and not `instructions`. `lms_chat_batch()` takes
# `inputs` where `lms_chat()` takes `input`.
other_faults <- list(
  list(label = "a bad model", model = 1, input = "hi", schema = NULL, arg = "model"),
  list(label = "a bad input", model = "a-model", input = NA_character_, schema = NULL, arg = "input"),
  list(label = "a refused schema", model = "a-model", input = "hi", schema = 1, arg = "schema")
)

expect_other_fault_first <- function(call, arg, info) {
  probe <- local_counting_probe()
  err <- tryCatch(call(), error = identity)
  expect_s3_class(err, "error")
  expect_identical(probe$calls, 0L, info = info)
  headline <- cli::ansi_strip(conditionMessage(err))
  headline <- strsplit(headline, "\n", fixed = TRUE)[[1]][[1]]
  expect_match(headline, paste0("^`", arg, "` must "), info = info)
  expect_no_match(headline, "instructions", fixed = TRUE, info = info)
}

test_that("another argument fault comes before the clashing dot", {
  for (fault in other_faults) {
    expect_other_fault_first(
      function() {
        lms_chat(
          fault$model,
          fault$input,
          api_type = "openresponses",
          schema = fault$schema,
          instructions = "Be brief."
        )
      },
      fault$arg,
      paste("lms_chat() with", fault$label)
    )
    inputs <- c("first", fault$input)
    expect_other_fault_first(
      function() {
        lms_chat_batch(
          fault$model,
          inputs,
          quiet = TRUE,
          api_type = "openresponses",
          schema = fault$schema,
          instructions = "Be brief."
        )
      },
      if (fault$arg == "input") "inputs" else fault$arg,
      paste("lms_chat_batch() with", fault$label)
    )
  }
})

# Each of `requests` must carry the dot of `case` with its value.
expect_dot_sent <- function(requests, n, case, info) {
  expect_identical(length(requests), n, info = info)
  name <- names(case$dot)
  for (req in requests) {
    body <- jsonlite::parse_json(request_body_text(req))
    expect_identical(body[[name]], case$dot[[name]], info = info)
  }
}

test_that("the dot on another route is sent as a field, with no abort", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (case in passing_cases) {
    info <- paste(names(case$dot), "on", case$route)
    recorder <- local_request_recorder(mock_response(200L, case$reply))
    expect_no_error(
      do.call(lms_chat, c(list("a-model", "hi", api_type = case$route), case$dot))
    )
    expect_dot_sent(recorder$requests, 1L, case, paste("lms_chat() with", info))

    # The batch takes the route in `...`, also under the shortened name `api`.
    for (route_arg in c("api_type", "api")) {
      route <- stats::setNames(list(case$route), route_arg)
      recorder <- local_request_recorder(mock_response(200L, case$reply))
      expect_no_error(
        do.call(
          lms_chat_batch,
          c(list("a-model", c("first", "second"), quiet = TRUE), route, case$dot)
        )
      )
      expect_dot_sent(
        recorder$requests,
        2L,
        case,
        paste("lms_chat_batch() with", info, "given as", route_arg)
      )
    }
  }
})

# R matches the exact name `instructions` first, so a shortened `instr` goes
# to the `...` of `lms_chat_openresponses()` and not to `instructions`.
test_that("a shortened instr dot is sent beside the system prompt", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  expect_both_fields <- function(requests, n, info) {
    expect_identical(length(requests), n, info = info)
    for (req in requests) {
      json <- request_body_text(req)
      expect_match(json, '"instructions":"S"', fixed = TRUE, info = info)
      expect_match(json, '"instr":"Be brief."', fixed = TRUE, info = info)
    }
  }

  recorder <- local_request_recorder(mock_response(200L, responses_reply()))
  expect_no_error(lms_chat(
    "a-model",
    "hi",
    system_prompt = "S",
    api_type = "openresponses",
    instr = "Be brief."
  ))
  expect_both_fields(recorder$requests, 1L, "lms_chat()")

  recorder <- local_request_recorder(mock_response(200L, responses_reply()))
  expect_no_error(lms_chat_batch(
    "a-model",
    c("first", "second"),
    system_prompt = "S",
    quiet = TRUE,
    api_type = "openresponses",
    instr = "Be brief."
  ))
  expect_both_fields(recorder$requests, 2L, "lms_chat_batch()")
})

# The arguments that lms_chat() passes by name to a route function, less its
# own formals, read from the body of lms_chat(). A new one turns this red,
# which is the signal to add it to the check.
test_that("instructions and messages are the arguments lms_chat() sets itself", {
  routes <- c("lms_chat_openresponses", "lms_chat_openai", "lms_chat_native")
  found <- list()
  walk <- function(expr) {
    if (is.call(expr)) {
      head <- expr[[1]]
      if (is.name(head) && as.character(head) %in% routes) {
        nms <- setdiff(names(as.list(expr)[-1]), c("", names(formals(lms_chat))))
        for (nm in nms) found[[nm]] <<- c(found[[nm]], as.character(head))
      }
      lapply(as.list(expr)[-1], function(part) if (!missing(part)) walk(part))
    }
  }
  walk(body(lms_chat))
  expect_identical(
    found[order(names(found))],
    list(instructions = "lms_chat_openresponses", messages = "lms_chat_openai")
  )
})
