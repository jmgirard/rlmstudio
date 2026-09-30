# A model name, job id, thread id, or type filter that is not valid text, or
# that carries a class, names, or the S4 bit. Each pair of function and
# argument gets its own test_that() block, so a failure names the pair.

# A call to each function with `value` in the checked argument and every other
# argument valid. `lms_chat_batch()` takes `previous_response_id` in `...`.
name_pairs <- list(
  "lms_chat(model)" = function(v) lms_chat(v, "hi"),
  "lms_chat_batch(model)" = function(v) {
    lms_chat_batch(v, c("first", "second"), quiet = TRUE)
  },
  "lms_chat_openresponses(model)" = function(v) lms_chat_openresponses(v, "hi"),
  "lms_chat_openai(model)" = function(v) {
    lms_chat_openai(v, list(list(role = "user", content = "hi")))
  },
  "lms_chat_native(model)" = function(v) lms_chat_native(v, "hi"),
  "lms_embed(model)" = function(v) lms_embed(v, "hi"),
  "lms_load(model)" = function(v) lms_load(v),
  "lms_download(model)" = function(v) lms_download(v),
  "lms_unload(model)" = function(v) lms_unload(v),
  "lms_download_status(job_id)" = function(v) lms_download_status(v),
  "lms_chat(previous_response_id)" = function(v) {
    lms_chat("a-model", "hi", previous_response_id = v)
  },
  "lms_chat_openresponses(previous_response_id)" = function(v) {
    lms_chat_openresponses("a-model", "hi", previous_response_id = v)
  },
  "lms_chat_native(previous_response_id)" = function(v) {
    lms_chat_native("a-model", "hi", previous_response_id = v)
  },
  "lms_chat_batch(previous_response_id)" = function(v) {
    lms_chat_batch(
      "a-model",
      c("first", "second"),
      quiet = TRUE,
      previous_response_id = v
    )
  },
  "list_models(type)" = function(v) list_models(type = v),
  "list_instances(type)" = function(v) list_instances(type = v)
)

pair_arg <- function(pair) sub("^.*\\((.*)\\)$", "\\1", pair)

marked <- function(bytes, encoding) {
  x <- rawToChar(as.raw(bytes))
  Encoding(x) <- encoding
  x
}

cafe_bytes <- c(0x63, 0x61, 0x66, 0xc3, 0xa9)

# Each probe with the text its detail must hold. The byte 0xff is not valid
# UTF-8, so these probes need a UTF-8 locale.
text_probes <- list(
  list(label = "0xff, no mark", value = marked(0xff, "unknown"), match = "not valid in its encoding"),
  list(label = "0xff, UTF-8", value = marked(0xff, "UTF-8"), match = "not valid in its encoding"),
  list(label = "a and 0xff, UTF-8", value = marked(c(0x61, 0xff), "UTF-8"), match = "not valid in its encoding"),
  list(label = "0xff, bytes", value = marked(0xff, "bytes"), match = "marked as bytes"),
  list(label = "cafe, bytes", value = marked(cafe_bytes, "bytes"), match = "marked as bytes")
)

# The same text in three forms that are each valid in their encoding.
valid_cafe <- list(
  latin1 = marked(c(0x63, 0x61, 0x66, 0xe9), "latin1"),
  utf8 = marked(cafe_bytes, "UTF-8"),
  unmarked = marked(cafe_bytes, "unknown")
)

expect_text_abort <- function(call, value, match, arg, info) {
  probe <- local_counting_probe()
  out <- collect_warnings(tryCatch(call(value), error = identity))
  err <- out$value
  expect_s3_class(err, "error")
  expect_false(inherits(err, "rlmstudio_no_server"), info = info)
  expect_identical(probe$calls, 0L, info = info)
  msg <- cli::ansi_strip(conditionMessage(err))
  expect_match(msg, paste0("`", arg, "`"), fixed = TRUE, info = info)
  expect_match(msg, match, fixed = TRUE, info = info)
  expect_no_match(msg, "whitespace", info = info)
  expect_identical(length(out$warnings), 0L, info = info)
  msg
}

for (pair in names(name_pairs)) {
  test_that(paste0(pair, " aborts on a string that is not valid text"), {
    skip_if_not(l10n_info()[["UTF-8"]], "needs a UTF-8 locale")
    call <- name_pairs[[pair]]
    arg <- pair_arg(pair)
    for (p in text_probes) {
      info <- paste(pair, "with", p$label)
      expect_text_abort(call, p$value, p$match, arg, info)
      if (arg == "type") {
        msg <- expect_text_abort(call, c("llm", p$value), p$match, arg, info)
        expect_match(msg, "Element 2", fixed = TRUE, info = info)
      }
    }
  })

  test_that(paste0(pair, " passes valid text in each encoding mark"), {
    skip_if_not(l10n_info()[["UTF-8"]], "needs a UTF-8 locale")
    call <- name_pairs[[pair]]
    for (form in names(valid_cafe)) {
      # Past the check, the stopped server is the abort.
      probe <- local_counting_probe()
      expect_error(
        call(valid_cafe[[form]]),
        class = "rlmstudio_no_server",
        info = paste(pair, "with cafe", form)
      )
      expect_identical(probe$calls, 1L, info = paste(pair, "with cafe", form))
    }
  })
}

# The function and argument of each call to the three check helpers in R/,
# read from the parsed sources. A new call site turns this red, which is the
# signal to add its pair to `name_pairs` above.
test_that("the pairs above are every call site of the three check helpers", {
  files <- list.files(test_path("..", "..", "R"), "\\.R$", full.names = TRUE)
  # Under R CMD check and covr there are no package sources here (LESSONS,
  # M005).
  skip_if(length(files) == 0L, "no package sources")
  helpers <- c("rlm_check_id", "rlm_check_response_id", "rlm_check_type")
  found <- character()
  walk <- function(expr, fn) {
    if (is.call(expr)) {
      head <- expr[[1]]
      if (is.name(head) && as.character(head) %in% helpers) {
        found <<- c(found, paste0(fn, "(", deparse(expr[[2]]), ")"))
      }
      # An empty argument, as in `x[, 1]`, arrives as a missing formal.
      lapply(as.list(expr)[-1], function(part) {
        if (!missing(part)) walk(part, fn)
      })
    }
  }
  for (file in files) {
    for (expr in parse(file, keep.source = FALSE)) {
      if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
          is.call(expr[[3]]) && identical(expr[[3]][[1]], as.name("function"))) {
        walk(expr[[3]][[3]], as.character(expr[[2]]))
      }
    }
  }
  expect_gt(length(found), 0L)
  expect_setequal(found, names(name_pairs))
})

# A name or id is sent as a plain string ------------------------------------

methods::setClass("rlmTestString", contains = "character")

# Each probe holds the value "m". `as.character()` on the class "foo" returns
# another value, so a plain string made by `as.character()` would show.
plain_probes <- list(
  "class foo" = structure("m", class = "foo"),
  "I()" = I("m"),
  "a name" = c(a = "m"),
  "S4" = methods::new("rlmTestString", "m")
)

# `one_loaded_llm` in test-list-args.R, with the key and the instance id "m".
model_m_loaded <- paste0(
  '{"models": [{"type": "llm", "key": "m", "display_name": "M", ',
  '"size_bytes": 1073741824, "loaded_instances": [{"id": "m"}]}]}'
)

download_status_reply <- '{"job_id": "m", "status": "downloading"}'

# For each pair: the replies to serve, the call, and the field that carries
# the argument. `field = NULL` means the URL path carries it. `sent` picks the
# requests that must carry it.
plain_pairs <- list(
  "lms_chat(model)" = list(
    replies = list(responses_reply()),
    call = function(v) lms_chat(v, "hi"),
    field = "model"
  ),
  "lms_chat_batch(model)" = list(
    replies = list(responses_reply(), responses_reply()),
    call = function(v) lms_chat_batch(v, c("first", "second"), quiet = TRUE),
    field = "model"
  ),
  "lms_chat_openresponses(model)" = list(
    replies = list(responses_reply()),
    call = function(v) lms_chat_openresponses(v, "hi"),
    field = "model"
  ),
  "lms_chat_openai(model)" = list(
    replies = list(openai_reply()),
    call = function(v) {
      lms_chat_openai(v, list(list(role = "user", content = "hi")))
    },
    field = "model"
  ),
  "lms_chat_native(model)" = list(
    replies = list(native_reply()),
    call = function(v) lms_chat_native(v, "hi"),
    field = "model"
  ),
  "lms_embed(model)" = list(
    replies = list(paste0(
      '{"object": "list", "model": "m", "data": ',
      '[{"object": "embedding", "index": 0, "embedding": [0.1, 0.2]}]}'
    )),
    call = function(v) lms_embed(v, "hi", quiet = TRUE),
    field = "model"
  ),
  "lms_load(model)" = list(
    replies = list('{"models": []}', '{"status": "loaded"}'),
    call = function(v) lms_load(v),
    field = "model",
    sent = 2L
  ),
  "lms_download(model)" = list(
    replies = list('{"job_id": "job-1", "status": "downloading"}'),
    call = function(v) lms_download(v),
    field = "model"
  ),
  "lms_unload(model)" = list(
    replies = list('{"status": "unloaded"}'),
    call = function(v) lms_unload(v),
    field = "instance_id"
  ),
  "lms_download_status(job_id)" = list(
    replies = list(download_status_reply),
    call = function(v) lms_download_status(v),
    field = NULL
  ),
  "lms_chat(previous_response_id)" = list(
    replies = list(responses_reply()),
    call = function(v) lms_chat("a-model", "hi", previous_response_id = v),
    field = "previous_response_id"
  ),
  "lms_chat_openresponses(previous_response_id)" = list(
    replies = list(responses_reply()),
    call = function(v) {
      lms_chat_openresponses("a-model", "hi", previous_response_id = v)
    },
    field = "previous_response_id"
  ),
  "lms_chat_native(previous_response_id)" = list(
    replies = list(native_reply()),
    call = function(v) {
      lms_chat_native("a-model", "hi", previous_response_id = v)
    },
    field = "previous_response_id"
  ),
  "lms_chat_batch(previous_response_id)" = list(
    replies = list(responses_reply(), responses_reply()),
    call = function(v) {
      lms_chat_batch(
        "a-model",
        c("first", "second"),
        quiet = TRUE,
        previous_response_id = v
      )
    },
    field = "previous_response_id"
  )
)

test_that("the plain-string pairs are the pairs of AC1 other than type", {
  expect_setequal(
    names(plain_pairs),
    grep("(type)", names(name_pairs), fixed = TRUE, invert = TRUE, value = TRUE)
  )
})

# Runs one pair on one probe and returns the value and the sent requests.
send_pair <- function(pair, value) {
  spec <- plain_pairs[[pair]]
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  testthat::local_mocked_s3_method(
    "as.character",
    "foo",
    function(x, ...) "other"
  )
  recorder <- local_request_sequence(
    lapply(spec$replies, function(body) mock_response(200L, body))
  )
  out <- suppressMessages(spec$call(value))
  list(value = out, requests = recorder$requests)
}

for (pair in names(plain_pairs)) {
  test_that(paste0(pair, " sends each probe as the plain string \"m\""), {
    spec <- plain_pairs[[pair]]
    for (label in names(plain_probes)) {
      info <- paste(pair, "with", label)
      sent <- send_pair(pair, plain_probes[[label]])
      expect_identical(
        length(sent$requests),
        length(spec$replies),
        info = info
      )
      picks <- if (is.null(spec$sent)) seq_along(sent$requests) else spec$sent
      for (req in sent$requests[picks]) {
        if (is.null(spec$field)) {
          expect_match(req$url, "/m$", info = info)
        } else {
          json <- request_body_text(req)
          # The field ends after the string, so "mm" does not match.
          expect_match(
            json,
            paste0('"', spec$field, '":"m"[,}]'),
            info = info
          )
          expect_identical(
            jsonlite::parse_json(json)[[spec$field]],
            "m",
            info = info
          )
        }
      }
    }
  })
}

test_that("lms_load() and lms_unload() return the plain string", {
  for (label in names(plain_probes)) {
    info <- paste("with", label)
    expect_identical(
      send_pair("lms_load(model)", plain_probes[[label]])$value,
      "m",
      info = paste("lms_load() load path", info)
    )
    expect_identical(
      send_pair("lms_unload(model)", plain_probes[[label]])$value,
      "m",
      info = paste("lms_unload()", info)
    )
  }
})

test_that("lms_load() returns the plain string on the already-loaded path", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  for (label in names(plain_probes)) {
    recorder <- local_request_sequence(list(mock_response(200L, model_m_loaded)))
    out <- suppressMessages(lms_load(plain_probes[[label]]))
    expect_identical(out, "m", info = label)
    # The model list alone: no load body went out.
    expect_identical(length(recorder$requests), 1L, info = label)
  }
})

test_that("a classed already_downloaded job id sends no HTTP request", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_no_request_allowed()
  out <- lms_download_status(structure("already_downloaded", class = "foo"))
  expect_s3_class(out, "lms_download_status")
  expect_identical(out$status, "already_downloaded")
})
