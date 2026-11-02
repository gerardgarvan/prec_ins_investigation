# R/00_build_icd_groups.R
# Build ICD cancer-site group lookup from CancerSiteCategories.xlsx
# SAS source: "dx and tumor 5 30 2024.sas" (also dxandtmr.sas, SAS_CODE_FOR_V5_13)
# Output: {data_dir_processed}/01_imported_icd_groups.rds
#   Columns: icd9_10 (character), group_site (character)
#
# fix_lookup_gaps flag (default FALSE = SAS-faithful):
#   FALSE: reproduce SAS exactly, including known missing codes
#   TRUE:  add C19/C20/C23/C65/C66/C50.0/C7A.00 and fix "Unrinary" typo
#   Set via: options(prec_ins.fix_lookup_gaps = TRUE) before sourcing.

library(here)
if (!exists("reference_dir")) source(here::here("R", "config.R"))
if (!requireNamespace("readxl", quietly = TRUE)) stop("readxl not installed. Run: install.packages('readxl')")
library(readxl)
library(dplyr)
library(stringr)

fix_lookup_gaps <- isTRUE(getOption("prec_ins.fix_lookup_gaps", default = FALSE))

norm_icd <- function(x) toupper(gsub("\\.", "", trimws(x)))

xlsx_path <- file.path(reference_dir, "CancerSiteCategories.xlsx")
if (!file.exists(xlsx_path)) {
  stop(
    "CancerSiteCategories.xlsx not found at: ", xlsx_path, "\n",
    "Copy from /orange/erin.mobley-precision/ to reference/"
  )
}

# ---- Step 1: ICD-9 -> ICD-10 crosswalk (cols D-E of ForSAS_ICD9toICD10) ----
# Actual workbook has 967 ICD-9 -> ICD-10 pairs (SAS-era range D1:E2917 is stale).
# Use a large range; empty rows are filtered below.
# Force text: ICD-9 values like "140.1" and "230" are numeric in Excel.
crosswalk_raw <- read_excel(
  xlsx_path, sheet = "ForSAS_ICD9toICD10",
  range = "D1:E1200", col_types = "text"
)
names(crosswalk_raw) <- c("icd9_10", "icd10")

crosswalk <- crosswalk_raw %>%
  filter(!is.na(icd9_10), str_trim(icd9_10) != "") %>%
  mutate(
    icd9_10 = str_trim(icd9_10),
    icd10   = str_trim(icd10)
    # NOTE: do NOT add ".0" to short ICD-9 codes — the real dx data has "185"
    # and "193" (no dot), so adding ".0" would cause them to never match.
  ) %>%
  filter(!is.na(icd10), icd10 != "")

message("crosswalk: ", nrow(crosswalk), " ICD-9->ICD-10 pairs after cleanup")

# ---- Step 2: ForSAS_ICD10 (4-col: icd10 | primary_site | detailed_site | Group_Site) ----
# Actual workbook has 1,130 data rows (SAS-era range A1:D1018 truncated at 1017 rows).
icd10_raw <- read_excel(
  xlsx_path, sheet = "ForSAS_ICD10",
  range = "A1:D1200", col_types = "text"
)
names(icd10_raw) <- c("icd10", "group_primary_disease_site", "group_detailed_site", "group_site")
icd10_lookup <- icd10_raw %>%
  filter(!is.na(icd10), str_trim(icd10) != "") %>%
  mutate(across(everything(), str_trim),
         group_site = if_else(is.na(group_site) | group_site == "",
                              "Reportable but not mapped above", group_site))
message("ForSAS_ICD10: ", nrow(icd10_lookup), " rows")

# ---- Step 3: merge crosswalk + icd10_lookup on icd10 (SAS: dx.icd10_groups1) ----
icd10_groups1 <- crosswalk %>%
  left_join(icd10_lookup %>% select(icd10, group_site), by = "icd10") %>%
  mutate(group_site = if_else(is.na(group_site) | group_site == "",
                              "Reportable but not mapped above", group_site))

# ---- Step 4: ICD-9 keyed rows (SAS: Icd10_groups2 via nodupkey on icd9_10) ----
icd10_groups2_icd9 <- icd10_groups1 %>%
  arrange(icd9_10) %>%
  distinct(icd9_10, .keep_all = TRUE) %>%
  select(icd9_10, group_site)
message("icd10_groups2 ICD-9 keyed rows: ", nrow(icd10_groups2_icd9))

# ---- Step 5: ICD-10 direct keys (SAS: Icd10_groups1/2 contain BOTH ICD-9 and ICD-10 in ICD9_10) ----
# ForSAS_ICD10 codes are ICD-10 codes and must be lookup keys themselves so that
# ICD-10 dx values (e.g. C61, C50.919) match directly without going through the crosswalk.
icd10_direct <- icd10_lookup %>%
  filter(!is.na(icd10), str_trim(icd10) != "") %>%
  select(icd9_10 = icd10, group_site)
message("icd10_groups2 ICD-10 direct rows: ", nrow(icd10_direct))

# ---- Step 6: combine, normalize keys, dedup ----
# Normalize: strip dots, trim, uppercase — both sides of every join use this form.
# Dedup order: ICD-9 crosswalk rows first (SAS Icd10_groups2 ordering), then ICD-10 direct.
icd10_groups2 <- bind_rows(icd10_groups2_icd9, icd10_direct) %>%
  mutate(icd9_10 = norm_icd(icd9_10)) %>%
  arrange(icd9_10) %>%
  distinct(icd9_10, .keep_all = TRUE)
message("icd10_groups2 (final lookup, normalized): ", nrow(icd10_groups2), " rows")

# ---- Step 7: bare ICD-9 codes absent from crosswalk ----
# 3-digit ICD-9 codes like "185" (prostate) and "193" (thyroid) appear frequently
# in dx data but the crosswalk only maps more specific sub-codes (e.g. "185.9").
# Derive group_site from the corresponding ICD-10 equivalent already in the lookup.
# TODO(ERIN): if the SAS-era crosswalk had "185" as a key, this block is redundant;
# confirm via proc contents data=Icd10_groups2; run; on HiPerGator.
bare_icd9_map <- tibble::tibble(
  icd9_10  = norm_icd(c("185", "193")),
  icd10_eq = norm_icd(c("C61", "C73"))
)
bare_icd9_extra <- bare_icd9_map %>%
  left_join(icd10_groups2 %>% select(icd10_eq = icd9_10, group_site),
            by = "icd10_eq") %>%
  filter(!is.na(group_site)) %>%
  select(icd9_10, group_site)
if (nrow(bare_icd9_extra) > 0L) {
  icd10_groups2 <- bind_rows(
    icd10_groups2 %>% filter(!icd9_10 %in% bare_icd9_extra$icd9_10),
    bare_icd9_extra
  ) %>% arrange(icd9_10)
  message("Added ", nrow(bare_icd9_extra), " bare ICD-9 keys (185, 193)")
}

# ---- Step 8: gap handling (TODO(ERIN)) ----
# DATA_LINEAGE gap codes: C19, C20 (rectum); C23 (gallbladder); C65 (renal pelvis);
# C66 (ureter); C50.0 (central breast); C7A.00 (neuroendocrine unspec).
# Typo: "Unrinary System" in some Group_Site labels should be "Urinary System".
if (fix_lookup_gaps) {
  message("fix_lookup_gaps=TRUE: adding known missing codes + fixing typos")
  gap_rows <- tibble::tibble(
    icd9_10    = norm_icd(c("C19", "C20", "C23", "C65", "C66", "C50.0", "C7A.00")),
    group_site = c("Digestive","Digestive","Digestive","Urinary System","Urinary System","Breast","Other")
  )
  icd10_groups2 <- bind_rows(
    icd10_groups2 %>% filter(!icd9_10 %in% gap_rows$icd9_10),
    gap_rows
  ) %>%
    arrange(icd9_10) %>%
    mutate(group_site = str_replace_all(group_site, "Unrinary", "Urinary"))
  message("  After gap patch: ", nrow(icd10_groups2), " rows")
} else {
  message("fix_lookup_gaps=FALSE (default, SAS-faithful).")
  message("  TODO(ERIN): known gaps not in ForSAS_ICD10: C19, C20, C23, C65, C66, C50.0, C7A.00")
  message("  TODO(ERIN): typo 'Unrinary System' present in some Group_Site labels")
  message("  Set options(prec_ins.fix_lookup_gaps=TRUE) before sourcing to patch.")
}

saveRDS(icd10_groups2, file.path(data_dir_processed, "01_imported_icd_groups.rds"))
message("Saved: 01_imported_icd_groups.rds (", nrow(icd10_groups2),
        " rows | cols: ", paste(names(icd10_groups2), collapse = ", "), ")")
