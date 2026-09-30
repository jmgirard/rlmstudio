# The `previous_response_id` argument that continues a stored chat thread, and
# the `response_id` attribute that a simplified reply carries (D-030). Most
# properties get one test_that() block per function, so a failure names the
# function it came from. Most replies are written here rather than recorded,
# because a recording cannot show what the request body held. The tests near
# the end of the file read the recorded replies.

# native_reply(), responses_reply(), and quoted() live in helper-chat-bodies.R.
thread_replies <- list(
  native = native_reply(),
  openresponses = responses_reply()
)

# A call to each function that takes `previous_response_id`, valid apart from
# it. `lms_chat_batch()` takes it in `...`. `route` picks the reply that the
# mocked server answers with and, where the function routes, the `api_type`.
thread_calls <- list(
  lms_chat_native = function(route, ...) {
    lms_chat_native("a-model", "hi", ...)
  },
  lms_chat_openresponses = function(route, ...) {
    lms_chat_openresponses("a-model", "hi", ...)
  },
  lms_chat = function(route, ...) {
    lms_chat("a-model", "hi", api_type = route, ...)
  },
  lms_chat_batch = function(route, ...) {
    lms_chat_batch(
      "a-model",
      c("first", "second"),
      api_type = route,
      quiet = TRUE,
      ...
    )
  }
)

# The thread routes each function is called on.
thread_routes <- list(
  lms_chat_native = "native",
  lms_chat_openresponses = "openresponses",
  lms_chat = c("native", "openresponses"),
  lms_chat_batch = c("native", "openresponses")
)

# Calls `name` on `route` against a mocked 200 reply and returns the JSON text
# of every request that was sent.
sent_thread_bodies <- function(name, route, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, thread_replies[[route]])
  )
  thread_calls[[name]](route, ...)
  vapply(recorder$requests, request_body_text, character(1))
}

# The domain ----------------------------------------------------------------

test_that("the exports that take previous_response_id are the three chat functions", {
  exports <- Filter(
    function(name) {
      obj <- get(name, envir = asNamespace("rlmstudio"))
      is.function(obj) && "previous_response_id" %in% names(formals(obj))
    },
    sort(getNamespaceExports("rlmstudio"))
  )
  expect_identical(
    exports,
    c("lms_chat", "lms_chat_native", "lms_chat_openresponses")
  )
  for (name in exports) {
    fm <- formals(get(name, envir = asNamespace("rlmstudio")))
    # After `...`, so a shortened name never matches it, and NULL by default.
    expect_gt(
      match("previous_response_id", names(fm)),
      match("...", names(fm))
    )
    expect_null(fm$previous_response_id)
  }
})

# The body field (AC1) --------------------------------------------------------

# A string reaches the body as a JSON string field, and NULL or no argument
# leaves the field out.
expect_thread_field <- function(name) {
  for (route in thread_routes[[name]]) {
    label <- paste(name, "on", route)

    jsons <- sent_thread_bodies(name, route, previous_response_id = "resp_1")
    expect_identical(
      length(jsons),
      if (name == "lms_chat_batch") 2L else 1L,
      info = label
    )
    for (json in jsons) {
      # The field ends after the string, so "resp_10" does not match.
      expect_match(
        json,
        '"previous_response_id":"resp_1"[,}]',
        info = label
      )
      expect_identical(
        jsonlite::parse_json(json)[["previous_response_id"]],
        "resp_1",
        info = label
      )
    }

    for (json in c(
      sent_thread_bodies(name, route),
      sent_thread_bodies(name, route, previous_response_id = NULL)
    )) {
      expect_false(
        "previous_response_id" %in% names(jsonlite::parse_json(json)),
        info = label
      )
    }
  }
}

test_that("lms_chat_native() sends previous_response_id as a string field", {
  expect_thread_field("lms_chat_native")
})

test_that("lms_chat_openresponses() sends previous_response_id as a string field", {
  expect_thread_field("lms_chat_openresponses")
})

test_that("lms_chat() sends previous_response_id on both thread routes", {
  expect_thread_field("lms_chat")
})

test_that("lms_chat_batch() sends previous_response_id from its dots on both thread routes", {
  expect_thread_field("lms_chat_batch")
})

# A shortened name is not the argument, so it goes to the server under the
# name the caller wrote (D-003).
expect_shortened_name_sent <- function(name) {
  for (route in thread_routes[[name]]) {
    label <- paste(name, "on", route)
    for (json in sent_thread_bodies(name, route, previous = 1)) {
      body <- jsonlite::parse_json(json)
      expect_identical(body[["previous"]], 1L, info = label)
      expect_false("previous_response_id" %in% names(body), info = label)
    }
  }
}

test_that("lms_chat_native() sends a shortened name unchecked", {
  expect_shortened_name_sent("lms_chat_native")
})

test_that("lms_chat_openresponses() sends a shortened name unchecked", {
  expect_shortened_name_sent("lms_chat_openresponses")
})

test_that("lms_chat() sends a shortened name unchecked", {
  expect_shortened_name_sent("lms_chat")
})

test_that("lms_chat_batch() sends a shortened name unchecked", {
  expect_shortened_name_sent("lms_chat_batch")
})

# The value check (AC2) -----------------------------------------------------

# Each value that is not one usable string, with the detail its abort gives.
thread_bad_values <- list(
  list(label = "NA", value = NA_character_, match = "You gave NA"),
  list(label = "an empty string", value = "", match = "an empty string"),
  list(label = "a space", value = " ", match = "whitespace only"),
  list(label = "two strings", value = c("a", "b"), match = "2 values"),
  list(label = "no strings", value = character(0), match = "0 values"),
  list(label = "a number", value = 1, match = "a numeric value")
)

# Stubs for the three delegates of `lms_chat()` that count their calls and
# keep the `previous_response_id` each call got. With the delegates stubbed,
# the checks of `lms_chat()` are the only ones that run (LESSONS, M003, M013).
local_counting_delegates <- function(.env = parent.frame()) {
  seen <- new.env(parent = emptyenv())
  seen$calls <- 0L
  seen$ids <- list()
  stub <- function(..., previous_response_id = NULL) {
    seen$calls <- seen$calls + 1L
    seen$ids[length(seen$ids) + 1L] <- list(previous_response_id)
    "ok"
  }
  testthat::local_mocked_bindings(
    lms_chat_native = stub,
    lms_chat_openresponses = stub,
    lms_chat_openai = stub,
    .env = .env
  )
  seen
}

# Each bad value aborts with no package class and a message that names the
# argument, before the probe and before any request.
expect_thread_value_aborts <- function(name, routes) {
  probe <- local_counting_probe()
  if (name == "lms_chat") {
    delegates <- local_counting_delegates()
  }
  for (route in routes) {
    for (p in thread_bad_values) {
      label <- paste(name, "on", route, "with", p$label)
      err <- expect_error(
        thread_calls[[name]](route, previous_response_id = p$value),
        p$match,
        info = label
      )
      expect_match(
        conditionMessage(err),
        "previous_response_id",
        fixed = TRUE,
        info = label
      )
      # No package class on an argument fault (D-008).
      expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
    }
  }
  expect_identical(probe$calls, 0L)
  if (name == "lms_chat") {
    expect_identical(delegates$calls, 0L)
  }
}

test_that("lms_chat_native() aborts on a previous_response_id that is not one usable string", {
  expect_thread_value_aborts("lms_chat_native", "native")
})

test_that("lms_chat_openresponses() aborts on a previous_response_id that is not one usable string", {
  expect_thread_value_aborts("lms_chat_openresponses", "openresponses")
})

test_that("lms_chat() aborts on a previous_response_id that is not one usable string", {
  expect_thread_value_aborts(
    "lms_chat",
    c("native", "openresponses", "openai")
  )
})

test_that("lms_chat_batch() aborts on a previous_response_id that is not one usable string", {
  expect_thread_value_aborts(
    "lms_chat_batch",
    c("native", "openresponses", "openai")
  )
})

# A string and NULL pass the check. The two direct functions and the batch
# then reach the server probe, and `lms_chat()` reaches its delegate with the
# value it got.
expect_thread_value_passes <- function(name, routes) {
  probe <- local_counting_probe()
  for (route in routes) {
    for (value in list("resp_1", NULL)) {
      label <- paste(name, "on", route, "with", deparse1(value))
      before <- probe$calls
      expect_error(
        thread_calls[[name]](route, previous_response_id = value),
        class = "rlmstudio_no_server",
        info = label
      )
      expect_identical(probe$calls, before + 1L, info = label)
    }
  }
}

test_that("lms_chat_native() passes a string and NULL to the server probe", {
  expect_thread_value_passes("lms_chat_native", "native")
})

test_that("lms_chat_openresponses() passes a string and NULL to the server probe", {
  expect_thread_value_passes("lms_chat_openresponses", "openresponses")
})

test_that("lms_chat() passes a string and NULL to its delegate", {
  delegates <- local_counting_delegates()
  for (route in c("native", "openresponses")) {
    for (value in list("resp_1", NULL)) {
      before <- delegates$calls
      expect_identical(
        lms_chat(
          "a-model",
          "hi",
          api_type = route,
          previous_response_id = value
        ),
        "ok",
        info = route
      )
      expect_identical(delegates$calls, before + 1L, info = route)
      expect_identical(
        delegates$ids[[length(delegates$ids)]],
        value,
        info = route
      )
    }
  }
})

test_that("lms_chat_batch() passes a string and NULL to the server probe", {
  expect_thread_value_passes("lms_chat_batch", c("native", "openresponses"))
})

# The route check (AC2) -----------------------------------------------------

# A string on the OpenAI route aborts before the probe and before the
# delegate, and names the two routes that take it. NULL passes on every
# route.
test_that("lms_chat() refuses previous_response_id on the openai route", {
  probe <- local_counting_probe()
  delegates <- local_counting_delegates()
  err <- expect_error(
    lms_chat(
      "a-model",
      "hi",
      api_type = "openai",
      previous_response_id = "resp_1"
    ),
    "previous_response_id",
    fixed = TRUE
  )
  expect_match(conditionMessage(err), "api_type = \"native\"", fixed = TRUE)
  expect_match(
    conditionMessage(err),
    "api_type = \"openresponses\"",
    fixed = TRUE
  )
  expect_false(any(grepl("^rlmstudio_", class(err))))
  expect_identical(probe$calls, 0L)
  expect_identical(delegates$calls, 0L)

  for (route in c("openai", "native", "openresponses")) {
    before <- delegates$calls
    expect_identical(
      lms_chat("a-model", "hi", api_type = route, previous_response_id = NULL),
      "ok",
      info = route
    )
    expect_identical(delegates$calls, before + 1L, info = route)
  }
})

test_that("lms_chat_batch() refuses previous_response_id on the openai route", {
  probe <- local_counting_probe()
  err <- expect_error(
    lms_chat_batch(
      "a-model",
      c("first", "second"),
      api_type = "openai",
      previous_response_id = "resp_1"
    ),
    "previous_response_id",
    fixed = TRUE
  )
  expect_match(conditionMessage(err), "api_type = \"native\"", fixed = TRUE)
  expect_match(
    conditionMessage(err),
    "api_type = \"openresponses\"",
    fixed = TRUE
  )
  expect_false(any(grepl("^rlmstudio_", class(err))))
  expect_identical(probe$calls, 0L)

  for (route in c("openai", "native", "openresponses")) {
    expect_error(
      lms_chat_batch(
        "a-model",
        c("first", "second"),
        api_type = route,
        quiet = TRUE,
        previous_response_id = NULL
      ),
      class = "rlmstudio_no_server",
      info = route
    )
  }
  expect_identical(probe$calls, 3L)
})

# The response_id attribute (AC3) -------------------------------------------

# The id field of a reply, as JSON text, and the attribute it gives. `NULL`
# JSON text leaves the field out, and a `NULL` attribute means none.
id_shapes <- list(
  list(label = "a string", json = quoted("resp_9"), attr = "resp_9"),
  list(label = "an empty string", json = quoted(""), attr = ""),
  list(label = "an absent field", json = NULL, attr = NULL),
  list(label = "null", json = "null", attr = NULL),
  list(label = "a number", json = "7", attr = NULL),
  list(label = "an array", json = json_array(quoted("resp_9")), attr = NULL)
)

# The logprobs array of an OpenResponses part. It holds one step.
thread_logprobs <- json_array(logprob_step("hi"))

# The reply a route sends with the id field `id_json`. `lp` picks the
# OpenResponses part: no logprobs field, or one that carries logprobs.
thread_reply_with_id <- function(route, id_json, lp = FALSE) {
  if (route == "native") {
    return(native_reply("hi", response_id = id_json))
  }
  responses_reply(
    "hi",
    id = id_json,
    logprobs_json = if (lp) thread_logprobs
  )
}

# What `call` returns for `body`, with the server probe passed.
simplified_value <- function(call, body) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(mock_response(200L, body)))
  call()
}

# The attribute matches each id shape, and with the attribute removed the
# value is the one the same reply gives with no id field.
expect_id_attribute <- function(label, call, route, lp = FALSE, class = NULL) {
  baseline <- simplified_value(call, thread_reply_with_id(route, NULL, lp))
  expect_null(attr(baseline, "response_id"), label = label)
  for (shape in id_shapes) {
    info <- paste(label, "with", shape$label)
    value <- simplified_value(call, thread_reply_with_id(route, shape$json, lp))
    expect_identical(attr(value, "response_id"), shape$attr, info = info)
    expect_identical(without_response_id(value), baseline, info = info)
    if (is.null(class)) {
      expect_identical(without_response_id(value), "hi", info = info)
    } else {
      expect_s3_class(value, class)
    }
  }
}

test_that("lms_chat_native() returns the response_id of the reply as an attribute", {
  expect_id_attribute(
    "lms_chat_native",
    function() lms_chat_native("a-model", "hi"),
    "native"
  )
})

test_that("lms_chat_openresponses() returns the id of the reply as an attribute", {
  expect_id_attribute(
    "lms_chat_openresponses, logprobs FALSE",
    function() lms_chat_openresponses("a-model", "hi"),
    "openresponses"
  )
  # With logprobs asked for and no part that carries them, the value is the
  # string.
  expect_id_attribute(
    "lms_chat_openresponses, logprobs TRUE, no logprobs part",
    function() lms_chat_openresponses("a-model", "hi", logprobs = TRUE),
    "openresponses"
  )
  # A part that carries logprobs gives an lms_chat_result, which carries the
  # attribute on the object.
  expect_id_attribute(
    "lms_chat_openresponses, logprobs TRUE, a logprobs part",
    function() lms_chat_openresponses("a-model", "hi", logprobs = TRUE),
    "openresponses",
    lp = TRUE,
    class = "lms_chat_result"
  )
})

test_that("lms_chat() returns the attribute on the two thread routes", {
  for (route in c("native", "openresponses")) {
    value <- simplified_value(
      function() lms_chat("a-model", "hi", api_type = route),
      thread_reply_with_id(route, quoted("resp_9"))
    )
    expect_identical(
      value,
      structure("hi", response_id = "resp_9"),
      info = route
    )
  }
})

test_that("lms_chat_openai() and lms_chat() on openai return no attribute", {
  body <- openai_reply(quoted("hi"), id = quoted("chatcmpl-9"))
  value <- simplified_value(
    function() {
      lms_chat_openai("a-model", list(list(role = "user", content = "hi")))
    },
    body
  )
  expect_identical(value, "hi")
  value <- simplified_value(
    function() lms_chat("a-model", "hi", api_type = "openai"),
    body
  )
  expect_identical(value, "hi")
})

test_that("a call with simplify = FALSE returns the body with no attribute", {
  calls <- list(
    native = function() lms_chat_native("a-model", "hi", simplify = FALSE),
    openresponses = function() {
      lms_chat_openresponses("a-model", "hi", simplify = FALSE)
    }
  )
  for (route in names(calls)) {
    for (via in c("direct", "lms_chat")) {
      info <- paste(route, via)
      call <- if (via == "direct") {
        calls[[route]]
      } else {
        function() lms_chat("a-model", "hi", api_type = route, simplify = FALSE)
      }
      body <- thread_reply_with_id(route, quoted("resp_9"))
      value <- simplified_value(call, body)
      expect_null(attr(value, "response_id"), info = info)
      expect_identical(value, jsonlite::parse_json(body), info = info)
    }
  }
})

# The batch formats (AC4) ---------------------------------------------------

# Runs a two-input batch on `route` against two replies with the ids "resp_a"
# and "resp_b", and returns the result with every warning it gave.
run_thread_batch <- function(route, format, logprobs = FALSE, lp = FALSE) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  replies <- lapply(c("resp_a", "resp_b"), function(id) {
    mock_response(200L, thread_reply_with_id(route, quoted(id), lp))
  })
  local_request_sequence(replies)
  collect_warnings(lms_chat_batch(
    "a-model",
    c("first", "second"),
    format = format,
    quiet = TRUE,
    api_type = route,
    logprobs = logprobs
  ))
}

test_that("a list batch keeps the reply id on each reply", {
  for (route in c("native", "openresponses")) {
    res <- run_thread_batch(route, "list")
    expect_identical(
      res$value,
      list(
        structure("hi", response_id = "resp_a"),
        structure("hi", response_id = "resp_b")
      ),
      info = route
    )
    expect_identical(res$warnings, list(), info = route)
  }
})

test_that("the list a vector batch returns with logprobs keeps the reply ids", {
  # On the OpenResponses route, a part that carries logprobs gives an
  # lms_chat_result, and the attribute is on the object.
  res <- run_thread_batch("openresponses", "vector", logprobs = TRUE, lp = TRUE)
  expect_type(res$value, "list")
  for (i in 1:2) {
    expect_s3_class(res$value[[i]], "lms_chat_result")
    expect_identical(
      attr(res$value[[i]], "response_id"),
      c("resp_a", "resp_b")[[i]]
    )
  }
  # The native route treats logprobs as off, so the vector format returns a
  # character vector with no reply id, as with logprobs = FALSE.
  res <- run_thread_batch("native", "vector", logprobs = TRUE)
  expect_identical(res$value, c("hi", "hi"))
})

test_that("a vector batch returns a character vector with no reply id", {
  for (route in c("native", "openresponses")) {
    res <- run_thread_batch(route, "vector")
    expect_identical(res$value, c("hi", "hi"), info = route)
    expect_identical(res$warnings, list(), info = route)
  }
})

test_that("a data-frame batch keeps the ids in its column and not on the output", {
  for (route in c("native", "openresponses")) {
    for (logprobs in c(FALSE, TRUE)) {
      info <- paste(route, "logprobs:", logprobs)
      res <- run_thread_batch(
        route,
        "data.frame",
        logprobs = logprobs,
        lp = logprobs && route == "openresponses"
      )
      out <- res$value
      expect_identical(out$output, c("hi", "hi"), info = info)
      expect_identical(out$response_id, c("resp_a", "resp_b"), info = info)
    }
  }
})

# The `results` field of a batch abort holds what the list format returns, so
# the reply ids of the inputs before the abort are there in every format.
test_that("a batch abort keeps the reply ids in its results in every format", {
  for (route in c("native", "openresponses")) {
    for (format in c("list", "vector", "data.frame")) {
      info <- paste(route, format)
      testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
      local_request_sequence(list(
        mock_response(200L, thread_reply_with_id(route, quoted("resp_a"))),
        mock_response(401L, '{"error": {"message": "refused"}}')
      ))
      cnd <- tryCatch(
        lms_chat_batch(
          "a-model",
          c("first", "second"),
          format = format,
          quiet = TRUE,
          api_type = route
        ),
        rlmstudio_api_error = identity
      )
      expect_s3_class(cnd, "rlmstudio_api_error")
      expect_identical(cnd$status, 401L, info = info)
      expect_identical(
        cnd$results,
        list(structure("hi", response_id = "resp_a"), NULL),
        info = info
      )
    }
  }
})

# A thread over the recorded replies ----------------------------------------

# The recorded replies in thread_live/ come from a live LM Studio server.
# Regenerate them with data-raw/record-thread-cassette.R, which carries the
# full provenance. The requests below must match the script's requests byte
# for byte.
thread_model <- "google/gemma-3-1b"
thread_first_prompt <- "Reply with the word hi."
thread_second_prompt <- "Now reply with the word bye."
thread_unknown_id <- "resp_not_a_stored_reply"

# Run `expr` against the recorded replies with no token and a server probe
# that always passes.
with_thread_recording <- function(expr, .env = parent.frame()) {
  local_mocked_bindings(is_server_running = function(...) TRUE, .env = .env)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = NA, .local_envir = .env)
  withr::local_options(rlmstudio.token = NULL, .local_envir = .env)
  httptest2::with_mock_dir("thread_live", expr)
}

# The recorded chat call of the script on `route`, with `...` as the script
# gave it.
thread_recorded_call <- function(route, input = thread_first_prompt, ...) {
  if (route == "native") {
    return(lms_chat_native(
      model = thread_model,
      input = input,
      host = "http://localhost:1234",
      temperature = 0,
      ...
    ))
  }
  lms_chat_openresponses(
    model = thread_model,
    input = input,
    host = "http://localhost:1234",
    temperature = 0,
    ...
  )
}

test_that("a recorded native reply id continues a thread on the OpenResponses route", {
  with_thread_recording({
    first <- thread_recorded_call("native")
    id <- attr(first, "response_id")
    expect_true(is.character(id) && length(id) == 1L && nzchar(id))
    second <- thread_recorded_call(
      "openresponses",
      input = thread_second_prompt,
      previous_response_id = id
    )
    second_id <- attr(second, "response_id")
    expect_true(is.character(second_id) && length(second_id) == 1L)
    expect_false(identical(second_id, id))
    # The same request with `simplify = FALSE` reads the same recorded reply.
    # That reply names the stored reply it continued.
    body <- thread_recorded_call(
      "openresponses",
      input = thread_second_prompt,
      previous_response_id = id,
      simplify = FALSE
    )
    expect_identical(body[["previous_response_id"]], id)
    expect_identical(body[["id"]], second_id)
  })
})

test_that("a recorded reply sent with store = FALSE has an id on OpenResponses alone", {
  with_thread_recording({
    native <- thread_recorded_call("native", store = FALSE)
    expect_null(attr(native, "response_id"))
    expect_type(native, "character")
    responses <- thread_recorded_call("openresponses", store = FALSE)
    id <- attr(responses, "response_id")
    expect_true(is.character(id) && length(id) == 1L && nzchar(id))
  })
})

# An unknown id (AC5) -------------------------------------------------------

test_that("lms_chat_native() raises an API error for a recorded unknown id", {
  with_thread_recording({
    err <- expect_error(
      thread_recorded_call("native", previous_response_id = thread_unknown_id),
      class = "rlmstudio_api_error"
    )
  })
  expect_identical(err$status, 400L)
  expect_identical(err$code, "invalid_value")
})

test_that("lms_chat_openresponses() raises an API error for a recorded unknown id", {
  with_thread_recording({
    err <- expect_error(
      thread_recorded_call(
        "openresponses",
        previous_response_id = thread_unknown_id
      ),
      class = "rlmstudio_api_error"
    )
  })
  expect_identical(err$status, 400L)
  expect_identical(err$code, "previous_response_not_found")
})

# The recorded unknown-id reply of `route`, as an httr2 response. httptest2
# writes a reply with a status other than 200 as an R file that rebuilds it.
recorded_unknown_reply <- function(route) {
  dir <- if (route == "native") {
    test_path("thread_live", "localhost-1234", "api", "v1")
  } else {
    test_path("thread_live", "localhost-1234", "v1")
  }
  pattern <- if (route == "native") {
    "^chat-.*-POST\\.R$"
  } else {
    "^responses-.*-POST\\.R$"
  }
  file <- list.files(dir, pattern = pattern, full.names = TRUE)
  stopifnot(length(file) == 1L)
  source(file, local = TRUE)$value
}

test_that("a batch keeps going past a recorded unknown-id reply on both routes", {
  codes <- c(
    native = "invalid_value",
    openresponses = "previous_response_not_found"
  )
  for (route in names(codes)) {
    testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
    recorder <- local_request_sequence(list(
      recorded_unknown_reply(route),
      mock_response(200L, thread_reply_with_id(route, quoted("resp_b")))
    ))
    res <- collect_warnings(lms_chat_batch(
      "a-model",
      c("first", "second"),
      format = "list",
      quiet = TRUE,
      api_type = route,
      previous_response_id = "resp_a"
    ))
    # The second input was sent after the first failed.
    expect_identical(length(recorder$requests), 2L, info = route)
    failed <- res$value[[1]]
    expect_s3_class(failed, "rlmstudio_api_error")
    expect_identical(failed$status, 400L, info = route)
    expect_identical(failed$code, codes[[route]], info = route)
    expect_identical(
      res$value[[2]],
      structure("hi", response_id = "resp_b"),
      info = route
    )
    expect_identical(length(res$warnings), 1L, info = route)
    expect_match(
      conditionMessage(res$warnings[[1]]),
      "1 input failed, at position 1\\.",
      info = route
    )
  }
})
