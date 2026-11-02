# R/02_clean.R
# Data Cleaning — data.table version (active).  OOM-safe rewrite:
#   - Encounters: rbindlist parts, recode in-place with :=
#   - Diagnosis:  per-part aggregation -> 02_dx_encounter.rds (one row per
#                 patid+encounterid; never materialises the 50+ GB combined table)
#   - Procedures: per-part patient-level flags -> 02_proc_patient_flags.rds
#   - Dispensing: reduce to distinct patids -> 02_dispensing_patids.rds
#
# Outputs:
#   02_encounters_cleaned.rds   (encounter-level, recoded)
#   02_dx_encounter.rds         (one row per patid+encounterid with cancer flags)
#   02_proc_patient_flags.rds   (one row per patid with treatment flags)
#   02_dispensing_patids.rds    (distinct patids that appear in dispensing)
#
# Removed outputs (no longer produced — would require 50+ GB in memory):
#   02_dx_combined.rds          -> replaced by 02_dx_encounter.rds
#   02_proc_combined.rds        -> replaced by 02_proc_patient_flags.rds

# ========================================
# Section 1 -- Setup
# ========================================

library(here)
source(here::here("R", "config.R"))
library(tidyverse)
library(data.table)
library(haven)
library(janitor)
library(assertr)

sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))

message("========================================")
message("Phase 2: Data Cleaning (data.table)")
message("Started: ", Sys.time())
message("========================================")

# ========================================
# Section 2 -- Import helpers
# ========================================

source(here::here("R", "utils_import.R"))

# ========================================
# Section 3 -- Encounter Load (CLN-02)
# ========================================

enc_cols_needed <- c(
  "patid", "encounterid", "providerid",
  "enc_type", "admit_date", "discharge_date",
  "discharge_status", "discharge_disposition",
  "payer_type_primary", "payer_type_secondary"
)

enc_part_files <- sort(list.files(data_dir_processed,
                                   pattern = "01_imported_enc_part\\d+\\.rds",
                                   full.names = TRUE))

# rbindlist() allocates the final table once — no intermediate copies.
encounters <- rbindlist(
  lapply(enc_part_files, function(f) {
    part <- readRDS(f)
    as.data.table(part)[, intersect(enc_cols_needed, names(part)), with = FALSE]
  }),
  use.names = TRUE, fill = TRUE
)
rm(enc_part_files); gc(verbose = FALSE)
message("Encounter rows: ", format(nrow(encounters), big.mark = ","),
        " | cols: ", ncol(encounters),
        " | in memory: ", format(object.size(encounters), units = "MB", standard = "legacy"))

# ========================================
# Section 4 -- Diagnosis: Per-Part Aggregation to Encounter Level
# ========================================
#
# SAS source: V5_3 lines 29-131
# SAS logic:
#   1. Left join each dx row to Icd10_groups2 on exact dx = ICD9_10 (V5_3 line 49)
#   2. Apply prefix/exact overrides for Group_Site (V5_3 lines 54-131, SAS =: operator)
#   3. any_reportable_cancer = (group_site != '')  (V5_3 line 128)
#
# R translation:
#   - Load icd_groups once; apply to each dx part
#   - Derive icd_personal_trt here (moved from 03_outcomes.R, V5_8 line 81)
#     so merged_complete carries the flag instead of raw dx rows
#   - Aggregate to one row per (patid, encounterid) before combining
#     -> never holds the full 50+ GB dx table in memory
#
# Per-encounter aggregation rules (match SAS PROC SORT + NODUPKEY pattern):
#   any_reportable_cancer: max over the encounter's dx rows
#   icd_personal_trt:      max of (dx in personal-treatment codes) across rows
#   cancer_dx / group_site: from the earliest cancer dx row by (dx_date, dx)
#                           per V5_4 sort by id desc cancer admit_date + NODUPKEY
#
# Must verify on HiPerGator:
#   names(readRDS(file.path(data_dir_processed, "01_imported_icd_groups.rds")))
#   Assumed join key column: "icd9_10" (from SAS column ICD9_10 after clean_names)
#   Assumed group column: "group_site" (from SAS column Group_Site after clean_names)

icd_path <- file.path(data_dir_processed, "01_imported_icd_groups.rds")
if (!file.exists(icd_path)) {
  stop(
    "01_imported_icd_groups.rds not found at: ", icd_path, "\n",
    "  Run R/01_import.R first to import Icd10_groups2.sas7bdat.\n",
    "  TODO(ERIN): confirm the canonical lookup source for ICD-10 cancer site groups ",
    "(Icd10_groups2.sas7bdat vs. a separate reference file)."
  )
}
icd_groups <- as.data.table(readRDS(icd_path))
message("icd_groups: ", nrow(icd_groups), " rows | cols: ", paste(names(icd_groups), collapse = ", "))

# ICD personal-treatment-history codes (V5_8 line 81)
ICD_PERSONAL_TRT_CODES <- c("V87.41", "V87.42", "V87.43", "V87.46", "V15.3",
                             "Z92.21", "Z92.22", "Z92.23", "Z92.25", "Z92.3")

# Helper: apply V5_3 prefix/exact overrides to a data.table that already has
# a group_site column (populated by the icd_groups join, possibly NA).
# SAS =: is a starts-with operator; R equivalent: startsWith(dx, prefix).
apply_icd_overrides <- function(dt) {
  # V5_3 lines 54-58: In situ (ICD-9 prefix)
  dt[startsWith(dx, "230") | startsWith(dx, "231") | startsWith(dx, "232") |
     startsWith(dx, "233") | startsWith(dx, "234") | startsWith(dx, "D0"),
     group_site := "In situ"]
  # V5_3 lines 60-65: Hematologic (Non-Hodgkin Lymphoma)
  dt[startsWith(dx, "C82") | startsWith(dx, "C83") |
     dx %in% c("C84.1","C84.4","C84.6","C84.7","C84.9","C84.A","C84.Z",
                "C841","C844","C846","C847","C849","C84A","C84Z") |
     startsWith(dx, "C85"),
     group_site := "Hematologic"]
  # V5_3 lines 66-73: Reportable but not mapped
  dt[startsWith(dx, "235") | startsWith(dx, "236") | startsWith(dx, "237") |
     startsWith(dx, "239") | startsWith(dx, "D37") | startsWith(dx, "D38") |
     startsWith(dx, "D39") | startsWith(dx, "D40") | startsWith(dx, "D41") |
     startsWith(dx, "D42") | startsWith(dx, "D43") | startsWith(dx, "D44") |
     startsWith(dx, "D45") | startsWith(dx, "D48") | startsWith(dx, "D49"),
     group_site := "Reportable but not mapped above"]
  # V5_3 lines 74-79: exact overrides
  dt[dx == "200.33",  group_site := "Hematologic"]
  dt[startsWith(dx, "C34"), group_site := "Oral and respiratory"]
  dt[startsWith(dx, "C25"), group_site := "Digestive"]
  dt[startsWith(dx, "C44") | startsWith(dx, "C4A") | startsWith(dx, "C43"),
     group_site := "Skin"]
  dt[dx == "C7A00",   group_site := "Other"]
  dt[dx == "53",      group_site := "Female Genital system"]
  dt[dx == "C84.07",  group_site := "Hematologic"]
  dt[dx == "C56.3",   group_site := "Female Genital System"]
  dt[dx == "C7A029",  group_site := "Digestive"]
  dt[dx == "C81.47",  group_site := "Hematologic"]
  dt
}

dx_part_files <- sort(list.files(data_dir_processed,
                                  pattern = "01_imported_dx_part\\d+\\.rds",
                                  full.names = TRUE))
message("Processing ", length(dx_part_files), " dx parts -> per-encounter summaries")

dx_part_summaries <- vector("list", length(dx_part_files))

for (i in seq_along(dx_part_files)) {
  message("  dx part ", i, "/", length(dx_part_files),
          " | ", basename(dx_part_files[i]))
  part <- as.data.table(readRDS(dx_part_files[i]))
  message("    rows: ", format(nrow(part), big.mark = ","),
          " | in memory: ", format(object.size(part), units = "MB", standard = "legacy"))

  # Step 1: Two-pass join (SAS matching rule):
  # Pass 1: exact join covers full ICD-9 codes ("174.9") and any exact ICD-10 matches.
  # Pass 2: 5-char substr join covers 5-7 char ICD-10 dx codes ("C50.911" -> "C50.9").
  # ForSAS_ICD10 keys are 5 chars max with dot (e.g. "C50.9", "C81.1").
  # SAS exact join (V5_3 line 49): left join dx.Icd10_groups2 on a.dx = b.ICD9_10
  # "icd9_10" is the clean_names() result for SAS column ICD9_10
  part <- merge(part, icd_groups[, .(icd9_10, group_site)],
                by.x = "dx", by.y = "icd9_10", all.x = TRUE)
  n_exact <- sum(!is.na(part$group_site))

  unmatched <- is.na(part$group_site)
  if (any(unmatched)) {
    part[, dx5 := substr(dx, 1L, 5L)]
    gs_prefix <- icd_groups[part[unmatched, .(dx5)],
                             on = .(icd9_10 = dx5), .(group_site)]$group_site
    part[unmatched, group_site := gs_prefix]
    part[, dx5 := NULL]
  }
  message("    ICD join -- exact: ", n_exact,
          " | prefix-fill: ", sum(!is.na(part$group_site)) - n_exact,
          " | unmatched: ", sum(is.na(part$group_site)))

  # Step 2: apply prefix/exact overrides (V5_3 lines 54-131)
  apply_icd_overrides(part)

  # Step 3: row-level flags
  # V5_3 line 128: any_reportable_cancer = 1 if group_site is non-empty after join+overrides
  part[, any_reportable_cancer := fifelse(!is.na(group_site) & nchar(group_site) > 0L, 1L, 0L)]
  part[, icd_personal_trt      := fifelse(dx %in% ICD_PERSONAL_TRT_CODES, 1L, 0L)]

  # Step 4: pick representative cancer row per encounter
  # Rule: earliest cancer dx by (dx_date asc, dx asc) — mirrors SAS V5_4 sort
  # by id desc any_reportable_cancer admit_date + NODUPKEY by id (keeps earliest
  # cancer encounter when sorted desc cancer then asc date).
  cancer_rows <- part[any_reportable_cancer == 1L]
  if (nrow(cancer_rows) > 0L) {
    setorder(cancer_rows, patid, encounterid, dx_date, dx)
    cancer_first <- cancer_rows[, .(cancer_dx = dx[1L], group_site = group_site[1L]),
                                 by = .(patid, encounterid)]
  } else {
    cancer_first <- data.table(patid = character(), encounterid = character(),
                               cancer_dx = character(), group_site = character())
  }

  # Step 5: aggregate encounter-level flags
  enc_sum <- part[, .(
    any_reportable_cancer = max(any_reportable_cancer, na.rm = TRUE),
    icd_personal_trt      = max(icd_personal_trt,      na.rm = TRUE)
  ), by = .(patid, encounterid)]

  enc_sum <- merge(enc_sum, cancer_first, by = c("patid", "encounterid"), all.x = TRUE)
  dx_part_summaries[[i]] <- enc_sum

  message("    -> ", format(nrow(enc_sum), big.mark = ","), " unique encounters",
          " | in memory: ", format(object.size(enc_sum), units = "MB", standard = "legacy"))
  rm(part, cancer_rows, cancer_first, enc_sum); gc(verbose = FALSE)
  gc_used <- gc(verbose = FALSE)
  message("    gc max used: ", format(gc_used["Vcells", "max used"] * 8 / 1024^2, digits = 1), " MB")
}

rm(icd_groups); gc(verbose = FALSE)

# Re-aggregate across parts (same encounter can appear in multiple dx parts)
dx_all_parts <- rbindlist(dx_part_summaries, use.names = TRUE, fill = TRUE)
rm(dx_part_summaries); gc(verbose = FALSE)
message("Combined dx part summaries: ", format(nrow(dx_all_parts), big.mark = ","), " rows")

dx_encounter <- dx_all_parts[, {
  arc  <- max(any_reportable_cancer, na.rm = TRUE)
  ipt  <- max(icd_personal_trt,      na.rm = TRUE)
  # cancer_dx / group_site: first non-NA value (rbindlist preserves part order)
  cdx  <- cancer_dx[!is.na(cancer_dx)][1L]
  gs   <- group_site[!is.na(group_site)][1L]
  list(any_reportable_cancer = arc, icd_personal_trt = ipt,
       cancer_dx = cdx, group_site = gs)
}, by = .(patid, encounterid)]

message("dx_encounter: ", format(nrow(dx_encounter), big.mark = ","), " unique (patid, encounterid) pairs",
        " | any_reportable_cancer=1: ",
        format(sum(dx_encounter$any_reportable_cancer == 1L, na.rm = TRUE), big.mark = ","),
        " | icd_personal_trt=1: ",
        format(sum(dx_encounter$icd_personal_trt == 1L, na.rm = TRUE), big.mark = ","),
        " | in memory: ", format(object.size(dx_encounter), units = "MB", standard = "legacy"))

saveRDS(as.data.frame(dx_encounter), file.path(data_dir_processed, "02_dx_encounter.rds"))
message("Saved: 02_dx_encounter.rds")
rm(dx_all_parts, dx_encounter); gc(verbose = FALSE)

# ========================================
# Section 4b -- Procedures: Per-Part Patient-Level Flags
# ========================================
#
# SAS source: V5_12 lines 134-143 (chemo), 497-567 (radiation),
#             607-655 (surgery), 663-720 (SCT)
# Downstream (03_exposure.R) needs only patient-level flags (chemo/surgery/
# radiation/sct) derived from procedure codes. Compute here per part so we
# never hold the full proc table in memory.

SCT_CODES_CPT   <- c("38240", "38241", "38242", "38243")
SCT_CODES_ICD10 <- c("T86.5", "Z94.81", "T86.09", "T86.0")
SCT_CODES_ICD9  <- c("V42.82", "V41.0")
SCT_CODES_PCS   <- c("30233C0", "30233G0", "30243C0", "30243G0", "30233Y0", "30243Y0")

proc_part_files <- sort(list.files(data_dir_processed,
                                    pattern = "01_imported_proc_part\\d+\\.rds",
                                    full.names = TRUE))
message("Processing ", length(proc_part_files), " proc parts -> patient-level flags")

proc_part_flags <- vector("list", length(proc_part_files))

for (i in seq_along(proc_part_files)) {
  message("  proc part ", i, "/", length(proc_part_files))
  pp <- as.data.table(readRDS(proc_part_files[i]))
  message("    rows: ", format(nrow(pp), big.mark = ","),
          " | in memory: ", format(object.size(pp), units = "MB", standard = "legacy"))

  # Chemo: V5_12 lines 134-143
  pp[, chemo_proc := fifelse(
    (px_type == "CH" & ((px >= "96401" & px <= "96549") | (px >= "J9000" & px <= "J9999"))) |
    (px_type == "10" & px %in% c("Z51.11", "Z51.12")) |
    (px_type == "09" & px %in% c("V58.11", "V58.12")),
    1L, 0L)]

  # Surgery: V5_12 lines 607-655 (best-effort without surgerycodes reference)
  # EDGE CASE: uses ICD-10-PCS Medical/Surgical section (starts with 0+letter)
  # Must verify against surgerycodes reference on HiPerGator
  pp[, surgery_proc := fifelse(px_type == "10" & grepl("^0[A-Z]", px), 1L, 0L)]

  # Radiation: V5_12 lines 497-567
  pp[, radiation_proc := fifelse(
    (px_type == "CH" & px >= "77000" & px <= "79999") |
    (px_type == "10" & px == "Z51.0") |
    (px_type == "09" & px == "V58.0"),
    1L, 0L)]

  # SCT: V5_12 lines 663-720
  pp[, sct_proc := fifelse(
    (px_type == "CH" & px %in% SCT_CODES_CPT) |
    (px_type == "10" & (px %in% SCT_CODES_ICD10 | px %in% SCT_CODES_PCS)) |
    (px_type == "09" & px %in% SCT_CODES_ICD9),
    1L, 0L)]

  pat_flags <- pp[, .(
    chemo_proc     = max(chemo_proc,     na.rm = TRUE),
    surgery_proc   = max(surgery_proc,   na.rm = TRUE),
    radiation_proc = max(radiation_proc, na.rm = TRUE),
    sct_proc       = max(sct_proc,       na.rm = TRUE)
  ), by = patid]

  proc_part_flags[[i]] <- pat_flags
  rm(pp, pat_flags); gc(verbose = FALSE)
}

proc_all <- rbindlist(proc_part_flags, use.names = TRUE)
rm(proc_part_flags); gc(verbose = FALSE)

proc_patient_flags <- proc_all[, .(
  chemo_proc     = max(chemo_proc,     na.rm = TRUE),
  surgery_proc   = max(surgery_proc,   na.rm = TRUE),
  radiation_proc = max(radiation_proc, na.rm = TRUE),
  sct_proc       = max(sct_proc,       na.rm = TRUE)
), by = patid]

message("proc_patient_flags: ", format(nrow(proc_patient_flags), big.mark = ","), " patients",
        " | in memory: ", format(object.size(proc_patient_flags), units = "MB", standard = "legacy"))
saveRDS(as.data.frame(proc_patient_flags), file.path(data_dir_processed, "02_proc_patient_flags.rds"))
message("Saved: 02_proc_patient_flags.rds")
rm(proc_all, proc_patient_flags); gc(verbose = FALSE)

# ========================================
# Section 4c -- Dispensing: Reduce to Distinct Patient IDs
# ========================================
# 03_exposure.R needs dispensing only for NDC-based chemo patient flags.
# Reduce to distinct patids here; 03_exposure.R loads the small table.
dispensing <- readRDS(file.path(data_dir_processed, "01_imported_dispensing.rds"))
dispensing_patids <- data.frame(patid = unique(dispensing$patid))
saveRDS(dispensing_patids, file.path(data_dir_processed, "02_dispensing_patids.rds"))
message("Saved: 02_dispensing_patids.rds (", nrow(dispensing_patids), " patients with dispensing records)")
rm(dispensing, dispensing_patids); gc(verbose = FALSE)

# ========================================
# Section 5 -- Missing Value Report (CLN-04)
# ========================================

message("\n--- Missing Value Report ---")
for (col in c("payer_type_primary", "enc_type", "admit_date", "discharge_status")) {
  if (col %in% names(encounters)) {
    message("  encounters$", col, ": ",
            sum(is.na(encounters[[col]])), " NA / ",
            nrow(encounters), " total")
  }
}

# ========================================
# Section 6 -- CLN-05: Encounter Type and Discharge Recoding
# ========================================

encounters[, enc_type_label := factor(enc_type,
                                       levels = sas_formats$enc_type$levels,
                                       labels = sas_formats$enc_type$labels)]

encounters[, discharge_status_label := factor(discharge_status,
                                               levels = sas_formats$discharge_status$levels,
                                               labels = sas_formats$discharge_status$labels)]

encounters[, discharge_disposition_label := factor(discharge_disposition,
                                                    levels = sas_formats$discharge_disposition$levels,
                                                    labels = sas_formats$discharge_disposition$labels)]

unlabeled_enc <- encounters[is.na(enc_type_label) & !is.na(enc_type), .N, by = enc_type]
if (nrow(unlabeled_enc) > 0) {
  message("WARNING: Unlabeled ENC_TYPE codes found:")
  print(unlabeled_enc)
}

unlabeled_disch <- encounters[is.na(discharge_status_label) & !is.na(discharge_status),
                               .N, by = discharge_status]
if (nrow(unlabeled_disch) > 0) {
  message("WARNING: Unlabeled DISCHARGE_STATUS codes found:")
  print(unlabeled_disch)
}

message("  ENC_TYPE distribution:")
print(janitor::tabyl(encounters, enc_type_label))

# ========================================
# Section 7 -- CLN-03 / CLN-06: Payer Type Recoding
# ========================================
#
# Source: SAS_CODE_FOR_v5_1.sas lines 57-382 (commented-out PROC SQL UPDATE block;
#         the updated v3.insurance table persists on disk from a prior run).
# Method: exhaustive explicit CASE WHEN — NOT a prefix/starts-with operator.
# Blank/NA input hits the ELSE clause -> '8' (no coverage / unknown).
#
# Dual eligibility (answer to question a):
#   Rule 1 — direct: raw codes '14' and '93' -> '4' (SAS_CODE_FOR_v5_1.sas lines 91-93)
#   Rule 2 — override: after recoding, if both primary2 AND secondary2 in ('1','2')
#             then primary2='4' (SAS_CODE_FOR_V5_8.sas line 89, follow-up encounters only)
#   Rule 2 fires for Medicare+Medicaid combos not already carrying code '14'.
#
# Blank/NA (answer to question b):
#   SAS: blank payer_type_primary hits ELSE -> '8'.
#   The 4,920 blank first_can_payer_type_primary in baseline are join misses
#   (no insurance row for that ENCOUNTERID — DATA_LINEAGE.md Task 2), not ELSE-clause hits.
#   In R: recode_payer(NA) -> '8' (matches ELSE on encounter rows present in the data).
#   Join misses remain NA because no encounter row exists to recode.
#
# Category labels: 1=Medicare, 2=Medicaid, 4=Dual/Disability, 5=Private, 8=None/unknown, 9=Other

# --- Explicit value sets from SAS_CODE_FOR_v5_1.sas lines 61-219 ---
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

# Primary and secondary recode (applied to encounter rows, not to join misses)
encounters[, payer_primary_recoded   := recode_payer(payer_type_primary)]
encounters[, payer_secondary_recoded := recode_payer(payer_type_secondary)]

# Rule 2 dual override (SAS_CODE_FOR_V5_8.sas line 89):
# Fires on follow-up encounters when both primary and secondary are Medicare or Medicaid.
# Applied here to all encounters; 03_exposure.R selects last encounter after first_admit_date.
encounters[payer_secondary_recoded %in% c("1","2") & payer_primary_recoded %in% c("1","2"),
           payer_primary_recoded := "4"]

message("\nPayer primary recoded distribution (after dual override):")
print(janitor::tabyl(encounters, payer_primary_recoded))
message("\nPayer secondary recoded distribution:")
print(janitor::tabyl(encounters, payer_secondary_recoded))

# ========================================
# Section 8 -- Save Encounter Checkpoint
# ========================================

saveRDS(as.data.frame(encounters),
        file.path(data_dir_processed, "02_encounters_cleaned.rds"))
message("\nSaved: 02_encounters_cleaned.rds (",
        format(nrow(encounters), big.mark = ","), " rows, ",
        ncol(encounters), " cols)")

message("\n========================================")
message("Phase 2 Cleaning complete: ", Sys.time())
message("========================================")
message("Outputs:")
message("  02_encounters_cleaned.rds   — encounter rows with recoded payer/type columns")
message("  02_dx_encounter.rds         — one row per (patid, encounterid): cancer flags, icd_personal_trt, group_site")
message("  02_proc_patient_flags.rds   — one row per patid: chemo/surgery/radiation/sct flags")
message("  02_dispensing_patids.rds    — distinct patids with dispensing records")
message("Next step: R/02_merge.R")
