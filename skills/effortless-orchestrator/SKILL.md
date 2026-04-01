---
name: effortless-orchestrator
description: >
  Use when working with Effortless Rulebook (ERB) projects — Airtable-sourced
  schema-first business rules, ssotme.json build pipelines, effortless-rulebook.json
  ontologies, rulebook-to-postgres code generation, or any project containing an
  effortless-rulebook/ directory or ssotme.json file.
---

# Effortless Rulebook (ERB) — Orchestrator

This is the top-level skill for ERB projects. It provides the mental model and routes to specialized sub-skills.

## The ERB Mental Model

```
                    AIRTABLE (UI for humans)
                         |
                    airtable-to-rulebook
                         |
                         v
              effortless-rulebook.json  <-- THE SINGLE SOURCE OF TRUTH
              /    |    |    |    \
             /     |    |    |     \
            v      v    v    v      v
        Postgres  Go  Python XLSX  OWL ...  (execution substrates)
            |
        vw_* views  <-- ALWAYS READ FROM THESE
```

## Critical Guardrails

1. **Query the rulebook FIRST, generated code SECOND** — The JSON has everything.
2. **NEVER edit generated files** — Files `00`-`05` in `postgres/` are overwritten on every build.
3. **Always read from `vw_*` views**, never base tables.
4. **Always ask permission** before modifying the rulebook, Airtable, or running `effortless build`.

## When You Need More Detail

This orchestrator provides the big picture. For specifics, the following companion skills are available — Claude Code will load them automatically based on what you're doing:

| Skill | When to Use |
|-------|-------------|
| `effortless-query` | Querying the rulebook JSON — listing tables, extracting schema, finding relationships, inspecting formulas |
| `effortless-schema` | Understanding the JSON structure — field types, datatypes, formula syntax, `_meta` section |
| `effortless-conventions` | Naming rules, DAG structure, PK/FK patterns, no many-to-many |
| `effortless-workflow` | Making changes — Path A (Airtable-first) vs Path B (Rulebook-first), permission checkpoints |
| `effortless-pipeline` | Build system — `ssotme.json`, transpilers, `effortless build`, installation |
| `effortless-sql` | Generated SQL — views vs tables, `00`-`05` files, `*b-customize-*` files, SQL patterns |
| `effortless-airtable` | Airtable API — adding fields, creating tables, modifying schema, API limitations |
| `effortless-omni-prompt` | Generating OMNI prompts for Airtable — the two-part split pattern (Part 1: raw fields + linked records, Part 2: lookups/formulas per table) |
| `effortless-diagnostics` | Diagnostic queries, DAG validation, legacy code migration |

## Quick Reference

- **Tables**: PascalCase, plural (`Customers`, `WorkflowSteps`)
- **Primary Keys**: `{SingularTable}Id` (`CustomerId`)
- **Foreign Keys**: Singular entity name, no "Id" suffix (`Order.Customer`)
- **Reverse FKs**: Plural (`Customer.Orders`)
- **It's a DAG**: 1-to-many only, no cycles, no many-to-many
- **Every table** has a `Name` field; **every field** has a `Description`
- **Schema is small, data is big** — extract schema to save tokens
- **Two change paths**: Airtable-first (preferred) or Rulebook-first with reverse sync
- **`effortless build`** from root runs enabled transpilers; `-id` includes disabled ones
- **`ssotme.json`** defines the build pipeline
