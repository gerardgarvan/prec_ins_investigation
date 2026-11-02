# R/00_build_prov_spec.R
# Build provider specialty cancer-flag lookup from nucc_taxonomy_210.xlsx
# SAS source: SAS_CODE_FOR_v5_1.sas lines 45-50 (PROC IMPORT, range "sas$A1:D866")
#             SAS_CODE_FOR_V5_2.sas lines 11-19 (LEFT JOIN on PROVIDER_SPECIALTY_PRIMARY)
# Output: {data_dir_processed}/01_imported_prov_spec.rds
#   Columns: provider_specialty_primary (character), cancer_provider (integer 0/1)
#
# Notes:
#   - Sheet "sas", A1:D866 => 865 data rows, 4 columns
#   - Column A = PROVIDER_SPECIALTY_PRIMARY (NUCC taxonomy code, e.g. "207RX0202X")
#   - Column D = Cancer_provider ("1" or "0" as text)
#   - 21 codes are flagged as Cancer_provider = "1"
#   - Missing join in 02_merge.R -> cancer_provider stays NA -> filled to 0 downstream

library(here)
if (!exists("reference_dir")) source(here::here("R", "config.R"))
if (!requireNamespace("readxl", quietly = TRUE)) stop("readxl not installed. Run: install.packages('readxl')")
library(readxl)
library(dplyr)
library(stringr)

xlsx_path <- file.path(reference_dir, "nucc_taxonomy_210.xlsx")
if (!file.exists(xlsx_path)) {
  stop(
    "nucc_taxonomy_210.xlsx not found at: ", xlsx_path, "\n",
    "Copy from /orange/erin.mobley-precision/ (originally F:\\Jax_Ascent\\) to reference/"
  )
}

# Read all 4 columns as text to avoid numeric coercion of codes
# SAS range: "sas$A1:D866" -- 865 data rows
prov_raw <- read_excel(
  xlsx_path, sheet = "sas",
  range = "A1:D866", col_types = "text"
)

# Column A = specialty code; Column D = Cancer_provider flag
# Normalize column names: use positions to be robust to Excel header casing
col_names_raw <- names(prov_raw)
message("nucc_taxonomy_210.xlsx columns (raw): ", paste(col_names_raw, collapse = ", "))

# Column A is provider_specialty_primary (Code), Column D is Cancer_provider
prov_spec <- prov_raw %>%
  rename(
    provider_specialty_primary = 1,
    cancer_provider_raw        = 4
  ) %>%
  select(provider_specialty_primary, cancer_provider_raw) %>%
  filter(!is.na(provider_specialty_primary), str_trim(provider_specialty_primary) != "") %>%
  mutate(
    # Normalize join key: upper + trim to match provider table values
    provider_specialty_primary = str_trim(toupper(provider_specialty_primary)),
    # Convert "1"/"0" text to integer; anything else -> 0 (safe default)
    cancer_provider = if_else(str_trim(cancer_provider_raw) == "1", 1L, 0L, missing = 0L)
  ) %>%
  select(provider_specialty_primary, cancer_provider)

n_flagged <- sum(prov_spec$cancer_provider == 1L)
message("prov_spec: ", nrow(prov_spec), " rows | flagged cancer_provider=1: ", n_flagged)

if (n_flagged != 21L) {
  warning(
    "DATA INTEGRITY: expected 21 flagged cancer specialty codes, found ", n_flagged, ".\n",
    "The nucc_taxonomy_210.xlsx file may differ from the version used in SAS.\n",
    "Verify against SAS_CODE_FOR_v5_1.sas and nucc_taxonomy_210.xlsx sheet 'sas' column D."
  )
}

# Log all flagged codes for DATA_LINEAGE.md documentation
flagged_codes <- prov_spec %>% filter(cancer_provider == 1L) %>% pull(provider_specialty_primary)
message("Flagged cancer specialty codes (", length(flagged_codes), "):")
message("  ", paste(flagged_codes, collapse = "\n  "))

saveRDS(prov_spec, file.path(data_dir_processed, "01_imported_prov_spec.rds"))
message("Saved: 01_imported_prov_spec.rds (", nrow(prov_spec),
        " rows | cols: ", paste(names(prov_spec), collapse = ", "), ")")
