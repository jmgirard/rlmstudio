# The `store` argument that turns off the storage of a chat reply on the
# native and OpenResponses routes. The tests of accepted forms match the JSON
# text of each request body and do not rely on a parsed body alone (LESSONS,
# M004),
# because an accepted form such as `matrix(FALSE)` must still go out as a
# plain `false`.

# native_reply(), responses_reply(), openai_reply(), and quoted() live in
# helper-chat-bodies.R.
store_replies <- list(
  native = native_reply(),
  openresponses = responses_reply(),
  openai = openai_reply()
)

# A call to each function that takes `store`, valid apart from it.
# `lms_chat_batch()` takes it in `...`. `route` picks the reply that the
# mocked server answers with and, where the function routes, the `api_type`.
store_calls <- list(
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

# The routes that take `store` for each function.
store_routes <- list(
  lms_chat_native = "native",
  lms_chat_openresponses = "openresponses",
  lms_chat = c("native", "openresponses"),
  lms_chat_batch = c("native", "openresponses")
)

# Calls `name` on `route` against a mocked 200 reply and returns the JSON text
# of every request that was sent.
sent_store_bodies <- function(name, route, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, store_replies[[route]])
  )
  store_calls[[name]](route, ...)
  vapply(recorder$requests, request_body_text, character(1))
}

# The domain ----------------------------------------------------------------

test_that("the exports that take store are the three chat functions", {
  exports <- Filter(
    function(name) {
      obj <- get(name, envir = asNamespace("rlmstudio"))
      is.function(obj) && "store" %in% names(formals(obj))
    },
    sort(getNamespaceExports("rlmstudio"))
  )
  for (name in exports) {
    test_that(name, {
      fm <- formals(get(name, envir = asNamespace("rlmstudio")))
      # After `...`, so a shortened name never matches it, and NULL by default.
      expect_gt(match("store", names(fm)), match("...", names(fm)))
      expect_null(fm$store)
    })
  }
  # After the subtests, so testthat keeps a failure here in its results.
  expect_identical(
    exports,
    c("lms_chat", "lms_chat_native", "lms_chat_openresponses")
  )
})

# The body field (AC1) --------------------------------------------------------

# Each accepted form, with the JSON word it must go out as. Every form that
# `isTRUE()` or `isFALSE()` accepts goes out as a plain `true` or `false`.
store_accepted <- list(
  list(label = "TRUE", value = TRUE, json = "true"),
  list(label = "FALSE", value = FALSE, json = "false"),
  list(label = "a named TRUE", value = c(a = TRUE), json = "true"),
  list(label = "a 1x1 matrix", value = matrix(FALSE), json = "false"),
  list(
    label = "a classed TRUE",
    value = structure(TRUE, class = "foo"),
    json = "true"
  )
)

expect_store_field <- function(name) {
  for (route in store_routes[[name]]) {
    for (p in store_accepted) {
      label <- paste(name, "on", route, "with", p$label)
      jsons <- sent_store_bodies(name, route, store = p$value)
      expect_identical(
        length(jsons),
        if (name == "lms_chat_batch") 2L else 1L,
        info = label
      )
      for (json in jsons) {
        # The field ends after the word, so it is one plain JSON boolean and
        # not an array or an object.
        expect_match(
          json,
          paste0('"store":', p$json, "[,}]"),
          info = label
        )
        expect_identical(
          jsonlite::parse_json(json)[["store"]],
          identical(p$json, "true"),
          info = label
        )
      }
    }

    # NULL and no argument leave the field out.
    for (json in c(
      sent_store_bodies(name, route),
      sent_store_bodies(name, route, store = NULL)
    )) {
      expect_no_match(json, '"store"', fixed = TRUE, info = route)
    }
  }
}

test_that("lms_chat_native() sends store as a plain JSON boolean", {
  expect_store_field("lms_chat_native")
})

test_that("lms_chat_openresponses() sends store as a plain JSON boolean", {
  expect_store_field("lms_chat_openresponses")
})

test_that("lms_chat() sends store as a plain JSON boolean on both routes", {
  expect_store_field("lms_chat")
})

# A shortened name is not the argument, so it goes into the body under the
# name the caller wrote, unchecked (D-003).
expect_store_shortened_sent <- function(name) {
  for (route in store_routes[[name]]) {
    label <- paste(name, "on", route)
    for (json in sent_store_bodies(name, route, sto = "x")) {
      body <- jsonlite::parse_json(json)
      expect_identical(body[["sto"]], "x", info = label)
      expect_false("store" %in% names(body), info = label)
    }
  }
}

test_that("each function sends a shortened store name unchecked", {
  for (name in names(store_calls)) {
    test_that(name, {
      expect_store_shortened_sent(name)
    })
  }
})

# The value check (AC2) -----------------------------------------------------

# Each value that is not NULL and that neither isTRUE() nor isFALSE() accepts.
store_bad_values <- list(
  list(label = "NA", value = NA),
  list(label = "NA_character_", value = NA_character_),
  list(label = "a string", value = "yes"),
  list(label = "a number", value = 1),
  list(label = "a list", value = list(TRUE)),
  list(label = "two flags", value = c(TRUE, FALSE)),
  list(label = "no flags", value = logical(0))
)

# Stubs for the three delegates of `lms_chat()` that count their calls. With
# the delegates stubbed, the checks of `lms_chat()` are the only ones that run
# (LESSONS, M003, M013).
local_store_delegates <- function(.env = parent.frame()) {
  seen <- new.env(parent = emptyenv())
  seen$calls <- 0L
  stub <- function(...) {
    seen$calls <- seen$calls + 1L
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

# Each bad value aborts with no package class and the message of the flag
# check, before the probe and before any request.
expect_store_value_aborts <- function(name, routes) {
  probe <- local_counting_probe()
  if (name == "lms_chat") {
    delegates <- local_store_delegates()
  }
  for (route in routes) {
    for (p in store_bad_values) {
      label <- paste(name, "on", route, "with", p$label)
      err <- tryCatch(
        store_calls[[name]](route, store = p$value),
        error = identity
      )
      expect_s3_class(err, "rlang_error")
      expect_match(
        cli::ansi_strip(conditionMessage(err)),
        "`store` must be `TRUE`, `FALSE`, or `NULL`.",
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

test_that("lms_chat_native() aborts on a store that is not a flag", {
  expect_store_value_aborts("lms_chat_native", "native")
})

test_that("lms_chat_openresponses() aborts on a store that is not a flag", {
  expect_store_value_aborts("lms_chat_openresponses", "openresponses")
})

test_that("lms_chat() aborts on a store that is not a flag", {
  expect_store_value_aborts("lms_chat", c("native", "openresponses", "openai"))
})

test_that("lms_chat_batch() aborts on a store in its dots that is not a flag", {
  expect_store_value_aborts(
    "lms_chat_batch",
    c("native", "openresponses", "openai")
  )
})

# The route check (AC3) -----------------------------------------------------

expect_store_route_abort <- function(err) {
  msg <- cli::ansi_strip(conditionMessage(err))
  expect_match(msg, "`store`", fixed = TRUE)
  expect_match(msg, "api_type = \"native\"", fixed = TRUE)
  expect_match(msg, "api_type = \"openresponses\"", fixed = TRUE)
  expect_match(msg, "api_type = \"openai\"", fixed = TRUE)
  expect_false(any(grepl("^rlmstudio_", class(err))))
}

test_that("lms_chat() refuses a store flag on the openai route", {
  probe <- local_counting_probe()
  delegates <- local_store_delegates()
  for (value in list(TRUE, FALSE)) {
    err <- tryCatch(
      lms_chat("a-model", "hi", api_type = "openai", store = value),
      error = identity
    )
    expect_s3_class(err, "rlang_error")
    expect_store_route_abort(err)
  }
  expect_identical(probe$calls, 0L)
  expect_identical(delegates$calls, 0L)
})

test_that("lms_chat_batch() refuses a store flag on the openai route", {
  probe <- local_counting_probe()
  for (value in list(TRUE, FALSE)) {
    err <- tryCatch(
      store_calls$lms_chat_batch("openai", store = value),
      error = identity
    )
    expect_s3_class(err, "rlang_error")
    expect_store_route_abort(err)
  }
  expect_identical(probe$calls, 0L)
})

test_that("lms_chat_openai() sends a store in its dots unchecked", {
  # It has no `store` argument, so the field goes to the server as any other
  # dot (D-003), even a value that the three chat functions refuse.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  expect_false("store" %in% names(formals(lms_chat_openai)))
  for (value in list(TRUE, "yes")) {
    recorder <- local_request_recorder(mock_response(200L, openai_reply()))
    lms_chat_openai(
      "a-model",
      list(list(role = "user", content = "hi")),
      store = value
    )
    json <- request_body_text(recorder$requests[[1]])
    expect_identical(jsonlite::parse_json(json)[["store"]], value)
  }
})

test_that("store = NULL on the openai route sends no store field", {
  for (name in c("lms_chat", "lms_chat_batch")) {
    test_that(name, {
      jsons <- sent_store_bodies(name, "openai", store = NULL)
      expect_identical(
        length(jsons),
        if (name == "lms_chat_batch") 2L else 1L,
        info = name
      )
      for (json in jsons) {
        expect_match(json, '"messages"', fixed = TRUE, info = name)
        expect_no_match(json, '"store"', fixed = TRUE, info = name)
      }
    })
  }
})

# The batch (AC4) -----------------------------------------------------------

# Runs a three-input batch against a mocked 200 reply, with a server probe
# that passes and counts its calls. Returns the JSON text of every request,
# the value, and the probe count.
run_store_batch <- function(route, format, ...) {
  probe <- new.env(parent = emptyenv())
  probe$calls <- 0L
  testthat::local_mocked_bindings(
    is_server_running = function(...) {
      probe$calls <- probe$calls + 1L
      TRUE
    }
  )
  recorder <- local_request_recorder(
    mock_response(200L, store_replies[[route]])
  )
  value <- lms_chat_batch(
    "a-model",
    c("one", "two", "three"),
    format = format,
    api_type = route,
    quiet = TRUE,
    ...
  )
  list(
    jsons = vapply(recorder$requests, request_body_text, character(1)),
    value = value,
    probes = probe$calls
  )
}

expect_store_in_every_body <- function(res, word, info) {
  expect_identical(length(res$jsons), 3L, info = info)
  for (json in res$jsons) {
    expect_match(json, paste0('"store":', word, "[,}]"), info = info)
  }
  # One probe for the batch and one for the route function of each input, so
  # each input made its own call to a route function.
  expect_identical(res$probes, 4L, info = info)
}

test_that("lms_chat_batch() sends store = FALSE to every call of a native data-frame batch", {
  res <- run_store_batch("native", "data.frame", store = FALSE)
  expect_store_in_every_body(res, "false", "native data.frame")
  expect_identical(nrow(res$value), 3L)
})

test_that("lms_chat_batch() sends store = FALSE to every call of an OpenResponses list batch", {
  res <- run_store_batch("openresponses", "list", store = FALSE)
  expect_store_in_every_body(res, "false", "openresponses list")
  expect_identical(length(res$value), 3L)
})

test_that("lms_chat_batch() sends store = TRUE to every call", {
  for (route in c("native", "openresponses")) {
    res <- run_store_batch(route, "vector", store = TRUE)
    expect_store_in_every_body(res, "true", route)
  }
})

test_that("two store values in the dots of lms_chat_batch() abort", {
  probe <- local_counting_probe()
  err <- tryCatch(
    store_calls$lms_chat_batch("native", store = TRUE, store = FALSE),
    error = identity
  )
  expect_identical(class(err), c("rlang_error", "error", "condition"))
  expect_match(
    cli::ansi_strip(conditionMessage(err)),
    "`store` is given more than once.",
    fixed = TRUE
  )
  expect_identical(probe$calls, 0L)
})
