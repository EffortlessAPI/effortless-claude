---
name: effortless-omni-prompt
description: >
  DEPRECATED — This skill has been merged into effortless-airtable-omni.
  Use effortless-airtable-omni instead for both OMNI prompt generation
  and Playwright-driven OMNI automation.
deprecated: true
replaced_by: effortless-airtable-omni
---

# DEPRECATED

This skill has been merged into **effortless-airtable-omni**, which combines:

- OMNI prompt generation (the two-part split pattern from this skill)
- Playwright-driven OMNI automation (new — lets Claude drive OMNI directly in a headed browser)

Please use `effortless-airtable-omni` instead. This skill will be removed in a future release.

To clean up, run:
```bash
rm -rf ~/.claude/skills/effortless-omni-prompt
```

Or re-run the installer which will offer to remove deprecated skills:
```bash
bash install.sh --yes
```
