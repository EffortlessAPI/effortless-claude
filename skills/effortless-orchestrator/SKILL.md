---
name: effortless-orchestrator
description: >
  Use when working with Effortless Rulebook (ERB) projects — Airtable-sourced
  schema-first business rules, `effortless.json` or the legacy `ssotme.json` build pipelines, effortless-rulebook.json
  ontologies, rulebook-to-postgres code generation, or any project containing an
  effortless-rulebook/ directory or effortless.json or ssotme.json file.
---

# Effortless Rulebook (ERB) — Orchestrator

This is the top-level skill for ERB projects. It provides the mental model and routes to specialized sub-skills.

## The ERB Mental Model

```
                    AIRTABLE SSoT <-- The formal editing surface for ontology. UI for agents both human and AI
                         |
                    airtable-to-rulebook <-- effortless tool
                         |
                         v
              effortless-rulebook.json  <-- PROJECTION OF THE SINGLE SOURCE OF TRUTH
              /    |    |    |    \
             /     |    |    |     \
            v      v    v    v      v
        Postgres  Go  Python XLSX  OWL ...  (execution substrates)
            |
        views.vw_*  <-- ALWAYS READ FROM THESE
        tables.*    <-- ALWAYS WRITE TO THESE
```

## The Leopold Loop

The "Leopold loop" is the user's name for the iterative ERB development cycle. It is the core *workflow* that makes ERB feel effortless. When the user says "Leopold loop," they mean this:

```
   1. CHANGE THE RULE (once, in Airtable — the SSoT)
            |
            v
   2. effortless build  (one command)
            |
            v
   3. EVERY DOWNSTREAM LAYER UPDATES AUTOMATICALLY
      - effortless-rulebook.json (canonical model)
      - postgres/01-05*.sql (tables, functions, views, seed data)
      - ODXML schema
      - C#/Go/Python/etc. base classes, ORM context, sync services
            |
            v
   4. APP CODE (server, client) JUST CONSUMES THE GENERATED VIEWS
      - reads from vw_* views
      - treats calculated fields (e.g. is_stopped) as opaque
      - NEVER reimplements business logic that lives in the rulebook
            |
            v
   5. NEXT TURN OF THE LOOP — repeat from step 1
```

### Why it's effortless

A single rule change propagates through every layer with **zero hand-written migrations, DTOs, ORM updates, API serializers, or client types**. The business logic ("a customer is stopped when CurrentColor is Green") lives in **exactly one place** — the Airtable formula → generated SQL function → exposed in the view as `is_stopped`. The app just reads `is_stopped`. If the rule flips ("now Red means stopped"), the loop runs once and *no app code changes*.

Compare to "naked Claude" (hand-coding every layer): the same change requires editing a migration, seed data, DTO, ORM model, API serializer, client type, and client logic — and probably missing one and shipping a bug.

### What "do a turn of the Leopold loop" implies

When the user says things like *"rebuild the rulebook"*, *"update the app to match the current rules"*, or *"do a turn of the loop"*, they expect:

1. **Run `effortless build`** to pull the current Airtable state through to all generated files.
2. **Verify the generated artifacts** (check views, functions, base classes) reflect the new rule.
3. **Update the app code only where it touches the schema surface** — column names, new fields, removed tables. **Never reimplement** rule logic in the app; consume the calculated fields from the view.
4. **Restart the app** if the user's project convention requires it (e.g. `./start.sh`).

### Leopold loop anti-patterns (DO NOT DO THESE)

- **Reimplementing rule logic in the client**: e.g. computing `isStopped = customer.color === 'Red'` in JS instead of using `customer.is_stopped` from the view. This duplicates the rule and breaks the loop — when the rule changes in Airtable, the client silently goes wrong.
- **Hand-editing generated files** (`postgres/01-05*.sql`, `dotnet/.../BaseClasses/*.cs`): they get blown away on the next build.
- **Adding columns/fields directly in SQL or C#**: changes must originate in Airtable so they survive `effortless build`.
- **Caching the rulebook output and forgetting to rebuild**: always rebuild before reasoning about the current state.

## Critical Guardrails

1. **Query the rulebook FIRST, generated code SECOND** — The JSON has everything.
   **Actuall QUERY** - like the root nodes will tend to be entity names with a "schema" and "data" sub-properties.  The schema has the fields/lookups/rollups/formulas (excel dialect).  
   **Grep last** You don't need to grep for a sense of the system.  
   **QUERY for TABLES first - then query for the fields from JUST those tables, rather than ever reading the full file.  The full file (with data) could be MB's.  QUERY IT!
2. **NEVER edit generated files** — Files `00`-`05` in `postgres/` are overwritten on every build.
   **ONLY** update `00b`-`05b` files AFTER the original airtable has been updated first.
   **ONLY if OMNI can't fix the tool's default 02 functions (for example) - THEN we can override it with a fallback 02b function.  But ONLY after exausting the actual SSoT (airtable) first.
3. **Always read from `vw_*` views**, never base tables.
   **Always WRITE to tables directly**
4. **Always ask permission** before modifying the json rulebook directly.
5. **Usually `effortless build` is the final step, except in the rare cases where we have modified the json rulebook directly, and are explicitly trying to move that dat FROM The rulebook INTO airtable.  IN that case, an effortless build would overwrite the currently HEAD, json.

## When You Need More Detail

This orchestrator provides the big picture. For specifics, the following companion skills are available — Claude Code will load them automatically based on what you're doing:

| Skill | When to Use |
|-------|-------------|
| `effortless-query` | Querying the rulebook JSON — listing tables, extracting schema, finding relationships, inspecting formulas |
| `effortless-schema` | Understanding the JSON structure — field types, datatypes, formula syntax, `_meta` section |
| `effortless-conventions` | Naming rules, DAG structure, PK/FK patterns, no many-to-many |
| `effortless-workflow` | Making changes — Path A (Airtable-first) vs Path B (Rulebook-first), permission checkpoints |
| `effortless-pipeline` | Build system — ``effortless.json` or the legacy `ssotme.json``, transpilers, `effortless build`, installation |
| `effortless-sql` | Generated SQL — views vs tables, `00`-`05` files, `*b-customize-*` files, SQL patterns |
| `effortless-airtable` | Airtable API — adding scalar fields, creating/modifying records, field renaming — anything the REST API supports |
| `effortless-airtable-omni` | Non-scalar schema changes via Playwright + OMNI — formula fields, lookup fields, rollup fields, and new table creation (requires the Name formula). Drives a headed Chrome browser automatically. |
| `effortless-diagnostics` | Diagnostic queries, DAG validation, legacy code migration |

## Schema Change Decision Tree

When making Airtable schema changes, follow this decision tree:

```
Is it a scalar field (text, number, select, checkbox, date, FK link, etc.)?
  YES → Use the Airtable REST API directly (effortless-airtable skill)
  NO  → Is it a formula, lookup, or rollup?
    YES → Use OMNI via Playwright (effortless-airtable-omni skill)
          Run: node ~/.claude/skills/effortless-airtable-omni/omni-send.mjs <baseId> '<prompt>'
    
Is it a new table?
  YES → Use OMNI — every table needs a Name formula: SUBSTITUTE(LOWER({Label}), " ", "-")
        Create scalar fields + FKs via API first, then add Name formula via OMNI

Is it a CRUD operation (create/read/update/delete records)?
  YES → Always use the Airtable REST API directly
```

**Never generate OMNI prompts for the user to paste manually.** Instead, drive OMNI directly using the bundled `omni-send.mjs` Playwright script. This avoids wasting the user's time as a copy-paste middleman.

## Project CLAUDE.md Bootstrap

When you first encounter an ERB project that lacks a `CLAUDE.md`, **create one** in the project root. This ensures every future conversation (any user, any session) automatically knows the project's nature and key behaviors without the user having to explain.

Write a `CLAUDE.md` containing at minimum:

```markdown
# Project: {ProjectName}

This is an Effortless Rulebook (ERB) project.

## Airtable Base
- Base ID: {baseId from `effortless.json` or the legacy `ssotme.json`}
- Use the Airtable REST API for scalar field changes and all CRUD operations.
- Use OMNI (via Playwright) for formula, lookup, and rollup fields:
  `node ~/.claude/skills/effortless-airtable-omni/omni-send.mjs {baseId} '<prompt>'`
- First-time OMNI use requires login: `node ~/.claude/skills/effortless-airtable-omni/omni-send.mjs {baseId} --login`

## Schema Rules
- Query effortless-rulebook.json FIRST, generated code SECOND.
- NEVER edit generated files (00-05 in postgres/).
- Always read from vw_* views, never base tables.
- Ask permission before modifying the rulebook, Airtable, or running effortless build.

## ERB Skills
All conventions live in the effortless-* skills (not in memory files):
effortless-orchestrator, effortless-conventions, effortless-schema,
effortless-query, effortless-sql, effortless-pipeline, effortless-workflow,
effortless-airtable, effortless-airtable-omni, effortless-diagnostics.
```

Fill in `{ProjectName}` and `{baseId}` from the project's `ssotme.json` or `effortless.json`. Add any project-specific notes (e.g., which tables are most active, known quirks, deployment targets).

This ensures the skills ARE the single source of truth for project behavior, not scattered memory entries.

## Quick Reference

- **Tables**: PascalCase, plural (`Customers`, `WorkflowSteps`)
- **`Name` is ALWAYS the first field** — a formula compound key, the logical primary key
- **No `{Entity}Id` fields** — surrogate keys are managed by the substrate off-screen
- **Foreign Keys**: Singular entity name, no "Id" suffix (`Order.Customer`)
- **Reverse FKs**: Plural (`Customer.Orders`)
- **It's a DAG**: 1-to-many only, no cycles, no many-to-many
- **Every field** has a `Description`
- **Schema is small, data is big** — extract schema to save tokens, and query for root entities (other than the name/description and meta data - these are all tables).  They can be queried as {"Widgets":{"schema":[{fields}, {}...], "data":[{data},{...}, ...], other meta-data...}.  You can use json query to not grep or ever have to read/process the whole thing.
- **Two change paths**: Airtable-first (preferred) or Rulebook-first with reverse sync
- **`effortless build`** from root runs enabled transpilers; `-id` includes disabled ones
- **`effortless.json` or the legacy `ssotme.json`** defines the build pipeline