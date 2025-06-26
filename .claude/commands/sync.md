# Sync - Verify Documentation Accuracy

Quick check that docs match reality (max 2 minutes).

## Core Checks

**README.md:**
- Test the first code example (30s timeout)
- Verify installation command works
- Check that main feature description is accurate

**Project Files:**
- Count actual tools/features vs documented count
- Verify main commands still exist
- Check file paths mentioned in docs

**Quick Fixes:**
- Fix obvious version numbers
- Update tool/feature counts
- Correct broken file paths
- Fix simple typos in headings

## Output Format

```
📋 README: ✅ Commands work
📊 Counts: ❌ Says 9 tools, found 8  
📁 Paths: ✅ All files exist
🔧 Fixed: Updated tool count

📋 Status: SYNCED
```

OR

```
📋 README: ❌ Setup command fails
📊 Counts: ✅ Match  
📁 Paths: ⚠️  2 broken links
🔧 Skipped: Manual fixes needed

📋 Status: OUT OF SYNC
```

## What It Checks

**Auto-detectable:**
- Command examples (run them)
- File existence
- Counts (tools, features, etc.)
- Version numbers in package files

**What It Skips:**
- Complex feature descriptions
- Architecture explanations  
- Screenshots/images
- Lengthy prose

## Quick Fixes Only

- Number corrections
- File path updates
- Simple find/replace
- Obvious typos

Anything requiring thought → skip and report.