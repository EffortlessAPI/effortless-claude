---
name: effortless-pipeline
description: >
  Use when working with the ERB build pipeline — ssotme.json configuration,
  transpiler catalog, effortless build commands, the -id flag, transpiler
  installation, or understanding how the build flows from Airtable through
  to generated code.
---

# The ssotme.json Build Pipeline

## Structure

```json
{
  "Name": "Project Name",
  "Description": "Optional description",
  "ProjectSettings": [
    { "Name": "baseId", "Value": "appXXXXXXXXXXXX" },
    { "Name": "project-name", "Value": "my-project" },
    { "Name": "_apikey_", "Value": "patXXX...XXX" }
  ],
  "ProjectTranspilers": [
    {
      "Name": "airtabletorulebook",
      "RelativePath": "/effortless-rulebook",
      "CommandLine": "airtable-to-rulebook -o effortless-rulebook.json -account airtable",
      "IsDisabled": false
    }
  ]
}
```

## Key Transpilers

| Transpiler | Direction | What It Does |
|------------|-----------|-------------|
| `airtable-to-rulebook` | Airtable -> JSON | Pulls schema + data from Airtable base into `effortless-rulebook.json` |
| `rulebook-to-postgres` | JSON -> SQL | Generates all `00`-`05` SQL files from the rulebook |
| `rulebook-to-airtable` | JSON -> Airtable | Pushes rulebook back to an Airtable base (reverse sync) |
| `init-db` | SQL -> Postgres | Runs `init-db.sh` to bootstrap the database |
| `json-hbars-transform` | JSON + Handlebars -> Docs | Generates documentation (README.SCHEMA.md etc.) |
| `rulebook-to-xlsx` | JSON -> Excel | Generates spreadsheet export |
| `airtable-to-odxml` | Airtable -> ODXML | Generates XML metadata for .NET |
| `odxml-to-csharp-pocos` | ODXML -> C# | Generates Entity Framework classes |

## Finding the Base ID and API Key

1. **Base ID**: Check `ssotme.json` -> `ProjectSettings` -> `baseId`. Also check transpiler `-p baseId=XXX` flags.
2. **API Key**: Priority order:
   - `AIRTABLE_API_KEY` environment variable
   - `~/.ssotme/ssotme.key` -> `APIKeys.airtable`
   - `ssotme.json` -> `ProjectSettings` -> `_apikey_`

## Running a Build

```bash
effortless build       # Runs all enabled transpilers in order (from project root)
effortless build -id   # Runs ALL transpilers, INCLUDING disabled ones
```

- **From project root**: `effortless build` reads `ssotme.json` and runs each enabled transpiler in its `RelativePath` directory. Disabled transpilers (`"IsDisabled": true`) are skipped.
- **From a subfolder**: `effortless build` can also be run from any subfolder that contains its own `ssotme.json` or is referenced as a `RelativePath`. This is how you run a specific transpiler in isolation.
- **The `-id` flag** (include disabled): Forces execution of all transpilers, even those marked `"IsDisabled": true`. This is essential for the reverse-sync workflow (Path B), where `rulebook-to-airtable` is intentionally disabled during normal builds but needs to run when pushing local changes back to Airtable.

**Example: Pushing rulebook changes back to Airtable:**
```bash
cd effortless-rulebook/push-to-airtable/
effortless build -id    # Runs rulebook-to-airtable (normally disabled)
```

## Installing Effortless Transpilers

Transpilers are installed using the `effortless` CLI with the `-install` flag:

```bash
effortless -install <transpiler-name> -p key=value -i input-file -o output-file [other flags]
```

Examples:
```bash
effortless -install airtable-to-rulebook -o effortless-rulebook.json -account airtable
effortless -install rulebook-to-postgres -i ../effortless-rulebook/effortless-rulebook.json
effortless -install rulebook-to-airtable -i ../effortless-rulebook.json -account airtable -w 120000
```

The installed transpiler configuration is stored in `ssotme.json` under `ProjectTranspilers`. The `CommandLine` field records the flags used at install time.

## Pipeline Flow

```
Airtable Base (SSoT)
    |  airtable-to-rulebook
    v
effortless-rulebook.json (Intermediate Representation)
    |                    |                    |
    |  rulebook-to-      |  rulebook-to-      |  json-hbars-
    |  postgres          |  xlsx              |  transform
    v                    v                    v
postgres/            output.xlsx          README.SCHEMA.md
(00-05 SQL files)
    |  init-db
    v
Running PostgreSQL Database
```

## Multi-Substrate Architecture

The rulebook is **substrate-agnostic**. The same JSON generates equivalent implementations across:

| Substrate | Generated From | Role |
|-----------|---------------|------|
| **PostgreSQL** | `rulebook-to-postgres` | Primary reference (deterministic, full formula coverage) |
| **Python** | `inject-into-python.py` | Dataclasses + calc methods |
| **Go** | `inject-into-golang.py` | Structs + business logic |
| **Excel/XLSX** | `rulebook-to-xlsx` | Native spreadsheet formulas |
| **C# / .NET** | `odxml-to-csharp-pocos` | Entity Framework classes |
| **OWL/RDF** | `inject-into-owl.py` | Semantic web ontology |
| **YAML** | `inject-into-yaml.py` | LLM-friendly serialization |
| **UML** | `inject-into-uml.py` | PlantUML entity-relationship diagrams |

**Key principle:** No execution substrate defines truth; all substrates merely project and compute from the rulebook.

### Conformance Testing
- **Blank test**: Load data with calculated fields set to NULL
- **Execute**: Each substrate computes the calculated fields
- **Grade**: Compare output to answer-key. All deterministic substrates must match exactly.
