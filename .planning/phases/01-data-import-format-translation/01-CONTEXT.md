# Phase 1: Data Import & Format Translation - Context

**Gathered:** 2026-04-16
**Updated:** 2026-04-16 (V5 files added)
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the SAS-to-R data pipeline foundation: import all required SAS7BDAT files using haven::read_sas(), translate the full Formats.sas (2,495 lines) into R factor definitions, set up project infrastructure (config.R, modular numbered scripts, run_all.R runner, renv lockfile), and create .rds checkpoint outputs between pipeline stages.

</domain>

<decisions>
## Implementation Decisions

### Format Translation
- **D-01:** Translate ALL format definitions from Formats.sas into R, not just study-specific ones. This includes both PCORnet CDM standard formats (~50+ blocks: $RACE, $SEX, $ENC_TYPE, $DISCHARGE_STATUS, etc.) and study-specific custom formats ($p, $gsite, sdif, $r, agef, $treament, yn, ruca_2cat, sdi).
- **D-02:** Format duplicate resolution is Claude's discretion. Formats.sas contains 4 duplicate $payer blocks with slight variations. Claude will forensically determine the correct version based on downstream usage and SAS overwrite semantics (later definition wins).
- **D-03:** Format definitions stored as named lists (e.g., `sas_formats$race`, `sas_formats$enc_type`) that can be used with `factor(x, levels=..., labels=...)`. Single list object, clean and grep-friendly.

### Config Structure
- **D-04:** Use a sourced config.R script for all path parameterization. No YAML or .Renviron dependencies. Example: `data_dir <- here("data", "raw")`.
- **D-05:** Config.R handles paths only (data directory, output directory, checkpoint directory). Study-specific parameters (date ranges, ICD code lists, age thresholds) stay in the analysis scripts where they're used for easier auditing.

### SAS Code Authority
- **D-06:** Forensic analysis across all ~122 SAS files (V4 series + V5 series + dated files + topic files) to determine the correct analytical logic for each step. Claude traces evolution across versions (March 2024 - January 2025), identifies the latest/correct logic, and resolves conflicts. No shortcuts to "latest file only."
- **D-07:** SAS errors and conflicting logic documented as inline R comments where the logic appears. Example: `# SAS BUG FIX: v4_3 had wrong payer code mapping, corrected per v4_8`. No separate changelog file.
- **D-10:** V5 is the primary target. The V5 series (`SAS_CODE_FOR_V5_0.sas` through `SAS_CODE_FOR_V5_18.sas`, plus MODELS and Table_1 variants) uses `Data_v5` directory and represents the latest analytical evolution. V4 and dated files are referenced when V5 logic is incomplete or unclear, but V5 takes precedence.

### Pipeline Checkpoints
- **D-08:** Each script saves output as .rds checkpoint files (e.g., `data/processed/01_encounters.rds`). Subsequent scripts read from checkpoints. Enables re-running from any stage.
- **D-09:** run_all.R includes a `start_step` parameter to resume from any script number, leveraging .rds checkpoints. Supports both full pipeline and partial re-runs.

### Analytical Approach (from V5 evolution)
- **D-11:** Include multiple imputation in the R pipeline. V5 uses PROC MIANALYZE with `mi_table` datasets — R equivalent will use the `mice` package (or similar). This is the more rigorous approach matching V5 intent.
- **D-12:** Advanced model selection is Claude's discretion. V5 uses PROC GLIMMIX (mixed effects with random intercept by SOURCE) and PROC COUNTREG (zero-truncated NB). Claude will forensically determine which models are used for final results vs. exploratory, and implement accordingly (candidates: lme4, glmmTMB, VGAM/countreg packages in R).

### Claude's Discretion
- D-02 (format duplicate resolution) — Claude determines correct version per duplicate format block
- D-12 (advanced model selection) — Claude determines which V5 models (GLIMMIX, COUNTREG) are used for final results and implements the appropriate R equivalents

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### SAS Source Files — V5 Series (PRIMARY)
- `SAS_CODE_FOR_V5_0.sas` through `SAS_CODE_FOR_V5_18.sas` — V5 main program evolution (18+ versions). Uses `Data_v5` directory. PRIMARY target for forensic analysis.
- `SAS_CODE_FOR_V5_Table_1.sas` — V5 Table 1 generation
- `SAS_CODE_FOR_V5_MODELS*.sas` / `SAS_CODE_V5_MODELS3.sas` / `SAS_CODE_FOR_v5_Models.sas` — V5 regression model specifications (5+ versions)
- `glimmix.sas` — External GLIMMIX macro for mixed effects models with multiple imputation. Called via `%include` in V5 files.

### SAS Source Files — V4 Series (SECONDARY)
- `SAS_CODE_FOR_V4_0.sas` through `SAS_CODE_V4_10.sas` — V4 main program evolution. Uses `Data_v4` directory. Reference when V5 is incomplete.
- `Formats.sas` — All SAS format definitions (2,495 lines). PCORnet CDM standard + study-specific custom formats. Contains duplicate blocks requiring forensic resolution.
- `keytodatasets.sas` — Shows library references, dataset names, and join structure for the analytical dataset.

### SAS Source Files — Dated/Topic Files (SUPPLEMENTARY)
- `HL_IDS_1_9_2025.sas` — Latest dated SAS file (January 2025)
- `use_this_one.sas` — Named to suggest authoritative status (requires forensic verification)
- Dated files (March 2024 - August 2024): topic-specific processing (chemo, treatment intensity, outcomes, cancer site, Table 1, checks)

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — IMP-01 through IMP-05, INF-01 through INF-06 (Phase 1 requirements)

### Stack References
- `.planning/research/STACK.md` — Validated technology stack (haven, tidyverse, here, renv, janitor). Note: V5 decisions may require adding mice, lme4/glmmTMB, VGAM to the stack.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — no R code exists yet. This is a greenfield phase.

### Established Patterns
- **V5 library pattern:** `libname v3 "&path/Data_v5";` — confusingly uses `v3` alias for Data_v5 directory. R config must clarify this.
- **V5 formats path:** `%include "/home/ggarvan/Formats.sas";` — user's home directory copy, not the project path copy.
- **V4 library pattern:** `libname v4 "&path/ResVault/f/Data_v4/";` — R config.R will parameterize as `data_dir`.
- SAS code uses `%include "Formats.sas";` to load formats at session start — R equivalent will be `source(here("R", "01_formats.R"))`.
- Multiple SAS library names (v3, v4, a, ww, dx, arm) reference different data locations — R config.R will unify these.

### Key V5 Data Tables Discovered
- Raw CDM tables with `_v5` suffix: `demographic_mobley_v5`, `Enrollment_mobley_v5`, `Address_history_mobley_v5`
- Analytical tables: `for_table1-4` (complete case), `mi_table1-4` (multiple imputation)
- Intermediate datasets: `valid_id`, `demo_validEnroll`, `provider1`, `zip_ruca`, `address`
- External data: `ruca` (RUCA codes), `prov_spec` (provider specialties), Dx library

### Integration Points
- Phase 1 outputs (.rds checkpoint files, format definitions list) will be consumed by Phase 2 (Data Cleaning & Merging).
- run_all.R structure established here will be extended in subsequent phases with additional numbered scripts.
- V5 multiple imputation setup will need to flow through to Phase 4 (Statistical Analysis).

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User trusts Claude's forensic judgment for resolving SAS code conflicts, format duplicates, and advanced model selection.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-data-import-format-translation*
*Context gathered: 2026-04-16*
*Updated: 2026-04-16 (V5 series + glimmix.sas added, ~122 total SAS files)*
