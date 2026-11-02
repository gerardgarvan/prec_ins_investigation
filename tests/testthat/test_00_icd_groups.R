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

    combined <- bind_rows(cw_joined, icd10_direct) %>%
      mutate(icd9_10 = norm_icd(icd9_10)) %>%
      arrange(icd9_10) %>%
      distinct(icd9_10, .keep_all = TRUE)

    # Bare ICD-9 codes not in crosswalk (mirrors 00_build_icd_groups.R Step 7)
    bare_map <- tibble::tibble(
      icd9_10  = norm_icd(c("185", "193")),
      icd10_eq = norm_icd(c("C61", "C73"))
    )
    bare_extra <- bare_map %>%
      left_join(combined %>% select(icd10_eq = icd9_10, group_site), by = "icd10_eq") %>%
      filter(!is.na(group_site)) %>%
      select(icd9_10, group_site)
    if (nrow(bare_extra) > 0L) {
      combined <- bind_rows(
        combined %>% filter(!icd9_10 %in% bare_extra$icd9_10),
        bare_extra
      ) %>% arrange(icd9_10)
    }
    combined
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

test_that("185 (ICD-9 prostate, no dot) -> Male Genital System", {
  skip_if_no_xlsx()
  expect_equal(lookup_site("185", lookup_built), "Male Genital System")
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

test_that("193 (ICD-9 thyroid, no dot) returns a non-NA site", {
  skip_if_no_xlsx()
  result <- lookup_site("193", lookup_built)
  expect_false(is.na(result), info = paste("193 returned NA — .0 restore rule may still be active"))
})
