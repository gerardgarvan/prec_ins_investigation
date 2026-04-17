# Phase 3: Analytical Dataset Construction - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 03-analytical-dataset-construction
**Areas discussed:** Script organization, CONSORT flowchart, Analytical dataset shape, Person-time & censoring

---

## Script Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Keep 4 scripts | 03_cohort.R -> 03_exposure.R -> 03_outcomes.R -> 03_covariates.R. Each saves .rds checkpoint. Linear dependency chain matches Phase 1/2 pattern. Most modular. | ✓ |
| Consolidate to 2 scripts | 03_cohort.R (cohort + exclusions) -> 03_variables.R (all exposure/outcome/covariate derivation). Simpler but larger files. | |
| You decide | Claude determines best split based on SAS code forensics. | |

**User's choice:** Keep 4 scripts (Recommended)
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Self-contained | Each script reads .rds inputs and writes .rds outputs. Matches Phase 1/2 pattern. Can rerun independently. | ✓ |
| Shared workspace | Scripts assume prior script objects are in memory. Faster but can't rerun one script alone. | |

**User's choice:** Self-contained (Recommended)
**Notes:** None

---

## CONSORT Flowchart

| Option | Description | Selected |
|--------|-------------|----------|
| ggplot2 custom | Build with ggplot2 + geom_rect/geom_text/geom_segment. No extra dependency. Full control. Matches existing stack. | ✓ |
| consort R package | Dedicated CONSORT diagram package. Purpose-built but adds dependency. | |
| Text-based with manual figure | Print counts to console/CSV. Team creates figure manually. | |

**User's choice:** ggplot2 custom (Recommended)
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| PNG + PDF | Save both formats. PNG for quick viewing, PDF for publication. | ✓ |
| PDF only | Vector format for journal submission only. | |
| You decide | Claude picks based on SAS output and journal norms. | |

**User's choice:** PNG + PDF (Recommended)
**Notes:** None

---

## Analytical Dataset Shape

| Option | Description | Selected |
|--------|-------------|----------|
| One wide dataset | Single patient-level tibble with all columns. Matches SAS for_table1 pattern. | ✓ |
| Multiple datasets | Separate datasets for cohort, outcomes, exposures, covariates. More modular but adds merge complexity. | |
| You decide | Claude determines based on SAS for_table1-4 / mi_table1-4 structure. | |

**User's choice:** One wide dataset (Recommended)
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Both (complete-case + MI) | Matches SAS for_table1-4 + mi_table1-4 structure. Phase 4 runs both per D-11. | ✓ |
| Complete-case only | Defer MI dataset to Phase 4 or future enhancement. | |
| You decide | Claude forensically determines MI placement. | |

**User's choice:** Both (Recommended)
**Notes:** None

---

## Person-Time & Censoring

| Option | Description | Selected |
|--------|-------------|----------|
| SAS logic exactly | Forensically extract and translate censoring rules faithfully. Don't redesign. | ✓ |
| SAS + document gaps | Translate SAS but flag questionable decisions as comments. | |
| You decide | Claude determines best approach. | |

**User's choice:** SAS logic exactly (Recommended)
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Strict SAS translation | Translate pct_change_ins exactly as V5 defines it. No modifications. | |
| Translate + flag issues | Faithfully translate but add inline comments flagging edge cases for review. | ✓ |
| You decide | Claude uses forensic judgment. | |

**User's choice:** Translate + flag issues (Recommended)
**Notes:** None

---

## Claude's Discretion

- Execution order within each script
- Specific assertr assertions at each checkpoint
- MI-ready dataset structure (mice-compatible)
- CONSORT flowchart visual layout
- SAS version conflict resolution (V5-primary per Phase 1 D-10)

## Deferred Ideas

None -- discussion stayed within phase scope.
