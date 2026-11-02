# Reference Workbooks

These files are committed to version control. They are analytical lookup tables,
not patient data, and do not contain HIPAA-protected information.

| File | Source | Feeds | Date Added |
|------|--------|-------|------------|
| CancerSiteCategories.xlsx | /orange/erin.mobley-precision/ (originally F:\Jax_Ascent\) | R/00_build_icd_groups.R -> 01_imported_icd_groups.rds -> 02_clean.R ICD site grouping | 2026-11-02 |
| nucc_taxonomy_210.xlsx | Supplied by Gerard, originally F:\Jax_Ascent\ | R/00_build_prov_spec.R -> 01_imported_prov_spec.rds -> 02_merge.R cancer_provider flag | 2026-11-02 |

## Sheets used

**CancerSiteCategories.xlsx**
- `ForSAS_ICD10` A1:D1018 -- 4-column ICD-10 code -> site group lookup (966 data rows)
- `ForSAS_ICD9toICD10` D1:E2917 -- ICD-9 to ICD-10 crosswalk (1,129+ pairs; cols D-E used per SAS range)

**nucc_taxonomy_210.xlsx**
- `sas` A1:D866 -- NUCC taxonomy code -> Cancer_provider flag (865 data rows, 21 codes flagged as 1)
