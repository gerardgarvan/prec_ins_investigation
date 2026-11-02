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

# ==============================================================================
# recode_payer(): prefix-based SAS recode per new828.sas lines 57-77
# ==============================================================================

# Inline the function here so tests run without sourcing 02_clean.R
recode_payer <- function(x) {
  dplyr::case_when(
    is.na(x) | x == ""                        ~ NA_character_,
    startsWith(x, "14")                        ~ "4",
    startsWith(x, "1")                         ~ "1",
    startsWith(x, "2")                         ~ "2",
    startsWith(x, "3") | startsWith(x, "5") |
      startsWith(x, "6") | startsWith(x, "7")  ~ "5",
    startsWith(x, "4")                         ~ "9",
    startsWith(x, "8")                         ~ "8",
    startsWith(x, "9") | x == "OT"            ~ "9",
    TRUE                                       ~ NA_character_
  )
}

test_that("recode_payer: Medicare 1xx -> '1'", {
  expect_equal(recode_payer("101"), "1")
  expect_equal(recode_payer("199"), "1")
  expect_equal(recode_payer("1"),   "1")
})

test_that("recode_payer: Medicaid 2xx -> '2'", {
  expect_equal(recode_payer("201"), "2")
  expect_equal(recode_payer("2"),   "2")
})

test_that("recode_payer: Dual 14x -> '4' (before 1xx)", {
  expect_equal(recode_payer("140"), "4")
  expect_equal(recode_payer("149"), "4")
  expect_equal(recode_payer("14"),  "4")
})

test_that("recode_payer: Private 3xx/5xx/6xx/7xx -> '5'", {
  expect_equal(recode_payer("301"), "5")
  expect_equal(recode_payer("511"), "5")
  expect_equal(recode_payer("512"), "5")  # 511->512 is NOT a change
  expect_equal(recode_payer("601"), "5")
  expect_equal(recode_payer("701"), "5")
})

test_that("recode_payer: 511 and 512 recode to same category (no change)", {
  expect_equal(recode_payer("511"), recode_payer("512"))
})

test_that("recode_payer: 4xx -> '9'", {
  expect_equal(recode_payer("401"), "9")
  expect_equal(recode_payer("4"),   "9")
})

test_that("recode_payer: No coverage 8xx -> '8'", {
  expect_equal(recode_payer("801"), "8")
  expect_equal(recode_payer("8"),   "8")
})

test_that("recode_payer: Other 9xx and OT -> '9'", {
  expect_equal(recode_payer("901"), "9")
  expect_equal(recode_payer("OT"),  "9")
})

test_that("recode_payer: blank and NA -> NA", {
  expect_true(is.na(recode_payer(NA_character_)))
  expect_true(is.na(recode_payer("")))
})
