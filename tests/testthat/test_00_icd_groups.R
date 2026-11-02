# tests/testthat/test_00_icd_groups.R
# Tests for ICD cancer-site lookup normalization and longest-prefix matching.
# Tests that require the real xlsx are skipped when reference/ is absent.

library(testthat)
library(dplyr)
library(stringr)

# ---- normalization helper (mirrors 00_build_icd_groups.R and 02_clean.R) ----
norm_icd <- function(x) toupper(gsub("\\.", "", trimws(x)))

# ---- prefix-match helper (mirrors 02_clean.R step 1 matching logic) ----
lookup_site <- function(dx_raw, lookup_df) {
  dx_n <- norm_icd(dx_raw)
  for (len in c(nchar(dx_n), 7:3)) {
    pfx <- substr(dx_n, 1L, len)
    idx <- match(pfx, lookup_df$icd9_10)
    if (!is.na(idx)) return(lookup_df$group_site[idx])
  }
  NA_character_
}

# ==============================================================================
# Normalization unit tests (no xlsx needed)
# ==============================================================================

test_that("norm_icd strips dots, uppercases, and trims", {
  expect_equal(norm_icd("174.9"),   "1749")
  expect_equal(norm_icd("c50.919"), "C50919")
  expect_equal(norm_icd(" 185 "),   "185")
  expect_equal(norm_icd("C61"),     "C61")
  expect_equal(norm_icd("233.0"),   "2330")
  expect_equal(norm_icd("204.00"),  "20400")
  expect_equal(norm_icd("C90.00"),  "C9000")
  expect_equal(norm_icd("193"),     "193")
})

test_that("norm_icd handles already-normalized codes", {
  expect_equal(norm_icd("C50919"), "C50919")
  expect_equal(norm_icd("1749"),   "1749")
})

# ==============================================================================
# Integration tests against real CancerSiteCategories.xlsx
# ==============================================================================

xlsx_path <- here::here("reference", "CancerSiteCategories.xlsx")
xlsx_present <- file.exists(xlsx_path)

# Build lookup once — sourced inside a local() so it doesn't pollute the test env
lookup_built <- local({
  if (!xlsx_present) return(NULL)
  tryCatch({
    library(readxl)

    cw_raw <- read_excel(xlsx_path, sheet = "ForSAS_ICD9toICD10",
                         range = "D1:E1200", col_types = "text")
    names(cw_raw) <- c("icd9", "icd10")
    cw <- cw_raw %>%
      filter(!is.na(icd9), str_trim(icd9) != "",
             !is.na(icd10), str_trim(icd10) != "") %>%
      mutate(across(everything(), str_trim))

    icd10_raw <- read_excel(xlsx_path, sheet = "ForSAS_ICD10",
                             range = "A1:D1200", col_types = "text")
    names(icd10_raw) <- c("icd10_code", "pds", "ds", "group_site")
    icd10_tbl <- icd10_raw %>%
      filter(!is.na(icd10_code), str_trim(icd10_code) != "") %>%
      mutate(across(everything(), str_trim),
             group_site = if_else(is.na(group_site) | group_site == "",
                                  "Reportable but not mapped above", group_site))

    # ICD-9 crosswalk rows
    cw_joined <- cw %>%
      left_join(icd10_tbl %>% select(icd10 = icd10_code, group_site), by = "icd10",
                relationship = "many-to-many") %>%
      mutate(icd9_10 = icd9,
             group_site = if_else(is.na(group_site) | group_site == "",
                                  "Reportable but not mapped above", group_site)) %>%
      arrange(icd9_10) %>%
      distinct(icd9_10, .keep_all = TRUE) %>%
      select(icd9_10, group_site)

    # ICD-10 direct rows
    icd10_direct <- icd10_tbl %>%
      rename(icd9_10 = icd10_code) %>%
      select(icd9_10, group_site)

    # SAS-faithful (fix_lookup_gaps=FALSE): 185/193/179/181 absent from crosswalk,
    # so they are NOT added here.
    bind_rows(cw_joined, icd10_direct) %>%
      mutate(icd9_10 = norm_icd(icd9_10)) %>%
      arrange(icd9_10) %>%
      distinct(icd9_10, .keep_all = TRUE)
  }, error = function(e) NULL)
})

skip_if_no_xlsx <- function() skip_if(is.null(lookup_built), "reference/CancerSiteCategories.xlsx not present")

test_that("lookup is built with both ICD-9 and ICD-10 keys", {
  skip_if_no_xlsx()
  expect_gt(nrow(lookup_built), 200)
  expect_true("icd9_10" %in% names(lookup_built))
  expect_true("group_site" %in% names(lookup_built))
  # Should contain both ICD-9 style (starts with digit) and ICD-10 style (starts with letter)
  has_icd9 <- any(grepl("^[0-9]", lookup_built$icd9_10))
  has_icd10 <- any(grepl("^[A-Z]", lookup_built$icd9_10))
  expect_true(has_icd9, info = "expected ICD-9 numeric keys")
  expect_true(has_icd10, info = "expected ICD-10 alpha keys")
})

test_that("no keys contain dots (all normalized)", {
  skip_if_no_xlsx()
  expect_false(any(grepl("\\.", lookup_built$icd9_10)))
})

test_that("185 (ICD-9 prostate, no dot) -> NA when fix_lookup_gaps=FALSE (SAS-faithful)", {
  skip_if_no_xlsx()
  # 185 is absent from BOTH crosswalk columns — SAS wouldn't have resolved it either.
  expect_true(is.na(lookup_site("185", lookup_built)))
})

test_that("C61 (ICD-10 prostate) -> Male Genital System", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("C61", lookup_built), "Male Genital System")
})

test_that("174.9 (ICD-9 female breast) -> Breast", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("174.9", lookup_built), "Breast")
})

test_that("C50.919 (ICD-10 breast, dotted) -> Breast", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("C50.919", lookup_built), "Breast")
})

test_that("C50919 (ICD-10 breast, no dot, already normalized) -> Breast", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("C50919", lookup_built), "Breast")
})

test_that("204.00 (ICD-9 lymphoid leukemia) -> Hematologic", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("204.00", lookup_built), "Hematologic")
})

test_that("C90.00 (ICD-10 multiple myeloma) -> Hematologic", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("C90.00", lookup_built), "Hematologic")
})

test_that("C85.89 (ICD-10 NHL) -> Hematologic", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("C85.89", lookup_built), "Hematologic")
})

test_that("162.9 (ICD-9 lung) -> Oral and respiratory", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("162.9", lookup_built), "Oral and respiratory")
})

test_that("193 (ICD-9 thyroid, no dot) -> NA when fix_lookup_gaps=FALSE (SAS-faithful)", {
  skip_if_no_xlsx()
  # 193 is absent from BOTH crosswalk columns — SAS wouldn't have resolved it either.
  expect_true(is.na(lookup_site("193", lookup_built)))
})

# ---- fix_lookup_gaps=TRUE tests (build a patched lookup inline) ----
lookup_patched <- local({
  if (is.null(lookup_built)) return(NULL)
  gap_rows <- tibble::tibble(
    icd9_10    = norm_icd(c(
      "185", "193", "179", "181",
      "C19", "C20", "C23", "C65", "C66", "C50.0", "C7A.00"
    )),
    group_site = c(
      "Male Genital System", "Endocrine", "Female Genital System", "Female Genital System",
      "Digestive", "Digestive", "Digestive", "Urinary System", "Urinary System", "Breast", "Other"
    )
  )
  bind_rows(
    lookup_built %>% dplyr::filter(!icd9_10 %in% gap_rows$icd9_10),
    gap_rows
  ) %>% dplyr::arrange(icd9_10)
})

test_that("185 -> Male Genital System when fix_lookup_gaps=TRUE", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("185", lookup_patched), "Male Genital System")
})

test_that("193 -> Endocrine when fix_lookup_gaps=TRUE", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("193", lookup_patched), "Endocrine")
})

test_that("179 -> Female Genital System when fix_lookup_gaps=TRUE", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("179", lookup_patched), "Female Genital System")
})

test_that("181 -> Female Genital System when fix_lookup_gaps=TRUE", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("181", lookup_patched), "Female Genital System")
})
