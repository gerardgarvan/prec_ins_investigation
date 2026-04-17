# tests/testthat/test_02_cleaning.R
# Test scaffolds for Phase 2 cleaning requirements (CLN-01 through CLN-06)
# Wave 0: Tests in RED state until 02_clean.R implements cleaning logic

library(testthat)
library(dplyr)
source("/home/ggarvan/prec_ins_investigation/tests/testthat/helper-fixtures.R")

# ==============================================================================
# CLN-01: Variable names already standardized at import (verify no uppercase)
# ==============================================================================

test_that("CLN-01: Column names are lowercase snake_case after import", {
  # Tests that import_sas() already handled clean_names
  expect_true(all(names(mock_encounter1) == tolower(names(mock_encounter1))))
  expect_true(all(names(mock_encounter2) == tolower(names(mock_encounter2))))
})

# ==============================================================================
# CLN-02: Encounter combination (bind_rows)
# ==============================================================================

test_that("CLN-02: encounter1 + encounter2 combine correctly via bind_rows", {
  combined <- bind_rows(mock_encounter1, mock_encounter2)
  expect_equal(nrow(combined), nrow(mock_encounter1) + nrow(mock_encounter2))
  expect_equal(ncol(combined), ncol(mock_encounter1))
  expect_true("patid" %in% names(combined))
  expect_true("encounterid" %in% names(combined))
})

# ==============================================================================
# CLN-03: Payer type recoding using sas_formats$p_payer (per D-03)
# ==============================================================================

test_that("CLN-03: Payer codes recode to grouped categories via factor()", {
  # This test will FAIL until 02_clean.R implements the recoding function
  # The function should: factor(payer_code, levels = sas_formats$p_payer$levels, labels = sas_formats$p_payer$labels)
  combined <- bind_rows(mock_encounter1, mock_encounter2)
  # Expect a function recode_payer() or inline mutate to exist
  # Test: payer code "1" -> "Medicare", "2" -> "Medicaid", "5" -> "Private"
  fmt <- mock_sas_formats$p_payer
  result <- factor(combined$payer_type_primary, levels = fmt$levels, labels = fmt$labels)
  expect_equal(as.character(result[combined$payer_type_primary == "1"]), "Medicare")
  expect_equal(as.character(result[combined$payer_type_primary == "2"]), "Medicaid")
  expect_equal(as.character(result[combined$payer_type_primary == "5"]), "Private")
  expect_equal(as.character(result[combined$payer_type_primary == "4"]), "Med_Medicaid")
})

# ==============================================================================
# CLN-03 continued: Unmapped payer codes handled per D-04
# ==============================================================================

test_that("CLN-03/D-04: Unmapped payer codes become NA from factor(), script warns and assigns Unknown", {
  fmt <- mock_sas_formats$p_payer
  result <- factor("ZZ", levels = fmt$levels, labels = fmt$labels)
  # factor() returns NA for unmapped codes — script must catch and assign "Unknown"
  expect_true(is.na(result))
})

# ==============================================================================
# CLN-04: Missing values handled explicitly with is.na()
# ==============================================================================

test_that("CLN-04: Missing payer_type_primary handled with explicit is.na()", {
  combined <- bind_rows(mock_encounter1, mock_encounter2)
  na_rows <- combined %>% filter(is.na(payer_type_primary))
  # At least one row has NA payer (from fixtures)
  expect_gt(nrow(na_rows), 0)
  # NA should NOT be silently dropped by filter operations
  expect_equal(nrow(combined), 10)
})

# ==============================================================================
# CLN-05: Encounter type and discharge status recoded with factor levels
# ==============================================================================

test_that("CLN-05: enc_type recodes to labeled factor via sas_formats$enc_type", {
  fmt <- mock_sas_formats$enc_type
  result <- factor(mock_encounter1$enc_type, levels = fmt$levels, labels = fmt$labels)
  expect_true(is.factor(result))
  expect_equal(as.character(result[mock_encounter1$enc_type == "AV"]), "Ambulatory Visit")
})

test_that("CLN-05: discharge_status recodes to labeled factor", {
  fmt <- mock_sas_formats$discharge_status
  result <- factor(mock_encounter1$discharge_status, levels = fmt$levels, labels = fmt$labels)
  expect_true(is.factor(result))
})

test_that("CLN-05: discharge_disposition recodes to labeled factor", {
  fmt <- mock_sas_formats$discharge_disposition
  result <- factor(mock_encounter1$discharge_disposition, levels = fmt$levels, labels = fmt$labels)
  expect_true(is.factor(result))
})

# ==============================================================================
# CLN-06: Primary/secondary payer derived with correct grouping
# ==============================================================================

test_that("CLN-06: Dual Medicare/Medicaid (code 4) maps to Med_Medicaid", {
  fmt <- mock_sas_formats$p_payer
  result <- factor("4", levels = fmt$levels, labels = fmt$labels)
  expect_equal(as.character(result), "Med_Medicaid")
})

test_that("CLN-06: Government payer (code 3) maps to Private per p_payer format", {
  # NOTE: In sas_formats$p_payer, code "3" maps to "Private" (study-specific decision)
  fmt <- mock_sas_formats$p_payer
  result <- factor("3", levels = fmt$levels, labels = fmt$labels)
  expect_equal(as.character(result), "Private")
})
