# tests/testthat/test_utils_import.R
# Tests for read_checkpoint() id -> patid migration (R/utils_import.R).
# Guards against the HiPerGator 02_clean.R failure where stale checkpoints
# carried `id` instead of `patid`.

library(testthat)

# Source only the helper definition; utils_import.R runs library() calls at the
# top (haven, janitor, purrr, dplyr) which are available in the test env.
source(testthat::test_path("..", "..", "R", "utils_import.R"))

test_that("read_checkpoint renames id -> patid when only id present", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(data.frame(id = c("A", "B"), x = 1:2, stringsAsFactors = FALSE), tmp)

  out <- read_checkpoint(tmp)
  expect_true("patid" %in% names(out))
  expect_false("id" %in% names(out))
  expect_equal(out$patid, c("A", "B"))
  expect_equal(out$x, 1:2)
})

test_that("read_checkpoint leaves patid untouched when already present", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(data.frame(patid = c("A", "B"), x = 1:2, stringsAsFactors = FALSE), tmp)

  out <- read_checkpoint(tmp)
  expect_equal(out$patid, c("A", "B"))
  expect_false("id" %in% names(out))
})

test_that("read_checkpoint errors when both id and patid are present", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(data.frame(id = "A", patid = "A", x = 1, stringsAsFactors = FALSE), tmp)

  expect_error(read_checkpoint(tmp), "ambiguous")
})
