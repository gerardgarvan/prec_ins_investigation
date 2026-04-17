# Phase 3: Analytical Dataset Construction - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the study cohort with sequential exclusion criteria, derive exposure variables (insurance change, treatment intensity, cancer site groups, chemotherapy), calculate outcome variables (non-acute visits, cancer-related visits, survivorship visits, person-time), process covariates (demographics, SDI, RUCA, age categories), and produce one wide patient-level analytical dataset (complete-case + MI-ready) for Phase 4 statistical analysis. Generate a publication-ready CONSORT exclusion flowchart.

</domain>

<decisions>
## Implementation Decisions

### Script Organization
- **D-01:** Keep 4 scripts matching run_all.R placeholders: `03_cohort.R` -> `03_exposure.R` -> `03_outcomes.R` -> `03_covariates.R`. Linear dependency chain.
- **D-02:** Each script is self-contained: reads .rds checkpoint inputs, writes .rds checkpoint outputs. Can rerun any script independently without running predecessors in the same R session.

### CONSORT Flowchart
- **D-03:** Generate CONSORT-style exclusion flowchart using ggplot2 custom (geom_rect + geom_text + geom_segment). No additional package dependency.
- **D-04:** Save flowchart in both PNG and PDF formats to `output/figures/` directory.

### Analytical Dataset Shape
- **D-05:** Final output is one wide patient-level tibble: one row per patient with all exposure, outcome counts, covariates, and person-time columns. Matches SAS `for_table1` pattern.
- **D-06:** Produce both complete-case analytical dataset AND MI-ready dataset. Matches SAS `for_table1-4` + `mi_table1-4` structure. Phase 4 runs analyses on both per Phase 1 D-11.

### Person-Time & Censoring
- **D-07:** Censoring rules extracted faithfully from V5 SAS code. Translate exactly as SAS defines them. Do not redesign censoring logic.
- **D-08:** Exposure variable (pct_change_ins) translated faithfully from SAS, with inline comments flagging edge cases (single-observation patients, undefined denominators, etc.) for research team review.

### Claude's Discretion
- Execution order within each script (section sequencing)
- Specific assertr assertions to include at each checkpoint
- How to structure the MI-ready dataset (mice-compatible format vs. pre-imputed)
- CONSORT flowchart visual layout and styling choices
- Resolution of conflicting logic between SAS file versions (using V5-primary rule from Phase 1 D-10)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### SAS Source Files -- V5 Series (PRIMARY)
- `SAS_CODE_FOR_V5_0.sas` through `SAS_CODE_FOR_V5_18.sas` -- V5 main program evolution. Contains cohort construction (valid_id, enrollment criteria), exposure variable derivation (pct_change_ins, treatment intensity), outcome variable calculation (visit type flags, person-time), and covariate processing.
- `SAS_CODE_FOR_V5_Table_1.sas` -- V5 Table 1 generation. Shows which variables end up in the final analytical dataset and their expected categories.
- `SAS_CODE_FOR_V5_MODELS*.sas` / `SAS_CODE_V5_MODELS3.sas` -- V5 model specifications. Shows outcome variables and offset terms (person-time usage).
- `glimmix.sas` -- External GLIMMIX macro. Referenced for understanding MI dataset structure.

### SAS Source Files -- Supplementary
- `Formats.sas` -- Format definitions for all categorical variables (already translated in Phase 1 `01_formats.R`)
- `keytodatasets.sas` -- Dataset structure and join keys
- Dated files (March 2024 - January 2025) -- topic-specific processing (chemo, treatment intensity, outcomes, cancer site) for gap-filling when V5 is incomplete

### Phase 1/2 Outputs (inputs to Phase 3)
- `R/config.R` -- Path configuration, directory setup
- `R/01_formats.R` -- All SAS format definitions (`sas_formats` object) for categorical recoding
- `data/processed/01_imported_*.rds` -- Phase 1 imported datasets (demo, enroll, dx_parts, dispensing, icd_groups, ruca, etc.)
- `data/processed/02_encounters_cleaned.rds` -- Cleaned encounter data
- `data/processed/02_merged_complete.rds` -- Merged encounter-dx-proc-provider dataset
- `data/processed/02_dx_combined.rds` -- Combined diagnosis parts
- `data/processed/02_proc_combined.rds` -- Combined procedure parts

### Project Documentation
- `.planning/PROJECT.md` -- Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` -- COH-01 through COH-05, EXP-01 through EXP-04, OUT-01 through OUT-06, COV-01 through COV-04 (Phase 3 requirements)
- `.planning/phases/01-data-import-format-translation/01-CONTEXT.md` -- Phase 1 decisions (D-10 V5 primary, D-11 MI included, D-12 advanced models)
- `.planning/phases/02-data-cleaning-merging/02-CONTEXT.md` -- Phase 2 decisions (assertr pattern, factor() with sas_formats)

### Stack References
- `.planning/research/STACK.md` -- Validated technology stack. Note: Phase 3 may require adding `mice` package for MI dataset preparation.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `sas_formats` object (`data/processed/01_formats.rds`): Full format definitions for all categorical variables. Use with `factor()` for COV-01 (sex, race, Hispanic), age categories, cancer site groups, etc.
- `import_sas()` helper pattern (R/02_clean.R:47+): Replicated SAS import function. If Phase 3 needs additional raw SAS imports, follow this pattern.
- `save_checkpoint()` pattern: `saveRDS(obj, file.path(data_dir_processed, "03_*.rds"))` with `message()` logging.
- `assertr` validation pattern (R/02_clean.R, R/02_merge.R): `verify()`, `assert()` with `warn_report` error function for data quality checks.

### Established Patterns
- `message()` logging for row counts and validation at every step
- `janitor::clean_names()` already applied to all data -- do NOT reapply
- .rds checkpoints in `data/processed/` with phase prefix (`01_`, `02_` -> Phase 3 uses `03_`)
- `library(here); source(here::here("R", "config.R"))` at top of every script
- SAS labels preserved as data frame attributes -- maintain through pipeline
- `dplyr::*_join()` with `relationship` argument for explicit cardinality

### Integration Points
- Phase 3 reads from: `data/processed/02_*.rds` checkpoints (primary) and `data/processed/01_imported_*.rds` for tables not touched by Phase 2 (demo, enroll, dispensing, ruca, icd_groups)
- Phase 3 writes to: `data/processed/03_cohort.rds`, `data/processed/03_exposure.rds`, `data/processed/03_outcomes.rds`, `data/processed/03_analytical.rds` (final wide dataset), `data/processed/03_analytical_mi.rds` (MI-ready)
- `output/figures/consort_flowchart.png` and `output/figures/consort_flowchart.pdf` -- CONSORT diagram
- `run_all.R` must be updated to uncomment/add Phase 3 scripts

</code_context>

<specifics>
## Specific Ideas

No specific requirements -- open to standard approaches. User trusts Claude's forensic judgment for SAS code translation, cohort construction logic, and variable derivation. Key principle: faithful translation with flagged edge cases (per D-08 pattern).

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope.

</deferred>

---

*Phase: 03-analytical-dataset-construction*
*Context gathered: 2026-04-16*
