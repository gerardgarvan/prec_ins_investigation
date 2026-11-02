# R/00_build_ndc.R
# Build NDC reference table from SEER*Rx public NDC export
# Source: reference/ndconc_results_new.csv
#         SEER*Rx (public export; no patient data)
# Output: data/processed/01_imported_ndc.rds
#
# Columns used: NDC_11_Package_ (11-digit package NDC), NDC_9_Product_ (dashed product NDC),
#               SEERRxCategory (text category: Ancillary Therapy, Chemotherapy, etc.)
#
# JOIN KEY: ndc9 = de-dashed NDC_9_Product_ (strip non-digits, take first 9).
#   Reference: "72205-0061" -> strip dashes -> "722050061" (already 9 digits)
#   Dispensing: "72205006101" -> first 9 chars -> "722050061"  (match!)
#
# CATEGORY RECODE (SAS V5_12 $seer format):
#   "Ancillary Therapy"              -> "1"
#   "Chemotherapy"                   -> "2"
#   "Chemotherapy, Hormonal Therapy" -> "3"
#   "Hormonal Therapy"               -> "4"
#   "Immunotherapy"                  -> "5"
#   "Radiopharmaceutical"            -> "6"
#
# chemo_disp: seer_cat_code in {"2","3","4","5","6"}  (SAS V5_12 != "1")
# anc_disp:   seer_cat_code == "1"

library(here)
source(here::here("R", "config.R"))
library(readr)
library(dplyr)
library(stringr)
library(janitor)

ndc_path <- here::here("reference", "ndconc_results_new.csv")

if (!file.exists(ndc_path)) {
  stop("NDC reference file missing: reference/ndconc_results_new.csv\n",
       "This is the SEER*Rx public NDC export (no patient data).\n",
       "Obtain from https://seer.cancer.gov/seerstat/databases/ndcseer/ and commit to reference/.")
}

message("Reading ndconc_results_new.csv...")

ndc_raw <- readr::read_csv(
  ndc_path,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

message("  Raw rows: ", nrow(ndc_raw), "  cols: ", ncol(ndc_raw))

# Standardize column names to snake_case (janitor)
ndc_raw <- janitor::clean_names(ndc_raw)
# After clean_names: NDC_11_Package_ -> ndc_11_package_, NDC_9_Product_ -> ndc_9_product_
# SEERRxCategory -> seer_rx_category

# Identify the actual column names (clean_names output may vary by CSV header)
pkg_col  <- grep("ndc.*11.*package", names(ndc_raw), value = TRUE, ignore.case = TRUE)[1]
prod_col <- grep("ndc.*9.*product",  names(ndc_raw), value = TRUE, ignore.case = TRUE)[1]
cat_col  <- grep("seer.*rx.*cat|seer_rx_cat", names(ndc_raw), value = TRUE, ignore.case = TRUE)[1]

if (is.na(pkg_col))  stop("Cannot find NDC_11_Package_ column in ndconc_results_new.csv after clean_names(). Columns: ", paste(names(ndc_raw), collapse = ", "))
if (is.na(prod_col)) stop("Cannot find NDC_9_Product_ column in ndconc_results_new.csv after clean_names(). Columns: ", paste(names(ndc_raw), collapse = ", "))
if (is.na(cat_col))  stop("Cannot find SEERRxCategory column in ndconc_results_new.csv after clean_names(). Columns: ", paste(names(ndc_raw), collapse = ", "))

message("  Column mapping: pkg=", pkg_col, " | prod=", prod_col, " | cat=", cat_col)

# Build ndc9 key: strip all non-digit chars from the dashed product NDC, take first 9
# "72205-0061" -> "722050061" (9 digits after stripping dash)
ndc <- ndc_raw |>
  dplyr::transmute(
    ndc11            = stringr::str_remove_all(.data[[pkg_col]],  "[^0-9]"),
    ndc9             = substr(stringr::str_remove_all(.data[[prod_col]], "[^0-9]"), 1, 9),
    seer_rx_category = .data[[cat_col]],
    seer_cat_code    = dplyr::case_when(
      seer_rx_category == "Ancillary Therapy"              ~ "1",
      seer_rx_category == "Chemotherapy"                   ~ "2",
      seer_rx_category == "Chemotherapy, Hormonal Therapy" ~ "3",
      seer_rx_category == "Hormonal Therapy"               ~ "4",
      seer_rx_category == "Immunotherapy"                  ~ "5",
      seer_rx_category == "Radiopharmaceutical"            ~ "6",
      TRUE                                                  ~ NA_character_
    )
  )

# Log any unmapped categories
unmapped <- ndc |> dplyr::filter(is.na(seer_cat_code)) |>
  dplyr::count(seer_rx_category, name = "n_rows")
if (nrow(unmapped) > 0) {
  message("  WARNING: Unmapped SEERRxCategory values (not in $seer format):")
  print(unmapped)
}

# Drop rows with missing ndc9
n_before <- nrow(ndc)
ndc <- dplyr::filter(ndc, !is.na(ndc9) & nchar(ndc9) > 0)
if (n_before > nrow(ndc)) {
  message("  Dropped ", n_before - nrow(ndc), " rows with empty/NA ndc9")
}

# Keep distinct(ndc9, seer_cat_code); log ambiguous mappings (ndc9 -> >1 code)
ndc_distinct <- dplyr::distinct(ndc, ndc9, seer_cat_code, .keep_all = TRUE)
ambiguous <- ndc_distinct |>
  dplyr::count(ndc9, name = "n_codes") |>
  dplyr::filter(n_codes > 1)
if (nrow(ambiguous) > 0) {
  message("  NOTE: ", nrow(ambiguous), " ndc9 values map to >1 SEERRxCategory code (ambiguity):")
  print(head(ambiguous, 10))
}

# Final reference table: distinct(ndc9, seer_cat_code) + original text + ndc11
ndc_ref <- ndc_distinct |>
  dplyr::select(ndc9, ndc11, seer_rx_category, seer_cat_code)

message("  Final reference rows: ", nrow(ndc_ref), " (distinct ndc9 x seer_cat_code)")
message("  seer_cat_code distribution:")
print(janitor::tabyl(ndc_ref, seer_cat_code))

saveRDS(ndc_ref, file.path(data_dir_processed, "01_imported_ndc.rds"))
message("Saved: 01_imported_ndc.rds (", nrow(ndc_ref), " NDC-category pairs)")
