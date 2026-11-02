# Fix List — Precision Insurance Investigation

Status key: DONE · PARTIAL · OPEN

| # | File(s) | Fix | Status |
|---|---------|-----|--------|
| 1 | `R/01_import.R` | Procedures = 7 files (`procedures_mobley1_v5` .. `procedures_mobley7_v5`); fix stale end messages | DONE |
| 2 | `R/02_clean.R` | Fail fast with clear message if `01_imported_icd_groups.rds` missing; add TODO(ERIN) on lookup source | DONE |
| 3 | `R/02_clean.R`, `tests/testthat/test_02_cleaning.R` | `recode_payer()` per `SAS_CODE_FOR_v5_1.sas:61–219` (explicit value lists, not prefix). Rule 1 dual: `'14'`/`'93'`→`'4'`; Rule 2 dual override: primary+secondary both in ('1','2')→'4' (V5_8.sas:89, follow-up encounters). blank/NA→`'8'` (ELSE clause). 16 unit tests covering each rule and edge case (incl. `'140'`→`'8'`, rule-2 override, rule-2 non-override) | DONE |
| 4 | `R/03_exposure.R` | first/last payer use `payer_primary_recoded`; `change_ins` compares recoded categories (511→512 is not a change) | DONE |
| 5 | `R/03_cohort.R`, `R/03_covariates.R` | Age at dx from `birth_date` + `first_admit_date` (SAS_CODE_FOR_v5_5.sas lines 10-11); `>=120→91` cap added; citation updated; categorical variable `age2` (in 03_covariates.R) | PARTIAL — continuous `age_at_dx` done; categorical `age2→age_cat` rename deferred |
| 6 | `R/03_cohort.R` | SAS V5_2 collapse before filtering: sex (blank/NI/OT/UN/A→UN), race (blank/NI/OT/UN/07→UN), hispanic (blank/R/NI/UN/OT→UN) | DONE |
| 7 | `R/03_cohort.R` | Valid enrollment = any enrollment record (no `!is.na(enr_end_date)` filter) | DONE |
| 8 | `R/03_cohort.R` | cancer_provider fail-fast guard + DATA_LINEAGE blocking entry — DONE; confirm whether any SAS file defines it from a code list | PARTIAL — guard done; code-list confirm pending |
| 9 | `R/03_covariates.R` | `first_can_ruca` / `first_can_sdi_score`: fail fast with TODO(ERIN) | DONE |
| 10 | `R/99_validate_vs_sas.R` | CHECK 3 compares SAS age2 (years) to R `age_at_dx` and SAS payer to R RECODED payer; CHECK 5 filters raw demo on id and reads only id+sex; CHECK 2 "last encounter" labelled INFERRED | DONE |
| 11 | `archive/` | Move `R/02_clean_dt.R` and `R/02_clean_dplyr_backup.R` to `archive/` | DONE |
| 12 | `R/00_build_icd_groups.R` + `R/02_clean.R` + `R/01_import.R` | ICD cancer site groups from CancerSiteCategories.xlsx; two-pass join (exact + 5-char substr) replicating SAS matching rule (V5_3 line 49); replaces Icd10_groups2.sas7bdat import | DONE |
| 13 | `R/00_build_prov_spec.R` + `R/02_merge.R` + `R/03_outcomes.R` | cancer_provider from nucc_taxonomy_210.xlsx "sas" sheet; prov_spec left join in 02_merge.R Section 7b; fill cancer_provider=0 for misses; log unmatched codes; 03_outcomes.R stop() → assertr::verify | DONE |
| 14 | `R/00_build_icd_groups.R` + tests + DATA_LINEAGE.md | Bare ICD-9 keys 185/193/179/181 absent from BOTH crosswalk columns — moved from always-added Step 7 into `fix_lookup_gaps=TRUE` block; ForSAS_ICD10 row count corrected to 966 (was "~1,130 truncated"); tests updated: 185→NA when FALSE, 185→Male Genital System when TRUE | DONE |
