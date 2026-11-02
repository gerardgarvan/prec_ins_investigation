# tests/testthat/test_equivalence.R
# Verifies that the new per-part dx aggregation path (02_dx_encounter.rds) gives
# the same any_reportable_cancer, icd_personal_trt, cancer_dx, and group_site
# per (patid, encounterid) as the old full-join logic, when run on the same
# synthetic fixtures in tests/testdata/processed/.
#
# Run:  testthat::test_file("tests/testthat/test_equivalence.R")
# or:   Rscript -e 'testthat::test_file("tests/testthat/test_equivalence.R")'
#
# Static review notes (R not installed on dev machine):
#   - Column name "icd9_10" is the assumed clean_names() result for SAS ICD9_10.
#     Must verify: names(readRDS(file.path(data_dir_processed,"01_imported_icd_groups.rds")))
#   - cancer_dx comes from the earliest-cancer-row-per-encounter rule in 02_clean.R.

library(testthat)
library(data.table)
library(dplyr)
library(here)

# Point all paths at test fixtures
Sys.setenv(PIPELINE_TEST = "TRUE")
source(here::here("R", "config.R"))   # sets data_dir_processed -> tests/testdata/processed

fixture_dir <- data_dir_processed

# ============================================================
# Helper: reproduce old full-join logic on the fixtures
# ============================================================
old_path_dx_flags <- function(fixture_dir) {
  # Mimics what 02_clean.R USED to do: rbindlist all dx parts, then join to
  # icd_groups and apply overrides, yielding one row per DX row (not per encounter).
  # Then derive any_reportable_cancer per dx row and aggregate per encounter.

  ICD_PERSONAL_TRT_CODES <- c("V87.41","V87.42","V87.43","V87.46","V15.3",
                               "Z92.21","Z92.22","Z92.23","Z92.25","Z92.3")

  icd_groups <- as.data.table(readRDS(file.path(fixture_dir, "01_imported_icd_groups.rds")))

  dx_parts <- sort(list.files(fixture_dir, pattern = "01_imported_dx_part\\d+\\.rds",
                               full.names = TRUE))
  dx_all <- rbindlist(lapply(dx_parts, function(f) as.data.table(readRDS(f))),
                      use.names = TRUE, fill = TRUE)

  # Exact join
  dx_all <- merge(dx_all, icd_groups[, .(icd9_10, group_site)],
                  by.x = "dx", by.y = "icd9_10", all.x = TRUE)

  # Prefix overrides (V5_3)
  dx_all[startsWith(dx, "230") | startsWith(dx, "231") | startsWith(dx, "232") |
         startsWith(dx, "233") | startsWith(dx, "234") | startsWith(dx, "D0"),
         group_site := "In situ"]
  dx_all[startsWith(dx, "C82") | startsWith(dx, "C83") | startsWith(dx, "C85"),
         group_site := "Hematologic"]
  dx_all[startsWith(dx, "D37") | startsWith(dx, "D38") | startsWith(dx, "D39") |
         startsWith(dx, "D40") | startsWith(dx, "D41") | startsWith(dx, "D42") |
         startsWith(dx, "D43") | startsWith(dx, "D44") | startsWith(dx, "D45") |
         startsWith(dx, "D48") | startsWith(dx, "D49"),
         group_site := "Reportable but not mapped above"]
  dx_all[startsWith(dx, "C34"), group_site := "Oral and respiratory"]
  dx_all[startsWith(dx, "C25"), group_site := "Digestive"]
  dx_all[startsWith(dx, "C44") | startsWith(dx, "C4A") | startsWith(dx, "C43"),
         group_site := "Skin"]

  dx_all[, any_reportable_cancer := fifelse(!is.na(group_site) & nchar(group_site) > 0L, 1L, 0L)]
  dx_all[, icd_personal_trt      := fifelse(dx %in% ICD_PERSONAL_TRT_CODES, 1L, 0L)]

  # Aggregate per encounter
  cancer_rows <- dx_all[any_reportable_cancer == 1L]
  if (nrow(cancer_rows) > 0L) {
    setorder(cancer_rows, patid, encounterid, dx_date, dx)
    cancer_first <- cancer_rows[, .(cancer_dx = dx[1L], group_site_enc = group_site[1L]),
                                 by = .(patid, encounterid)]
  } else {
    cancer_first <- data.table(patid = character(), encounterid = character(),
                               cancer_dx = character(), group_site_enc = character())
  }

  enc_agg <- dx_all[, .(
    any_reportable_cancer_old = max(any_reportable_cancer, na.rm = TRUE),
    icd_personal_trt_old      = max(icd_personal_trt,      na.rm = TRUE)
  ), by = .(patid, encounterid)]

  enc_agg <- merge(enc_agg, cancer_first, by = c("patid", "encounterid"), all.x = TRUE)
  setkey(enc_agg, patid, encounterid)
  enc_agg
}

# ============================================================
# Helper: run new per-part aggregation path (mirrors 02_clean.R Section 4)
# ============================================================
new_path_dx_flags <- function(fixture_dir) {
  ICD_PERSONAL_TRT_CODES <- c("V87.41","V87.42","V87.43","V87.46","V15.3",
                               "Z92.21","Z92.22","Z92.23","Z92.25","Z92.3")

  icd_groups <- as.data.table(readRDS(file.path(fixture_dir, "01_imported_icd_groups.rds")))

  apply_overrides <- function(dt) {
    dt[startsWith(dx, "230") | startsWith(dx, "231") | startsWith(dx, "232") |
       startsWith(dx, "233") | startsWith(dx, "234") | startsWith(dx, "D0"),
       group_site := "In situ"]
    dt[startsWith(dx, "C82") | startsWith(dx, "C83") | startsWith(dx, "C85"),
       group_site := "Hematologic"]
    dt[startsWith(dx, "D37") | startsWith(dx, "D38") | startsWith(dx, "D39") |
       startsWith(dx, "D40") | startsWith(dx, "D41") | startsWith(dx, "D42") |
       startsWith(dx, "D43") | startsWith(dx, "D44") | startsWith(dx, "D45") |
       startsWith(dx, "D48") | startsWith(dx, "D49"),
       group_site := "Reportable but not mapped above"]
    dt[startsWith(dx, "C34"), group_site := "Oral and respiratory"]
    dt[startsWith(dx, "C25"), group_site := "Digestive"]
    dt[startsWith(dx, "C44") | startsWith(dx, "C4A") | startsWith(dx, "C43"),
       group_site := "Skin"]
    dt
  }

  dx_parts <- sort(list.files(fixture_dir, pattern = "01_imported_dx_part\\d+\\.rds",
                               full.names = TRUE))
  summaries <- vector("list", length(dx_parts))
  for (i in seq_along(dx_parts)) {
    part <- as.data.table(readRDS(dx_parts[i]))
    part <- merge(part, icd_groups[, .(icd9_10, group_site)],
                  by.x = "dx", by.y = "icd9_10", all.x = TRUE)
    apply_overrides(part)
    part[, any_reportable_cancer := fifelse(!is.na(group_site) & nchar(group_site) > 0L, 1L, 0L)]
    part[, icd_personal_trt      := fifelse(dx %in% ICD_PERSONAL_TRT_CODES, 1L, 0L)]
    cancer_rows <- part[any_reportable_cancer == 1L]
    if (nrow(cancer_rows) > 0L) {
      setorder(cancer_rows, patid, encounterid, dx_date, dx)
      cf <- cancer_rows[, .(cancer_dx = dx[1L], group_site = group_site[1L]),
                         by = .(patid, encounterid)]
    } else {
      cf <- data.table(patid = character(), encounterid = character(),
                       cancer_dx = character(), group_site = character())
    }
    es <- part[, .(any_reportable_cancer = max(any_reportable_cancer, na.rm = TRUE),
                   icd_personal_trt      = max(icd_personal_trt, na.rm = TRUE)),
               by = .(patid, encounterid)]
    summaries[[i]] <- merge(es, cf, by = c("patid", "encounterid"), all.x = TRUE)
  }

  combined <- rbindlist(summaries, use.names = TRUE, fill = TRUE)
  result <- combined[, {
    arc <- max(any_reportable_cancer, na.rm = TRUE)
    ipt <- max(icd_personal_trt, na.rm = TRUE)
    cdx <- cancer_dx[!is.na(cancer_dx)][1L]
    gs  <- group_site[!is.na(group_site)][1L]
    list(any_reportable_cancer_new = arc, icd_personal_trt_new = ipt,
         cancer_dx_new = cdx, group_site_new = gs)
  }, by = .(patid, encounterid)]
  setkey(result, patid, encounterid)
  result
}

# ============================================================
# Tests
# ============================================================

fixtures_available <- file.exists(file.path(fixture_dir, "01_imported_icd_groups.rds")) &&
  file.exists(file.path(fixture_dir, "01_imported_dx_part1.rds")) &&
  file.exists(file.path(fixture_dir, "01_imported_dx_part2.rds"))

test_that("fixtures exist", {
  skip_if(!fixtures_available, "Pipeline fixtures not built — run the pipeline first to generate testdata/processed/*.rds")
  expect_true(file.exists(file.path(fixture_dir, "01_imported_icd_groups.rds")))
  expect_true(file.exists(file.path(fixture_dir, "01_imported_dx_part1.rds")))
  expect_true(file.exists(file.path(fixture_dir, "01_imported_dx_part2.rds")))
})

test_that("new per-part path gives same any_reportable_cancer as old full-join path", {
  skip_if(!fixtures_available, "Pipeline fixtures not built")
  old <- old_path_dx_flags(fixture_dir)
  new <- new_path_dx_flags(fixture_dir)

  merged <- merge(old[, .(patid, encounterid, any_reportable_cancer_old)],
                  new[, .(patid, encounterid, any_reportable_cancer_new)],
                  by = c("patid", "encounterid"), all = TRUE)

  # fill NA (encounters with no dx rows at all) both ways
  merged[is.na(any_reportable_cancer_old), any_reportable_cancer_old := 0L]
  merged[is.na(any_reportable_cancer_new), any_reportable_cancer_new := 0L]

  mismatches <- merged[any_reportable_cancer_old != any_reportable_cancer_new]
  expect_equal(nrow(mismatches), 0L,
    info = paste("Mismatch in any_reportable_cancer for:",
                 paste(mismatches$encounterid, collapse = ", ")))
})

test_that("new per-part path gives same icd_personal_trt as old full-join path", {
  skip_if(!fixtures_available, "Pipeline fixtures not built")
  old <- old_path_dx_flags(fixture_dir)
  new <- new_path_dx_flags(fixture_dir)

  merged <- merge(old[, .(patid, encounterid, icd_personal_trt_old)],
                  new[, .(patid, encounterid, icd_personal_trt_new)],
                  by = c("patid", "encounterid"), all = TRUE)
  merged[is.na(icd_personal_trt_old), icd_personal_trt_old := 0L]
  merged[is.na(icd_personal_trt_new), icd_personal_trt_new := 0L]

  mismatches <- merged[icd_personal_trt_old != icd_personal_trt_new]
  expect_equal(nrow(mismatches), 0L,
    info = paste("Mismatch in icd_personal_trt for:",
                 paste(mismatches$encounterid, collapse = ", ")))
})

test_that("cross-part edge case: E008 gets icd_personal_trt=1 (Z92.21 in part2)", {
  skip_if(!fixtures_available, "Pipeline fixtures not built")
  new <- new_path_dx_flags(fixture_dir)
  e008 <- new[encounterid == "E008"]
  expect_equal(nrow(e008), 1L)
  # E008 has C64.9 (cancer) in part1 AND Z92.21 (personal trt) in part2
  expect_equal(e008$any_reportable_cancer_new, 1L)
  expect_equal(e008$icd_personal_trt_new, 1L)
})

test_that("non-cancer patient P004 has any_reportable_cancer=0", {
  skip_if(!fixtures_available, "Pipeline fixtures not built")
  new <- new_path_dx_flags(fixture_dir)
  p004 <- new[patid == "P004"]
  expect_true(all(p004$any_reportable_cancer_new == 0L))
})

test_that("P002 (C34.90, prefix override) gets group_site='Oral and respiratory'", {
  skip_if(!fixtures_available, "Pipeline fixtures not built")
  new <- new_path_dx_flags(fixture_dir)
  p002 <- new[patid == "P002"]
  expect_equal(p002$group_site_new, "Oral and respiratory")
})

test_that("cancer_dx and group_site agree between old and new paths for all encounters", {
  skip_if(!fixtures_available, "Pipeline fixtures not built")
  old <- old_path_dx_flags(fixture_dir)
  new <- new_path_dx_flags(fixture_dir)

  merged <- merge(
    old[, .(patid, encounterid, cancer_dx_old = cancer_dx, gs_old = group_site_enc)],
    new[, .(patid, encounterid, cancer_dx_new, gs_new = group_site_new)],
    by = c("patid", "encounterid"), all = TRUE
  )
  cancer_enc <- merged[!is.na(cancer_dx_old) | !is.na(cancer_dx_new)]
  # cancer_dx must match exactly where old path has a value
  mismatch_dx <- cancer_enc[!is.na(cancer_dx_old) & cancer_dx_old != cancer_dx_new]
  expect_equal(nrow(mismatch_dx), 0L,
    info = paste("cancer_dx mismatch for encounters:",
                 paste(mismatch_dx$encounterid, collapse = ", ")))
})

Sys.unsetenv("PIPELINE_TEST")
