# Reference Workbooks

These files are committed to version control. They are analytical lookup tables,
not patient data, and do not contain HIPAA-protected information.

| File | Source | Feeds | Date Added |
|------|--------|-------|------------|
| CancerSiteCategories.xlsx | /orange/erin.mobley-precision/ (originally F:\Jax_Ascent\) | R/00_build_icd_groups.R -> 01_imported_icd_groups.rds -> 02_clean.R ICD site grouping | 2026-11-02 |
| nucc_taxonomy_210.xlsx | Supplied by Gerard, originally F:\Jax_Ascent\ | R/00_build_prov_spec.R -> 01_imported_prov_spec.rds -> 02_merge.R cancer_provider flag | 2026-11-02 |
| RUCA2010zipcode.xlsx | USDA ERS (public; originally F:\Jax_Ascent\RUCA2010zipcode.xlsx, SAS imported sheet "sas$A1:41165") | R/00_build_ruca.R -> 01_imported_ruca.rds -> 03_geo.R first_can_ruca derivation | 2026-11-02 |

## Sheets used

**CancerSiteCategories.xlsx**
- `ForSAS_ICD10` A1:D1018 -- 4-column ICD-10 code -> site group lookup (966 data rows)
- `ForSAS_ICD9toICD10` D1:E2917 -- ICD-9 to ICD-10 crosswalk (1,129+ pairs; cols D-E used per SAS range)

**nucc_taxonomy_210.xlsx**
- `sas` A1:D866 -- NUCC taxonomy code -> Cancer_provider flag (865 data rows, 21 codes flagged as 1)

**RUCA2010zipcode.xlsx**
- `Data` A1:E41165 -- ZIP_CODE, STATE, ZIP_TYPE, RUCA1 (1-10, 99), RUCA2 (with decimals); 41,164 data rows
- Column rename in 00_build_ruca.R: ZIP_CODE→ADDRESS_ZIP5, STATE→STATE_ruca, ZIP_TYPE→ZIP_TYPE_ruca
- RUCA1=99 = water/territory areas; excluded from ruca3 derivation
- Note: ACS2015_zctaallvars.xlsx (SDI source) is NOT in this repo — obtain from HiPerGator ww library
