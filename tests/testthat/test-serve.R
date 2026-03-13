test_that("build_args_server_start constructs correct arguments", {
  expect_equal(build_args_server_start(), c("server", "start"))
  expect_equal(
    build_args_server_start(port = 3000, cors = TRUE),
    c("server", "start", "--port", "3000", "--cors")
  )
})

test_that("build_args_server_status handles logging flags", {
  expect_equal(
    build_args_server_status(json = TRUE, quiet = TRUE),
    c("server", "status", "--json", "--quiet")
  )
})
