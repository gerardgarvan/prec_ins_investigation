# Phase 2: Data Cleaning & Merging - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Import the missed encounter files (encounter1, encounter2, plus any other tables discovered during forensic analysis), clean all encounter-level data (standardize names, recode payer types, encounter types, discharge fields, handle missing values explicitly), then merge encounters with diagnoses, procedures, and provider data using validated PCORnet CDM join keys with row count tracking at every step.

</domain>

<decisions>
## Implementation Decisions

### Script Structure
- **D-01:** Two scripts: `02_clean.R` (encounter import, variable recoding, payer grouping) + `02_merge.R` (encounter-dx-proc-provider joins with row count validation). Saves intermediate .rds checkpoint between them.
- **D-02:** Diagnosis/procedure multi-part concatenation (bind_rows for 7 dx parts, 4 proc parts) placement is Claude's discretion — assign to whichever script produces the cleanest separation of concerns.

### Payer Grouping
- **D-03:** Use `factor()` with Phase 1 `sas_formats$p_payer` format definition as single source of truth. Direct translation of SAS FORMAT statement. Do NOT use hand-rolled `case_when()` for the 170+ payer codes.
- **D-04:** Unmapped payer codes: warn with `message()` (log the code and count), assign to "Unknown". Pipeline continues. Matches Phase 1 warn-and-continue pattern.

### Data Quality Assertions
- **D-05:** Use `assertr` package for post-merge data quality checks. On assertion failure: warn and continue (do not halt pipeline). Good for initial development without data to test against.
- **D-06:** Assertion result reporting (summary at end vs inline logging) is Claude's discretion — pick based on how many assertions the final scripts contain.

### Missing Encounter Files
- **D-07:** Import encounter1_mobley_v5.sas7bdat and encounter2_mobley_v5.sas7bdat at the top of `02_clean.R` using existing `import_sas()` helper from Phase 1. Do NOT modify 01_import.R retroactively.
- **D-08:** During forensic analysis, if Claude discovers additional tables needed for Phase 2 merges (encounter-insurance linking tables, etc.), import them all at the top of `02_clean.R`.

### Claude's Discretion
- D-02 (diagnosis/procedure concatenation placement) — Claude determines best split between 02_clean.R and 02_merge.R
- D-06 (assertion reporting style) — Claude picks inline logging vs summary report based on assertion count
- Encounter deduplication approach — translate SAS logic exactly; defer advanced N3C/RECOVER "macrovisit" methods to future enhancement
- Dual Medicare/Medicaid detection logic — follow SAS format definitions, document any discrepancies

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Outputs (inputs to Phase 2)
- `R/config.R` — Path configuration, directory setup, SAS encoding parameter
- `R/01_formats.R` — All SAS format definitions including `sas_formats$p_payer`, `sas_formats$enc_type`, `sas_formats$discharge_status`, `sas_formats$discharge_disposition`
- `R/01_import.R` — `import_sas()` helper function (reuse for encounter files), checkpoint naming pattern, date validation logic
- `R/run_all.R` — Pipeline runner (must be updated with 02_clean.R and 02_merge.R)

### SAS Source Files (forensic analysis targets)
- `SAS_CODE_FOR_V5_0.sas` through `SAS_CODE_FOR_V5_18.sas` — V5 main program evolution. PRIMARY target for encounter cleaning, payer recoding, and merge logic.
- `HL_IDS_1_9_2025.sas` — Contains encounter combination pattern (lines 73-74: SET encounter1 encounter2)
- `Formats.sas` — Payer format definitions (Block 4 definitive per D-02 from Phase 1)
- `keytodatasets.sas` — Join structure reference for encounter-dx-proc-provider merges

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — CLN-01 through CLN-06, MRG-01 through MRG-04 (Phase 2 requirements)
- `.planning/phases/01-data-import-format-translation/01-CONTEXT.md` — Phase 1 decisions (D-07, D-08, D-10 carry forward)

### Stack References
- `.planning/research/STACK.md` — Validated technology stack (dplyr 1.2.1+, janitor 2.2.1, assertr)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `import_sas()` (R/01_import.R:57-101): SAS7BDAT import helper with clean_names, label preservation, date conversion. Reuse for encounter1/encounter2 import.
- `sas_formats` object (01_formats.rds checkpoint): Full payer, encounter type, discharge format definitions. Apply with `factor()`.
- `save_checkpoint()` (R/01_import.R:225-233): Checkpoint save helper. Can be reused or adapted for Phase 2 checkpoints.

### Established Patterns
- `janitor::clean_names()` applied at import time — do NOT reapply in Phase 2
- .rds checkpoints in `data/processed/` with `01_imported_` prefix — Phase 2 should use `02_` prefix
- `message()` logging for row counts and validation — continue this pattern
- SAS labels stored as data frame attribute via `attr(df, "sas_labels")` — preserve through pipeline

### Integration Points
- Phase 2 reads from: `data/processed/01_imported_*.rds` checkpoints (demo, enroll, dx_parts, proc_parts, provider, prov_spec, ruca, dispensing, icd_groups)
- Phase 2 writes to: `data/processed/02_encounters_cleaned.rds`, `data/processed/02_merged_*.rds` (checkpoint naming to be determined)
- `run_all.R` must be updated to source 02_clean.R and 02_merge.R with correct step numbering

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User trusts Claude's forensic judgment for SAS code translation and merge logic.

</specifics>

<deferred>
## Deferred Ideas

- Advanced encounter deduplication using N3C/RECOVER "macrovisit" aggregation methods — beyond scope for initial SAS translation, note as future enhancement
- Retroactive update of 01_import.R to include encounter files — Phase 1 is complete, encounter import handled in Phase 2

</deferred>

---

*Phase: 02-data-cleaning-merging*
*Context gathered: 2026-04-16*
