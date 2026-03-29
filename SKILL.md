---
name: effortless-rulebooks
description: >
  Use when working with Effortless Rulebook (ERB) projects — Airtable-sourced
  schema-first business rules, ssotme.json build pipelines, effortless-rulebook.json
  ontologies, rulebook-to-postgres code generation, or any project containing an
  effortless-rulebook/ directory or ssotme.json file.
---

# Effortless Rulebook (ERB) Architecture - Complete Reference

## CRITICAL: Query the Rulebook First

**Before reading code, SQL, or any generated files — ALWAYS query `effortless-rulebook.json` first.**

The rulebook is the single source of truth. It contains everything: schema, relationships, formulas, descriptions, and data. Do NOT grep through Go/Python/SQL files to understand the domain. Instead:

1. **Find the rulebook**: Look for `effortless-rulebook/effortless-rulebook.json` or check `ssotme.json` transpiler inputs for the path
2. **Extract schema only** (strip data to save tokens):
   ```bash
   cat effortless-rulebook/effortless-rulebook.json | \
     python3 -c "import sys,json; d=json.load(sys.stdin); [d[k].__delitem__('data') for k in d if isinstance(d.get(k),dict) and 'data' in d.get(k,{})]; print(json.dumps(d,indent=2))"
   ```
3. **Query specific aspects** rather than loading everything:
   ```bash
   # List all tables
   cat effortless-rulebook.json | python3 -c "
   import sys,json; d=json.load(sys.stdin)
   skip={'\$schema','Name','Description','_meta'}
   for k in d:
     if k not in skip and isinstance(d[k],dict) and 'schema' in d[k]:
       fields=d[k]['schema']
       print(f'  {k}: {len(fields)} fields, {len(d[k].get(\"data\",[]))} rows')
   "

   # Show schema for one table
   cat effortless-rulebook.json | python3 -c "
   import sys,json; d=json.load(sys.stdin)
   for f in d['TableName']['schema']:
     print(f'  {f[\"name\"]:30s} {f[\"type\"]:15s} {f[\"datatype\"]:10s} {f.get(\"Description\",\"\")[:60]}')
   "

   # Find all FK relationships across all tables
   cat effortless-rulebook.json | python3 -c "
   import sys,json; d=json.load(sys.stdin)
   for k,v in d.items():
     if isinstance(v,dict) and 'schema' in v:
       for f in v['schema']:
         if f['type']=='relationship':
           print(f'  {k}.{f[\"name\"]} -> {f[\"RelatedTo\"]}')
   "

   # Find all calculated fields and their formulas
   cat effortless-rulebook.json | python3 -c "
   import sys,json; d=json.load(sys.stdin)
   for k,v in d.items():
     if isinstance(v,dict) and 'schema' in v:
       for f in v['schema']:
         if f['type'] in ('calculated','aggregation','lookup'):
           print(f'  {k}.{f[\"name\"]} ({f[\"type\"]}): {f.get(\"formula\",\"\")}')
   "
   ```

### Why This Matters

- The rulebook is typically 500-3000 lines, but the **schema alone is 10-20% of that**
- Loading just schema saves enormous token budget
- Every answer about "what fields exist" or "how are these related" is in the rulebook
- You do NOT need to read generated SQL, Go, or Python to understand the domain

---

## Rulebook JSON Schema Reference

### Top-Level Structure

```json
{
  "$schema": "https://example.com/cmcc-schema/v1",
  "Name": "Project Display Name",
  "Description": "Rulebook generated from Airtable base 'Base Name'.",
  "TableName": {
    "Description": "Table: TableName",
    "schema": [ /* field definitions */ ],
    "data": [ /* row records */ ]
  },
  "AnotherTable": { ... },
  "_meta": { /* conversion metadata */ }
}
```

**Top-level keys:**
| Key | Purpose |
|-----|---------|
| `$schema` | Schema version URI (always `https://example.com/cmcc-schema/v1`) |
| `Name` | Human-readable project/base name |
| `Description` | Auto-generated description |
| `{TableName}` | One key per entity table (PascalCase) |
| `_meta` | Conversion metadata, type mappings, tool version |

### Table Object

Each table key contains:
```json
{
  "Description": "Table: TableName",
  "schema": [ /* array of field definitions */ ],
  "data": [ /* array of row objects */ ]
}
```

### Field Schema Object

Every field in the `schema` array follows this structure:

```json
{
  "name": "FieldName",
  "datatype": "string",
  "type": "raw",
  "nullable": true,
  "Description": "What this field represents and how it is used.",
  "formula": "=CONCAT({{FirstName}}, \" \", {{LastName}})",
  "RelatedTo": "OtherTable"
}
```

| Property | Required | Values | Notes |
|----------|----------|--------|-------|
| `name` | Yes | PascalCase string | Field identifier |
| `datatype` | Yes | `string`, `integer`, `number`, `boolean`, `datetime` | Target data type |
| `type` | Yes | `raw`, `calculated`, `lookup`, `relationship`, `aggregation` | Field derivation type |
| `nullable` | Yes | `true` / `false` | Whether NULL is allowed |
| `Description` | Should exist | Free text | Purpose, usage, ontology mapping |
| `formula` | If calculated/lookup/aggregation | Excel-dialect formula | How the value is derived |
| `RelatedTo` | If relationship | Table name (PascalCase) | FK target entity |

### Field Types

| Type | Meaning | Stored In | Example |
|------|---------|-----------|---------|
| `raw` | Direct user input | Base table | `FirstName`, `EmailAddress`, `DueDate` |
| `calculated` | Derived from formula on same-row fields | View (via function) | `FullName = {{LastName}} & ", " & {{FirstName}}` |
| `lookup` | Value pulled from a related table via FK | View (via function) | `=INDEX(Roles!{{Label}}, MATCH({{AssignedRole}}, Roles!{{RoleId}}, 0))` |
| `relationship` | Foreign key reference to another table | Base table (as text ID) | `Customer` pointing to `Customers` table |
| `aggregation` | Rollup/count/sum over related rows | View (via function) | `=COUNTIFS(Orders!{{Customer}}, Customers!{{CustomerId}})` |

### Data Types

| Datatype | Postgres | Go | Python | Airtable Source |
|----------|----------|-----|--------|-----------------|
| `string` | `TEXT` | `string` | `str` | singleLineText, multilineText, email, url, phoneNumber, singleSelect |
| `integer` | `INTEGER` | `int` | `int` | number (when whole) |
| `number` | `NUMERIC` | `float64` | `float` | number (when decimal) |
| `boolean` | `BOOLEAN` | `bool` | `bool` | checkbox |
| `datetime` | `TIMESTAMPTZ` | `time.Time` | `datetime` | date, dateTime |

### Formula Syntax

Formulas use Excel dialect with `={{FieldName}}` for field references:

```
# String concatenation
={{LastName}} & ", " & {{FirstName}}

# Conditional
=IF({{Status}} = "Active", TRUE(), FALSE())

# Boolean compound
=AND({{HasSyntax}}, {{IsParsed}}, NOT({{CanBeHeld}}))

# Lookup (cross-table)
=INDEX(Roles!{{Label}}, MATCH({{AssignedRole}}, Roles!{{RoleId}}, 0))

# Aggregation
=COUNTIFS(WorkflowSteps!{{IsStepOf}}, Workflows!{{WorkflowId}})
=SUMIFS(Orders!{{Amount}}, Orders!{{Customer}}, Customers!{{CustomerId}})

# String manipulation
=SUBSTITUTE(LOWER({{CompanyName}}), " ", "-")
```

**Supported functions:** IF, AND, OR, NOT, TRUE, FALSE, CONCAT, SUBSTITUTE, LOWER, UPPER, LEFT, RIGHT, MID, LEN, TRIM, FIND, SEARCH, TEXT, VALUE, SUM, COUNT, COUNTIFS, SUMIFS, AVERAGEIFS, MIN, MAX, INDEX, MATCH, POWER, LOG, LOG10, ABS, ROUND, COALESCE/IFERROR.

### The _meta Section

```json
"_meta": {
  "_CMCC_Summary": "Airtable export with schema-first type mapping...",
  "_conversion_metadata": {
    "source_base_id": "appXXXXXXXXXXXX",
    "table_count": 5,
    "tool_version": "2.0.0",
    "field_type_mapping": "checkbox->boolean, number->number/integer, multipleRecordLinks->relationship...",
    "export_mode": "schema_first_type_mapping",
    "type_inference": {
      "priority": "airtable_metadata (NO COERCION) -> formula_analysis -> data_analysis (fallback only)",
      "error_value_handling": "#NUM!, #ERROR!, #N/A, #REF!, #DIV/0!, #VALUE!, #NAME? are treated as NULL"
    }
  }
}
```

---

## Naming & Design Conventions

### Table Names
- **PascalCase**, no spaces, no symbols, no underscores
- Plural for collections: `Customers`, `WorkflowSteps`, `TypesOfAgents`
- Example: `ClientProgramSessions`, `DocumentCategories`, `ApprovalGates`

### Primary Keys
- Named `{SingularTableName}Id` — e.g., `CustomerId`, `WorkflowStepId`, `RoleId`
- Always `datatype: "string"`, `type: "raw"`, `nullable: false`
- Values are human-readable slugs: `"production-deployment-workflow"`, `"client-bob"`, `"cust0001"`

### The Name Field
- **Every table MUST have a `Name` field** (or equivalent human-readable compound key)
- This is the display label for each row — the human-readable identity
- In Airtable, this is the primary field (first column) that labels each record
- It can be `raw` (user-entered) or `calculated` (derived from other fields)
- Example: `Name = "client-" & SUBSTITUTE(LOWER({{CompanyName}}), " ", "-")`

### Every Table and Field Must Have a Description
- Descriptions form the semantic backbone of the DAG
- They explain purpose, usage context, and ontology mappings
- Example: `"Human-readable name for the workflow. Maps to dct:title per Dublin Core."`

### Foreign Key Conventions

**The FK field uses the SINGULAR entity name, NO "Id" suffix:**

```
Order.Customer     (FK to Customers table)    -- NOT Order.CustomerId
Employee.Role      (FK to Roles table)        -- NOT Employee.RoleId
Artifact.DerivedFrom (FK to Artifacts table)  -- NOT Artifact.DerivedFromId
```

**The reverse relationship uses the PLURAL name:**

```
Customer.Orders    (relationship, RelatedTo: "Orders")
Role.Employees     (relationship, RelatedTo: "Employees")
Workflow.WorkflowSteps (relationship, RelatedTo: "WorkflowSteps")
```

**Always 1-to-many. The singular side is the parent (1), the plural side is the children (many).**

### NO MANY-TO-MANY RELATIONSHIPS. EVER.

The rulebook is a **Directed Acyclic Graph (DAG)**. Many-to-many breaks the acyclic requirement.

If you think you need many-to-many, introduce a **junction table**:
```
# WRONG: Students <-> Courses (many-to-many)

# RIGHT: Students -> Enrollments <- Courses (two 1-to-many via junction)
Students.Enrollments   (1-to-many)
Courses.Enrollments    (1-to-many)
Enrollment.Student     (FK to Students)
Enrollment.Course      (FK to Courses)
```

### Calculated Field Naming Patterns

| Pattern | Meaning | Example |
|---------|---------|---------|
| `Is{Something}` | Boolean flag | `IsRedHeaded`, `IsWinningBid`, `IsHighQualityFit` |
| `CountOf{Related}` | Aggregation count | `CountOfWorkflowSteps`, `CountOfOrders` |
| `{FK}{FieldName}` | Lookup field | `AssignedRoleLabel`, `IsStepOfTitle`, `CustomerName` |
| `{Noun}Amount` | Monetary/numeric total | `BidAmount`, `TotalSales` |
| `{Noun}Status` | Status lookup | `RfpStatus`, `VendorStatus` |

---

## The DAG: Directed Acyclic Graph

The rulebook IS a DAG. Understanding this is essential.

### Table-Level DAG
- **Tables are nodes**, FK relationships are directed edges
- Edges point from child to parent: `Order -> Customer`, `WorkflowStep -> Workflow`
- No cycles allowed. If A references B, B cannot reference A (directly or transitively)
- Lookup/aggregation fields traverse these edges to pull or roll up data

### Field-Level DAG (within a table)
- **Level 0**: Raw fields (no dependencies)
- **Level 1**: Calculated fields that depend only on Level 0 raw fields
- **Level 2+**: Calculated fields that depend on other calculated fields
- Formula parsing must respect this ordering — compute Level 0 first, then Level 1, etc.

### Visualizing the DAG
```
Departments
    |
    v
Roles ---------> Agents
    |
    v
WorkflowSteps --> Workflows
    |
    v
Artifacts ------> Datasets
```

Arrows point from child (many-side) to parent (one-side). Data flows UPWARD through lookups and aggregations.

---

## The ssotme.json Build Pipeline

### Structure

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

### Key Transpilers

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

### Finding the Base ID and API Key

1. **Base ID**: Check `ssotme.json` -> `ProjectSettings` -> `baseId`. Also check transpiler `-p baseId=XXX` flags.
2. **API Key**: Priority order:
   - `AIRTABLE_API_KEY` environment variable
   - `~/.ssotme/ssotme.key` -> `APIKeys.airtable`
   - `ssotme.json` -> `ProjectSettings` -> `_apikey_`

### Running a Build

```bash
effortless build    # Runs all enabled transpilers in order
```

Each transpiler runs in its `RelativePath` directory. Disabled transpilers (`"IsDisabled": true`) are skipped.

### Pipeline Flow

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

---

## CRITICAL: Always Read From Views, Never Base Tables

**NEVER SELECT from base tables. ALWAYS use `vw_*` views for ALL read operations.**

```sql
-- WRONG: Reading from base table
SELECT * FROM customers WHERE hair_color = 'red';

-- RIGHT: Reading from view
SELECT * FROM vw_customers WHERE is_red_headed = true;
```

### Before Writing ANY Query or Filter Logic:

1. **Check the view first** - Run `\d vw_tablename` or read `03-create-views.sql` to see ALL available fields
2. **Look for existing calculated fields** - The view likely already has `is_*`, `*_count`, `*_status` fields that answer your question
3. **Use calculated fields, don't recompute** - If `is_red_headed` exists, use it. Do NOT write `LOWER(hair_color) = 'red'`

### Why This Matters:

- Business logic belongs in Airtable formulas, not in ad-hoc queries
- Views contain pre-calculated fields that encapsulate business rules
- Computing things yourself (e.g., `LOWER(field) = 'value'`) duplicates logic and risks inconsistency
- The whole point of ERB is that the view already did the work for you

### The Rule:

| Operation | Use |
|-----------|-----|
| SELECT / READ | `vw_*` views ONLY |
| INSERT | Base table |
| UPDATE | Base table |
| DELETE | Base table |

---

## CRITICAL: Never Modify Generated Files

**NEVER directly edit generated SQL files.** The postgres/ folder contains:

### Generated Files (NEVER EDIT):
- `00-bootstrap.sql` - Database initialization
- `01-drop-and-create-tables.sql` - DDL for all tables (raw fields only)
- `02-create-functions.sql` - `calc_*()` and `get_*()` PL/pgSQL functions (1:1 with calculated/lookup/aggregation fields)
- `03-create-views.sql` - `vw_*` views combining raw tables + calculated fields via function calls
- `04-create-policies.sql` - Row-level security (RLS) policies
- `05-insert-data.sql` - INSERT statements from rulebook data

These files are regenerated by `effortless build` and ANY manual changes will be lost.

### Customization Files (Edit WITH PERMISSION):
- `01b-customize-schema.sql` - runs after 01 (extra tables, ALTER TABLE, indexes)
- `02b-customize-functions.sql` - runs after 02 (custom functions)
- `03b-customize-views.sql` - runs after 03 (custom views)
- `04b-customize-policies.sql` - runs after 04 (custom RLS rules)
- `05b-customize-data.sql` - runs after 05 (custom seed data, migrations)

These `*b-customize-*` files are preserved across builds. Use them for project-specific customizations that can't be expressed in Airtable.

### ERBCustomizations Table Pattern

Some rulebooks store customization SQL directly in an `ERBCustomizations` table within the rulebook itself:

```json
"ERBCustomizations": {
  "schema": [
    { "name": "ERBCustomizationId", "datatype": "string", "type": "raw" },
    { "name": "Name", "datatype": "string", "type": "raw" },
    { "name": "CustomizationType", "datatype": "string", "type": "raw" },
    { "name": "SQLCode", "datatype": "string", "type": "raw" },
    { "name": "SQLTarget", "datatype": "string", "type": "raw" }
  ]
}
```

`CustomizationType` values: `Schema`, `Functions`, `Views`, `RLS`, `Data` — corresponding to each `*b-customize-*` file.

### NO FALLBACK ALLOWED

If you cannot make a change in Airtable (e.g., API limitations for formula fields):
1. **STOP** - Do not "fall back" to manual edits
2. **ASK THE USER** - Explain what you cannot do via API
3. **Let the user decide** - They may want to make the change in Airtable UI, or use a customization file

---

## Generated SQL Patterns

### Table Creation (01)
- Tables contain ONLY raw fields (no calculated/lookup/aggregation columns)
- Primary key is always `{table_name}_id TEXT PRIMARY KEY`
- Column names are snake_case versions of PascalCase field names
- Each column has a `COMMENT` with the field's Description

```sql
CREATE TABLE workflow_steps (
  workflow_step_id TEXT PRIMARY KEY,
  label TEXT,
  sequence_position INTEGER,
  requires_human_approval BOOLEAN,
  is_step_of TEXT,              -- FK to workflows (no _id suffix in schema)
  assigned_role TEXT             -- FK to roles
);
COMMENT ON COLUMN workflow_steps.label IS 'Human-readable name...';
```

### Functions (02)
- One `get_{table}_{field}(p_{pk} TEXT)` function per raw field (single-row retrieval)
- One `calc_{table}_{field}(p_{pk} TEXT)` function per calculated/lookup/aggregation field
- All functions are `LANGUAGE plpgsql STABLE SECURITY DEFINER`

```sql
-- Lookup: resolves FK to get a field from related table
CREATE OR REPLACE FUNCTION calc_workflow_steps_assigned_role_label(p_workflow_step_id TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT label FROM roles
          WHERE role_id = (SELECT assigned_role FROM workflow_steps
                           WHERE workflow_step_id = p_workflow_step_id));
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Aggregation: counts related rows
CREATE OR REPLACE FUNCTION calc_workflows_count_of_workflow_steps(p_workflow_id TEXT)
RETURNS INTEGER AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM workflow_steps WHERE is_step_of = p_workflow_id)::integer;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

### Views (03)
- One `vw_{table_name}` view per table
- SELECTs all raw fields from base table + all calculated fields via function calls
- All views use `WITH (security_invoker = ON)`

```sql
CREATE OR REPLACE VIEW vw_workflow_steps WITH (security_invoker = ON) AS
SELECT
  t.workflow_step_id,
  t.label,
  t.sequence_position,
  t.requires_human_approval,
  t.is_step_of,
  calc_workflow_steps_is_step_of_title(t.workflow_step_id) AS is_step_of_title,
  t.assigned_role,
  calc_workflow_steps_assigned_role_label(t.workflow_step_id) AS assigned_role_label,
  calc_workflow_steps_assigned_role_filled_by(t.workflow_step_id) AS assigned_role_filled_by
FROM workflow_steps t;
```

---

## View Field Naming Conventions

### FK Lookup Fields
For any foreign key `foo`, the view includes:
- `foo` - the raw FK value (the ID)
- `foo_name` - display name of related entity
- `foo_label` - alternative display (if the related entity uses Label instead of Name)
- `foo_{field}` - any field from the related entity

### Calculated Field Patterns
- `*_count` / `count_of_*` - count of related items
- `*_amount` - monetary totals
- `is_*` - boolean flags
- `*_status` - status lookups
- `*_at` - timestamps

---

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

---

## Airtable as Single Source of Truth

ERB projects use Airtable as the single source of truth for schema definitions. The local `effortless-rulebook.json` file is generated FROM Airtable - **never edit it directly**.

### Making Schema Changes

**ALL schema changes must go through Airtable, then regenerate:**

1. **Get the base ID** from `ssotme.json` (the `baseId` setting)
2. **Get the API key** from `AIRTABLE_API_KEY` env var or `~/.ssotme/ssotme.key`
3. **Use the Airtable API** to make changes
4. **Run `effortless build`** from project root to regenerate all code

### Adding a Field to a Table

```bash
# 1. Get table schema to find table ID
curl -s "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables" \
  -H "Authorization: Bearer {API_KEY}" | jq '.tables[] | {id, name}'

# 2. Add the field
curl -s -X POST "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables/{TABLE_ID}/fields" \
  -H "Authorization: Bearer {API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "FieldName",
    "type": "singleLineText",
    "description": "Field description"
  }'

# 3. Regenerate code
effortless build
```

### Common Airtable Field Types
- `singleLineText` - short text
- `multilineText` - long text
- `number` - numeric values
- `checkbox` - boolean
- `singleSelect` - dropdown
- `multipleSelects` - multi-select
- `date` - date only
- `dateTime` - date and time
- `email` - email address
- `url` - URL
- `formula` - calculated field (CANNOT be created/modified via API)
- `multipleRecordLinks` - foreign key relationship

### Modifying an Existing Field

```bash
curl -s -X PATCH "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables/{TABLE_ID}/fields/{FIELD_ID}" \
  -H "Authorization: Bearer {API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "NewFieldName",
    "description": "Updated description"
  }'
```

### Creating a New Table

```bash
curl -s -X POST "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables" \
  -H "Authorization: Bearer {API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TableName",
    "description": "Table description",
    "fields": [
      {"name": "Name", "type": "singleLineText"},
      {"name": "Status", "type": "singleSelect", "options": {"choices": [{"name": "Active"}, {"name": "Inactive"}]}}
    ]
  }'
```

### When Airtable API Has Limitations

Some operations (like modifying formula fields) cannot be done via API. When you hit these limitations:

1. **Tell the user** what you cannot do programmatically
2. **Explain the options**:
   - User can make the change manually in Airtable's UI
   - User can add logic to a customization file (e.g., `02b-customize-functions.sql`)
3. **Wait for user direction** - do not proceed with manual edits to generated files

---

## Diagnostic Queries

### Against the Rulebook (PREFERRED - do these first)

```bash
# Count tables and total fields
cat effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
tables=[(k,v) for k,v in d.items() if isinstance(v,dict) and 'schema' in v]
print(f'{len(tables)} tables, {sum(len(v[\"schema\"]) for k,v in tables)} total fields')
for k,v in tables:
  raw=len([f for f in v['schema'] if f['type']=='raw'])
  calc=len([f for f in v['schema'] if f['type'] in ('calculated','lookup','aggregation')])
  rel=len([f for f in v['schema'] if f['type']=='relationship'])
  print(f'  {k}: {raw} raw, {calc} derived, {rel} relationships')
"

# Validate DAG (check for missing FK targets)
cat effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
tables={k for k,v in d.items() if isinstance(v,dict) and 'schema' in v}
for k,v in d.items():
  if isinstance(v,dict) and 'schema' in v:
    for f in v['schema']:
      if f['type']=='relationship' and f.get('RelatedTo') not in tables:
        print(f'  BROKEN FK: {k}.{f[\"name\"]} -> {f.get(\"RelatedTo\")} (not found)')
"
```

### Against Generated Code (secondary)

```bash
# Find JOIN anti-patterns in Go code
grep -r "JOIN" cmd/api/*.go | grep -v "// " | wc -l
# Should be ~0 for a healthy codebase

# Find base table reads
grep -rE "FROM (bids|rfps|companies|contacts|documents)\s" cmd/api/*.go
# Should mostly be INSERTs, UPDATEs, DELETEs

# Find view usage
grep -r "FROM vw_" cmd/api/*.go | wc -l
# Should be high - this is where reads happen
```

---

## Migration Path for Legacy Code

When fixing JOIN anti-patterns:

1. Identify what fields the JOIN is fetching
2. Verify those fields exist in the source view (check the rulebook first!)
3. Remove the JOIN, select from view directly
4. If field is missing, extend the view via Airtable (not the app code)

### Before
```go
rows, _ := db.Query(`
    SELECT b.bid_id, b.rfp, c.company_name, r.title
    FROM bids b
    JOIN companies c ON b.submitted_by_vendor = c.companie_id
    JOIN rfps r ON b.rfp = r.rfp_id
    WHERE b.bid_id = $1`, bidID)
```

### After
```go
rows, _ := db.Query(`
    SELECT bid_id, rfp, company_name, rfp_title
    FROM vw_bids
    WHERE bid_id = $1`, bidID)
```

---

## Summary: The ERB Mental Model

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

**Remember:**
- Query the rulebook FIRST, generated code SECOND
- Schema is small, data is big -- extract schema to save tokens
- It's a DAG: 1-to-many only, no cycles, no many-to-many
- Every table has a Name, every field has a Description
- PascalCase names, no spaces, no symbols
- FK = singular entity name (no Id suffix), reverse = plural
- Never edit generated files, never fall back to manual edits
- Views do the work -- use them for reads, base tables for writes
