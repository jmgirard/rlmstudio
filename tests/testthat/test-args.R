# tests/testthat/test-args.R

# --- Chat Args ---

test_that("build_args_model_chat constructs correct vectors", {
  # Default
  expect_equal(build_args_model_chat(), "chat")

  # Positional model and prompt
  expect_equal(
    build_args_model_chat(model = "llama3", prompt = "Hello"),
    c("chat", "llama3", "--prompt", "Hello")
  )

  # All flags
  expect_equal(
    build_args_model_chat(
      model = "model-x", prompt = "Hi", system_prompt = "Sys", stats = TRUE, ttl = 60
    ),
    c("chat", "model-x", "--prompt", "Hi", "--system-prompt", "Sys", "--stats", "--ttl", "60")
  )
})


# --- Model Args ---

test_that("build_args_model_ls constructs correct vectors", {
  expect_equal(build_args_model_ls(), "ls")
  expect_equal(
    build_args_model_ls(llm = TRUE, json = TRUE, host = "localhost"),
    c("ls", "--llm", "--json", "--host", "localhost")
  )
})

test_that("build_args_model_ps constructs correct vectors", {
  expect_equal(build_args_model_ps(), "ps")
  expect_equal(
    build_args_model_ps(json = TRUE, host = "127.0.0.1"),
    c("ps", "--json", "--host", "127.0.0.1")
  )
})

test_that("build_args_model_get constructs correct vectors", {
  expect_equal(build_args_model_get(), "get")
  expect_equal(
    build_args_model_get(model_name = "llama", mlx = TRUE, limit = 5, always_show_download_options = TRUE),
    c("get", "llama", "--mlx", "--limit", "5", "-a")
  )
})

test_that("build_args_model_load constructs correct vectors", {
  expect_equal(build_args_model_load(), "load")
  expect_equal(
    build_args_model_load(model = "llama", ttl = 300, gpu = "max", estimate_only = TRUE),
    c("load", "llama", "--ttl", "300", "--gpu", "max", "--estimate-only")
  )
})

test_that("build_args_model_unload constructs correct vectors", {
  expect_equal(build_args_model_unload(), "unload")
  expect_equal(
    build_args_model_unload(model = "llama", all = TRUE, host = "local"),
    c("unload", "llama", "--all", "--host", "local")
  )
})

test_that("build_args_model_import constructs correct vectors", {
  # Requires file_path, so default doesn't apply
  expect_equal(
    build_args_model_import("file.gguf", action = "move"),
    c("import", "file.gguf") # "move" is default, no flag added
  )
  expect_equal(
    build_args_model_import("file.gguf", user_repo = "org/repo", yes = TRUE, action = "copy", dry_run = TRUE),
    c("import", "file.gguf", "--user-repo", "org/repo", "--yes", "--dry-run", "--copy")
  )
})


# --- Runtime Args ---

test_that("build_args_runtime_ls constructs correct vectors", {
  expect_equal(build_args_runtime_ls(), c("runtime", "ls"))
  expect_equal(build_args_runtime_ls(json = TRUE), c("runtime", "ls", "--json"))
})

test_that("build_args_runtime_get constructs correct vectors", {
  expect_equal(build_args_runtime_get(), c("runtime", "get"))
  expect_equal(build_args_runtime_get("llama.cpp"), c("runtime", "get", "llama.cpp"))
})

test_that("build_args_runtime_select constructs correct vectors", {
  expect_equal(build_args_runtime_select(), c("runtime", "select"))
  expect_equal(build_args_runtime_select("mlx"), c("runtime", "select", "mlx"))
})

test_that("build_args_runtime_update constructs correct vectors", {
  expect_equal(build_args_runtime_update(), c("runtime", "update"))
  expect_equal(build_args_runtime_update("onnx"), c("runtime", "update", "onnx"))
})

test_that("build_args_runtime_remove constructs correct vectors", {
  expect_equal(build_args_runtime_remove(), c("runtime", "remove"))
  expect_equal(build_args_runtime_remove("llama.cpp"), c("runtime", "remove", "llama.cpp"))
})


# --- Server Args ---

test_that("build_args_server_start constructs correct vectors", {
  expect_equal(build_args_server_start(), c("server", "start"))
  expect_equal(
    build_args_server_start(port = 1234, cors = TRUE),
    c("server", "start", "--port", "1234", "--cors")
  )
})

test_that("build_args_server_stop constructs correct vectors", {
  expect_equal(build_args_server_stop(), c("server", "stop"))
})

test_that("build_args_server_status constructs correct vectors", {
  expect_equal(build_args_server_status(), c("server", "status"))
  expect_equal(
    build_args_server_status(json = TRUE, log_level = "debug"),
    c("server", "status", "--json", "--log-level", "debug")
  )
})


# --- Stream Args ---

test_that("build_args_log_stream constructs correct vectors", {
  # Default
  expect_equal(build_args_log_stream(source = "model"), c("log", "stream"))

  # With server source and filters
  expect_equal(
    build_args_log_stream(source = "server", filter = c("input", "output"), stats = TRUE, json = TRUE),
    c("log", "stream", "--source", "server", "--filter", "input,output", "--stats", "--json")
  )
})
