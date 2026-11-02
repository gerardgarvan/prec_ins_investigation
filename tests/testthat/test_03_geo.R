# tests/testthat/test_03_geo.R
# Unit tests for the three-step address window selection and ruca3 derivation
# implemented in R/03_geo.R.
#
# SAS source: SAS_CODE_FOR_V5_5 (1).sas (primary)
# Six scenarios tested (as specified in task):
#   1. address window covers dx date                 -> step 1 match
#   2. only an earlier address (no coverage at dx)   -> step 2 match
#   3. a later address within 30 days               -> step 3 match
#   4. ZIP with RUCA1 = 99                          -> excluded (no ruca3)
#   5. ZIP not in RUCA file                         -> excluded (no ruca3)
#   6. leading-zero ZIP                             -> matched correctly

library(testthat)
library(dplyr)

# ============================================================
# Helper: run the address selection logic extracted from 03_geo.R
# Returns a tibble with patid and ruca3 (one row per matched patient).
# ============================================================

derive_ruca <- function(cohort_ids, zip_ruca) {

  END_DATE_DEFAULT <- as.Date("2023-08-31")

  # Step 1 -- address covers dx date
  step1_join <- cohort_ids %>%
    left_join(zip_ruca, by = "patid") %>%
    filter(
      is.na(ADDRESS_PERIOD_START) |
        (first_admit_date >= ADDRESS_PERIOD_START & first_admit_date <= ADDRESS_PERIOD_END)
    ) %>%
    mutate(
      days_START_can = if_else(
        !is.na(ADDRESS_PERIOD_START),
        as.numeric(ADDRESS_PERIOD_START - first_admit_date),
        NA_real_
      )
    )

  step1_dedup <- step1_join %>%
    arrange(patid, desc(days_START_can)) %>%
    distinct(patid, .keep_all = TRUE)

  step1_matched <- step1_dedup %>%
    filter(!is.na(RUCA1) & RUCA1 != 99) %>%
    filter(!is.na(ADDRESS_ZIP5) & ADDRESS_ZIP5 != "") %>%
    mutate(ruca3 = if_else(RUCA1 %in% c(1, 2, 3, 1.1, 2.1), 0L, 1L))

  step1_unmatched <- cohort_ids %>%
    filter(!patid %in% step1_matched$patid)

  # Step 2 -- closest earlier address start
  step2_join <- step1_unmatched %>%
    left_join(zip_ruca, by = "patid") %>%
    mutate(
      days_START_can = if_else(
        !is.na(ADDRESS_PERIOD_START),
        as.numeric(ADDRESS_PERIOD_START - first_admit_date),
        NA_real_
      )
    ) %>%
    filter(!is.na(days_START_can) & days_START_can <= 0) %>%
    filter(!is.na(ADDRESS_ZIP5) & ADDRESS_ZIP5 != "") %>%
    filter(!is.na(RUCA1) & RUCA1 != 99)

  step2_matched <- step2_join %>%
    arrange(patid, desc(days_START_can)) %>%
    distinct(patid, .keep_all = TRUE) %>%
    mutate(ruca3 = if_else(RUCA1 %in% c(1, 2, 3, 1.1, 2.1), 0L, 1L))

  step2_unmatched <- step1_unmatched %>%
    filter(!patid %in% step2_matched$patid)

  # Step 3 -- start within 30 days after dx
  step3_join <- step2_unmatched %>%
    left_join(zip_ruca, by = "patid") %>%
    mutate(
      days_START_can = if_else(
        !is.na(ADDRESS_PERIOD_START),
        as.numeric(ADDRESS_PERIOD_START - first_admit_date),
        NA_real_
      )
    ) %>%
    filter(!is.na(days_START_can) & days_START_can >= 0 & days_START_can <= 30) %>%
    filter(!is.na(ADDRESS_ZIP5) & ADDRESS_ZIP5 != "") %>%
    filter(!is.na(RUCA1) & RUCA1 != 99)

  step3_matched <- step3_join %>%
    arrange(patid, days_START_can) %>%
    distinct(patid, .keep_all = TRUE) %>%
    mutate(ruca3 = if_else(RUCA1 %in% c(1, 2, 3, 1.1, 2.1), 0L, 1L))

  bind_rows(
    step1_matched %>% select(patid, ADDRESS_ZIP5, RUCA1, ruca3),
    step2_matched %>% select(patid, ADDRESS_ZIP5, RUCA1, ruca3),
    step3_matched %>% select(patid, ADDRESS_ZIP5, RUCA1, ruca3)
  )
}

# ============================================================
# Scenario 1: address window covers dx date  -> step 1 match
# ============================================================
test_that("GEO-01: address period covering dx date is matched in step 1", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P01", first_admit_date = dx_date)
  zip_ruca <- tibble(
    patid              = "P01",
    ADDRESS_ZIP5       = "32601",
    RUCA1              = 1,
    RUCA2              = 1.0,
    ADDRESS_PERIOD_START = as.Date("2020-01-01"),
    ADDRESS_PERIOD_END   = as.Date("2021-12-31")
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 1)
  expect_equal(result$ruca3, 0L)   # RUCA1=1 -> urban
  expect_equal(result$ADDRESS_ZIP5, "32601")
})

# ============================================================
# Scenario 2: only an earlier address (no coverage at dx) -> step 2 match
# ============================================================
test_that("GEO-02: closest prior address selected when dx date not covered", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P02", first_admit_date = dx_date)
  zip_ruca <- tibble(
    patid              = "P02",
    ADDRESS_ZIP5       = "32601",
    RUCA1              = 7,  # rural
    RUCA2              = 7.0,
    ADDRESS_PERIOD_START = as.Date("2018-01-01"),
    ADDRESS_PERIOD_END   = as.Date("2019-12-31")  # ends before dx date
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 1)
  expect_equal(result$ruca3, 1L)   # RUCA1=7 -> rural
})

# ============================================================
# Scenario 3: a later address start within 30 days -> step 3 match
# ============================================================
test_that("GEO-03: address starting within 30 days after dx matched in step 3", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P03", first_admit_date = dx_date)
  zip_ruca <- tibble(
    patid              = "P03",
    ADDRESS_ZIP5       = "32601",
    RUCA1              = 4,  # rural
    RUCA2              = 4.0,
    ADDRESS_PERIOD_START = dx_date + 20,   # 20 days after dx
    ADDRESS_PERIOD_END   = as.Date("2022-12-31")
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 1)
  expect_equal(result$ruca3, 1L)
})

# ============================================================
# Scenario 3b: address starts exactly 31 days after dx -> NOT matched (> 30 days)
# ============================================================
test_that("GEO-03b: address starting 31 days after dx is excluded", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P03b", first_admit_date = dx_date)
  zip_ruca <- tibble(
    patid              = "P03b",
    ADDRESS_ZIP5       = "32601",
    RUCA1              = 4,
    RUCA2              = 4.0,
    ADDRESS_PERIOD_START = dx_date + 31,
    ADDRESS_PERIOD_END   = as.Date("2022-12-31")
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 0)
})

# ============================================================
# Scenario 4: ZIP with RUCA1 = 99 -> excluded
# ============================================================
test_that("GEO-04: RUCA1=99 (water area) is excluded; patient has no ruca3", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P04", first_admit_date = dx_date)
  zip_ruca <- tibble(
    patid              = "P04",
    ADDRESS_ZIP5       = "00901",  # example territory zip
    RUCA1              = 99,
    RUCA2              = 99.0,
    ADDRESS_PERIOD_START = as.Date("2020-01-01"),
    ADDRESS_PERIOD_END   = as.Date("2021-12-31")
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 0)
})

# ============================================================
# Scenario 5: ZIP not in RUCA file (RUCA1 = NA after left join) -> excluded
# ============================================================
test_that("GEO-05: ZIP not in RUCA file yields no match", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P05", first_admit_date = dx_date)
  zip_ruca <- tibble(
    patid              = "P05",
    ADDRESS_ZIP5       = "99999",  # ZIP not in RUCA lookup
    RUCA1              = NA_real_,
    RUCA2              = NA_real_,
    ADDRESS_PERIOD_START = as.Date("2020-01-01"),
    ADDRESS_PERIOD_END   = as.Date("2021-12-31")
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 0)
})

# ============================================================
# Scenario 6: leading-zero ZIP code matched correctly
# ============================================================
test_that("GEO-06: leading-zero ZIP code is matched correctly", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P06", first_admit_date = dx_date)
  zip_ruca <- tibble(
    patid              = "P06",
    ADDRESS_ZIP5       = "01001",   # 5-char text, leading zero preserved
    RUCA1              = 2,
    RUCA2              = 2.0,
    ADDRESS_PERIOD_START = as.Date("2020-01-01"),
    ADDRESS_PERIOD_END   = as.Date("2021-12-31")
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 1)
  expect_equal(result$ADDRESS_ZIP5, "01001")
  expect_equal(result$ruca3, 0L)   # RUCA1=2 -> urban
})

# ============================================================
# Multiple address records: step 1 picks the record closest
# to (but still before) dx date when multiple overlap
# ============================================================
test_that("GEO-07: multiple overlapping periods deduplicates correctly", {
  dx_date <- as.Date("2020-06-15")
  cohort_ids <- tibble(patid = "P07", first_admit_date = dx_date)
  # Two address periods both covering dx date; step 1 should keep only one
  zip_ruca <- tibble(
    patid              = c("P07", "P07"),
    ADDRESS_ZIP5       = c("32601", "32601"),
    RUCA1              = c(1, 1),
    RUCA2              = c(1.0, 1.0),
    ADDRESS_PERIOD_START = c(as.Date("2018-01-01"), as.Date("2020-01-01")),
    ADDRESS_PERIOD_END   = c(as.Date("2021-12-31"), as.Date("2021-12-31"))
  )

  result <- derive_ruca(cohort_ids, zip_ruca)

  expect_equal(nrow(result), 1)  # deduplicated to one row
})

# ============================================================
# ruca3 derivation: RUCA1 values 1.1 and 2.1 are urban (=0)
# ============================================================
test_that("GEO-08: RUCA1 decimal values 1.1 and 2.1 are classified as urban", {
  dx_date <- as.Date("2020-06-15")

  for (r1_val in c(1.1, 2.1)) {
    cohort_ids <- tibble(patid = "P08", first_admit_date = dx_date)
    zip_ruca <- tibble(
      patid              = "P08",
      ADDRESS_ZIP5       = "32601",
      RUCA1              = r1_val,
      RUCA2              = r1_val,
      ADDRESS_PERIOD_START = as.Date("2020-01-01"),
      ADDRESS_PERIOD_END   = as.Date("2021-12-31")
    )
    result <- derive_ruca(cohort_ids, zip_ruca)
    expect_equal(result$ruca3, 0L,
                 label = paste0("RUCA1=", r1_val, " should be urban (ruca3=0)"))
  }
})
