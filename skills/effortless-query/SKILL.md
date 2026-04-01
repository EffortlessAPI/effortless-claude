---
name: effortless-query
description: >
  Use when querying an effortless-rulebook.json file — listing tables, extracting
  schema without data, finding FK relationships, inspecting calculated fields and
  formulas. Activates for any project with effortless-rulebook.json or
  effortless-rulebook/ directory.
---

# Querying the Effortless Rulebook

## CRITICAL: Query the Rulebook First

**Before reading code, SQL, or any generated files — ALWAYS query `effortless-rulebook.json` first.**

The rulebook is the single source of truth. It contains everything: schema, relationships, formulas, descriptions, and data. Do NOT grep through Go/Python/SQL files to understand the domain. Instead:

1. **Find the rulebook**: Look for `effortless-rulebook/effortless-rulebook.json` or check `ssotme.json` transpiler inputs for the path
2. **Extract schema only** (strip data to save tokens):
   ```bash
   cat effortless-rulebook/effortless-rulebook.json | \
     python3 -c "import sys,json; d=json.load(sys.stdin); [d[k].__delitem__('data') for k in d if isinstance(d.get(k),dict) and 'data' in d.get(k,{})]; print(json.dumps(d,indent=2))"
   ```
3. **Query specific aspects** rather than loading everything.

### Why This Matters

- The rulebook is typically 500-3000 lines, but the **schema alone is 10-20% of that**
- Loading just schema saves enormous token budget
- Every answer about "what fields exist" or "how are these related" is in the rulebook
- You do NOT need to read generated SQL, Go, or Python to understand the domain

## Common Queries

### List All Tables

```bash
cat effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
skip={'\$schema','Name','Description','_meta'}
for k in d:
  if k not in skip and isinstance(d[k],dict) and 'schema' in d[k]:
    fields=d[k]['schema']
    print(f'  {k}: {len(fields)} fields, {len(d[k].get(\"data\",[]))} rows')
"
```

### Show Schema for One Table

```bash
cat effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for f in d['TableName']['schema']:
  print(f'  {f[\"name\"]:30s} {f[\"type\"]:15s} {f[\"datatype\"]:10s} {f.get(\"Description\",\"\")[:60]}')
"
```

### Find All FK Relationships

```bash
cat effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for k,v in d.items():
  if isinstance(v,dict) and 'schema' in v:
    for f in v['schema']:
      if f['type']=='relationship':
        print(f'  {k}.{f[\"name\"]} -> {f[\"RelatedTo\"]}')
"
```

### Find All Calculated Fields and Formulas

```bash
cat effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
for k,v in d.items():
  if isinstance(v,dict) and 'schema' in v:
    for f in v['schema']:
      if f['type'] in ('calculated','aggregation','lookup'):
        print(f'  {k}.{f[\"name\"]} ({f[\"type\"]}): {f.get(\"formula\",\"\")}')
"
```

### Count Tables and Fields Summary

```bash
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
```
