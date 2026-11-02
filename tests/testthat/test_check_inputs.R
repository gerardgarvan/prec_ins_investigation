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

# ============================================================
# Task 3: run_preflight() severity, INCOMPLETE, and report tests
# These tests FAIL until run_preflight() is implemented.
# ============================================================

test_that("FAIL for imported table with missing file", {
  tmp_mfst <- tempfile(fileext = ".csv")
  tmp_raw  <- tempfile(); dir.create(tmp_raw)
  tmp_rpt  <- tempfile(); dir.create(tmp_rpt)
  write.csv(data.frame(
    alias = "v3", table_group = "GROUP 1",
    sas_filename = "demo_fake.sas7bdat",
    hipergator_path = tmp_raw, r_import_call = "import_and_save",
    r_checkpoint_rds = "01_imported_demo.rds",
    expected_raw_cols = "ALL", downstream_consumers = "02_clean.R",
    manifest_status = "ok", r_import_name = "demo_fake.sas7bdat",
    disk_name = NA, notes = ""
  ), tmp_mfst, row.names = FALSE)
  res <- run_preflight(tmp_mfst, tmp_raw, character(0), tmp_rpt, write_reports = FALSE)
  expect_true(any(res$check_result == "FAIL"))
  expect_equal(attr(res, "overall"), "FAIL")
})

test_that("WARN (not FAIL) for missing_in_r table that is absent", {
  tmp_mfst <- tempfile(fileext = ".csv")
  tmp_raw  <- tempfile(); dir.create(tmp_raw)
  tmp_rpt  <- tempfile(); dir.create(tmp_rpt)
  write.csv(data.frame(
    alias = "dx", table_group = "WARN",
    sas_filename = "ndc_cond2.sas7bdat",
    hipergator_path = tmp_raw, r_import_call = NA,
    r_checkpoint_rds = NA, expected_raw_cols = NA,
    downstream_consumers = NA,
    manifest_status = "missing_in_r",
    r_import_name = "ndc_cond2.sas7bdat", disk_name = NA, notes = ""
  ), tmp_mfst, row.names = FALSE)
  res <- run_preflight(tmp_mfst, tmp_raw, character(0), tmp_rpt, write_reports = FALSE)
  expect_true(any(res$check_result == "WARN"))
  expect_false(any(res$check_result == "FAIL"))
  expect_equal(attr(res, "overall"), "PASS")
})

test_that("INCOMPLETE for imported table when directory does not exist", {
  tmp_mfst <- tempfile(fileext = ".csv")
  tmp_raw  <- "/no/such/dir/xyz987abc"
  tmp_rpt  <- tempfile(); dir.create(tmp_rpt)
  write.csv(data.frame(
    alias = "v3", table_group = "GROUP 1",
    sas_filename = "demo_fake.sas7bdat",
    hipergator_path = tmp_raw, r_import_call = "import_and_save",
    r_checkpoint_rds = NA, expected_raw_cols = "ALL",
    downstream_consumers = NA, manifest_status = "ok",
    r_import_name = "demo_fake.sas7bdat", disk_name = NA, notes = ""
  ), tmp_mfst, row.names = FALSE)
  res <- run_preflight(tmp_mfst, tmp_raw, character(0), tmp_rpt, write_reports = FALSE)
  expect_true(any(res$check_result == "INCOMPLETE"))
  expect_false(any(res$check_result == "FAIL"))
  expect_equal(attr(res, "overall"), "INCOMPLETE")
})

test_that("case-only match is FAIL for imported table", {
  tmp_raw  <- tempfile(); dir.create(tmp_raw)
  file.create(file.path(tmp_raw, "icd10_groups2.sas7bdat"))
  tmp_mfst <- tempfile(fileext = ".csv")
  tmp_rpt  <- tempfile(); dir.create(tmp_rpt)
  write.csv(data.frame(
    alias = "dx", table_group = "GROUP 7",
    sas_filename = "Icd10_groups2.sas7bdat",
    hipergator_path = tmp_raw, r_import_call = "import_sas",
    r_checkpoint_rds = "01_imported_icd_groups.rds",
    expected_raw_cols = "ALL", downstream_consumers = "02_clean.R",
    manifest_status = "must_verify",
    r_import_name = "Icd10_groups2.sas7bdat",
    disk_name = "icd10_groups2.sas7bdat", notes = ""
  ), tmp_mfst, row.names = FALSE)
  res <- run_preflight(tmp_mfst, tmp_raw, tmp_raw, tmp_rpt, write_reports = FALSE)
  expect_true(any(res$check_result == "FAIL"))
})

test_that("dx probes produce one result row per candidate path", {
  tmp_mfst <- tempfile(fileext = ".csv")
  tmp_rpt  <- tempfile(); dir.create(tmp_rpt)
  write.csv(data.frame(
    alias = "dx", table_group = "GROUP 7",
    sas_filename = "Icd10_groups2.sas7bdat",
    hipergator_path = "multiple", r_import_call = "import_sas",
    r_checkpoint_rds = NA, expected_raw_cols = "ALL",
    downstream_consumers = NA, manifest_status = "must_verify",
    r_import_name = "Icd10_groups2.sas7bdat", disk_name = NA, notes = ""
  ), tmp_mfst, row.names = FALSE)
  fake_dirs <- c(tempfile(), tempfile(), tempfile())
  res <- run_preflight(tmp_mfst, tempfile(), fake_dirs, tmp_rpt, write_reports = FALSE)
  icd_rows <- res[grepl("Icd10_groups2", res$sas_filename, ignore.case = TRUE), ]
  expect_equal(nrow(icd_rows), length(fake_dirs))
})

test_that("run_preflight writes both report files", {
  tmp_mfst <- tempfile(fileext = ".csv")
  tmp_raw  <- tempfile(); dir.create(tmp_raw)
  tmp_rpt  <- tempfile(); dir.create(tmp_rpt)
  write.csv(data.frame(
    alias = "v3", table_group = "GROUP 1",
    sas_filename = "demo.sas7bdat",
    hipergator_path = tmp_raw, r_import_call = "import_and_save",
    r_checkpoint_rds = NA, expected_raw_cols = "ALL",
    downstream_consumers = NA, manifest_status = "must_verify",
    r_import_name = "demo.sas7bdat", disk_name = NA, notes = ""
  ), tmp_mfst, row.names = FALSE)
  run_preflight(tmp_mfst, tmp_raw, character(0), tmp_rpt, write_reports = TRUE)
  expect_true(file.exists(file.path(tmp_rpt, "preflight_report.txt")))
  expect_true(file.exists(file.path(tmp_rpt, "preflight_report.csv")))
  txt <- readLines(file.path(tmp_rpt, "preflight_report.txt"))
  expect_true(any(grepl("OVERALL:", txt)))
  expect_true(any(grepl("MUST VERIFY ON HIPERGATOR", txt, ignore.case = TRUE)))
})
