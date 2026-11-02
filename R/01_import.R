# R/01_import.R
# Import all required V5 SAS7BDAT files for the Precision Cancer Survivorship pipeline
# Per IMP-01: Uses haven::read_sas() with correct encoding
# Per IMP-03: Validates SAS date conversion to R Date objects
# Per IMP-05: Preserves SAS variable labels as R attributes
# Per INF-05: Saves .rds checkpoints for each imported dataset
# Per D-10: V5 is primary target. SAS code uses "v3" alias for Data_v5 directory.
#
# MEMORY REVISION (HiPerGator crash at import):
#   - Large tables (diagnosis, procedures, dispensing) are read with column
#     selection (KEEP_* vectors below). Edit these if a downstream script needs
#     another column. NULL = read every column.
#   - Multi-part files are stacked once (import_parts) instead of in a growing loop.
#   - Small tables (demo, enrollment, address, provider, reference) are read in full.
#   - Run as a SLURM batch job with enough memory (see run_import.sbatch).
#
# Raw V5 Data Tables Inventory: see original header (unchanged file list).

library(here)
source(here::here("R", "config.R"))
source(here::here("R", "utils_import.R"))
library(tidyverse)

# Load format definitions from Phase 1 checkpoint
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

# ------------------------------------------------------------
# Columns to keep for the large tables (case-insensitive SAS names)
# Derived from what 02_clean.R through 04_regression.R reference.
# NOTE: admit_date / enc_type / providerid are deliberately NOT kept from
# diagnosis or procedures. They duplicate ENCOUNTER columns, and keeping them
# would produce admit_date.x / admit_date.y after the patid+encounterid joins
# in 02_merge.R. The encounter table remains the source for those fields.
# ------------------------------------------------------------
KEEP_DX <- c("ID", "DIAGNOSISID", "ENCOUNTERID", "DX", "DX_TYPE",
             "DX_DATE", "DX_SOURCE", "PDX")

KEEP_PROC <- c("ID", "PROCEDURESID", "ENCOUNTERID", "PX", "PX_TYPE",
               "PX_DATE", "PX_SOURCE", "PPX")

KEEP_DISP <- c("ID", "DISPENSINGID", "NDC", "DISPENSE_DATE",
               "DISPENSE_SUP", "DISPENSE_AMT")

KEEP_ENC <- c("ID", "ENCOUNTERID", "ADMIT_DATE", "DISCHARGE_DATE", "ENC_TYPE",
              "DISCHARGE_STATUS", "DISCHARGE_DISPOSITION", "PAYER_TYPE_PRIMARY",
              "PAYER_TYPE_SECONDARY", "PROVIDERID", "FACILITYID", "DRG", "SOURCE")

message("========================================")
message("Starting SAS data import at ", Sys.time())
message("Data directory: ", data_dir_raw)
message("Encoding: ", sas_encoding)
slurm_mem <- Sys.getenv("SLURM_MEM_PER_NODE", unset = NA)
if (!is.na(slurm_mem)) message("SLURM memory allocation: ", slurm_mem, " MB")
message("========================================")

# GROUP 1: Core patient data (small; read in full)
# Source: SAS_CODE_FOR_V5_2.sas lines 39-97
import_and_save("demographic_mobley_v5.sas7bdat",   "demo",    "Patient demographics")
import_and_save("enrollment_mobley_v5.sas7bdat",    "enroll",  "Patient enrollment periods")
import_and_save("address_history_mobley_v5.sas7bdat","address", "Address history for RUCA/SDI linkage")

# GROUP 2: Diagnosis data (7 parts — SAS concatenates with SET statement)
# Source: SAS_CODE_FOR_V5_2.sas lines 100-108
# Each part is saved to its own RDS and discarded immediately (see import_parts).
# 02_clean.R reads and filters parts individually to avoid 50+ GB combined load.
import_parts(
  files       = paste0("diagnosis_mobley", 1:7, "_v5.sas7bdat"),
  description = "dx",
  keep_cols   = KEEP_DX
)

# GROUP 3: Provider data (specialty included in same file — no separate prov_spec)
import_and_save("provider_mobley_v5.sas7bdat", "provider", "Provider data (with specialty)")

# GROUP 4: Geographic reference data (ZCTA-based)
import_and_save("zcta.sas7bdat", "zcta", "ZCTA geographic reference (SDI/RUCA linkage)")

# GROUP 5: Dispensing/prescription data
import_and_save("dispensing_mobley_v5.sas7bdat", "dispensing", "Dispensing/prescription data",
                keep_cols = KEEP_DISP)

# GROUP 6: Procedures data (7 parts — procedures_mobley1_v5 through procedures_mobley7_v5)
# Source: SAS_CODE_FOR_V5_12.sas line 149
# Each part saved individually; combined in 02_clean.R after patient filtering.
import_parts(
  files = paste0("procedures_mobley", 1:7, "_v5.sas7bdat"),
  description = "proc",
  keep_cols   = KEEP_PROC
)

# GROUP 6b: Encounter data (2 parts — moved here from 02_clean.R to use save-and-discard pattern)
# Each part saved individually to blue; 02_clean.R reads RDS files instead of raw SAS.
import_parts(
  files       = c("encounter1_mobley_v5.sas7bdat", "encounter2_mobley_v5.sas7bdat"),
  description = "enc",
  keep_cols   = KEEP_ENC
)

# GROUP 7: ICD code reference data
out_icd <- file.path(data_dir_processed, "01_imported_icd_groups.rds")
if (file.exists(out_icd)) {
  message("  Skipping icd_groups — RDS already exists")
} else {
  icd_groups <- import_sas("Icd10_groups2.sas7bdat", description = "ICD-10 cancer site group mapping")
  if (is.null(icd_groups)) {
    dx_dir <- file.path(data_dir_raw, "Dx")
    if (dir.exists(dx_dir))
      icd_groups <- import_sas("Icd10_groups2.sas7bdat", data_dir = dx_dir,
                               description = "ICD-10 cancer site groups (from Dx/ subdir)")
  }
  save_checkpoint(icd_groups, "icd_groups"); rm(icd_groups); gc(verbose = FALSE)
}

message("\n========================================")
message("Import complete at ", Sys.time())
message("Checkpoints saved to: ", data_dir_processed)
message("========================================")
message("\nIMPORTED DATASETS SUMMARY (checkpoints in data/processed/):")
message("  01_imported_demo.rds, 01_imported_enroll.rds, 01_imported_address.rds")
message("  01_imported_dx_part1.rds .. 01_imported_dx_part7.rds")
message("  01_imported_provider.rds")
message("  01_imported_zcta.rds")
message("  01_imported_dispensing.rds")
message("  01_imported_proc_part1.rds .. 01_imported_proc_part7.rds")
message("  01_imported_enc_part1.rds, 01_imported_enc_part2.rds")
message("  01_imported_icd_groups.rds")
message("\nNext step: R/02_clean.R (Phase 2)")
