# R/00_build_sdi.R
# Build SDI lookup table from Robert Graham Center SDI file (2011-2015 ACS, by ZCTA)
# Source: reference/asset_rgc_sdi_2011_through_2015_zcta.csv
#         Robert Graham Center — Social Deprivation Index (RGC SDI), 2011-2015 ACS
#         Replaces: reference/ACS2015_zctaallvars.xlsx (same ACS vintage, never obtained)
# Output: data/processed/01_imported_sdi.rds
#
# Columns used: ZCTA5_FIPS (zero-padded to 5 chars -> renamed zcta),
#               SDI_score (1-100 PERCENTILE — USE THIS, not the raw `sdi` composite z-score)
#
# NOTE on column choice: The CSV contains two SDI-related columns:
#   - SDI_score: 1-100 percentile score (integer; e.g. 33, 65). THIS IS USED.
#   - sdi: raw composite z-score (e.g. -0.536, 0.399). NOT used — task specifies percentile.
# The 1-100 percentile scale matches the SAS SDI derivation intent (V5_5 line 359-383).

library(here)
source(here::here("R", "config.R"))
library(readr)
library(dplyr)
library(stringr)

sdi_path <- here::here("reference", "asset_rgc_sdi_2011_through_2015_zcta.csv")

if (!file.exists(sdi_path)) {
  stop("SDI reference file missing: reference/asset_rgc_sdi_2011_through_2015_zcta.csv\n",
       "This is the Robert Graham Center SDI 2011-2015 ACS file (by ZCTA).\n",
       "It should be committed to reference/ in this repo.")
}

message("Reading asset_rgc_sdi_2011_through_2015_zcta.csv...")

sdi_raw <- readr::read_csv(
  sdi_path,
  col_types = cols(
    ZCTA5_FIPS = col_character(),  # read as text to allow leading-zero padding
    SDI_score  = col_integer(),
    .default   = col_guess()
  ),
  show_col_types = FALSE
)

message("  Raw rows: ", nrow(sdi_raw), "  cols: ", ncol(sdi_raw))

# Build the lookup: zero-pad ZCTA5_FIPS to 5 chars and keep SDI_score (percentile)
sdi <- sdi_raw |>
  dplyr::transmute(
    # ZCTA5_FIPS is numeric in raw CSV (e.g. 1001, 1002) — zero-pad to 5-char text ("01001")
    # to match zcta table ADDRESS_ZIP5->zcta keys which are 5-char zero-padded strings
    zcta      = stringr::str_pad(ZCTA5_FIPS, width = 5, side = "left", pad = "0"),
    # Use SDI_score (1-100 percentile), NOT the raw `sdi` composite z-score column
    sdi_score = SDI_score
  )

message("  Rows after transmute: ", nrow(sdi))
message("  sdi_score range: ", min(sdi$sdi_score, na.rm = TRUE), " - ",
        max(sdi$sdi_score, na.rm = TRUE), " (expected ~1-100)")
n_leading_zero <- sum(substr(sdi$zcta, 1, 1) == "0", na.rm = TRUE)
message("  Leading-zero ZCTAs (confirms padding worked): ", n_leading_zero)

saveRDS(sdi, file.path(data_dir_processed, "01_imported_sdi.rds"))
message("Saved: 01_imported_sdi.rds (", nrow(sdi), " ZCTAs)")
