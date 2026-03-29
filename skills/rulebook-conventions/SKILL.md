---
name: rulebook-conventions
description: >
  Use when you need ERB naming conventions, DAG structure rules, PascalCase table
  names, primary key and foreign key patterns, the Name field requirement, or
  understanding why many-to-many relationships are not allowed.
---

# ERB Naming & Design Conventions

## Table Names
- **PascalCase**, no spaces, no symbols, no underscores
- Plural for collections: `Customers`, `WorkflowSteps`, `TypesOfAgents`
- Example: `ClientProgramSessions`, `DocumentCategories`, `ApprovalGates`

## Primary Keys
- Named `{SingularTableName}Id` — e.g., `CustomerId`, `WorkflowStepId`, `RoleId`
- Always `datatype: "string"`, `type: "raw"`, `nullable: false`
- Values are human-readable slugs: `"production-deployment-workflow"`, `"client-bob"`, `"cust0001"`

## The Name Field
- **Every table MUST have a `Name` field** (or equivalent human-readable compound key)
- This is the display label for each row — the human-readable identity
- In Airtable, this is the primary field (first column) that labels each record
- It can be `raw` (user-entered) or `calculated` (derived from other fields)
- Example: `Name = "client-" & SUBSTITUTE(LOWER({{CompanyName}}), " ", "-")`

## Every Table and Field Must Have a Description
- Descriptions form the semantic backbone of the DAG
- They explain purpose, usage context, and ontology mappings
- Example: `"Human-readable name for the workflow. Maps to dct:title per Dublin Core."`

## Foreign Key Conventions

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

## NO MANY-TO-MANY RELATIONSHIPS. EVER.

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

## Calculated Field Naming Patterns

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
