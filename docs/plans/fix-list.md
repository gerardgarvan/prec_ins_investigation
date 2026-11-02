# Fix List — Precision Insurance Investigation

Status key: DONE · PARTIAL · OPEN

| # | File(s) | Fix | Status |
|---|---------|-----|--------|
| 1 | `R/01_import.R` | Procedures = 7 files (`procedures_mobley1_v5` .. `procedures_mobley7_v5`); fix stale end messages | DONE |
| 2 | `R/02_clean.R` | Fail fast with clear message if `01_imported_icd_groups.rds` missing; add TODO(ERIN) on lookup source | DONE |
| 3 | `R/02_clean.R`, `tests/testthat/test_02_cleaning.R` | `recode_payer()` per SAS new828.sas (14x→4; 1xx→1; 2xx→2; 3xx/5xx/6xx/7xx→5; 4xx→9; 8xx→8; 9xx/OT→9; blank→NA); applied to primary and secondary; unit-tested | DONE |
| 4 | `R/03_exposure.R` | first/last payer use `payer_primary_recoded`; `change_ins` compares recoded categories (511→512 is not a change) | DONE |
| 5 | `R/03_cohort.R`, `R/03_covariates.R` | Age at dx from `birth_date` + `first_admit_date` (SAS_CODE_FOR_v5_5.sas lines 10-11); `>=120→91` cap added; citation updated; categorical variable `age2` (in 03_covariates.R) | PARTIAL — continuous `age_at_dx` done; categorical `age2→age_cat` rename deferred |
| 6 | `R/03_cohort.R` | SAS V5_2 collapse before filtering: sex (blank/NI/OT/UN/A→UN), race (blank/NI/OT/UN/07→UN), hispanic (blank/R/NI/UN/OT→UN) | DONE |
| 7 | `R/03_cohort.R` | Valid enrollment = any enrollment record (no `!is.na(enr_end_date)` filter) | DONE |
| 8 | `R/03_cohort.R` | cancer_provider fail-fast guard + DATA_LINEAGE blocking entry — DONE; confirm whether any SAS file defines it from a code list | PARTIAL — guard done; code-list confirm pending |
| 9 | `R/03_covariates.R` | `first_can_ruca` / `first_can_sdi_score`: fail fast with TODO(ERIN) | DONE |
| 10 | `R/99_validate_vs_sas.R` | CHECK 3 compares SAS age2 (years) to R `age_at_dx` and SAS payer to R RECODED payer; CHECK 5 filters raw demo on id and reads only id+sex; CHECK 2 "last encounter" labelled INFERRED | DONE |
| 11 | `archive/` | Move `R/02_clean_dt.R` and `R/02_clean_dplyr_backup.R` to `archive/` | DONE |
