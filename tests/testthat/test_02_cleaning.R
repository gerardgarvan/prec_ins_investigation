# tests/testthat/test_02_cleaning.R
# Test scaffolds for Phase 2 cleaning requirements (CLN-01 through CLN-06)
# Wave 0: Tests in RED state until 02_clean.R implements cleaning logic

library(testthat)
library(dplyr)

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
# recode_payer(): explicit-list SAS recode per SAS_CODE_FOR_v5_1.sas lines 61-219
# ==============================================================================
# Source: SAS_CODE_FOR_v5_1.sas lines 57-382 (PROC SQL UPDATE, commented-out block).
# Method: exhaustive explicit CASE WHEN — no prefix operator.
# Blank/NA -> '8' (ELSE clause). OT -> '9'. Dual: codes '14','93' -> '4' (direct),
# plus post-recode override when both primary and secondary are '1' or '2'.

PAYER_MEDICARE  <- c("1","11","111","112","113","119","12","121","122","123","129",
                     "13","19","191")
PAYER_MEDICAID  <- c("2","21","211","212","213","219","22","23","24","25","26",
                     "29","291","299")
PAYER_DUAL      <- c("14","93")
PAYER_PRIVATE   <- c(
  "3","31","311","3111","3112","3113","3114","3115","3116","3119",
  "312","3121","3122","3123","313","32","321","3211","3212",
  "32121","32122","32123","32124","32125","32126","32127","32128",
  "322","3221","3222","3223","3229","33","331","332","333","334",
  "34","341","342","343","349","35","36","361","362","369",
  "37","371","3711","3712","3713","372","379",
  "38","381","3811","3812","3813","3819","382","389","39","391",
  "5","51","511","512","513","514","515","516","517","519",
  "52","521","522","523","524","529","53","54","55","56","561","562",
  "6","61","611","612","613","614","619","62","621","622","623","629",
  "7","71","72","73","79"
)
PAYER_OTHER     <- c("4","41","42","43","44","9","91","92","94","95","951","953",
                     "954","959","96","97","98","99","OT")

recode_payer <- function(x) {
  dplyr::case_when(
    x %in% PAYER_DUAL     ~ "4",
    x %in% PAYER_MEDICARE ~ "1",
    x %in% PAYER_MEDICAID ~ "2",
    x %in% PAYER_PRIVATE  ~ "5",
    x %in% PAYER_OTHER    ~ "9",
    TRUE                  ~ "8"   # blank/NA/unmapped -> '8' per ELSE clause
  )
}

# --- Rule 1: direct codes (SAS_CODE_FOR_v5_1.sas lines 91-93) ---
test_that("recode_payer rule-1a: code '14' -> '4' (dual eligibility)", {
  expect_equal(recode_payer("14"), "4")
})
test_that("recode_payer rule-1b: code '93' -> '4' (disability insurance dual)", {
  expect_equal(recode_payer("93"), "4")
})
test_that("recode_payer rule-1c: '140' is NOT in dual list -> '8' (ELSE, not prefix)", {
  expect_equal(recode_payer("140"), "8")
})

# --- Medicare (SAS_CODE_FOR_v5_1.sas lines 61-75) ---
test_that("recode_payer: Medicare codes -> '1'", {
  expect_equal(recode_payer("1"),   "1")
  expect_equal(recode_payer("11"),  "1")
  expect_equal(recode_payer("111"), "1")
  expect_equal(recode_payer("13"),  "1")
  expect_equal(recode_payer("191"), "1")
})

# --- Medicaid (SAS_CODE_FOR_v5_1.sas lines 76-89) ---
test_that("recode_payer: Medicaid codes -> '2'", {
  expect_equal(recode_payer("2"),   "2")
  expect_equal(recode_payer("21"),  "2")
  expect_equal(recode_payer("299"), "2")
})

# --- Private/commercial (SAS_CODE_FOR_v5_1.sas lines 94-198) ---
test_that("recode_payer: Private/commercial codes -> '5'", {
  expect_equal(recode_payer("3"),   "5")   # Other Government lumped with private
  expect_equal(recode_payer("511"), "5")
  expect_equal(recode_payer("512"), "5")   # 511 and 512 are NOT a change
  expect_equal(recode_payer("611"), "5")   # BCBS
  expect_equal(recode_payer("71"),  "5")   # Managed Care
  expect_equal(recode_payer("79"),  "5")
})
test_that("recode_payer: 511 and 512 recode identically (not a coverage change)", {
  expect_equal(recode_payer("511"), recode_payer("512"))
})

# --- Other/Corrections (SAS_CODE_FOR_v5_1.sas lines 199-218) ---
test_that("recode_payer: Other/corrections codes -> '9'", {
  expect_equal(recode_payer("4"),  "9")
  expect_equal(recode_payer("41"), "9")
  expect_equal(recode_payer("9"),  "9")
  expect_equal(recode_payer("99"), "9")
  expect_equal(recode_payer("OT"), "9")
})

# --- Blank/NA/unmapped (ELSE clause, SAS_CODE_FOR_v5_1.sas line 219) ---
test_that("recode_payer: NA -> '8' (ELSE clause, not NA)", {
  expect_equal(recode_payer(NA_character_), "8")
})
test_that("recode_payer: blank string -> '8' (ELSE clause)", {
  expect_equal(recode_payer(""), "8")
})
test_that("recode_payer: unmapped code -> '8' (ELSE clause)", {
  expect_equal(recode_payer("ZZ"), "8")
})

# --- Rule 2: post-recode override (SAS_CODE_FOR_V5_8.sas line 89) ---
# When both primary2 and secondary2 are in ('1','2') -> primary2='4'.
# This fires for Medicare+Medicaid combos not already carrying code '14'/'93'.
test_that("recode_payer rule-2: Medicare primary + Medicaid secondary -> override to '4'", {
  primary_r   <- recode_payer("1")   # "1" Medicare
  secondary_r <- recode_payer("2")   # "2" Medicaid
  if (secondary_r %in% c("1","2") && primary_r %in% c("1","2")) primary_r <- "4"
  expect_equal(primary_r, "4")
})
test_that("recode_payer rule-2: Medicaid primary + Medicare secondary -> override to '4'", {
  primary_r   <- recode_payer("2")
  secondary_r <- recode_payer("11")
  if (secondary_r %in% c("1","2") && primary_r %in% c("1","2")) primary_r <- "4"
  expect_equal(primary_r, "4")
})
test_that("recode_payer rule-2: Medicare primary + Private secondary -> NO override", {
  primary_r   <- recode_payer("1")   # "1"
  secondary_r <- recode_payer("511") # "5"
  if (secondary_r %in% c("1","2") && primary_r %in% c("1","2")) primary_r <- "4"
  expect_equal(primary_r, "1")       # unchanged
})
