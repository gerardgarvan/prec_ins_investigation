# Reference Workbooks

These files are committed to version control. They are analytical lookup tables,
not patient data, and do not contain HIPAA-protected information.

| File | Source | Feeds | Date Added |
|------|--------|-------|------------|
| CancerSiteCategories.xlsx | /orange/erin.mobley-precision/ (originally F:\Jax_Ascent\) | R/00_build_icd_groups.R -> 01_imported_icd_groups.rds -> 02_clean.R ICD site grouping | 2026-11-02 |
| nucc_taxonomy_210.xlsx | Supplied by Gerard, originally F:\Jax_Ascent\ | R/00_build_prov_spec.R -> 01_imported_prov_spec.rds -> 02_merge.R cancer_provider flag | 2026-11-02 |
| RUCA2010zipcode.xlsx | USDA ERS (public; originally F:\Jax_Ascent\RUCA2010zipcode.xlsx, SAS imported sheet "sas$A1:41165") | R/00_build_ruca.R -> 01_imported_ruca.rds -> 03_geo.R first_can_ruca derivation | 2026-11-02 |
| asset_rgc_sdi_2011_through_2015_zcta.csv | Robert Graham Center SDI (2011-2015 ACS, by ZCTA); replaces ACS2015_zctaallvars.xlsx (xlsx never obtained) | R/00_build_sdi.R -> 01_imported_sdi.rds -> 03_geo.R first_can_sdi_score derivation | 2026-11-02 |
| ndconc_results_new.csv | SEER*Rx public NDC export (no patient data); imported in CHEMO_ID_4_10_2024.sas line 6 | R/00_build_ndc.R -> 01_imported_ndc.rds -> 03_exposure.R chemo_disp/anc_disp flags | 2026-11-02 |

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

**asset_rgc_sdi_2011_through_2015_zcta.csv**
- Single CSV table, 32,989 data rows (1 header + 32,989 rows), 18 columns
- Columns used: ZCTA5_FIPS (zero-padded to 5-char text in 00_build_sdi.R) + SDI_score (1-100 percentile)
- SDI_score is the 1-100 PERCENTILE score — NOT the raw `sdi` composite z-score column
- This file supersedes ACS2015_zctaallvars.xlsx (same ACS 2011-2015 vintage); the xlsx was never obtained from HiPerGator
- SDI is now sourced entirely from the RGC CSV committed to this repo

**ndconc_results_new.csv**
- Single CSV, ~10,696 rows; all columns read as text (readr col_character())
- Columns used: NDC_11_Package_ (11-digit package NDC), NDC_9_Product_ (dashed product NDC, e.g. "72205-0061"), SEERRxCategory (text label)
- ndc9 key = strip all non-digits from NDC_9_Product_, take first 9 chars (de-dashed 9-digit product NDC)
- SEERRxCategory recoded to single-char codes per SAS V5_12 $seer format: '1'=Ancillary Therapy, '2'=Chemotherapy, '3'=Chemotherapy, Hormonal Therapy, '4'=Hormonal Therapy, '5'=Immunotherapy, '6'=Radiopharmaceutical
- Join to dispensing: dispensing ndc9 = first 9 chars of digit-stripped 11-digit dispensing NDC
