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

# ============================================================
# Task 2: CSV-validation tests (added after scaffold)
# These tests FAIL until docs/file_manifest.csv and
# docs/column_lineage.csv are populated.
# ============================================================

test_that("file_manifest.csv has 20 imported-file rows (one per physical file)", {
  m <- read.csv(here::here("docs", "file_manifest.csv"), stringsAsFactors = FALSE)
  expect_gte(sum(m$manifest_status %in% c("ok", "mismatch", "must_verify")), 20L)
})

test_that("file_manifest.csv statuses are valid", {
  m <- read.csv(here::here("docs", "file_manifest.csv"), stringsAsFactors = FALSE)
  expect_true(all(m$manifest_status %in% c("ok", "missing_in_r", "unused", "mismatch", "must_verify")))
})

test_that("Icd10_groups2 row has must_verify status and notes mention case", {
  m <- read.csv(here::here("docs", "file_manifest.csv"), stringsAsFactors = FALSE)
  icd <- m[grepl("Icd10_groups2", m$sas_filename, ignore.case = TRUE), ]
  expect_gte(nrow(icd), 1L)
  expect_true(all(icd$manifest_status == "must_verify"))
  expect_true(any(grepl("case", icd$notes, ignore.case = TRUE)))
})

test_that("WARN-tier tables present in manifest", {
  m <- read.csv(here::here("docs", "file_manifest.csv"), stringsAsFactors = FALSE)
  warn <- m[m$manifest_status == "missing_in_r", ]
  expect_true(any(grepl("ndc_cond2", warn$sas_filename, ignore.case = TRUE)))
  expect_true(any(grepl("surgerycodes", warn$sas_filename, ignore.case = TRUE)))
  expect_true(any(grepl("sctcodes", warn$sas_filename, ignore.case = TRUE)))
})

test_that("column_lineage.csv origins are valid", {
  cl <- read.csv(here::here("docs", "column_lineage.csv"), stringsAsFactors = FALSE)
  expect_gte(nrow(cl), 30L)
  expect_true(all(cl$origin %in% c("raw", "renamed", "derived")))
})

test_that("D-11 broken-pipe candidates all present in column_lineage", {
  cl <- read.csv(here::here("docs", "column_lineage.csv"), stringsAsFactors = FALSE)
  needed <- c("first_can_ruca", "first_can_sdi_score", "any_reportable_cancer",
              "group_site", "patid", "source")
  expect_true(all(needed %in% cl$column))
})
