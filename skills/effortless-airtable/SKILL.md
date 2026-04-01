---
name: effortless-airtable
description: >
  Use when making schema or data changes via the Airtable API in an ERB project —
  adding fields, creating tables, modifying existing fields, or when you need to
  understand Airtable API limitations (e.g., formula fields cannot be created via API).
---

# Airtable as Single Source of Truth

ERB projects use Airtable as the authoritative source of truth for schema definitions. The local `effortless-rulebook.json` file is normally generated FROM Airtable.

**Preferred flow (Path A):** Edit Airtable, then `effortless build` to regenerate the JSON and all downstream files.

**Reverse-sync flow (Path B):** When necessary, you CAN edit `effortless-rulebook.json` directly, then push back to Airtable via `effortless build -id` from the `push-to-airtable/` subfolder.

**In either case, always ask the user for permission before modifying the rulebook or Airtable.**

## Making Schema Changes

**ALL schema changes must go through Airtable, then regenerate:**

1. **Get the base ID** from `ssotme.json` (the `baseId` setting)
2. **Get the API key** from `AIRTABLE_API_KEY` env var or `~/.ssotme/ssotme.key`
3. **Use the Airtable API** to make changes
4. **Run `effortless build`** from project root to regenerate all code

## Adding a Field to a Table

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

## Common Airtable Field Types
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

## Modifying an Existing Field

```bash
curl -s -X PATCH "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables/{TABLE_ID}/fields/{FIELD_ID}" \
  -H "Authorization: Bearer {API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "NewFieldName",
    "description": "Updated description"
  }'
```

## Creating a New Table

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

## Generating OMNI Prompts for Base Setup

When creating prompts for Airtable's OMNI AI to set up tables, **always use the two-part split pattern** documented in the `effortless-omni-prompt` skill:

- **Part 1**: Raw fields + `Link to another record` FKs + Name formula. No other computed fields.
- **Part 2**: Lookups & formulas, **organized by table** (OMNI can only work on one table at a time). Excludes MANY-side rollups.

This pattern ensures linked records are established first, making lookups trivial in Part 2. Never combine into a single file — OMNI will produce incorrect field types.

## When Airtable API Has Limitations

Some operations (like modifying formula fields) cannot be done via API. When you hit these limitations:

1. **Tell the user** what you cannot do programmatically
2. **Explain the options**:
   - User can make the change manually in Airtable's UI
   - User can add logic to a customization file (e.g., `02b-customize-functions.sql`)
3. **Wait for user direction** - do not proceed with manual edits to generated files
