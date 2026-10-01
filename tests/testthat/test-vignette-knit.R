# Tests that each knitted vignette matches its source. `data-raw/knit-vignettes.R`
# ends each `vignettes/<name>.Rmd` with a line that holds the MD5 sum of its
# `vignettes/<name>.Rmd.orig` source. An edit to a source after its knit
# changes the sum. The sources do not ship to R CMD check, so there the test
# finds no source and skips.

# The MD5 sum that the knit stamp of `target` holds, or NA if the file has no
# stamp.
knit_stamp <- function(target) {
  lines <- readLines(target, warn = FALSE)
  pattern <- "^<!-- Knitted from .+ with MD5 ([0-9a-f]{32})\\. -->$"
  hits <- grep(pattern, lines, value = TRUE)
  if (length(hits) == 0) {
    return(NA_character_)
  }
  sub(pattern, "\\1", hits[[length(hits)]])
}

test_that("each knitted vignette holds the MD5 sum of its source", {
  sources <- list.files(
    testthat::test_path("../../vignettes"),
    pattern = "\\.Rmd\\.orig$",
    full.names = TRUE
  )
  skip_if(length(sources) == 0, "No vignette sources to compare.")

  for (source in sources) {
    test_that(paste("the knit of", basename(source), "is current"), {
      target <- sub("\\.orig$", "", source)
      name <- basename(source)
      if (!file.exists(target)) {
        fail(paste0(name, " has no knitted .Rmd. Run data-raw/knit-vignettes.R."))
        return()
      }
      stamp <- knit_stamp(target)
      if (is.na(stamp)) {
        fail(paste0(
          "The .Rmd of ", name, " holds no source MD5 sum. ",
          "Run data-raw/knit-vignettes.R."
        ))
        return()
      }
      expect(
        identical(stamp, unname(tools::md5sum(source))),
        paste0(
          name, " changed after its knit. ",
          "Run data-raw/knit-vignettes.R on it."
        )
      )
    })
  }
})
