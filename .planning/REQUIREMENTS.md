# Requirements: Precision Cancer Survivorship — SAS-to-R Conversion

**Defined:** 2026-04-16
**Core Value:** Produce a trustworthy, readable R pipeline where every analytical step has clear logic, so the research team can confidently understand and reproduce the insurance investigation results.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Data Import

- [x] **IMP-01**: R code reads all required SAS7BDAT files using haven::read_sas() with correct encoding
- [x] **IMP-02**: All SAS format definitions from Formats.sas are translated to R factor levels with matching labels
- [x] **IMP-03**: SAS date values convert correctly to R Date objects (validated against known dates)
- [x] **IMP-04**: All file paths are parameterized in a config file using here::here() — no hardcoded paths
- [x] **IMP-05**: Variable labels from SAS datasets are preserved as R attributes

### Data Cleaning

- [x] **CLN-01**: All variable names are standardized to consistent case (janitor::clean_names)
- [x] **CLN-02**: Encounter datasets (encounter1 + encounter2) are correctly combined into single dataset
- [x] **CLN-03**: Insurance payer type codes are recoded from raw PCORnet codes to grouped categories matching SAS logic
- [x] **CLN-04**: Missing values are handled explicitly with is.na() — no implicit SAS-style missing comparisons
- [x] **CLN-05**: Encounter type, discharge status, and discharge disposition are recoded with proper factor levels
- [x] **CLN-06**: Primary and secondary payer types are derived with correct grouping logic (including dual Medicare/Medicaid)

### Data Merging

- [x] **MRG-01**: Encounters merge correctly with diagnoses, procedures, and provider data by appropriate keys
- [x] **MRG-02**: Row counts are validated after every merge operation (logged to console)
- [x] **MRG-03**: Many-to-many merge relationships are identified and handled appropriately (no unintended Cartesian products)
- [x] **MRG-04**: Data quality assertions verify key variables after merges (no unexpected NAs, correct value ranges)

### Cohort Construction

- [x] **COH-01**: Valid enrollment criteria filter patients correctly (matching SAS valid_id logic)
- [x] **COH-02**: Cancer diagnosis identification uses correct ICD-9/ICD-10 codes for reportable cancers
- [x] **COH-03**: Sequential exclusion criteria are applied with patient counts logged at each step
- [x] **COH-04**: CONSORT-style exclusion flowchart is generated as a publication-ready figure
- [x] **COH-05**: Baseline (first cancer diagnosis date) is correctly identified per patient

### Exposure Variables

- [ ] **EXP-01**: Insurance change variable (pct_change_ins) calculated correctly from first cancer payer to follow-up payer
- [ ] **EXP-02**: Treatment intensity derived from SCT, radiation, surgery, and chemotherapy data matching SAS logic
- [ ] **EXP-03**: Cancer site groups (group_site) created with correct ICD code-to-site mapping
- [ ] **EXP-04**: Chemotherapy identification uses correct NDC codes and procedure codes

### Outcome Variables

- [ ] **OUT-01**: Non-acute care encounters (Enc_nonacute_care) correctly flagged using ENC_TYPE in ('AV','TH')
- [ ] **OUT-02**: Cancer-related visits correctly require non-acute care + any_reportable_cancer diagnosis
- [ ] **OUT-03**: Cancer visit with provider correctly requires cancer-related visit + cancer provider specialty
- [ ] **OUT-04**: Survivorship visits correctly require non-acute care + cancer provider + ICD personal treatment history codes
- [ ] **OUT-05**: Person-time (days from first cancer dx to follow-up) calculated correctly with appropriate censoring
- [ ] **OUT-06**: Visit counts are aggregated per patient for use as count outcomes in regression

### Covariate Processing

- [ ] **COV-01**: Sex, race, and Hispanic ethnicity recoded with correct PCORnet CDM factor labels
- [ ] **COV-02**: Age categories derived correctly (matching SAS age2 groupings: <15, 15-40, 40-54, 55-64, 65+)
- [ ] **COV-03**: SDI score processed with correct formatting/categories
- [ ] **COV-04**: RUCA classification processed with correct urban-rural categories

### Statistical Analysis

- [ ] **STA-01**: Table 1 shows patient characteristics stratified by exposure group(s) with appropriate statistics
- [ ] **STA-02**: Bivariate tests (chi-square for categorical, Wilcoxon rank sum for continuous) compare groups correctly
- [ ] **STA-03**: Poisson regression models fit visit rate outcomes with log(person-time) offset
- [ ] **STA-04**: Negative binomial regression models fit when overdispersion detected
- [ ] **STA-05**: Regression tables show IRRs/rate ratios, 95% CIs, and p-values
- [ ] **STA-06**: Model diagnostics include overdispersion test and goodness-of-fit assessment
- [ ] **STA-07**: Frequency/cross-tabulation tables generated for key variable distributions

### Pipeline Infrastructure

- [x] **INF-01**: Code organized as numbered modular scripts (01_import.R through final output script)
- [x] **INF-02**: Master runner script (run_all.R) executes full pipeline from data import to final outputs
- [x] **INF-03**: Config files separate file paths and study parameters from analysis code
- [x] **INF-04**: All logic decisions and SAS error fixes documented in code comments
- [x] **INF-05**: Intermediate datasets saved as .rds checkpoints between pipeline stages
- [x] **INF-06**: renv lockfile created for reproducible package management

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Validation

- **VAL-01**: Side-by-side SAS vs R output comparison tables for key results
- **VAL-02**: Automated regression coefficient concordance testing against SAS PROC GENMOD output

### Enhanced Visualization

- **VIZ-01**: Forest plots for regression results
- **VIZ-02**: Kaplan-Meier curves if survival analysis added

### Pipeline Automation

- **AUTO-01**: targets package integration for dependency-aware pipeline execution
- **AUTO-02**: Automated report generation with R Markdown

## Out of Scope

| Feature | Reason |
|---------|--------|
| Running code against actual data | Code written for structure only — pointed at data later |
| New analyses beyond SAS code | Reconstruction project, not extension |
| Automated SAS-to-R translation tool | Code too tangled for automated conversion |
| CDISC/pharmaverse regulatory packages | Research study, not clinical trial submission |
| Interactive dashboards or Shiny apps | Static analysis pipeline only |
| Mobile/web deployment | Desktop R scripts for research team |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| IMP-01 | Phase 1 | Complete |
| IMP-02 | Phase 1 | Complete |
| IMP-03 | Phase 1 | Complete |
| IMP-04 | Phase 1 | Complete |
| IMP-05 | Phase 1 | Complete |
| CLN-01 | Phase 2 | Complete |
| CLN-02 | Phase 2 | Complete |
| CLN-03 | Phase 2 | Complete |
| CLN-04 | Phase 2 | Complete |
| CLN-05 | Phase 2 | Complete |
| CLN-06 | Phase 2 | Complete |
| MRG-01 | Phase 2 | Complete |
| MRG-02 | Phase 2 | Complete |
| MRG-03 | Phase 2 | Complete |
| MRG-04 | Phase 2 | Complete |
| COH-01 | Phase 3 | Complete |
| COH-02 | Phase 3 | Complete |
| COH-03 | Phase 3 | Complete |
| COH-04 | Phase 3 | Complete |
| COH-05 | Phase 3 | Complete |
| EXP-01 | Phase 3 | Pending |
| EXP-02 | Phase 3 | Pending |
| EXP-03 | Phase 3 | Pending |
| EXP-04 | Phase 3 | Pending |
| OUT-01 | Phase 3 | Pending |
| OUT-02 | Phase 3 | Pending |
| OUT-03 | Phase 3 | Pending |
| OUT-04 | Phase 3 | Pending |
| OUT-05 | Phase 3 | Pending |
| OUT-06 | Phase 3 | Pending |
| COV-01 | Phase 3 | Pending |
| COV-02 | Phase 3 | Pending |
| COV-03 | Phase 3 | Pending |
| COV-04 | Phase 3 | Pending |
| STA-01 | Phase 4 | Pending |
| STA-02 | Phase 4 | Pending |
| STA-03 | Phase 4 | Pending |
| STA-04 | Phase 4 | Pending |
| STA-05 | Phase 4 | Pending |
| STA-06 | Phase 4 | Pending |
| STA-07 | Phase 4 | Pending |
| INF-01 | Phase 1 | Complete |
| INF-02 | Phase 1 | Complete |
| INF-03 | Phase 1 | Complete |
| INF-04 | Phase 1 | Complete |
| INF-05 | Phase 1 | Complete |
| INF-06 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 44 total
- Mapped to phases: 44
- Unmapped: 0

---
*Requirements defined: 2026-04-16*
*Last updated: 2026-04-16 after initial definition*
