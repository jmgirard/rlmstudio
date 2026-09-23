# Helpers for the shape tests of status-200 reply bodies. The bodies are built
# as JSON text, so each fault keeps the exact JSON form under test.

# JSON literals, one per form a field can take.
json_forms <- c(
  number = "1",
  string = '"a"',
  boolean = "true",
  "empty array" = "[]",
  array = '["a"]',
  "empty object" = "{}",
  object = '{"a": 1}',
  null = "null"
)

# Build a JSON object from a named character vector of JSON literals. `drop`
# leaves a field out. `extend` writes the field under its name plus "X".
shape_object <- function(fields, drop = NULL, extend = NULL) {
  keys <- names(fields)
  keys[keys %in% extend] <- paste0(keys[keys %in% extend], "X")
  keep <- !names(fields) %in% drop
  if (!any(keep)) {
    return("{}")
  }
  paste0(
    "{",
    paste0('"', keys[keep], '": ', fields[keep], collapse = ", "),
    "}"
  )
}

shape_array <- function(items) paste0("[", paste(items, collapse = ", "), "]")

# The condition a call raises, or NULL when it returns.
shape_raised_by <- function(expr) {
  tryCatch({
    expr
    NULL
  }, error = identity)
}
