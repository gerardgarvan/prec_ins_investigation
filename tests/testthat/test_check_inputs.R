# tests/testthat/test_check_inputs.R
# Behavioral tests for preflight checker functions: check_file_ci and read_header_cols
# Tests verify case-insensitive file finding and header extraction with fallback behavior

library(testthat)
Sys.setenv(PIPELINE_TEST = "TRUE")
source(here::here("R", "00_check_inputs.R"))

test_that("check_file_ci finds file with case-mismatched query", {
  tmp <- tempfile(); dir.create(tmp)
  file.create(file.path(tmp, "icd10_groups2.sas7bdat"))
  res <- check_file_ci(tmp, "ICD10_GROUPS2.SAS7BDAT")
  expect_true(res$found)
  expect_equal(res$disk_name, "icd10_groups2.sas7bdat")
})

test_that("check_file_ci returns found=FALSE for non-existent directory", {
  res <- check_file_ci("/no/such/dir/abc123", "anything.sas7bdat")
  expect_false(res$found)
  expect_true(is.na(res$disk_name))
})

test_that("check_file_ci returns found=FALSE when file absent from existing dir", {
  tmp <- tempfile(); dir.create(tmp)
  res <- check_file_ci(tmp, "ghost.sas7bdat")
  expect_false(res$found)
})

test_that("read_header_cols returns character(0) when reader throws", {
  # Mock read_sas to throw
  local_mocked_bindings(
    read_sas = function(...) stop("simulated read error"),
    .package = "haven"
  )
  result <- read_header_cols("/fake/path.sas7bdat")
  expect_equal(result, character(0))
})

test_that("read_header_cols falls back to n_max=1 when n_max=0 returns rows", {
  call_count <- 0L
  local_mocked_bindings(
    read_sas = function(path, n_max, ...) {
      call_count <<- call_count + 1L
      if (n_max == 0) return(data.frame(a = 1, b = 2))  # simulate non-zero return
      data.frame(a = integer(0), b = integer(0))          # n_max=1 but discard
    },
    .package = "haven"
  )
  result <- read_header_cols("/fake/path.sas7bdat")
  expect_equal(call_count, 2L)
  expect_equal(sort(result), c("a", "b"))
})
