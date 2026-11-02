# tests/testthat/test_00_ndc.R
# Unit tests for NDC normalization, SEERRxCategory recode, and chemo/anc flag logic
# implemented in R/00_build_ndc.R and consumed by R/03_exposure.R.
#
# SAS source: NDC_ID_4_10_2024.sas, CHEMO_ID_4_10_2024.sas, SAS_CODE_FOR_V5_12.sas
#
# Five scenarios:
#   NDC-01: dashed reference NDC_9_Product_ normalizes to 9-digit ndc9
#   NDC-02: 11-digit dispensing NDC first-9 matches reference ndc9 (join succeeds)
#   NDC-03: "Hormonal Therapy" -> seer_cat_code "4" (non-ancillary; counted as chemo)
#   NDC-04: "Ancillary Therapy" -> seer_cat_code "1" (ancillary; anc_disp = 1)
#   NDC-05: NDC absent from reference -> left_join yields NA code -> chemo_disp=0, anc_disp=0

library(testthat)
library(dplyr)
library(stringr)

# ============================================================
# Helper: normalize a reference NDC_9_Product_ -> ndc9
# Mirrors 00_build_ndc.R: strip non-digits, take first 9
# ============================================================
normalize_ref_ndc9 <- function(ndc_9_product) {
  substr(stringr::str_remove_all(ndc_9_product, "[^0-9]"), 1, 9)
}

# Helper: normalize a dispensing NDC -> ndc9 (first 9 chars of digit-stripped string)
normalize_disp_ndc9 <- function(ndc) {
  substr(stringr::str_remove_all(as.character(ndc), "[^0-9]"), 1, 9)
}

# Helper: recode SEERRxCategory text -> single-char code
# Mirrors 00_build_ndc.R case_when (SAS V5_12 $seer format)
recode_seer_cat <- function(seer_rx_category) {
  dplyr::case_when(
    seer_rx_category == "Ancillary Therapy"              ~ "1",
    seer_rx_category == "Chemotherapy"                   ~ "2",
    seer_rx_category == "Chemotherapy, Hormonal Therapy" ~ "3",
    seer_rx_category == "Hormonal Therapy"               ~ "4",
    seer_rx_category == "Immunotherapy"                  ~ "5",
    seer_rx_category == "Radiopharmaceutical"            ~ "6",
    TRUE                                                  ~ NA_character_
  )
}

# Helper: derive patient-level chemo_disp / anc_disp flags from a disp_cat tibble
# Mirrors 03_exposure.R flag logic (SAS V5_12 != "1" rule)
derive_disp_flags <- function(disp_cat) {
  disp_cat |>
    dplyr::group_by(patid) |>
    dplyr::summarise(
      chemo_disp = as.integer(any(seer_cat_code %in% c("2", "3", "4", "5", "6"), na.rm = TRUE)),
      anc_disp   = as.integer(any(seer_cat_code == "1", na.rm = TRUE)),
      .groups    = "drop"
    )
}

# ============================================================
# NDC-01: dashed reference NDC_9_Product_ normalizes to "722050061"
# ============================================================
test_that("NDC-01: dashed reference '72205-0061' normalizes to ndc9 '722050061'", {
  result <- normalize_ref_ndc9("72205-0061")
  expect_equal(result, "722050061")
  expect_equal(nchar(result), 9L)
})

# ============================================================
# NDC-02: 11-digit dispensing NDC first-9 matches reference ndc9
# ============================================================
test_that("NDC-02: dispensing '72205006101' first-9 == reference ndc9 '722050061' (join match)", {
  ref_ndc9  <- normalize_ref_ndc9("72205-0061")      # "722050061"
  disp_ndc9 <- normalize_disp_ndc9("72205006101")    # first 9 of 11-digit

  expect_equal(disp_ndc9, "722050061")
  expect_equal(ref_ndc9, disp_ndc9)  # they match -> join succeeds
})

# ============================================================
# NDC-03: "Hormonal Therapy" -> seer_cat_code "4" (non-ancillary -> chemo_disp = 1)
# Note: Hormonal Therapy (incl. prednisone/dexamethasone corticosteroids) counted as
# chemo-like under V5_12 != "1" rule. See TODO(ERIN) in DATA_LINEAGE.md.
# ============================================================
test_that("NDC-03: 'Hormonal Therapy' recodes to seer_cat_code '4' and yields chemo_disp=1", {
  code <- recode_seer_cat("Hormonal Therapy")
  expect_equal(code, "4")

  # Verify flag logic: code "4" is in the chemo set (2-6)
  disp_cat <- tibble::tibble(patid = "P001", ndc9 = "123456789", seer_cat_code = code)
  flags <- derive_disp_flags(disp_cat)

  expect_equal(flags$chemo_disp, 1L)
  expect_equal(flags$anc_disp,   0L)
})

# ============================================================
# NDC-04: "Ancillary Therapy" -> seer_cat_code "1" -> anc_disp = 1, chemo_disp = 0
# ============================================================
test_that("NDC-04: 'Ancillary Therapy' recodes to seer_cat_code '1' and yields anc_disp=1", {
  code <- recode_seer_cat("Ancillary Therapy")
  expect_equal(code, "1")

  disp_cat <- tibble::tibble(patid = "P002", ndc9 = "987654321", seer_cat_code = code)
  flags <- derive_disp_flags(disp_cat)

  expect_equal(flags$anc_disp,   1L)
  expect_equal(flags$chemo_disp, 0L)
})

# ============================================================
# NDC-05: NDC absent from reference -> left_join yields NA seer_cat_code
#         -> chemo_disp = 0, anc_disp = 0
# ============================================================
test_that("NDC-05: unmatched dispensing NDC yields chemo_disp=0 and anc_disp=0", {
  # Simulate a minimal ndc_ref (reference table from 00_build_ndc.R)
  ndc_ref <- tibble::tibble(
    ndc9             = "722050061",
    seer_cat_code    = "2",
    seer_rx_category = "Chemotherapy"
  )

  # Patient with an NDC not in the reference
  dispensing_ndc <- tibble::tibble(
    patid = "P003",
    ndc9  = "000000000"  # not in ndc_ref
  )

  # Replicate 03_exposure.R join
  disp_cat <- dispensing_ndc |>
    dplyr::left_join(ndc_ref |> dplyr::distinct(ndc9, seer_cat_code), by = "ndc9")

  expect_true(is.na(disp_cat$seer_cat_code))  # unmatched -> NA

  flags <- derive_disp_flags(disp_cat)

  expect_equal(flags$chemo_disp, 0L)
  expect_equal(flags$anc_disp,   0L)
})
