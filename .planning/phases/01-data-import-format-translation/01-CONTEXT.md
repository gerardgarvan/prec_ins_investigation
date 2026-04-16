# Phase 1: Data Import & Format Translation - Context

**Gathered:** 2026-04-16
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
- **D-06:** Forensic analysis across all ~90 SAS files to determine the correct analytical logic for each step. Claude traces evolution across versions (March 2024 - January 2025), identifies the latest/correct logic, and resolves conflicts. No shortcuts to "latest file only."
- **D-07:** SAS errors and conflicting logic documented as inline R comments where the logic appears. Example: `# SAS BUG FIX: v4_3 had wrong payer code mapping, corrected per v4_8`. No separate changelog file.

### Pipeline Checkpoints
- **D-08:** Each script saves output as .rds checkpoint files (e.g., `data/processed/01_encounters.rds`). Subsequent scripts read from checkpoints. Enables re-running from any stage.
- **D-09:** run_all.R includes a `start_step` parameter to resume from any script number, leveraging .rds checkpoints. Supports both full pipeline and partial re-runs.

### Claude's Discretion
- D-02 (format duplicate resolution) — Claude determines correct version per duplicate format block

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### SAS Source Files
- `Formats.sas` — All SAS format definitions (2,495 lines). PCORnet CDM standard + study-specific custom formats. Contains duplicate blocks requiring forensic resolution.
- `keytodatasets.sas` — Shows library references, dataset names, and join structure for the analytical dataset.
- `SAS_CODE_V4_10.sas` — Latest numbered version of the main SAS program (may be empty/stub).
- `SAS_CODE_FOR_V4_9.sas` — Previous version of main SAS program.
- `HL_IDS_1_9_2025.sas` — Latest dated SAS file (January 2025).
- `use_this_one.sas` — Named to suggest authoritative status (requires forensic verification).

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — IMP-01 through IMP-05, INF-01 through INF-06 (Phase 1 requirements)

### Stack References
- `.planning/research/STACK.md` — Validated technology stack (haven, tidyverse, here, renv, janitor)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — no R code exists yet. This is a greenfield phase.

### Established Patterns
- SAS code uses `%let path=...; libname v4 "&path/ResVault/f/Data_v4/";` pattern for path parameterization — R equivalent will use `here::here()` + config.R.
- SAS code uses `%include "Formats.sas";` to load formats at session start — R equivalent will be `source(here("R", "01_formats.R"))`.
- Multiple SAS library names (v3, v4, a, ww, dx, arm) reference different data locations — R config.R will unify these into a single `data_dir` variable.

### Integration Points
- Phase 1 outputs (.rds checkpoint files, format definitions list) will be consumed by Phase 2 (Data Cleaning & Merging).
- run_all.R structure established here will be extended in subsequent phases with additional numbered scripts.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User trusts Claude's forensic judgment for resolving SAS code conflicts and format duplicates.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-data-import-format-translation*
*Context gathered: 2026-04-16*
