---
name: rulebook-omni-prompt
description: >
  Use when generating OMNI prompts for Airtable base setup from an ERB schema —
  the two-part split pattern that puts linked records in Part 1 and lookups/formulas
  in Part 2, organized by table.
---

# OMNI Prompt Generation Pattern for Airtable Base Setup

When asked to create an OMNI prompt (a prompt that instructs Airtable's OMNI AI to set up tables), **always split into exactly two files**. This pattern was hard-won and must not be collapsed back into a single file.

## Why Two Parts?

OMNI (Airtable's AI) can only operate on **one table at a time**. It also handles raw fields + linked records much more reliably than computed fields. By splitting:

- **Part 1** creates all tables with their raw fields and linked records — establishing the full relational graph.
- **Part 2** adds lookups and formulas per table — trivial once the links exist.

If you combine them, OMNI gets confused, creates formulas where it should create lookups, misses linked records, and produces a mess that takes hours to fix manually.

## Part 1: Normalized Fields + Name Formula

**File name:** `OMNI-PROMPT-PART1.md`

### What to include:
- **Name formula** for each table (the kebab-case slug formula using `LOWER(SUBSTITUTE(...))`)
- **All raw fields**: Single line text, Number, Date, Checkbox, Single Select, Long text, etc.
- **All FK fields as `Link to another record`** — NOT as Single line text. This is the critical insight. Example:
  ```
  - **Ward** (Link to another record → Wards): The Ward this mail pertains to.
  ```

### What to EXCLUDE:
- `{Table}Id` fields — Airtable manages record IDs internally
- Formula fields (other than Name)
- Lookup fields
- Rollup fields
- Any computed field whatsoever

### Structure:
```markdown
## Table: {TableName}

**Description:** {one-liner}

**Name formula:** `LOWER(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE({SourceField}, " ", "-"), "/", "-"), "&", "-"))`

### Fields

- **{FieldName}** ({type}): {description}
- **{FKField}** (Link to another record → {TargetTable}): {description}
```

### Special case — Name formula depends on a computed field:
If a table's Name formula references a computed field (e.g., Wards Name uses `DisplayName` which is `CONCATENATE({FirstName}, " ", {LastName})`), **inline the computation directly into the Name formula** so Part 1 has zero formula dependencies:
```
LOWER(SUBSTITUTE(SUBSTITUTE(SUBSTITUTE(CONCATENATE({FirstName}, " ", {LastName}), " ", "-"), "/", "-"), "&", "-"))
```

## Part 2: Lookups & Formulas (Per Table)

**File name:** `OMNI-PROMPT-PART2.md`

### What to include:
- **Lookup fields** that resolve through linked records from Part 1
- **Formula fields** that compute from raw fields in the same table

### What to EXCLUDE (MANY-side rollups):
- Rollup/count fields that aggregate across child tables (e.g., `TotalMailItems` on Wards counting MailItems)
- These require either Airtable Rollups created via UI or app-layer computation
- List them in an "Excluded" summary table at the bottom for completeness

### Structure — MUST be broken up by table:
Each table section must be **self-contained** so it can be fed to OMNI as a standalone prompt. OMNI can only modify one table per interaction.

```markdown
## {TableName} — Computed Fields

### Lookups

- **{FieldName}** (Lookup): {description}
  - Through: `{LinkedRecordField}` → {TargetTable}.`{TargetField}`

### Formulas

- **{FieldName}** (Formula): {description}
  - `{AirtableFormulaExpression}`
```

### DAG ordering within Part 2:
If any formula depends on another computed field (not just raw fields), that dependency must appear earlier in the file. Organize in layers:
1. **Layer 1**: Formulas on raw fields only (e.g., `DisplayName`, `IsOverdue`)
2. **Layer 2**: Lookups through linked records (these reference raw fields in target tables)
3. **Layer 3**: Formulas that depend on Layer 1 or Layer 2 fields

In practice, most Part 2 fields are Layer 1 or Layer 2 with no inter-dependencies, so per-table organization is usually sufficient.

### End with exclusion summary:
Always include a table listing every MANY-side rollup that was excluded:

```markdown
## Excluded: MANY-Side Rollups

| Table | Field | Aggregates From |
|-------|-------|-----------------|
| Users | AssignedMailItemCount | MailItems |
```

## Airtable Formula Syntax Reminders

When writing formulas for OMNI prompts, use **Airtable formula syntax**, not Excel:

| Pattern | Airtable Syntax |
|---------|----------------|
| Field reference | `{FieldName}` (single braces) |
| Not equal | `!=` (not `<>`) |
| Blank check | `{Field} = BLANK()` (not `ISBLANK()`) |
| Date difference | `DATETIME_DIFF({Date1}, {Date2}, 'days')` |
| String concat | `CONCATENATE()` or `&` |
| No `=` prefix | Formulas do NOT start with `=` |
| TODAY | `TODAY()` works |
| Boolean logic | `AND()`, `OR()`, `NOT()`, `IF()` all work |
| SWITCH | `SWITCH()` works for same-table references |

## Example Reference

See the PostBericht project for a complete worked example:
- `effortless-rulebook/OMNI-PROMPT-PART1.md` — 12 tables, all raw fields + linked records
- `effortless-rulebook/OMNI-PROMPT-PART2.md` — 7 table sections with lookups/formulas, 5 tables with no Part 2 work, exclusion summary
