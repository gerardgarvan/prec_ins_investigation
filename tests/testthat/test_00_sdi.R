# tests/testthat/test_00_sdi.R
# Unit tests for the SDI ZCTA join logic implemented in R/03_geo.R Section 7
# and the zero-padding / column-selection logic in R/00_build_sdi.R.
#
# SAS source: SAS_CODE_FOR_V5_5 (1).sas lines 359-383
# Four scenarios:
#   SDI-01: leading-zero ZCTA ("01001") joins to correct sdi_score
#   SDI-02: ZIP whose zcta lookup yields NA produces NA sdi_score -> dropped
#   SDI-03: ZCTA present in geo but absent from SDI lookup yields NA -> dropped
#   SDI-04: builder padding turns numeric-style ZCTA (1001) into "01001";
#           SDI_score (percentile) is kept, not the raw `sdi` composite

library(testthat)
library(dplyr)
library(stringr)

# ============================================================
# Helper: reproduces the ZCTA->SDI join from 03_geo.R Section 7
# geo           tibble with column ADDRESS_ZIP5
# zcta_lookup   tibble with columns ADDRESS_ZIP5, zcta
# sdi_lookup    tibble with columns zcta, sdi_score
# Returns: joined + filtered tibble (rows dropped when sdi_score is NA)
# ============================================================
join_sdi <- function(geo, zcta_lookup, sdi_lookup) {
  geo |>
    left_join(zcta_lookup, by = "ADDRESS_ZIP5") |>
    left_join(sdi_lookup, by = "zcta") |>
    filter(!is.na(sdi_score))      # SAS V5_5 line 383 + "No ZCTA" drop
}

# ============================================================
# SDI-01: leading-zero ZCTA joins to correct sdi_score
# ============================================================
test_that("SDI-01: leading-zero ZCTA '01001' joins to sdi_score", {
  geo         <- tibble(ADDRESS_ZIP5 = "01001")
  zcta_lookup <- tibble(ADDRESS_ZIP5 = "01001", zcta = "01001")
  sdi_lookup  <- tibble(zcta = "01001", sdi_score = 42L)

  result <- join_sdi(geo, zcta_lookup, sdi_lookup)

  expect_equal(nrow(result), 1)
  expect_equal(result$sdi_score, 42L)
})

# ============================================================
# SDI-02: ZIP whose zcta lookup yields NA -> 0 rows after filter
# ============================================================
test_that("SDI-02: ZIP with no ZCTA yields NA sdi_score and is dropped", {
  geo         <- tibble(ADDRESS_ZIP5 = "99999")
  # zcta_lookup has no entry for 99999 -> left join produces NA zcta
  zcta_lookup <- tibble(ADDRESS_ZIP5 = "01001", zcta = "01001")
  sdi_lookup  <- tibble(zcta = "01001", sdi_score = 42L)

  result <- join_sdi(geo, zcta_lookup, sdi_lookup)

  expect_equal(nrow(result), 0)
})

# ============================================================
# SDI-03: ZCTA present in geo but absent from SDI lookup -> 0 rows
# ============================================================
test_that("SDI-03: ZCTA with no SDI entry yields NA sdi_score and is dropped", {
  geo         <- tibble(ADDRESS_ZIP5 = "32601")
  zcta_lookup <- tibble(ADDRESS_ZIP5 = "32601", zcta = "32601")
  # sdi_lookup has no entry for 32601
  sdi_lookup  <- tibble(zcta = "99999", sdi_score = 55L)

  result <- join_sdi(geo, zcta_lookup, sdi_lookup)

  expect_equal(nrow(result), 0)
})

# ============================================================
# SDI-04: builder padding — numeric-style ZCTA -> "01001"; SDI_score kept, not raw sdi
# ============================================================
test_that("SDI-04: builder pads ZCTA to 5 chars and keeps SDI_score (percentile) not sdi (z-score)", {
  # Simulate the raw CSV row (ZCTA5_FIPS as character "1001" after col_character() read)
  raw <- tibble(ZCTA5_FIPS = "1001", SDI_score = 33L, sdi = -0.53)

  # Apply the same transmute used in 00_build_sdi.R
  result <- raw |>
    dplyr::transmute(
      zcta      = stringr::str_pad(ZCTA5_FIPS, width = 5, side = "left", pad = "0"),
      sdi_score = SDI_score
    )

  expect_equal(result$zcta, "01001")
  expect_equal(result$sdi_score, 33L)
  # Confirm raw z-score is NOT present in output
  expect_false("sdi" %in% names(result))
})
