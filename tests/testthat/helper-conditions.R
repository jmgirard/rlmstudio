# Run `expr` and return its value with every warning it gave, as condition
# objects, so a test can read each warning's class. Each warning is muffled.
collect_warnings <- function(expr) {
  warnings <- list()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = warnings)
}

# The warnings of `warnings` that carry `class`.
warnings_of_class <- function(warnings, class) {
  Filter(function(w) inherits(w, class), warnings)
}
