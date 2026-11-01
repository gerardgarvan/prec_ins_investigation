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

message("========================================")
message("Starting SAS data import at ", Sys.time())
message("Data directory: ", data_dir_raw)
message("Encoding: ", sas_encoding)
slurm_mem <- Sys.getenv("SLURM_MEM_PER_NODE", unset = NA)
if (!is.na(slurm_mem)) message("SLURM memory allocation: ", slurm_mem, " MB")
message("========================================")

# GROUP 1: Core patient data (small; read in full)
# Source: SAS_CODE_FOR_V5_2.sas lines 39-97
demo <- import_sas("demographic_mobley_v5.sas7bdat", description = "Patient demographics")
save_checkpoint(demo, "demo"); rm(demo); gc(verbose = FALSE)

enroll <- import_sas("enrollment_mobley_v5.sas7bdat", description = "Patient enrollment periods")
save_checkpoint(enroll, "enroll"); rm(enroll); gc(verbose = FALSE)

address <- import_sas("address_history_mobley_v5.sas7bdat",
                      description = "Address history for RUCA/SDI linkage")
save_checkpoint(address, "address"); rm(address); gc(verbose = FALSE)

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
# Source: SAS_CODE_FOR_V5_2.sas lines 11-20
provider <- import_sas("provider_mobley_v5.sas7bdat", description = "Provider data (with specialty)")
save_checkpoint(provider, "provider"); rm(provider); gc(verbose = FALSE)

# GROUP 4: Geographic reference data (ZCTA-based)
# Source: SAS_CODE_FOR_V5_2.sas lines 27-37
# NOTE: actual file is zcta.sas7bdat (not ruca.sas7bdat)
zcta <- import_sas("zcta.sas7bdat", description = "ZCTA geographic reference (SDI/RUCA linkage)")
save_checkpoint(zcta, "zcta"); rm(zcta); gc(verbose = FALSE)

# GROUP 5: Dispensing/prescription data
# Source: SAS_CODE_FOR_V5_12.sas lines 22-29
dispensing <- import_sas("dispensing_mobley_v5.sas7bdat",
                         description = "Dispensing/prescription data",
                         keep_cols = KEEP_DISP)
save_checkpoint(dispensing, "dispensing"); rm(dispensing); gc(verbose = FALSE)

# GROUP 6: Procedures data (4 parts)
# Source: SAS_CODE_FOR_V5_12.sas line 149
# SAS BUG FIX: Part 4 naming inconsistency — "procedures4_mobley_v5"
# Each part saved individually; combined in 02_clean.R after patient filtering.
import_parts(
  files = c("procedures_mobley1_v5.sas7bdat",
            "procedures_mobley2_v5.sas7bdat",
            "procedures_mobley3_v5.sas7bdat",
            "procedures4_mobley_v5.sas7bdat"),
  description = "proc",
  keep_cols   = KEEP_PROC
)

# GROUP 7: ICD code reference data (separate Dx directory)
# Source: SAS_CODE_FOR_V5_3.sas line 49
icd_groups <- import_sas("Icd10_groups2.sas7bdat", description = "ICD-10 cancer site group mapping")
if (is.null(icd_groups)) {
  dx_dir <- file.path(data_dir_raw, "Dx")
  if (dir.exists(dx_dir)) {
    icd_groups <- import_sas("Icd10_groups2.sas7bdat", data_dir = dx_dir,
                             description = "ICD-10 cancer site groups (from Dx/ subdir)")
  }
}
save_checkpoint(icd_groups, "icd_groups"); rm(icd_groups); gc(verbose = FALSE)

message("\n========================================")
message("Import complete at ", Sys.time())
message("Checkpoints saved to: ", data_dir_processed)
message("========================================")
message("\nIMPORTED DATASETS SUMMARY (checkpoints in data/processed/):")
message("  01_imported_demo.rds, enroll.rds, address.rds")
message("  01_imported_dx_combined.rds")
message("  01_imported_provider.rds, prov_spec.rds, ruca.rds")
message("  01_imported_dispensing.rds")
message("  01_imported_proc_combined.rds")
message("  01_imported_icd_groups.rds")
message("\nNext step: R/02_clean.R (Phase 2)")
