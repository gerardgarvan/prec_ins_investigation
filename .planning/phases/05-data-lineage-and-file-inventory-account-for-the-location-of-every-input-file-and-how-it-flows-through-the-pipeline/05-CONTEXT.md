# Phase 5: Data Lineage and File Inventory - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Produce four deliverables that map every SAS input file to the R pipeline and flag gaps:

1. `docs/DATA_LINEAGE.md` — narrative + two Mermaid diagrams (phase-grouped overview + focused dx/encounter file-level diagram). Must record the git commit hash the lineage was generated from at the top of the document, since the memory-fix work will change the code afterward.
2. `docs/file_manifest.csv` — one row per SAS table: alias, HiPerGator path, R import call name, checkpoint RDS, columns kept, downstream consumers, status, notes (including both SAS-declared and on-disk filename when they differ by case)
3. `docs/column_lineage.csv` — one row per column: table, column, origin (raw/renamed/derived), created_in script, consumed_by scripts
4. `R/00_check_inputs.R` — HiPerGator preflight checker; reads headers only, writes pass/fail report

This phase reads code only (no data access). It documents problems but does not fix them. Problems are flagged for the memory-fix work.

</domain>

<decisions>
## Implementation Decisions

### SAS Alias Resolution

- **D-01:** Parse ALL LIBNAME, FILENAME, and `%include` statements across every SAS file in the repo — including dated/exploratory ones (`chemo_*`, `checks_*`, `SAS_PROGRAM_*`, `HL_IDS_*`, `CHEMO_ID_*`, `NDC_ID_*`, `Formats.sas`). Do not limit to V5 pipeline files only.
- **D-02:** For each alias found, record: alias name, declared path, which SAS programs use it, and whether it feeds the V5 analytical pipeline or is legacy (V4/local drive/one-off check).
- **D-03:** Resolve every alias from SAS LIBNAME statements first; then compare against `R/config.R` and record agreement or conflict. Do **not** treat any alias as confirmed until the SAS LIBNAME parse is done — `v4`'s path in particular is unknown until parsed. `R/config.R` comments (e.g. `v3 → Data_v5`) are hypotheses to verify, not ground truth.
- **D-04:** For the `dx` library alias (where `Icd10_groups2.sas7bdat` lives), `00_check_inputs.R` must probe all of the following candidate paths and report which exist:
  - `data_dir_raw` (i.e., `/orange/erin.mobley-precision/Data_v5`)
  - `file.path(data_dir_raw, "Dx")`
  - `/blue/erin.mobley-precision/ResVault/f/Dx` (declared in SAS LIBNAME)
  - `/orange/erin.mobley-precision/f/Dx`
  - Any additional path found in a SAS LIBNAME for `dx` during the parse
- **D-05:** Any additional aliases discovered during parsing get the same treatment: resolve from SAS code, compare with R config, flag "Must verify on HiPerGator" if path cannot be confirmed from code alone.

### Case-Insensitive File Name Matching

- **D-06 (new):** SAS on Linux writes dataset files in lowercase (e.g., `dx.Icd10_groups2` → `icd10_groups2.sas7bdat`). `00_check_inputs.R` must:
  - Perform case-insensitive file existence checks (list directory contents and match without case sensitivity).
  - Report the actual on-disk filename alongside the name the R import call uses.
  - Flag a discrepancy between the R import call's filename and the real on-disk name as a `mismatch` status — this is a latent bug in the R import call that will fail on a case-sensitive filesystem.
  - The manifest records both: `r_import_name` (what `01_import.R` passes to `haven::read_sas`) and `disk_name` (actual filename found on disk, if different).

### Missing-in-R Table Handling

- **D-07:** Two-tier severity in `00_check_inputs.R`:
  - **FAIL** — table is imported by the current R pipeline (via `import_and_save`, `import_parts`, or `import_sas` in production scripts) and is missing or lacks expected columns. Pipeline cannot run.
  - **WARN** — table is used in SAS but not yet imported in R (`ndc_cond2`/SEERRxCategory, `surgerycodes`, `sctcodes`, and any other missing-in-R tables found). Report FOUND/MISSING with path. Does not block overall PASS/FAIL result.
- **D-08:** The manifest `status` column uses: `ok` / `missing_in_r` / `unused` / `mismatch` / `must_verify`. `00_check_inputs.R` probes all rows; severity follows D-07.

### Mermaid Diagram Structure

- **D-09:** `DATA_LINEAGE.md` contains TWO Mermaid diagrams:
  1. **Phase-grouped overview** — nodes are pipeline stages: `Raw SAS files → 01_import (checkpoints) → 02_clean → 02_merge → 03_cohort → 03_exposure / 03_outcomes / 03_covariates → 04_table1 / 04_regression → Output`. Individual file details live in the CSV.
  2. **File-level dx/encounter diagram** — covers only: dx parts + encounter parts + icd_groups2 → `02_dx_encounter` / `encounters_cleaned` → `merged_enc_dx` → `03_*` scripts. This is the path the memory-fix work restructures. Diagram must reflect the current R code state, not the SAS original.

### Column Lineage Depth

- **D-10:** Two separate outputs:
  - `docs/column_lineage.csv` — full column map: `table`, `column`, `origin` (raw/renamed/derived), `created_in`, `consumed_by`. One row per column per table.
  - `DATA_LINEAGE.md` narrative — broken-pipe findings only: columns read but never produced, columns produced but never consumed, renames, `.x/.y` collision points.
- **D-11:** Known broken-pipe candidates to check (add any others found during analysis):
  - `first_can_ruca` — read by `03_covariates.R`; check whether it is produced upstream
  - `first_can_sdi_score` — read by `03_covariates.R`; check whether it is produced upstream
  - `source` (column) — check where it is read vs. produced
  - `any_reportable_cancer` — dropped from `KEEP_DX` but may be read by `03_cohort.R` / `03_exposure.R`
  - `group_site` — dropped from `KEEP_DX` but may be read by `03_exposure.R`
  - `ID → patid` rename — record where `ID` is renamed to `patid` and whether any script still reads `ID` after the rename

### 00_check_inputs.R Constraints

- **D-12:** Never load full tables. Call `haven::read_sas(path, n_max = 0)` directly — **not** `import_sas()` (which lacks an `n_max` argument and performs cleaning steps). After the call, assert `nrow(result) == 0`; if haven returns rows (older versions), fall back to `n_max = 1` and discard data. Only column names and file existence matter.
- **D-13:** Output is a written report (text or CSV), not just console messages, so it can be reviewed after a batch run on HiPerGator.
- **D-14:** Script must be runnable standalone: sources `R/config.R` for path variables (which provides `data_dir_raw`, etc.) and no other pipeline script. Does not call `import_sas()` or any `utils_import.R` function.

### Claude's Discretion

- Report format for `00_check_inputs.R` output (plain text vs. CSV vs. both) — Claude decides based on what's most useful for a batch HiPerGator run.
- Whether `column_lineage.csv` includes columns from RDS checkpoint tables or only raw SAS input columns — Claude decides based on feasibility from static code analysis.
- Ordering and grouping of rows in the manifest CSV — Claude decides.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing R Pipeline (authoritative source of truth for what R currently does)
- `R/config.R` — HiPerGator paths, directory structure, PIPELINE_TEST switch. Note: `data_dir_processed` resolves via `here::here()` in test mode and may be project-relative, not necessarily `/blue/…`.
- `R/utils_import.R` — `import_sas()`, `import_parts()`, `import_and_save()` function signatures. **Do not use `import_sas()` in 00_check_inputs.R** — it has no `n_max` argument and performs cleaning.
- `R/01_import.R` — all import calls, KEEP_* vectors, known alias notes, Icd10_groups2 dual-path fallback logic, `procedures4_mobley_v5` naming note
- `R/02_clean.R` — surgerycodes/ndc_cond2 deferral comments (lines ~86-88, ~266-268)
- `R/02_merge.R` — prov_spec absorption note (line ~127)
- `R/03_cohort.R` — reads that depend on upstream column production (check `any_reportable_cancer`, `group_site`)
- `R/03_exposure.R` — reads `group_site`; ndc_cond2 deferral (line ~86)
- `R/03_covariates.R` — `first_can_ruca → first_ruca` rename, `first_can_sdi_score` usage

### SAS Source Files (in project root — all must be inventoried)
- `SAS_CODE_FOR_V5_*.sas` — primary V5 analytical pipeline
- `HL_IDS_*.sas`, `CHEMO_ID_*.sas`, `NDC_ID_*.sas`, `Formats.sas` — reference/lookup code
- `SAS_PROGRAM_*.sas`, `chemo_*.sas`, `checks_*.sas` — dated/exploratory files (parse for LIBNAME/FILENAME but classify as legacy if not V5)

### Known Gaps (documented in prior phase code comments)
- `ndc_cond2` (SEERRxCategory) — missing in R, needed for chemo identification (`03_exposure.R` line ~86)
- `surgerycodes` — missing in R, needed for surgery identification (`02_clean.R` line ~266)
- `sctcodes` — missing in R (referenced in SAS; not yet imported)
- `Icd10_groups2` — path uncertain; `01_import.R` has dual-path fallback; case on disk unknown
- `procedures4_mobley_v5` — naming inconsistency flagged in `01_import.R` line ~84

### No external specs — requirements fully captured in decisions above

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/config.R` — provides `data_dir_raw`, `data_dir_processed`, and output dirs; source this in `00_check_inputs.R`
- `haven::read_sas(path, n_max = 0)` — call directly in `00_check_inputs.R` for header-only reads (do not go through `import_sas()`)

### Established Patterns
- Import functions write checkpoints to `data_dir_processed` as `01_imported_<name>.rds`
- `import_parts()` writes per-part RDS files named `01_imported_<name>_part<N>.rds`
- Two-directory scheme: `data_dir_raw` (orange, read-only) for SAS7BDAT; `data_dir_processed` for RDS checkpoints. In PIPELINE_TEST mode, `data_dir_processed` is a project-relative `here::here("tests/testdata/processed")` path — not necessarily on `/blue`.

### Integration Points
- `00_check_inputs.R` is a preflight script — runs before `run_all.R`, not sourced by it
- `docs/` directory does not yet exist — must be created as part of this phase

</code_context>

<specifics>
## Specific Ideas

- The phase request explicitly named these missing-in-R candidates: `ndc_cond2` (SEERRxCategory), `surgerycodes`, `sctcodes`, `prov_spec vs provider_mobley_v5`, `ruca vs zcta`, `Icd10_groups2`.
- "Must verify on HiPerGator" items go both into the manifest `notes` column AND into a dedicated section of `00_check_inputs.R` output so they're easy to find during the HiPerGator run.
- The dx/encounter file-level Mermaid diagram covers the path being restructured by the memory-fix work — make it accurate to the current R code state, not the SAS original.
- `DATA_LINEAGE.md` must record the git commit hash at the top so readers know which code version the lineage describes (the memory-fix work will change the code afterward).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-data-lineage-and-file-inventory*
*Context gathered: 2026-11-02*
*Revised: 2026-11-02 (7 corrections applied post-discussion)*
