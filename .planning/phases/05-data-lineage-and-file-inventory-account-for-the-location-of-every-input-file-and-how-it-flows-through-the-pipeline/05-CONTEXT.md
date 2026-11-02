# Phase 5: Data Lineage and File Inventory - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Produce three deliverables that map every SAS input file to the R pipeline and flag gaps:

1. `docs/DATA_LINEAGE.md` — narrative + two Mermaid diagrams (phase-grouped overview + focused dx/encounter file-level diagram)
2. `docs/file_manifest.csv` — one row per SAS table: alias, HiPerGator path, R import status, checkpoint, columns kept, downstream consumers, status, notes
3. `docs/column_lineage.csv` — one row per column: table, column, origin (raw/renamed/derived), created_in script, consumed_by scripts
4. `R/00_check_inputs.R` — HiPerGator preflight checker; reads headers only, writes pass/fail report

This phase reads code only (no data access). It documents problems but does not fix them. Problems are flagged for the memory-fix work.

</domain>

<decisions>
## Implementation Decisions

### SAS Alias Resolution

- **D-01:** Parse ALL LIBNAME, FILENAME, and `%include` statements across every SAS file in the repo — including dated/exploratory ones (`chemo_*`, `checks_*`, `SAS_PROGRAM_*`, `HL_IDS_*`, `CHEMO_ID_*`, `NDC_ID_*`, `Formats.sas`). Do not limit to V5 pipeline files only.
- **D-02:** For each alias found, record: alias name, declared path, which SAS programs use it, and whether it feeds the V5 analytical pipeline or is legacy (V4/local drive/one-off check).
- **D-03:** Known aliases from config.R comments: `v3` → `/orange/erin.mobley-precision/Data_v5`, `v4` → Data_v4 directory. These are confirmed in code.
- **D-04:** The `dx` library alias path (where `Icd10_groups2.sas7bdat` lives) is **unknown** — flag as "Must verify on HiPerGator." The `01_import.R` fallback logic checks two locations; 00_check_inputs.R should probe both.
- **D-05:** Any additional aliases discovered during parsing get the same treatment: resolve from code if possible, flag "Must verify" if not.

### Missing-in-R Table Handling

- **D-06:** Two-tier severity in `00_check_inputs.R`:
  - **FAIL** — table is imported by the current R pipeline (via `import_and_save`, `import_parts`, or `import_sas` in production scripts) and is missing or lacks expected columns. Pipeline cannot run.
  - **WARN** — table is used in SAS but not yet imported in R (`ndc_cond2`/SEERRxCategory, `surgerycodes`, `sctcodes`, and any other missing-in-R tables found). Report FOUND/MISSING with path. Does not block overall PASS/FAIL result.
- **D-07:** The manifest `status` column uses: `ok` / `missing_in_r` / `unused` / `mismatch` / `must_verify`. `00_check_inputs.R` probes all rows; severity follows D-06.

### Mermaid Diagram Structure

- **D-08:** `DATA_LINEAGE.md` contains TWO Mermaid diagrams:
  1. **Phase-grouped overview** — nodes are pipeline stages: `Raw SAS files → 01_import (checkpoints) → 02_clean → 02_merge → 03_cohort → 03_exposure / 03_outcomes / 03_covariates → 04_table1 / 04_regression → Output`. Individual file details live in the CSV.
  2. **File-level dx/encounter diagram** — covers only: dx parts + encounter parts + icd_groups2 → `02_dx_encounter` / `encounters_cleaned` → `merged_enc_dx` → `03_*` scripts. This is the path the memory-fix work restructures.

### Column Lineage Depth

- **D-09:** Two separate outputs:
  - `docs/column_lineage.csv` — full column map: columns: `table`, `column`, `origin` (raw/renamed/derived), `created_in`, `consumed_by`. One row per column per table.
  - `DATA_LINEAGE.md` narrative — broken-pipe findings only: columns read but never produced, columns produced but never consumed, renames (e.g., `ID → patid`), `.x/.y` collision points.
- **D-10:** Known broken-pipe candidates to check: `first_can_ruca`, `first_can_sdi_score`, `source` (column). Flag any others found during analysis.

### 00_check_inputs.R Constraints

- **D-11:** Never load full tables. Use `haven::read_sas(n_max = 0)` for header-only reads. Report file size via `file.info()$size`.
- **D-12:** Output is a written report (text or CSV), not just console messages, so it can be reviewed after a batch run on HiPerGator.
- **D-13:** Script must be runnable standalone (sources `config.R` for paths, no other pipeline script dependency).

### Claude's Discretion

- Report format for `00_check_inputs.R` output (plain text vs. CSV vs. both) — Claude decides based on what's most useful for a batch HiPerGator run.
- Whether `column_lineage.csv` includes columns from output tables (RDS checkpoints) or only raw input columns — Claude decides based on what's feasible from static code analysis.
- Ordering and grouping of rows in the manifest CSV — Claude decides.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing R Pipeline (authoritative source of truth for what R currently does)
- `R/config.R` — HiPerGator paths, directory structure, PIPELINE_TEST switch
- `R/utils_import.R` — `import_sas()`, `import_parts()`, `import_and_save()` function signatures and behavior
- `R/01_import.R` — all import calls, KEEP_* vectors, known alias notes, Icd10_groups2 fallback logic
- `R/02_clean.R` — surgerycodes/ndc_cond2 deferral comments (lines ~86-88, ~266-268)
- `R/02_merge.R` — prov_spec absorption note (line ~127)
- `R/03_covariates.R` — first_can_ruca → first_ruca rename, first_can_sdi_score usage

### SAS Source Files (in project root — all must be inventoried)
- `SAS_CODE_FOR_V5_*.sas` — primary V5 analytical pipeline
- `HL_IDS_*.sas`, `CHEMO_ID_*.sas`, `NDC_ID_*.sas`, `Formats.sas` — reference/lookup code
- `SAS_PROGRAM_*.sas`, `chemo_*.sas`, `checks_*.sas` — dated/exploratory files (parse for LIBNAME/FILENAME but classify as legacy if not V5)

### Known Gaps (documented in prior phase code comments)
- `ndc_cond2` (SEERRxCategory) — missing in R, needed for chemo identification (`03_exposure.R` line ~86)
- `surgerycodes` — missing in R, needed for surgery identification (`02_clean.R` line ~266)
- `sctcodes` — missing in R (referenced in SAS; not yet imported)
- `Icd10_groups2` — path uncertain; `01_import.R` has dual-path fallback
- `procedures4_mobley_v5` — naming inconsistency flagged in `01_import.R` line ~84

### No external specs — requirements fully captured in decisions above

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `utils_import.R:import_sas()` — can be called with `n_max = 0` for header-only reads in 00_check_inputs.R
- `config.R` — provides all HiPerGator paths; 00_check_inputs.R should source this

### Established Patterns
- Import functions write checkpoints to `data_dir_processed` as `01_imported_<name>.rds`
- `import_parts()` writes per-part RDS files named `01_imported_<name>_part<N>.rds`
- Two-directory scheme: `data_dir_raw` (orange, read-only) for SAS7BDAT; `data_dir_processed` (blue) for RDS checkpoints

### Integration Points
- `00_check_inputs.R` should run before `run_all.R` — it is a preflight, not part of the pipeline
- `docs/` directory does not yet exist — must be created as part of this phase

</code_context>

<specifics>
## Specific Ideas

- The phase request explicitly named these missing-in-R candidates: `ndc_cond2` (SEERRxCategory), `surgerycodes`, `sctcodes`, `prov_spec vs provider_mobley_v5`, `ruca vs zcta`, `Icd10_groups2`.
- "Must verify on HiPerGator" items go both into the manifest notes column AND into a dedicated section of `00_check_inputs.R` output so they're easy to find during the HiPerGator run.
- The dx/encounter file-level Mermaid diagram is specifically useful because it covers the path being restructured by the memory-fix work — make it accurate to the current R code, not the SAS original.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-data-lineage-and-file-inventory*
*Context gathered: 2026-11-02*
