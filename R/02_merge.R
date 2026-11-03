# R/02_merge.R
# Data Merging: Join encounters with per-encounter dx flags and provider data
# Per D-01: Second of two Phase 2 scripts (02_clean.R -> 02_merge.R)
# Per MRG-02: Row counts logged before/after every merge operation
# Per MRG-03: Join cardinality enforced by explicit uniqueness checks on the
#             right-hand key before each join (replaces dplyr `relationship =`)
#
# data.table rewrite (memory/time):
#   - Duplicate checks use anyDuplicated(by=) instead of janitor::get_dupes()
#     (get_dupes builds ~178M dplyr groups; that alone can take hours).
#   - Joins are update-joins (:=) that add columns to `encounters` IN PLACE.
#     The prior version held encounters + enc_with_dx + enc_dx_prov at once
#     (three full copies of a ~30 GB table) and could approach 100 GB.
#   - cancer_provider is resolved on the 374k-row provider table, then carried
#     to encounters with the other provider columns, instead of trimming /
#     uppercasing 178M specialty strings. Result is identical: encounters with no
#     provider match or no specialty match get cancer_provider = 0.
#   - Post-merge checks use vector operations (no filtered copies of the table).
#   - Large objects are removed before the script ends so the next step in
#     run_all.R does not inherit them.
#
# Output contract is unchanged:
#   data/processed/02_provider_full.rds   provider with SOURCE renamed provider_source
#   data/processed/02_merged_complete.rds one row per encounter; encounter columns,
#     then dx_encounter columns, then provider columns, then prov_spec columns
#     (cancer_provider 0/1 integer). Saved with the same class the encounters
#     checkpoint had on input.

# ========================================
# Section 1 -- Setup
# ========================================

library(here)
source(here::here("R", "config.R"))

# Skip guard — both outputs must exist to skip
merge_outputs <- c("02_provider_full.rds", "02_merged_complete.rds")
merge_paths <- file.path(data_dir_processed, merge_outputs)
if (all(file.exists(merge_paths))) {
  message("Skipping 02_merge.R — all outputs already exist:")
  for (p in merge_paths) message("  ", basename(p))
  message("Delete any of the above to force a re-run.")
  quit(save = "no", status = 0)
}

source(here::here("R", "utils_import.R"))
library(data.table)

fmt <- function(x) format(x, big.mark = ",", scientific = FALSE)

t_start <- Sys.time()
elapsed <- function() sprintf("%.1f min", as.numeric(difftime(Sys.time(), t_start, units = "mins")))

mem_note <- function(label) {
  g <- gc(full = TRUE)
  message(sprintf("  [mem] %s: %.1f GB in use (%s elapsed)", label, sum(g[, 2]) / 1024, elapsed()))
}

check_no_clash <- function(new_cols, target, what) {
  clash <- intersect(new_cols, names(target))
  if (length(clash) > 0L) {
    stop(what, ": columns already present in encounters: ", paste(clash, collapse = ", "),
         "\nRename them before joining (the dplyr version would have produced .x/.y pairs).")
  }
}

message("========================================")
message("Phase 2: Data Merging (data.table)")
message("Started: ", t_start)
message("========================================")

# ========================================
# Section 2 -- Load Checkpoints
# ========================================

encounters <- read_checkpoint(file.path(data_dir_processed, "02_encounters_cleaned.rds"))
enc_class  <- class(encounters)
setDT(encounters)
mem_note("encounters loaded")

dx_encounter <- read_checkpoint(file.path(data_dir_processed, "02_dx_encounter.rds"))
setDT(dx_encounter)

provider   <- read_checkpoint(file.path(data_dir_processed, "01_imported_provider.rds"))
prov_class <- class(provider)
setDT(provider)

message("Loaded datasets:")
message("  encounters:   ", fmt(nrow(encounters)),   " rows")
message("  dx_encounter: ", fmt(nrow(dx_encounter)), " rows (expected unique patid+encounterid)")
message("  provider:     ", fmt(nrow(provider)),     " rows")
mem_note("all inputs loaded")

# ========================================
# Section 3 -- Pre-Merge Duplicate Detection (per MRG-03)
# ========================================

n_patients_original <- NA_integer_

if (anyDuplicated(encounters, by = "encounterid") > 0L) {
  n_patients_original <- uniqueN(encounters$patid)
  n_affected <- uniqueN(encounters$encounterid[duplicated(encounters, by = "encounterid")])
  message("WARNING: Non-unique ENCOUNTERID in encounters (", fmt(n_affected),
          " affected). Deduplicating (first occurrence kept).")
  encounters <- unique(encounters, by = "encounterid")
  message("  After dedup: ", fmt(nrow(encounters)), " rows")
} else {
  message("Encounter ENCOUNTERID uniqueness: OK")
}

if (anyDuplicated(dx_encounter, by = c("patid", "encounterid")) > 0L) {
  message("WARNING: Non-unique (patid, encounterid) in dx_encounter. Deduplicating (first occurrence kept).")
  dx_encounter <- unique(dx_encounter, by = c("patid", "encounterid"))
} else {
  message("dx_encounter (patid, encounterid) uniqueness: OK")
}
mem_note("duplicate checks done")

# ========================================
# Section 4 -- Merge 1: Encounters + dx_encounter (one-to-one, left)
# ========================================

dx_cols <- setdiff(names(dx_encounter), c("patid", "encounterid"))
check_no_clash(dx_cols, encounters, "dx_encounter")

n_before <- nrow(encounters)
message("\n=== Join: Encounters + dx_encounter flags (one-to-one, left) ===")
message("  Keys: patid, encounterid")
message("  Left rows:  ", fmt(n_before))
message("  Right rows: ", fmt(nrow(dx_encounter)))
message("  Columns added: ", paste(dx_cols, collapse = ", "))

setkeyv(encounters,  c("patid", "encounterid"))
setkeyv(dx_encounter, c("patid", "encounterid"))
# Explicit column assignment avoids mget() materializing an intermediate list
encounters[dx_encounter, `:=`(
  any_reportable_cancer = i.any_reportable_cancer,
  icd_personal_trt      = i.icd_personal_trt,
  cancer_dx             = i.cancer_dx,
  group_site            = i.group_site
)]

stopifnot(nrow(encounters) == n_before)
message("  Result rows: ", fmt(nrow(encounters)), " (growth 1x)")
if ("any_reportable_cancer" %in% names(encounters)) {
  message("  any_reportable_cancer=1 in merged: ",
          fmt(sum(encounters$any_reportable_cancer == 1L, na.rm = TRUE)))
}

rm(dx_encounter)
mem_note("dx join done, dx_encounter released")

# ========================================
# Section 5 -- Provider table (SOURCE rename) -> 02_provider_full.rds
# ========================================

# KEEP_ENC includes SOURCE, so encounters already has `source`; rename the
# provider's copy to avoid a clash.
if ("source" %in% names(provider)) setnames(provider, "source", "provider_source")

if (anyDuplicated(provider, by = "providerid") > 0L) {
  stop("PROVIDERID is not unique in the provider table (",
       fmt(sum(duplicated(provider, by = "providerid"))), " duplicate rows). ",
       "The dplyr version (relationship = 'many-to-one') would also have stopped here.")
}

provider_full <- copy(provider)
setattr(provider_full, "class", prov_class)
saveRDS(provider_full, file.path(data_dir_processed, "02_provider_full.rds"))
message("Saved: 02_provider_full.rds (", fmt(nrow(provider_full)), " rows)")
rm(provider_full)

# ========================================
# Section 6 -- cancer_provider flag, resolved at provider level
# ========================================
#
# SAS source: SAS_CODE_FOR_v5_1.sas lines 45-50 (PROC IMPORT nucc_taxonomy_210.xlsx)
#             SAS_CODE_FOR_V5_2.sas lines 11-19 (LEFT JOIN on PROVIDER_SPECIALTY_PRIMARY)
# Missing match (no provider, or specialty not in prov_spec) -> cancer_provider = 0.

prov_spec_path <- file.path(data_dir_processed, "01_imported_prov_spec.rds")
if (!file.exists(prov_spec_path)) {
  stop("01_imported_prov_spec.rds not found at: ", prov_spec_path, "\n",
       "Run 01_import.R first (which sources 00_build_prov_spec.R).")
}
prov_spec <- as.data.table(readRDS(prov_spec_path))
stopifnot(all(c("provider_specialty_primary", "cancer_provider") %in% names(prov_spec)))
if (anyDuplicated(prov_spec, by = "provider_specialty_primary") > 0L) {
  stop("provider_specialty_primary is not unique in prov_spec.")
}
prov_spec[, cancer_provider := as.integer(cancer_provider)]
message("prov_spec: ", nrow(prov_spec), " rows | flagged: ",
        sum(prov_spec$cancer_provider == 1L, na.rm = TRUE), " cancer specialty codes")

spec_cols <- setdiff(names(prov_spec), "provider_specialty_primary")
clash_spec <- intersect(spec_cols, names(provider))
if (length(clash_spec) > 0L) stop("prov_spec columns already in provider: ", paste(clash_spec, collapse = ", "))

provider[, provider_specialty_primary_key := stringr::str_trim(toupper(provider_specialty_primary))]
setkey(prov_spec, provider_specialty_primary)
provider[prov_spec, cancer_provider := i.cancer_provider,
         on = c(provider_specialty_primary_key = "provider_specialty_primary")]

# Unmatched specialty codes among providers that appear on encounters
used_providers  <- unique(encounters$providerid)
specs_used      <- provider[providerid %in% used_providers & !is.na(provider_specialty_primary),
                            unique(provider_specialty_primary_key)]
unmatched_specs <- setdiff(specs_used, prov_spec$provider_specialty_primary)
rm(used_providers)
if (length(unmatched_specs) > 0L) {
  message("  Specialty codes on encounter providers NOT in prov_spec (cancer_provider=0): ",
          length(unmatched_specs))
  if (length(unmatched_specs) <= 20L) message("    ", paste(unmatched_specs, collapse = ", "))
}
provider[, provider_specialty_primary_key := NULL]

# ========================================
# Section 7 -- Merge 2: Encounters+Dx + Provider (many-to-one, left)
# ========================================

prov_cols <- setdiff(names(provider), "providerid")
check_no_clash(prov_cols, encounters, "provider")

message("\n=== Join: Enc+Dx + Provider incl. cancer_provider (many-to-one, left) ===")
message("  Keys: providerid")
message("  Left rows:  ", fmt(nrow(encounters)))
message("  Right rows: ", fmt(nrow(provider)))
message("  Columns added: ", paste(prov_cols, collapse = ", "))

setkey(provider, providerid)
setkeyv(encounters, "providerid")
encounters[provider, (prov_cols) := mget(paste0("i.", prov_cols)), on = "providerid"]
encounters[is.na(cancer_provider), cancer_provider := 0L]

stopifnot(nrow(encounters) == n_before || !is.na(n_patients_original))
message("  Result rows: ", fmt(nrow(encounters)), " (growth 1x)")
rm(provider, prov_spec)
mem_note("provider join done")

stopifnot(all(encounters$cancer_provider %in% c(0L, 1L)))
message("  cancer_provider=1 encounters: ", fmt(sum(encounters$cancer_provider == 1L)))
message("PASS: cancer_provider is 0/1 integer with no NA in all ", fmt(nrow(encounters)), " rows")

# ========================================
# Section 8 -- Save
# ========================================

setattr(encounters, "class", enc_class)
message("Saving 02_merged_complete.rds ... (", elapsed(), " elapsed)")
saveRDS(encounters, file.path(data_dir_processed, "02_merged_complete.rds"))
message("Saved: 02_merged_complete.rds (", elapsed(), " elapsed)")

# ========================================
# Section 9 -- Post-Merge Data Quality Assertions (per MRG-04, D-05)
# ========================================
# Vector operations only: no filtered copies of the merged table.

message("\n=== Post-Merge Data Quality Assertions ===")

n_patients_merged <- uniqueN(encounters$patid)
if (is.na(n_patients_original)) {
  message("Patient count after merge: ", fmt(n_patients_merged),
          " (no encounter rows removed, so unchanged from input)")
} else {
  message("Patient count: original=", fmt(n_patients_original), ", after merge=", fmt(n_patients_merged))
  if (n_patients_original != n_patients_merged) {
    warning("MRG-04 ASSERTION FAILED: Patient count changed after ENCOUNTERID dedup! ",
            "Original: ", n_patients_original, ", Merged: ", n_patients_merged)
  }
}

if (anyNA(encounters$encounterid)) {
  warning("MRG-04 ASSERTION FAILED: ", fmt(sum(is.na(encounters$encounterid))), " missing ENCOUNTERIDs.")
} else message("PASS: No missing ENCOUNTERIDs")

if (anyNA(encounters$patid)) {
  warning("MRG-04 ASSERTION FAILED: ", fmt(sum(is.na(encounters$patid))), " missing PATIDs.")
} else message("PASS: No missing PATIDs")

lo <- as.Date("2000-01-01"); hi <- Sys.Date()
n_out <- sum(encounters$admit_date < lo | encounters$admit_date > hi, na.rm = TRUE)
if (n_out > 0L) {
  rng <- range(encounters$admit_date, na.rm = TRUE)
  warning("MRG-04 ASSERTION: ", fmt(n_out), " ADMIT_DATE values outside 2000-01-01..today ",
          "(observed range ", rng[1], " to ", rng[2], ").")
} else message("PASS: ADMIT_DATE within plausible range")

sas_formats <- readRDS(file.path(data_dir_processed, "01_formats.rds"))
valid_enc_types <- c(sas_formats$enc_type$levels, NA_character_)
bad_enc <- !(encounters$enc_type %in% valid_enc_types)
if (any(bad_enc)) {
  warning("MRG-04 ASSERTION: Invalid ENC_TYPE codes found (not in 01_formats enc_type levels):")
  print(sort(table(encounters$enc_type[bad_enc], useNA = "ifany"), decreasing = TRUE))
} else {
  message("PASS: All ENC_TYPE values are valid PCORnet codes")
}
rm(bad_enc)

# ========================================
# Section 10 -- Summary Report
# ========================================

message("\n========================================")
message("Phase 2 Merging complete: ", Sys.time(), " (", elapsed(), ")")
message("========================================")
message("\nMERGED DATASET SUMMARY:")
message("  02_merged_complete.rds:  ", fmt(nrow(encounters)), " rows",
        " (one per encounter; no row inflation from dx join)")
message("  Unique patients:          ", fmt(n_patients_merged))
message("  Unique encounters:        ", fmt(nrow(encounters)), " (ENCOUNTERID verified unique)")
if ("any_reportable_cancer" %in% names(encounters)) {
  message("  Encounters with cancer dx:", fmt(sum(encounters$any_reportable_cancer == 1L, na.rm = TRUE)))
}
message("\nNext step: Phase 3 (Analytical Dataset Construction)")

# Release memory so the next step in run_all.R starts clean.
rm(encounters)
invisible(gc(full = TRUE))
