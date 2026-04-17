# R/01_import.R
# Import all required V5 SAS7BDAT files for the Precision Cancer Survivorship pipeline
# Per IMP-01: Uses haven::read_sas() with correct encoding
# Per IMP-03: Validates SAS date conversion to R Date objects
# Per IMP-05: Preserves SAS variable labels as R attributes
# Per INF-05: Saves .rds checkpoints for each imported dataset
# Per INF-04: All SAS logic decisions documented in inline comments
# Per D-10: V5 is primary target. SAS code uses "v3" alias for Data_v5 directory.
#
# Raw V5 Data Tables Inventory (from forensic analysis of V5 SAS files):
# -----------------------------------------------------------------------
# From Data_v5/ directory (SAS alias: v3):
#   1. demographic_mobley_v5.sas7bdat     — Patient demographics (SOURCE: V5_2 line 54)
#   2. Enrollment_mobley_v5.sas7bdat      — Patient enrollment (SOURCE: V5_2 line 39)
#   3. Address_history_mobley_v5.sas7bdat — Address history (SOURCE: V5_2 line 23)
#   4. diagnosis_mobley1_v5.sas7bdat      — Diagnosis part 1 of 7 (SOURCE: V5_2 line 100)
#   5. diagnosis_mobley2_v5.sas7bdat      — Diagnosis part 2 of 7
#   6. diagnosis_mobley3_v5.sas7bdat      — Diagnosis part 3 of 7
#   7. diagnosis_mobley4_v5.sas7bdat      — Diagnosis part 4 of 7
#   8. diagnosis_mobley5_v5.sas7bdat      — Diagnosis part 5 of 7
#   9. diagnosis_mobley6_v5.sas7bdat      — Diagnosis part 6 of 7
#  10. diagnosis_mobley7_v5.sas7bdat      — Diagnosis part 7 of 7
#  11. provider.sas7bdat                  — Provider data (SOURCE: V5_2 line 18)
#  12. prov_spec.sas7bdat                 — Provider specialty reference (SOURCE: V5_2 line 19)
#  13. ruca.sas7bdat                      — RUCA codes reference (SOURCE: V5_2 line 37)
#  14. dispensing_mobley_v5.sas7bdat      — Dispensing/prescriptions (SOURCE: V5_12 line 22)
#  15. procedures_mobley1_v5.sas7bdat     — Procedures part 1 of 4 (SOURCE: V5_12 line 149)
#  16. procedures_mobley2_v5.sas7bdat     — Procedures part 2 of 4
#  17. procedures_mobley3_v5.sas7bdat     — Procedures part 3 of 4
#  18. procedures4_mobley_v5.sas7bdat     — Procedures part 4 of 4 (NOTE: naming inconsistency)
#
# From Dx/ directory (SAS alias: dx):
#  19. Icd10_groups2.sas7bdat             — ICD-10 cancer site groups (SOURCE: V5_3 line 49)
#
# SAS BUG FIX: SAS code uses "v3" alias for Data_v5 directory (confusing).
# R config uses clear name: data_dir_raw. See config.R for documentation.

source("/home/ggarvan/prec_ins_investigation/R/config.R")
library(haven)
library(tidyverse)
library(janitor)

# Load format definitions from Phase 1 checkpoint
sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

message("========================================")
message("Starting SAS data import at ", Sys.time())
message("Data directory: ", data_dir_raw)
message("Encoding: ", sas_encoding)
message("========================================")

#' Import a SAS7BDAT file with standard validation
#' @param filename Character, the .sas7bdat filename (without path)
#' @param data_dir Character, directory containing the file (default: data_dir_raw)
#' @param description Character, human-readable description for logging
#' @return Tibble with clean names and preserved labels
import_sas <- function(filename, data_dir = data_dir_raw, description = filename) {
  filepath <- file.path(data_dir, filename)
  message("  Importing: ", description, " (", filename, ")")

  if (!file.exists(filepath)) {
    warning("File not found: ", filepath, " — skipping. ",
            "Place file in ", data_dir, " and rerun.")
    return(NULL)
  }

  df <- read_sas(data_file = filepath, encoding = sas_encoding)

  # Preserve original labels before clean_names potentially drops them
  original_labels <- purrr::map_chr(df, ~attr(.x, "label") %||% NA_character_)

  # Standardize column names (per CLN-01 prep, janitor convention)
  df <- janitor::clean_names(df)

  # Store original labels as an attribute on the data frame itself
  # (individual column labels may be lost during tidyverse operations per Research pitfall 5)
  attr(df, "sas_labels") <- original_labels

  # Per IMP-03: Check for date columns that should be Date class
  # SAS dates auto-convert via haven if they have DATE format metadata
  # Numeric dates (days since 1960-01-01) need manual conversion
  date_candidates <- names(df)[grepl("date|dt$|_dt$", names(df), ignore.case = TRUE)]
  for (col in date_candidates) {
    if (is.numeric(df[[col]]) && !inherits(df[[col]], "Date")) {
      # Check if values are in plausible SAS date range (days since 1960-01-01)
      # Year 1950 = -3653 days, Year 2030 = 25567 days from 1960 origin
      vals <- df[[col]][!is.na(df[[col]])]
      if (length(vals) > 0 && all(vals > -5000 & vals < 30000)) {
        message("    NOTE: Converting ", col, " from numeric to Date (SAS origin 1960-01-01)")
        message("    # SAS date variable without format metadata - manual conversion applied")
        df[[col]] <- as.Date(df[[col]], origin = "1960-01-01")
      }
    }
  }

  message("    Rows: ", format(nrow(df), big.mark = ","),
          " | Cols: ", ncol(df),
          " | Labels preserved: ", sum(!is.na(original_labels)), "/", length(original_labels))

  return(df)
}

# ============================================================
# GROUP 1: Core patient data
# Source: SAS_CODE_FOR_V5_2.sas lines 39-97
# SAS pattern: v3.demographic_mobley_v5, v3.Enrollment_mobley_v5
# NOTE: SAS "v3" alias = Data_v5 directory (per D-10)
# ============================================================

demo <- import_sas("demographic_mobley_v5.sas7bdat",
                    description = "Patient demographics")

enroll <- import_sas("Enrollment_mobley_v5.sas7bdat",
                     description = "Patient enrollment periods")

address <- import_sas("Address_history_mobley_v5.sas7bdat",
                      description = "Address history for RUCA/SDI linkage")

# ============================================================
# GROUP 2: Diagnosis data (7 parts — SAS concatenates with SET statement)
# Source: SAS_CODE_FOR_V5_2.sas lines 100-108
# SAS pattern: data v3.diagnosis; set v3.diagnosis_mobley1_v5
#                                     v3.diagnosis_mobley2_v5 ... v3.diagnosis_mobley7_v5;
# R equivalent: Import individually, then bind_rows() in Phase 2
# ============================================================

dx_parts <- list()
for (i in 1:7) {
  filename <- paste0("diagnosis_mobley", i, "_v5.sas7bdat")
  dx_parts[[i]] <- import_sas(filename,
                               description = paste("Diagnosis part", i, "of 7"))
}
# Remove any NULL entries (missing files)
dx_parts <- purrr::compact(dx_parts)
if (length(dx_parts) > 0) {
  message("  Diagnosis parts loaded: ", length(dx_parts), "/7")
}

# ============================================================
# GROUP 3: Provider and specialty data
# Source: SAS_CODE_FOR_V5_2.sas lines 11-20
# SAS pattern: v3.provider, v3.prov_spec
# ============================================================

provider <- import_sas("provider.sas7bdat",
                        description = "Provider data")

prov_spec <- import_sas("prov_spec.sas7bdat",
                         description = "Provider specialty reference (cancer provider flag)")

# ============================================================
# GROUP 4: Geographic reference data
# Source: SAS_CODE_FOR_V5_2.sas lines 27-37
# SAS pattern: v3.ruca (RUCA codes for rural-urban classification)
# ============================================================

ruca <- import_sas("ruca.sas7bdat",
                    description = "RUCA rural-urban classification codes")

# ============================================================
# GROUP 5: Dispensing/prescription data
# Source: SAS_CODE_FOR_V5_12.sas lines 22-29
# SAS pattern: v4.dispensing_mobley_v5
# NOTE: V5_12 confusingly uses "v4" alias for Data_v5 directory
# SAS BUG FIX: V5_12 line 15 has "libname v4 &path/Data_v5/" — v4 alias points to v5 data
# ============================================================

dispensing <- import_sas("dispensing_mobley_v5.sas7bdat",
                          description = "Dispensing/prescription data")

# ============================================================
# GROUP 6: Procedures data (4 parts)
# Source: SAS_CODE_FOR_V5_12.sas line 149
# SAS pattern: set v4.procedures_mobley1_v5 v4.procedures_mobley2_v5
#                  v4.procedures_mobley3_v5 v4.procedures4_mobley_v5
# NOTE: Part 4 has inconsistent naming: "procedures4_mobley_v5" not "procedures_mobley4_v5"
# SAS BUG FIX: Inconsistent file naming — procedures 1-3 use "procedures_mobleyN" but
# part 4 uses "procedures4_mobley". Preserved in R import to match actual file names.
# ============================================================

proc_files <- c(
  "procedures_mobley1_v5.sas7bdat",
  "procedures_mobley2_v5.sas7bdat",
  "procedures_mobley3_v5.sas7bdat",
  "procedures4_mobley_v5.sas7bdat"  # NOTE: naming inconsistency in part 4
)

proc_parts <- list()
for (i in seq_along(proc_files)) {
  proc_parts[[i]] <- import_sas(proc_files[i],
                                 description = paste("Procedures part", i, "of 4"))
}
proc_parts <- purrr::compact(proc_parts)
if (length(proc_parts) > 0) {
  message("  Procedure parts loaded: ", length(proc_parts), "/4")
}

# ============================================================
# GROUP 7: ICD code reference data (separate Dx directory)
# Source: SAS_CODE_FOR_V5_3.sas line 49
# SAS pattern: dx.Icd10_groups2
# SAS libname: libname dx "/blue/erin.mobley-precision/ResVault/f/Dx";
# R equivalent: Place Icd10_groups2.sas7bdat in data/raw/ or a subdirectory
# Per D-04: Path parameterized, user adjusts config.R if in different location
# ============================================================

# NOTE: ICD reference data may be in a separate directory from main V5 data.
# Check data_dir_raw first, then try a "Dx" subdirectory.
icd_groups <- import_sas("Icd10_groups2.sas7bdat",
                          description = "ICD-10 cancer site group mapping")
if (is.null(icd_groups)) {
  # Try Dx subdirectory (matches SAS library structure)
  dx_dir <- file.path(data_dir_raw, "Dx")
  if (dir.exists(dx_dir)) {
    icd_groups <- import_sas("Icd10_groups2.sas7bdat",
                              data_dir = dx_dir,
                              description = "ICD-10 cancer site groups (from Dx/ subdir)")
  }
}

# ============================================================
# SAVE CHECKPOINTS (per D-08: .rds checkpoints between pipeline stages)
# ============================================================

save_checkpoint <- function(obj, name) {
  if (!is.null(obj)) {
    path <- file.path(data_dir_processed, paste0("01_imported_", name, ".rds"))
    saveRDS(obj, path)
    message("  Saved: ", name, ".rds (", format(nrow(obj), big.mark = ","), " rows)")
  } else {
    message("  Skipped (NULL): ", name)
  }
}

# Core patient data
save_checkpoint(demo, "demo")
save_checkpoint(enroll, "enroll")
save_checkpoint(address, "address")

# Diagnosis parts (save as list for Phase 2 to bind_rows)
if (length(dx_parts) > 0) {
  saveRDS(dx_parts, file.path(data_dir_processed, "01_imported_dx_parts.rds"))
  total_dx_rows <- sum(purrr::map_int(dx_parts, nrow))
  message("  Saved: dx_parts.rds (", length(dx_parts), " parts, ",
          format(total_dx_rows, big.mark = ","), " total rows)")
}

# Provider data
save_checkpoint(provider, "provider")
save_checkpoint(prov_spec, "prov_spec")

# Geographic reference
save_checkpoint(ruca, "ruca")

# Dispensing
save_checkpoint(dispensing, "dispensing")

# Procedure parts (save as list)
if (length(proc_parts) > 0) {
  saveRDS(proc_parts, file.path(data_dir_processed, "01_imported_proc_parts.rds"))
  total_proc_rows <- sum(purrr::map_int(proc_parts, nrow))
  message("  Saved: proc_parts.rds (", length(proc_parts), " parts, ",
          format(total_proc_rows, big.mark = ","), " total rows)")
}

# ICD reference
save_checkpoint(icd_groups, "icd_groups")

# ============================================================
# DATE VALIDATION (per IMP-03)
# Per Research pitfall 2: Some SAS date variables may import as numeric
# if they lack explicit DATE format metadata. The import_sas() helper
# auto-converts plausible numeric dates, but verify key date columns here.
#
# VALIDATION CHECKLIST (run when data is available):
# - demo$birth_date: expect Date class, range ~1920-2020
# - enroll$enr_end_date: expect Date class, range ~2010-2025
# - enroll$enr_start_date: expect Date class, range ~2010-2025
# - address$address_period_start: expect Date class
# - address$address_period_end: expect Date class
# - dx_parts[[1]]$admit_date: expect Date class
# - dx_parts[[1]]$dx_date: expect Date class
# ============================================================

validate_date_columns <- function(df, name, expected_date_cols) {
  if (is.null(df)) return(invisible(NULL))
  for (col in expected_date_cols) {
    col_clean <- janitor::make_clean_names(col)
    if (col_clean %in% names(df)) {
      if (inherits(df[[col_clean]], "Date")) {
        message("  OK: ", name, "$", col_clean, " is Date class")
      } else {
        warning("  CHECK: ", name, "$", col_clean, " is ", class(df[[col_clean]])[1],
                " — may need manual date conversion from SAS origin 1960-01-01")
      }
    }
  }
}

validate_date_columns(demo, "demo", c("BIRTH_DATE"))
validate_date_columns(enroll, "enroll", c("ENR_START_DATE", "ENR_END_DATE"))
validate_date_columns(address, "address", c("ADDRESS_PERIOD_START", "ADDRESS_PERIOD_END"))
if (length(dx_parts) > 0) {
  validate_date_columns(dx_parts[[1]], "dx_parts[[1]]", c("ADMIT_DATE", "DX_DATE"))
}

# ============================================================
# LABEL PRESERVATION REPORT (per IMP-05)
# SAS variable labels stored as "sas_labels" attribute on each data frame
# Access via: attr(demo, "sas_labels")
# ============================================================

report_labels <- function(df, name) {
  if (is.null(df)) return(invisible(NULL))
  labels <- attr(df, "sas_labels")
  if (!is.null(labels)) {
    n_labelled <- sum(!is.na(labels))
    message("  ", name, ": ", n_labelled, "/", length(labels), " variables have SAS labels")
  }
}

message("\nLabel preservation report:")
report_labels(demo, "demo")
report_labels(enroll, "enroll")
report_labels(address, "address")
if (length(dx_parts) > 0) report_labels(dx_parts[[1]], "dx_parts[[1]]")
report_labels(provider, "provider")
report_labels(dispensing, "dispensing")

message("\n========================================")
message("Import complete at ", Sys.time())
message("Checkpoints saved to: ", data_dir_processed)
message("========================================")
message("\nIMPORTED DATASETS SUMMARY:")
message("  Core: demo, enroll, address")
message("  Diagnosis: ", length(dx_parts), " parts")
message("  Provider: provider, prov_spec")
message("  Geographic: ruca")
message("  Dispensing: dispensing")
message("  Procedures: ", length(proc_parts), " parts")
message("  ICD reference: icd_groups")
message("\nNext step: R/02_clean.R (Phase 2)")
