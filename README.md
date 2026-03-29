# Effortless Claude

A [Claude Code](https://claude.ai/claude-code) skill that teaches Claude how to work with **Effortless Rulebook (ERB)** projects — schema-first, Airtable-sourced, multi-substrate code generation.

## What This Does

When installed as a Claude Code skill, Claude will automatically activate this knowledge whenever it detects an ERB project (presence of `ssotme.json`, `effortless-rulebook/`, or `effortless-rulebook.json`). It teaches Claude to:

- **Query the rulebook JSON first** instead of grep-ing through generated code — saving tokens and getting accurate answers
- **Extract schema without data** to minimize context window usage on large rulebooks
- **Understand the DAG structure** — tables, foreign keys, calculated fields, lookups, and aggregations
- **Follow ERB naming conventions** — PascalCase tables, `{Singular}Id` primary keys, singular FK names, plural reverse relationships, no many-to-many
- **Never edit generated files** (`00`-`05` SQL) — only use `*b-customize-*` files for project-specific logic
- **Always read from `vw_*` views**, never base tables — views contain all calculated/lookup fields
- **Use the Airtable API** for schema changes, then `effortless build` to regenerate
- **Understand the full build pipeline** — `ssotme.json` transpilers, `airtable-to-rulebook`, `rulebook-to-postgres`, and more
- **Generate conformant code** across PostgreSQL, Python, Go, Excel, C#, OWL/RDF, and other substrates

## Installation

### Option A: Ask Claude to install it

In any Claude Code session, say:

```
Clone https://github.com/EffortlessAPI/effortless-claude and run install.sh
```

Claude will clone the repo, run the installer, and the skill will be available in all future sessions.

### Option B: One-liner

```bash
git clone https://github.com/EffortlessAPI/effortless-claude.git /tmp/effortless-claude && bash /tmp/effortless-claude/install.sh && rm -rf /tmp/effortless-claude
```

### Option C: Symlink (recommended for contributors)

If you've cloned this repo locally, symlink it into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills
ln -sf /path/to/effortless-claude ~/.claude/skills/effortless-rulebooks
```

### Option D: Clone directly into skills

```bash
git clone https://github.com/EffortlessAPI/effortless-claude.git ~/.claude/skills/effortless-rulebooks
```

## Verification

After installation, start a Claude Code session in any ERB project directory (one containing `ssotme.json` or `effortless-rulebook/`). Claude should automatically:

1. Recognize it as an ERB project
2. Query `effortless-rulebook.json` before exploring code
3. Use views (`vw_*`) for read operations
4. Refuse to edit generated SQL files

You can test by asking Claude: "What tables are in this rulebook?" — it should parse the JSON directly rather than reading SQL files.

## What's an ERB Project?

An Effortless Rulebook project uses **Airtable as a single source of truth** for business schema and rules. The architecture flows like this:

```
Airtable Base (humans edit here)
    |
    |  airtable-to-rulebook
    v
effortless-rulebook.json (portable, substrate-agnostic IR)
    |          |          |          |
    v          v          v          v
PostgreSQL   Python      Go       Excel ...
(tables,     (classes,   (structs, (native
 functions,   calc        methods)  formulas)
 views)       methods)
```

The key insight: **the rulebook JSON is the invariant**. All generated code is disposable and regenerated from this single file. Schema changes go through Airtable, not through manual code edits.

### Key Files in an ERB Project

| File | Purpose |
|------|---------|
| `ssotme.json` | Project config — base ID, transpiler pipeline |
| `effortless-rulebook/effortless-rulebook.json` | The rulebook — schema + data in one JSON file |
| `postgres/00-bootstrap.sql` | Database init (generated) |
| `postgres/01-drop-and-create-tables.sql` | Table DDL (generated) |
| `postgres/02-create-functions.sql` | `calc_*` / `get_*` functions (generated) |
| `postgres/03-create-views.sql` | `vw_*` views (generated) |
| `postgres/04-create-policies.sql` | RLS policies (generated) |
| `postgres/05-insert-data.sql` | Seed data (generated) |
| `postgres/*b-customize-*.sql` | User customizations (preserved across builds) |

## Skill Contents

| File | Purpose |
|------|---------|
| `SKILL.md` | The skill definition — YAML frontmatter + full ERB reference. This is what Claude Code loads. |
| `CLAUDE.md` | Pointer file for Claude Code's secondary discovery mechanism. |
| `README.md` | This file — human-readable installation and usage guide. |

## Key Principles the Skill Enforces

1. **Rulebook-first querying** — Always parse `effortless-rulebook.json` before reading generated code. The schema is 10-20% of the file; extract it to save tokens.

2. **DAG integrity** — The rulebook is a Directed Acyclic Graph. Tables are nodes, FKs are edges. No cycles, no many-to-many. If you need M:N, use a junction table.

3. **Views for reads, tables for writes** — `vw_*` views contain all calculated, lookup, and aggregation fields. Base tables are only for INSERT/UPDATE/DELETE.

4. **Never edit generated files** — Files `00`-`05` in `postgres/` are overwritten on every build. Use `*b-customize-*` files for project-specific SQL.

5. **Airtable is the SSoT** — Schema changes go through the Airtable API (or UI for formula fields), then `effortless build` regenerates everything.

6. **No fallback to manual edits** — If the Airtable API can't do something (e.g., formula fields), Claude stops and asks the user rather than hacking generated files.

## Naming Conventions

The skill teaches Claude these ERB naming rules:

- **Tables**: PascalCase, plural (`Customers`, `WorkflowSteps`)
- **Primary Keys**: `{SingularTable}Id` (`CustomerId`, `RoleId`)
- **Foreign Keys**: Singular entity name, no "Id" suffix (`Order.Customer`, not `Order.CustomerId`)
- **Reverse FKs**: Plural (`Customer.Orders`)
- **Booleans**: `Is{Something}` (`IsActive`, `IsWinningBid`)
- **Aggregations**: `CountOf{Related}` (`CountOfOrders`)
- **Lookups**: `{FK}{Field}` (`AssignedRoleLabel`)
- **Every table**: Must have a `Name` field (human-readable compound key)
- **Every field**: Must have a `Description`

## Updates

To update the skill after pulling new changes:

```bash
cd ~/.claude/skills/effortless-rulebooks
git pull
```

If you used the symlink approach, updates to the source repo are reflected automatically.

## Contributing

This skill is maintained by [EffortlessAPI](https://effortlessapi.com). To suggest improvements:

1. Open an issue on this repo
2. Or submit a PR with changes to `SKILL.md`

The `SKILL.md` file is the single source of truth for the skill's behavior. Keep it focused on what Claude needs to know — not what humans need to read (that's what this README is for).

## License

Proprietary. Copyright EffortlessAPI. All rights reserved.
