# tests/testthat/test_04_table1.R
# Test scaffolds for Phase 4 Table 1 and frequency table requirements
# Covers STA-01 (Table 1), STA-02 (bivariate tests), STA-07 (frequency tables)
# Wave 0: Tests in RED state until production scripts (04_table1.R) implement statistical outputs

library(testthat)
library(dplyr)
library(gtsummary)
library(janitor)

# ==============================================================================
# STA-01: Table 1 structure
# ==============================================================================

test_that("STA-01: Table 1 structure created with tbl_summary", {
  skip_if_not_installed("gtsummary")

  # Create Table 1 stratified by insurance change
  tbl1 <- mock_p4_analytical %>%
    gtsummary::tbl_summary(by = change_ins)

  # Verify tbl_summary object class
  expect_true("tbl_summary" %in% class(tbl1))

  # Convert to tibble and check structure
  tbl1_df <- as_tibble(tbl1)

  # Should have at least 3 columns: label + stat_1 + stat_2
  expect_gte(ncol(tbl1_df), 3)

  # Verify demographic variables present
  tbl1_vars <- tbl1_df$label
  expect_true(any(grepl("sex|Sex", tbl1_vars, ignore.case = TRUE)))
  expect_true(any(grepl("race|Race", tbl1_vars, ignore.case = TRUE)))
  expect_true(any(grepl("age", tbl1_vars, ignore.case = TRUE)))
})

# ==============================================================================
# STA-02: Bivariate test p-values
# ==============================================================================

test_that("STA-02: Bivariate tests produce p-values", {
  skip_if_not_installed("gtsummary")

  # Create Table 1 with statistical tests
  tbl1_with_p <- mock_p4_analytical %>%
    gtsummary::tbl_summary(
      by = change_ins,
      label = mock_p4_label_list
    ) %>%
    gtsummary::add_p(
      test = list(
        all_categorical() ~ "chisq.test.no.correct",
        all_continuous() ~ "wilcox.test"
      )
    )

  # Verify p-value column exists
  tbl1_df <- as_tibble(tbl1_with_p)
  expect_true("p.value" %in% names(tbl1_df))

  # Extract p-values (excluding NA for headers)
  p_values <- tbl1_df$p.value[!is.na(tbl1_df$p.value)]

  # At least one p-value should be present
  expect_gt(length(p_values), 0)

  # All p-values should be numeric and between 0 and 1
  p_numeric <- suppressWarnings(as.numeric(p_values))
  p_numeric_valid <- p_numeric[!is.na(p_numeric)]
  expect_true(all(p_numeric_valid >= 0 & p_numeric_valid <= 1))
})

# ==============================================================================
# STA-07: Frequency table structure (tabyl)
# ==============================================================================

test_that("STA-07: Frequency table structure with janitor::tabyl", {
  skip_if_not_installed("janitor")

  # Create frequency table for cancer site
  freq_site <- mock_p4_analytical %>%
    janitor::tabyl(group_site)

  # Should be a data.frame with columns: group_site, n, percent
  expect_true(is.data.frame(freq_site))
  expect_true("group_site" %in% names(freq_site))
  expect_true("n" %in% names(freq_site))
  expect_true("percent" %in% names(freq_site))

  # Should have 6 unique cancer sites (Breast, Colorectal, Prostate, Lung, Leukemia, Kidney)
  expect_equal(nrow(freq_site), 6)

  # Test adding total row
  freq_site_total <- freq_site %>%
    janitor::adorn_totals("row")

  # Should have 7 rows now (6 sites + Total)
  expect_equal(nrow(freq_site_total), 7)

  # Total row should have n=8
  total_row <- freq_site_total[nrow(freq_site_total), ]
  expect_equal(total_row$n, 8)
})

# ==============================================================================
# STA-07: Cross-tabulation with janitor::tabyl
# ==============================================================================

test_that("STA-07: Cross-tabulation for insurance change by race", {
  skip_if_not_installed("janitor")

  # Create 2x3 crosstab: change_ins (rows) by race2 (columns)
  crosstab <- mock_p4_analytical %>%
    janitor::tabyl(change_ins, race2)

  # Should be a data.frame
  expect_true(is.data.frame(crosstab))

  # Should have 2 rows (change_ins=0, change_ins=1)
  expect_equal(nrow(crosstab), 2)

  # Should have at least 4 columns: change_ins + 3 race categories (WH, AA, OT)
  expect_gte(ncol(crosstab), 4)

  # Verify race2 categories are present as columns
  expect_true("WH" %in% names(crosstab))
  expect_true("AA" %in% names(crosstab))
  expect_true("OT" %in% names(crosstab))
})

# ==============================================================================
# STA-07: Cross-tabulation with gtsummary::tbl_cross
# ==============================================================================

test_that("STA-07: Cross-tabulation with p-value using gtsummary::tbl_cross", {
  skip_if_not_installed("gtsummary")

  # Create crosstab with p-value
  crosstab_p <- mock_p4_analytical %>%
    gtsummary::tbl_cross(
      row = change_ins,
      col = race2
    ) %>%
    gtsummary::add_p()

  # Verify tbl_cross object class
  expect_true("tbl_cross" %in% class(crosstab_p))

  # Convert to tibble
  crosstab_df <- as_tibble(crosstab_p)

  # Should have p.value column
  expect_true("p.value" %in% names(crosstab_df))

  # Extract p-value (should be single value for overall test)
  p_val <- crosstab_df$p.value[!is.na(crosstab_df$p.value)]

  # If p-value exists, should be numeric between 0 and 1
  if (length(p_val) > 0) {
    p_numeric <- suppressWarnings(as.numeric(p_val[1]))
    if (!is.na(p_numeric)) {
      expect_true(p_numeric >= 0 & p_numeric <= 1)
    }
  }
})
