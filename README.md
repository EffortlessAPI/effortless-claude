# Effortless Claude

A [Claude Code](https://claude.ai/claude-code) skill suite that teaches Claude how to work with **Effortless Rulebook (ERB)** projects — schema-first, Airtable-sourced, multi-substrate code generation.

## What This Does

When installed as Claude Code skills, Claude will automatically activate the relevant knowledge whenever it detects an ERB project (presence of `ssotme.json`, `effortless-rulebook/`, or `effortless-rulebook.json`). The skills are modular — Claude only loads what's needed for the task at hand.

## Skills

| Skill | Description |
|-------|-------------|
| `rulebook-orchestrator` | Top-level ERB overview, mental model, and routing to other skills |
| `rulebook-query` | Querying `effortless-rulebook.json` — listing tables, extracting schema, finding relationships |
| `rulebook-schema` | JSON structure reference — field types, datatypes, formula syntax, `_meta` |
| `rulebook-conventions` | Naming rules, DAG structure, PK/FK patterns, no many-to-many |
| `rulebook-workflow` | Change workflow — Path A (Airtable-first) vs Path B (Rulebook-first), permission checkpoints |
| `rulebook-pipeline` | Build system — `ssotme.json`, transpilers, `effortless build`, multi-substrate architecture |
| `rulebook-sql` | Generated SQL — views vs tables, `00`-`05` files, `*b-customize-*` files, SQL patterns |
| `rulebook-airtable` | Airtable API — adding fields, creating tables, modifying schema, API limitations |
| `rulebook-diagnostics` | Diagnostic queries, DAG validation, legacy code migration |

## Installation

### Option A: Ask Claude to install it

In any Claude Code session, say:

```
Clone https://github.com/EffortlessAPI/effortless-claude and run install.sh
```

Claude will clone the repo, run the installer, and the skills will be available in all future sessions.

### Option B: One-liner

```bash
git clone https://github.com/EffortlessAPI/effortless-claude.git /tmp/effortless-claude && bash /tmp/effortless-claude/install.sh && rm -rf /tmp/effortless-claude
```

### Option C: Symlink (recommended for contributors)

If you've cloned this repo locally, symlink each skill into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills
for skill in skills/rulebook-*; do
  ln -sf "$(pwd)/$skill" ~/.claude/skills/$(basename "$skill")
done
```

### Option D: Clone and install

```bash
git clone https://github.com/EffortlessAPI/effortless-claude.git
cd effortless-claude
bash install.sh
```

## Updating

If you installed via `install.sh`, just re-run it to update:

```bash
cd /path/to/effortless-claude
git pull
bash install.sh
```

If you used the symlink approach, updates to the source repo are reflected automatically.

The installer will also clean up the old monolithic `effortless-rulebooks` skill if present.

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

## Project Structure

```
effortless-claude/
├── skills/
│   ├── rulebook-orchestrator/
│   │   └── SKILL.md
│   ├── rulebook-query/
│   │   └── SKILL.md
│   ├── rulebook-schema/
│   │   └── SKILL.md
│   ├── rulebook-conventions/
│   │   └── SKILL.md
│   ├── rulebook-workflow/
│   │   └── SKILL.md
│   ├── rulebook-pipeline/
│   │   └── SKILL.md
│   ├── rulebook-sql/
│   │   └── SKILL.md
│   ├── rulebook-airtable/
│   │   └── SKILL.md
│   └── rulebook-diagnostics/
│       └── SKILL.md
├── install.sh
├── README.md
└── SKILL.md              ← legacy monolithic file (kept for reference)
```

## Contributing

This skill suite is maintained by [EffortlessAPI](https://effortlessapi.com). To suggest improvements:

1. Open an issue on this repo
2. Or submit a PR with changes to the relevant `skills/rulebook-*/SKILL.md` file

Each skill file under `skills/` is the source of truth for that skill's behavior. The `install.sh` script copies them into `~/.claude/skills/`.

## License

Proprietary. Copyright EffortlessAPI. All rights reserved.
