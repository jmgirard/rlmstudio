# Tests of the request body that a call sends. Unlike test-arg-guards.R, this
# file has no CRAN skip, so a CRAN check runs it. The helpers it shares
# with test-arg-guards.R are in helper-arg-guards.R.

# A reply that the route of `name` reads as text.
stream_reply <- function(name, route) {
  if (!is.null(route)) {
    name <- paste0("lms_chat_", route)
  }
  switch(
    name,
    lms_chat_openresponses = responses_reply(),
    lms_chat_openai = openai_reply(),
    lms_chat_native = native_reply()
  )
}

for (name in stream_domain()) {
  test_that(
    paste0(
      "stream = FALSE is sent and stream = NULL is left out by ",
      name,
      "()"
    ),
    {
      testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

      for (route in stream_routes(name)) {
        test_that(paste("route", deparse1(route)), {
          for (value in list(FALSE, NULL)) {
            test_that(paste("stream =", deparse1(value)), {
              dots <- list(stream = value)
              label <- stream_label(name, route, dots)
              recorder <- local_request_recorder(
                mock_response(200L, stream_reply(name, route))
              )
              # In a subtest, so testthat keeps a failure here in its results.
              test_that("the call", {
                expect_no_error(stream_call(name, route, dots))
                expected <- if (identical(name, "lms_chat_batch")) 2L else 1L
                expect_identical(
                  length(recorder$requests),
                  expected,
                  info = label
                )
              })
              for (i in seq_along(recorder$requests)) {
                test_that(paste("request", i, "of", label), {
                  body <- request_target(recorder$requests[[i]])$body
                  if (is.null(value)) {
                    expect_false("stream" %in% names(body), info = label)
                  } else {
                    expect_identical(body[["stream"]], FALSE, info = label)
                  }
                })
              }
            })
          }
        })
      }
    }
  )
}

test_that("a FALSE with names or attributes passes, as isFALSE() reads it", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  for (value in list(c(a = FALSE), structure(FALSE, foo = 1))) {
    test_that(deparse1(value), {
      label <- deparse1(value)
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(
        lms_chat_openai("a-model", arg_placeholders$messages, stream = value)
      )
      expect_identical(length(recorder$requests), 1L, info = label)
      body <- request_target(recorder$requests[[1]])$body
      expect_identical(body[["stream"]], FALSE, info = label)
    })
  }
})

# The messages field of the body a captured request sends, parsed back with no
# simplification, so a list of objects stays a list of lists.
sent_messages <- function(req) {
  out <- request_dry_run(req, redact_headers = FALSE)
  jsonlite::parse_json(rawToChar(out$body), simplifyVector = FALSE)$messages
}

# jsonlite writes a length-1 POSIXlt column in each row. The row-count rule
# does not read it, so it is sent with its one value in each message. The
# sent form is stated here by hand. With every other column NA, the empty-row
# rule reads its one NA cell in each row.
test_that("a length-1 POSIXlt column is read as jsonlite writes it", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  stamp <- as.POSIXlt("2026-01-01 12:00:00", tz = "UTC")
  sent <- df_of_rows(
    2L,
    role = c("user", "user"),
    content = c("a", "b"),
    t = stamp
  )
  recorder <- local_request_recorder(mock_response(200L, openai_reply()))
  out <- chat_openai_outcome(sent)
  expect_null(out$error)
  expect_identical(out$n_warnings, 0L)
  expect_identical(
    sent_messages(recorder$requests[[1]]),
    list(
      list(role = "user", content = "a", t = "2026-01-01 12:00:00"),
      list(role = "user", content = "b", t = "2026-01-01 12:00:00")
    )
  )

  probe <- local_counting_probe()
  empty <- df_of_rows(
    2L,
    role = c(NA_character_, NA_character_),
    t = as.POSIXlt(NA)
  )
  out <- chat_openai_outcome(empty)
  expect_identical(out$n_warnings, 0L)
  expect_match(
    conditionMessage(out$error),
    messages_rule_details[["rule6"]],
    fixed = TRUE
  )
  expect_identical(probe$calls, 0L)
})

# The rule reads the storage type, so each value below passes it. The sent
# form of each is stated here, as jsonlite writes it with the request's
# options. An S4 object whose class contains "numeric" is atomic, and
# jsonlite writes its data part.
test_that("values the non-vector rule passes reach the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  class_env <- new.env()
  numeric_generator <- methods::setClass(
    "rlmstudioM043Numeric",
    contains = "numeric",
    where = class_env
  )
  field <- function(v) list(list(role = "user", content = v))
  column <- function(name, v) {
    df <- data.frame(role = "user")
    df[[name]] <- v
    df
  }

  cases <- list(
    list(
      label = "a NULL field",
      value = field(NULL),
      sent = list(list(role = "user", content = NULL))
    ),
    list(
      label = "a NULL cell of a list column",
      value = local({
        df <- data.frame(role = "user")
        df$c <- I(list(NULL))
        df
      }),
      sent = list(list(role = "user", c = NULL))
    ),
    list(
      label = "a factor field",
      value = field(factor("a")),
      sent = list(list(role = "user", content = "a"))
    ),
    list(
      label = "a Date field",
      value = field(as.Date("2026-01-01")),
      sent = list(list(role = "user", content = "2026-01-01"))
    ),
    list(
      label = "a POSIXct column",
      value = column("t", as.POSIXct("2026-01-01", tz = "UTC")),
      sent = list(list(role = "user", t = "2026-01-01"))
    ),
    list(
      label = "a field wrapped in I()",
      value = field(I("x")),
      sent = list(list(role = "user", content = list("x")))
    ),
    list(
      label = "an atomic matrix field",
      value = field(matrix(1:4, 2)),
      sent = list(list(
        role = "user",
        content = list(list(1L, 3L), list(2L, 4L))
      ))
    ),
    list(
      label = "a list-matrix column",
      value = column("m", matrix(list(1, "a"), 1)),
      sent = list(list(role = "user", m = list(list(1L), list("a"))))
    ),
    list(
      label = "a data-frame column",
      value = column("sub", data.frame(a = 1)),
      sent = list(list(role = "user", sub = list(a = 1L)))
    ),
    list(
      label = "an S4 object whose class contains numeric",
      value = field(numeric_generator(1)),
      sent = list(list(role = "user", content = 1L))
    )
  )

  for (case in cases) {
    test_that(case$label, {
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(lms_chat_openai("a-model", case$value), message = NULL)
      expect_identical(
        sent_messages(recorder$requests[[1]]),
        case$sent,
        info = case$label
      )
    })
  }
})

test_that("numbers jsonlite leaves out, and classed values, still reach the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  # The body each place sends once jsonlite leaves `x` out of its row.
  left_out <- list(
    "the top level" = list(list(role = "user")),
    "a data-frame column" = list(list(role = "user", sub = list(k = "a"))),
    "a data frame as a list field" = list(
      list(role = "user", content = list(list(k = "a")))
    ),
    "a data frame in a list-column cell" = list(
      list(role = "user", c = list(list(k = "a")))
    )
  )
  missing_numbers <- list(
    "a double NA" = NA_real_,
    "NaN" = NaN,
    "an integer NA" = NA_integer_
  )
  for (number in names(missing_numbers)) {
    test_that(number, {
      for (place in names(plain_column_places)) {
        test_that(place, {
          label <- paste(number, "in a plain column at", place)
          recorder <- local_request_recorder(mock_response(
            200L,
            openai_reply()
          ))
          expect_no_error(
            lms_chat_openai(
              "a-model",
              plain_column_places[[place]](missing_numbers[[number]])
            ),
            message = NULL
          )
          expect_identical(
            sent_messages(recorder$requests[[1]]),
            left_out[[place]],
            info = label
          )
        })
      }
    })
  }

  classed <- list(
    list(label = "a Date NA", value = as.Date(NA), sent = NULL),
    list(label = "a POSIXct NA", value = as.POSIXct(NA), sent = NULL),
    list(label = "a factor NA", value = factor(NA), sent = NULL),
    list(label = "a character NA", value = NA_character_, sent = NULL),
    list(label = "a logical NA", value = NA, sent = NULL),
    list(label = "as.Date(Inf)", value = as.Date(Inf), sent = "Inf"),
    # Its gmtoff part is an integer NA, which the rule must not read.
    list(
      label = "a POSIXlt in a named zone",
      value = local({
        x <- as.POSIXlt("2026-01-01 10:00:00", tz = "America/Chicago")
        stopifnot(is.na(unclass(x)$gmtoff))
        x
      }),
      sent = "2026-01-01 10:00:00"
    )
  )
  for (case in classed) {
    test_that(case$label, {
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(
        lms_chat_openai(
          "a-model",
          list(list(role = "user", content = case$value))
        ),
        message = NULL
      )
      expect_identical(
        sent_messages(recorder$requests[[1]]),
        list(list(role = "user", content = case$sent)),
        info = case$label
      )
    })
  }
  # After the subtests, so testthat keeps a failure here in its results.
  expect_setequal(names(left_out), names(plain_column_places))
})

test_that("the number rule reads I() columns, 1-D arrays, and unwritable classed lists", {
  # An I() atomic column has no dim, so jsonlite leaves an NA cell out and
  # the rule refuses an Inf cell alone.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(200L, openai_reply()))
  expect_no_error(
    lms_chat_openai("a-model", data.frame(role = "user", x = I(NA_real_))),
    message = NULL
  )
  expect_identical(
    sent_messages(recorder$requests[[1]]),
    list(list(role = "user"))
  )
  expect_error(
    lms_chat_openai("a-model", data.frame(role = "user", x = I(Inf))),
    number_detail,
    fixed = TRUE
  )

  # A 1-D array column has a dim, so jsonlite writes an NA cell as "NA".
  df <- data.frame(role = "user")
  df$a <- array(NA_real_, 1L)
  expect_error(lms_chat_openai("a-model", df), number_detail, fixed = TRUE)

  # jsonlite cannot write this list, so the number rule does not read it and
  # the trial write refuses it.
  err <- expect_error(
    lms_chat_openai(
      "a-model",
      list(list(
        role = "user",
        content = structure(list(NA_real_), class = c("AsIs", "foo"))
      ))
    ),
    messages_rule_details[["rule10"]],
    fixed = TRUE
  )
  expect_no_match(conditionMessage(err), number_detail, fixed = TRUE)
})

test_that("a column with no cells in a row is not empty", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  nested_matrix <- local({
    inner <- data.frame(row.names = 1:2)
    inner$m <- matrix(numeric(0), 2L, 0L)
    inner
  })
  cases <- list(
    list(
      label = "a 2-by-0 numeric matrix",
      column = matrix(numeric(0), 2L, 0L),
      row2 = "[]"
    ),
    list(
      label = "a 2-by-0 character matrix",
      column = matrix(character(0), 2L, 0L),
      row2 = "[]"
    ),
    list(
      label = "a 2-by-0 list matrix",
      column = matrix(list(), 2L, 0L),
      row2 = "[]"
    ),
    list(
      label = "a 2-by-0-by-3 array",
      column = array(numeric(0), c(2L, 0L, 3L)),
      row2 = "[]"
    ),
    list(
      label = "a 2-by-3-by-0 array",
      column = array(numeric(0), c(2L, 3L, 0L)),
      row2 = "[[],[],[]]"
    ),
    list(
      label = "a data-frame column whose column is a 2-by-0 matrix",
      column = nested_matrix,
      row2 = '{"m":[]}'
    )
  )
  for (case in cases) {
    test_that(case$label, {
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(
        lms_chat_openai("a-model", no_cell_frame(case$column)),
        message = NULL
      )
      expected <- jsonlite::parse_json(
        paste0(
          '[{"role":"user","content":"Hi","x":',
          case$row2,
          '},{"x":',
          case$row2,
          "}]"
        ),
        simplifyVector = FALSE
      )
      expect_identical(
        sent_messages(recorder$requests[[1]]),
        expected,
        info = case$label
      )
    })
  }
})

first_msg <- list(role = "system", content = "Be brief.")

later_msg <- list(role = "user", content = "hi")

classed_sent <- list(first_msg, later_msg)

class_forms <- list(
  "an S3 class" = function(x) structure(x, class = "foo"),
  "a class vector of two entries" = function(x) {
    structure(x, class = c("foo", "bar"))
  },
  "the class \"list\"" = function(x) structure(x, class = "list"),
  "I()" = function(x) I(x)
)

test_that("a messages value that keeps every rule reaches the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  passes <- list(
    list(
      label = "a data frame with role and content",
      value = data.frame(
        role = c("system", "user"),
        content = c("Be brief.", "hi")
      ),
      sent = list(
        list(role = "system", content = "Be brief."),
        list(role = "user", content = "hi")
      )
    ),
    list(
      label = "a data frame with one column x",
      value = data.frame(x = "a"),
      sent = list(list(x = "a"))
    ),
    list(
      label = "string content",
      value = list(list(role = "user", content = "hi")),
      sent = list(list(role = "user", content = "hi"))
    ),
    list(
      label = "content parts",
      value = list(
        list(role = "user", content = list(list(type = "text", text = "hi")))
      ),
      sent = list(
        list(role = "user", content = list(list(type = "text", text = "hi")))
      )
    ),
    list(
      label = "number content",
      value = list(list(role = "user", content = 5)),
      sent = list(list(role = "user", content = 5L))
    ),
    list(
      label = "an I() field, sent as an array",
      value = list(list(role = I("user"), content = "hi")),
      sent = list(list(role = list("user"), content = "hi"))
    ),
    list(
      label = "a data frame with an NA cell in every row",
      value = data.frame(
        role = c("user", "user"),
        content = c(NA, "hi"),
        name = c("a", NA)
      ),
      sent = list(
        list(role = "user", name = "a"),
        list(role = "user", content = "hi")
      )
    ),
    list(
      label = "a data frame row with one cell that is not NA",
      value = data.frame(role = c("user", NA), content = c("hi", "yo")),
      sent = list(list(role = "user", content = "hi"), list(content = "yo"))
    ),
    # A list() cell is written as [] and a list(NA) cell as [null]. Both are
    # field values, so such a row is not empty.
    list(
      label = "a row of NA and a list() cell",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$content <- list("hi", list())
        df
      }),
      sent = list(list(role = "user", content = "hi"), list(content = list()))
    ),
    list(
      label = "a fully named nested list",
      value = list(list(role = "user", content = list(a = "x", b = "y"))),
      sent = list(list(role = "user", content = list(a = "x", b = "y")))
    ),
    list(
      label = "an unnamed nested list",
      value = list(list(role = "user", content = list("x", "y"))),
      sent = list(list(role = "user", content = list("x", "y")))
    ),
    # jsonlite does not write the names of a list column, so they are not
    # read, even when one of them is empty.
    list(
      label = "a list column with names, one of them empty",
      value = local({
        df <- data.frame(role = c("user", "user"))
        df$content <- list(p = "hi", "yo")
        stopifnot(identical(names(df$content), c("p", "")))
        df
      }),
      sent = list(
        list(role = "user", content = "hi"),
        list(role = "user", content = "yo")
      )
    ),
    # is.na() on the whole data frame spreads the matrix over two columns, so
    # a rule that reads it by column position looks at the wrong cells.
    list(
      label = "a NULL list cell after a matrix column, and a later value",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$m <- matrix(c("x", NA, "y", NA), 2)
        df$content <- list("hi", NULL)
        df$name <- c("a", "b")
        df
      }),
      sent = list(
        list(role = "user", m = list("x", "y"), content = "hi", name = "a"),
        list(m = list(NULL, NULL), content = NULL, name = "b")
      )
    ),
    list(
      label = "a row of NA and a list(NA) cell",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$content <- list("hi", list(NA))
        df
      }),
      sent = list(
        list(role = "user", content = "hi"),
        list(content = list(NULL))
      )
    ),
    # A list-matrix column is read per row, so a NULL cell beside a value in
    # the same row leaves the row with a field value.
    list(
      label = "a row of NA and a list-matrix row with one value",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$m <- matrix(list(1, NULL, NULL, 2), 2)
        df
      }),
      sent = list(
        list(role = "user", m = list(list(1L), NULL)),
        list(m = list(NULL, list(2L)))
      )
    ),
    list(
      label = "a tibble-classed data frame",
      value = structure(
        data.frame(role = c("system", "user"), content = c("Be brief.", "hi")),
        class = c("tbl_df", "tbl", "data.frame")
      ),
      sent = classed_sent
    ),
    list(
      label = "a foo-classed data frame",
      value = structure(
        data.frame(role = c("system", "user"), content = c("Be brief.", "hi")),
        class = c("foo", "data.frame")
      ),
      sent = classed_sent
    )
  )
  # A class on the outer list or on a message is removed before the body is
  # built. Each form sits at the outer level and on a later message, and one
  # S3 class also sits on the first message and on both levels at once.
  for (form in names(class_forms)) {
    add <- class_forms[[form]]
    passes <- c(
      passes,
      list(
        list(
          label = paste(form, "on the outer list"),
          value = add(list(first_msg, later_msg)),
          sent = classed_sent
        ),
        list(
          label = paste(form, "on a later message"),
          value = list(first_msg, add(later_msg)),
          sent = classed_sent
        )
      )
    )
  }
  passes <- c(
    passes,
    list(
      list(
        label = "an S3 class on the first message",
        value = list(structure(first_msg, class = "foo"), later_msg),
        sent = classed_sent
      ),
      list(
        label = "an S3 class on both levels",
        value = structure(
          list(structure(first_msg, class = "foo"), later_msg),
          class = "foo"
        ),
        sent = classed_sent
      )
    )
  )

  for (p in passes) {
    test_that(p$label, {
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(lms_chat_openai("a-model", p$value))
      expect_identical(length(recorder$requests), 1L, info = p$label)
      expect_identical(
        sent_messages(recorder$requests[[1]]),
        p$sent,
        info = p$label
      )
    })
  }
})

# The list-array rule leaves an atomic matrix field and a list-matrix column
# of any data frame alone, and the function rule leaves a message with no
# function alone. Each value below reaches the request.
test_that("matrix forms the list-array rule allows reach the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  top <- data.frame(role = "user")
  top$m <- matrix(list("a", "b"), 1)
  inner <- data.frame(a = 1)
  inner$m <- matrix(list("a", "b"), 1)
  nested <- data.frame(role = "user")
  nested$sub <- inner

  cases <- list(
    list(
      label = "a message with a nested list and no function",
      value = list(list(
        role = "user",
        content = list(list(type = "text", text = "hi"))
      )),
      sent = list(list(
        role = "user",
        content = list(list(type = "text", text = "hi"))
      ))
    ),
    list(
      label = "an atomic matrix field",
      value = list(list(role = "user", m = matrix(1:4, 2))),
      sent = list(list(role = "user", m = list(list(1L, 3L), list(2L, 4L))))
    ),
    list(
      label = "a list-matrix column",
      value = top,
      sent = list(list(role = "user", m = list(list("a"), list("b"))))
    ),
    list(
      label = "a list-matrix column of a nested data frame",
      value = nested,
      sent = list(list(
        role = "user",
        sub = list(a = 1L, m = list(list("a"), list("b")))
      ))
    ),
    list(
      label = "a data-frame field with a list-matrix column",
      value = list(list(role = "user", content = inner)),
      sent = list(list(
        role = "user",
        content = list(list(a = 1L, m = list(list("a"), list("b"))))
      ))
    )
  )

  for (case in cases) {
    test_that(case$label, {
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(lms_chat_openai("a-model", case$value), message = NULL)
      expect_identical(
        sent_messages(recorder$requests[[1]]),
        case$sent,
        info = case$label
      )
    })
  }
})

# The lms_chat_openai() help gives the sent form of one list-matrix row. The
# form is stated here as JSON text, so a change to what jsonlite sends turns
# the test red. A boxed value parses back as a list, so the comparison sees
# the boxing.
test_that("a list-matrix column is sent with its cells boxed", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  help_row <- data.frame(role = "user", content = "hi")
  help_row$tags <- matrix(list("a", NULL, list(k = "v")), 1)
  help_form <- '{"role":"user","content":"hi","tags":[["a"],null,{"k":["v"]}]}'

  # unbox() unboxes a cell and a value in a list at any depth. A data frame
  # in a cell is sent as an array of objects with its values not boxed.
  other_row <- data.frame(role = "user")
  other_row$m <- matrix(
    list(
      jsonlite::unbox("a"),
      list(list(z = 1)),
      list(q = jsonlite::unbox("b")),
      data.frame(k = "v")
    ),
    1
  )
  other_form <- '{"role":"user","m":["a",[{"z":[1]}],{"q":"b"},[{"k":"v"}]]}'

  cases <- list(
    list(label = "the help example", value = help_row, form = help_form),
    list(label = "unbox and a data frame", value = other_row, form = other_form)
  )
  for (case in cases) {
    test_that(case$label, {
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(lms_chat_openai("a-model", case$value))
      expect_identical(
        sent_messages(recorder$requests[[1]]),
        list(jsonlite::parse_json(case$form, simplifyVector = FALSE)),
        info = case$label
      )
    })
  }
})

# A three-dimensional atomic column with one NA in a row passes the empty-row
# rule. jsonlite sends that NA as null in a character or logical column. A
# numeric one aborts under the number rule, which the test "a number jsonlite
# cannot send as a number aborts" in test-arg-guards.R covers.
test_that("an NA in a three-dimensional logical or character column is sent as null", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  array_row <- function(values) {
    df <- data.frame(role = c("user", "user"))
    df$x <- array(values, c(2L, 2L, 2L))
    df
  }
  cases <- list(
    list(
      label = "logical",
      value = array_row(c(TRUE, NA, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE)),
      form = '[{"role":"user","x":[[true,true],[true,true]]},{"role":"user","x":[[null,true],[true,true]]}]'
    ),
    list(
      label = "character",
      value = array_row(c("a", NA, "c", "d", "e", "f", "g", "h")),
      form = '[{"role":"user","x":[["a","e"],["c","g"]]},{"role":"user","x":[[null,"f"],["d","h"]]}]'
    )
  )
  for (case in cases) {
    test_that(case$label, {
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(lms_chat_openai("a-model", case$value))
      expect_identical(
        sent_messages(recorder$requests[[1]]),
        jsonlite::parse_json(case$form, simplifyVector = FALSE),
        info = case$label
      )
    })
  }
})

test_that("a Date, a factor, and an I() field reach the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  recorder <- local_request_recorder(mock_response(200L, openai_reply()))
  expect_no_error(lms_chat_openai(
    "a-model",
    list(list(
      role = I("user"),
      content = factor("hi"),
      date = as.Date("2026-01-01")
    ))
  ))
  expect_identical(
    sent_messages(recorder$requests[[1]]),
    list(list(role = list("user"), content = "hi", date = "2026-01-01"))
  )
})

# The request sends the text that jsonlite writes from the body, with the
# options of the trial write. httr2 1.3.0 req_body_json() rebuilt each list
# first: it dropped a zero-width matrix or array column, sent a 2-by-0 list
# matrix as null, and recursed with no end on a POSIXlt value. The 2-by-2
# matrix was sent this way before the change and stays a control.
test_that("messages reach the request as jsonlite writes them", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  lt <- as.POSIXlt("2020-01-01 10:00:00", tz = "UTC")
  frame <- function(column) {
    df <- data.frame(role = c("user", "user"), content = c("Hi", "Yo"))
    df$x <- column
    df
  }
  field <- function(value) list(list(role = "user", content = "Hi", x = value))
  zero_width_frame <- function() {
    inner <- data.frame(a = 1:2)
    inner$a <- NULL
    inner$m <- matrix(numeric(), 2L, 0L)
    inner
  }

  cases <- list(
    "a 2-by-0 numeric matrix column" = frame(matrix(numeric(), 2L, 0L)),
    "a 2-by-0 character matrix column" = frame(matrix(character(), 2L, 0L)),
    "a 2-by-0 list matrix column" = frame(matrix(list(), 2L, 0L)),
    "a 2-by-3-by-0 array column" = frame(array(numeric(), c(2L, 3L, 0L))),
    "a data-frame column holding a 2-by-0 matrix" = frame(zero_width_frame()),
    "a POSIXlt column" = frame(as.POSIXlt(
      c("2020-01-01 10:00:00", "2020-01-02 10:00:00"),
      tz = "UTC"
    )),
    "a 2-by-2 numeric matrix column" = frame(matrix(c(1, 2, 3, 4), 2L)),
    "a POSIXlt field" = field(lt),
    "a data-frame field holding a 2-by-0 matrix" = field(zero_width_frame()),
    "a list field whose first element is POSIXlt" = field(list(lt, 1))
  )

  for (label in names(cases)) {
    test_that(label, {
      value <- cases[[label]]
      recorder <- local_request_recorder(mock_response(200L, openai_reply()))
      expect_no_error(lms_chat_openai("a-model", value), message = NULL)
      expected <- as.character(jsonlite::toJSON(
        list(model = "a-model", messages = value),
        auto_unbox = TRUE,
        digits = 22,
        null = "null"
      ))
      sent <- tryCatch(
        request_body_text(recorder$requests[[1]], seconds = 10),
        error = function(e) paste("no body:", conditionMessage(e))
      )
      expect_identical(sent, expected, info = label)
    })
  }

  # Two sent forms stated by hand, so the check does not rest on jsonlite
  # alone.
  recorder <- local_request_recorder(mock_response(200L, openai_reply()))
  lms_chat_openai("a-model", cases[["a 2-by-0 list matrix column"]])
  expect_match(
    request_body_text(recorder$requests[[1]]),
    '{"role":"user","content":"Hi","x":[]}',
    fixed = TRUE
  )
  recorder <- local_request_recorder(mock_response(200L, openai_reply()))
  lms_chat_openai("a-model", cases[["a POSIXlt field"]])
  expect_match(
    tryCatch(
      request_body_text(recorder$requests[[1]], seconds = 10),
      error = function(e) conditionMessage(e)
    ),
    '"x":"2020-01-01 10:00:00"',
    fixed = TRUE
  )
})
