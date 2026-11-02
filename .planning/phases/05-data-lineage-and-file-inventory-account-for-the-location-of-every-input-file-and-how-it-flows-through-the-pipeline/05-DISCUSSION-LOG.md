# Phase 5: Data Lineage and File Inventory - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-02
**Phase:** 05-data-lineage-and-file-inventory
**Areas discussed:** SAS alias resolution, Missing-in-R table handling, Mermaid diagram scope, Column lineage depth

---

## SAS Alias Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| /blue/erin.mobley-precision/ResVault/f/Dx | Use path from phase description for dx alias | |
| Same as data_dir_raw | Icd10_groups2 is in Data_v5 directory | |
| Unknown — flag as Must verify | Can't confirm from code; flag and check both locations | ✓ |

**User's choice:** Unknown — flag as Must verify on HiPerGator

**Follow-up question:** Are v3/v4/dx the only aliases, or are there more?

**User's answer (free text):** Parse every LIBNAME, FILENAME, and `%include` in all SAS files in the repo including dated/exploratory ones (`chemo_*`, `checks_*`, `new_*`, `SAS_PROGRAM_*`). Report every alias and path found, which programs use it, and whether it feeds the V5 pipeline or is legacy.

---

## Missing-in-R Table Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Check them — FAIL if not found | 00_check_inputs.R probes all tables; missing-in-R cause FAIL | |
| Skip — only check R imports | Missing-in-R documented in manifest but not probed | |
| Check them — WARN (not FAIL) | Missing-in-R get FOUND/MISSING; FAIL only for currently-imported tables | ✓ |

**User's choice:** Two-tier severity: FAIL for R-imported tables, WARN for missing-in-R tables. Overall result is FAIL only when a currently-imported table is missing or lacks expected columns.

---

## Mermaid Diagram Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Phase-grouped | One diagram, nodes are pipeline stages | ✓ (partial) |
| File-level | Every file as its own node | ✓ (partial) |

**User's choice:** Both — phase-grouped as the main diagram, PLUS a second focused file-level diagram covering only the dx/encounter path (dx parts + encounter parts + icd_groups2 → cleaned → merged → 03_* scripts). This path is what the memory-fix restructures. All other file-level detail stays in the manifest CSV.

---

## Column Lineage Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Broken-pipe check only | Flag columns read but never produced | ✓ (for DATA_LINEAGE.md) |
| Full column map | Every KEEP, rename, derived column, consumer | ✓ (for column_lineage.csv) |

**User's choice:** Split by output file. `docs/column_lineage.csv` gets the full column map (table, column, origin, created_in, consumed_by). `DATA_LINEAGE.md` shows only broken-pipe findings: columns read but never produced, columns produced but never consumed, renames, and .x/.y collisions.

---

## Claude's Discretion

- Report format for 00_check_inputs.R output
- Whether column_lineage.csv includes output/checkpoint columns or only raw inputs
- Ordering and grouping of manifest CSV rows

## Deferred Ideas

None.
