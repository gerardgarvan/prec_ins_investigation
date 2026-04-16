# Phase 2: Data Cleaning & Merging - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 02-data-cleaning-merging
**Areas discussed:** Script structure, Payer grouping approach, Assertion failure behavior, Missing encounter files

---

## Script Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Two scripts (Recommended) | 02_clean.R (encounter import, variable recoding, payer grouping) + 02_merge.R (encounter-dx-proc-provider joins with row count validation). Saves intermediate .rds checkpoint between them. | ✓ |
| Single script | 02_clean_merge.R combines everything. Simpler but no intermediate checkpoint between cleaning and merging steps. | |
| You decide | Claude picks based on complexity of the SAS logic discovered during forensic analysis. | |

**User's choice:** Two scripts (Recommended)
**Notes:** None — user accepted recommendation.

### Follow-up: Concatenation placement

| Option | Description | Selected |
|--------|-------------|----------|
| Combine in 02_clean.R | All bind_rows() operations (encounters, diagnoses, procedures) happen in cleaning. 02_merge.R only does cross-table joins. | |
| Combine in 02_merge.R | 02_clean.R handles encounter combination + variable recoding only. Diagnosis/procedure concatenation happens in merge script alongside their joins. | |
| You decide | Claude determines the best split based on SAS code structure. | ✓ |

**User's choice:** You decide
**Notes:** Claude's discretion for diagnosis/procedure concatenation placement.

---

## Payer Grouping Approach

| Option | Description | Selected |
|--------|-------------|----------|
| factor() with sas_formats (Recommended) | Use factor(payer_type_primary, levels=sas_formats$p_payer$levels, labels=sas_formats$p_payer$labels). Direct translation of SAS FORMAT statement. Single source of truth. | ✓ |
| case_when() explicit logic | Spell out every grouping rule in case_when(). More auditable — reviewer sees all logic inline. But error-prone with 170+ codes. | |
| Hybrid approach | Use factor() for raw-to-label step, then case_when() for label-to-group step. | |

**User's choice:** factor() with sas_formats (Recommended)
**Notes:** None — user accepted recommendation.

### Follow-up: Unmapped payer codes

| Option | Description | Selected |
|--------|-------------|----------|
| Warn and set to 'Unknown' | Log a warning with the unmapped code and count, assign 'Unknown'. Pipeline continues. Matches Phase 1 warn-and-continue pattern. | ✓ |
| Halt pipeline | Stop execution if any payer code has no mapping. Forces investigation before proceeding. | |
| You decide | Claude picks based on how the SAS code handles unmapped values. | |

**User's choice:** Warn and set to 'Unknown'
**Notes:** Matches Phase 1 warn-and-continue pattern.

---

## Assertion Failure Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Warn and continue (Recommended) | Log detailed warnings (what failed, how many rows affected, which variables), but continue pipeline. Good for initial development without data. | ✓ |
| Halt on critical, warn on minor | Define critical assertions that halt and minor ones that warn. More protective but requires defining criticality thresholds. | |
| Always halt | Any assertion failure stops the pipeline. Strictest but may be impractical without data to test against. | |

**User's choice:** Warn and continue (Recommended)
**Notes:** None — user accepted recommendation.

### Follow-up: Assertion reporting style

| Option | Description | Selected |
|--------|-------------|----------|
| Summary report at end | Collect all assertion results into a data quality summary printed at script end. | |
| Log as they occur | Print warnings inline as each assertion runs. Simpler implementation. | |
| You decide | Claude picks based on how many assertions there end up being. | ✓ |

**User's choice:** You decide
**Notes:** Claude's discretion for reporting style.

---

## Missing Encounter Files

| Option | Description | Selected |
|--------|-------------|----------|
| Import at top of 02_clean.R (Recommended) | Use existing import_sas() helper. Keeps Phase 1 scripts untouched. Phase 2 is natural home. | ✓ |
| Add to 01_import.R retroactively | More logical but changes a verified Phase 1 script. | |
| You decide | Claude picks whichever keeps the pipeline cleanest. | |

**User's choice:** Import at top of 02_clean.R (Recommended)
**Notes:** None — user accepted recommendation.

### Follow-up: Additional missing tables

| Option | Description | Selected |
|--------|-------------|----------|
| Only encounter1 + encounter2 | Import just the two known missing files. | |
| Import all missing tables | During forensic analysis, if Claude discovers additional tables needed, import them all at top of 02_clean.R. | ✓ |
| You decide | Claude determines what needs importing based on forensic analysis. | |

**User's choice:** Import all missing tables
**Notes:** Claude should discover and import any additional tables needed for Phase 2 merges during forensic analysis.

---

## Claude's Discretion

- Diagnosis/procedure multi-part concatenation placement (02_clean.R vs 02_merge.R)
- Assertion reporting style (summary report vs inline logging)
- Encounter deduplication approach (translate SAS logic only)
- Dual Medicare/Medicaid detection logic

## Deferred Ideas

- Advanced encounter deduplication (N3C/RECOVER "macrovisit" methods) — future enhancement
- Retroactive update of 01_import.R — Phase 1 is complete
