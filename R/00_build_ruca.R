# R/00_build_ruca.R
# Build RUCA lookup table from USDA ERS RUCA2010zipcode.xlsx
# SAS source: F:\Jax_Ascent\RUCA2010zipcode.xlsx (same file, renamed sheet)
# Output: data/processed/01_imported_ruca.rds
#
# Sheet "Data": 41,164 rows
# Columns: ZIP_CODE (5-char text), STATE, ZIP_TYPE, RUCA1 (1-10, 99), RUCA2 (with decimals)
# SAS column names after import: ADDRESS_ZIP5, STATE_ruca, ZIP_TYPE_ruca, RUCA1, RUCA2

library(here)
source(here::here("R", "config.R"))
library(readxl)

ruca_path <- here::here("reference", "RUCA2010zipcode.xlsx")
if (!file.exists(ruca_path)) {
  stop("RUCA reference file missing: reference/RUCA2010zipcode.xlsx\n",
       "Download from USDA ERS: https://www.ers.usda.gov/webdocs/DataFiles/53241/ruca2010revised.xlsx\n",
       "Save as reference/RUCA2010zipcode.xlsx with sheet named 'Data'.")
}

message("Reading RUCA2010zipcode.xlsx sheet 'Data'...")

ruca_raw <- read_excel(
  ruca_path,
  sheet = "Data",
  col_types = "text"   # read all as text — ZIP_CODE has leading zeros
)

message("  Raw rows: ", nrow(ruca_raw), "  cols: ", ncol(ruca_raw))

# Rename to match SAS column names used throughout the pipeline
ruca <- ruca_raw |>
  dplyr::rename(
    ADDRESS_ZIP5 = ZIP_CODE,
    STATE_ruca   = STATE,
    ZIP_TYPE_ruca = ZIP_TYPE
  ) |>
  dplyr::mutate(
    RUCA1 = suppressWarnings(as.numeric(RUCA1)),
    RUCA2 = suppressWarnings(as.numeric(RUCA2))
  )

message("  Rows after rename: ", nrow(ruca))
message("  RUCA1 range (excl 99 and NA): ",
        min(ruca$RUCA1[!is.na(ruca$RUCA1) & ruca$RUCA1 != 99], na.rm = TRUE), " - ",
        max(ruca$RUCA1[!is.na(ruca$RUCA1) & ruca$RUCA1 != 99], na.rm = TRUE))
message("  RUCA1=99 (water/territories): ", sum(ruca$RUCA1 == 99, na.rm = TRUE), " ZIPs")
message("  Leading-zero ZIPs preserved: ",
        sum(nchar(ruca$ADDRESS_ZIP5) == 5 & substr(ruca$ADDRESS_ZIP5, 1, 1) == "0"))

saveRDS(ruca, file.path(data_dir_processed, "01_imported_ruca.rds"))
message("Saved: 01_imported_ruca.rds (", nrow(ruca), " ZIP codes)")
