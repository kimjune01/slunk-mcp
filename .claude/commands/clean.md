# Clean - Auto-fix Code Quality Issues

Automatically fix obvious code issues (max 3 minutes).

## What Gets Auto-Fixed

**Imports:**
- Remove unused imports
- Sort alphabetically
- Group system vs project imports

**Formatting:**
- Fix indentation
- Remove trailing whitespace
- Consistent spacing around operators

**Simple TODOs (< 2 min each):**
- Fix obvious typos in comments
- Remove commented-out code
- Add missing semicolons/braces
- Fix simple naming (temp → temporaryFile)

**Language-Specific:**

**Swift:**
- Use `let` instead of `var` where possible
- Replace force unwrapping with safe alternatives (obvious cases only)
- Fix simple SwiftUI property wrappers

**JavaScript/TypeScript:**
- Use `const` instead of `let` where possible
- Replace `var` with `let`/`const`
- Add missing return types (obvious cases)

**Python:**
- Fix import order (PEP 8)
- Remove unused variables
- Add type hints to obvious cases

## Output Format

```
🧹 CLEANED
├─ Removed 3 unused imports
├─ Fixed 7 formatting issues  
├─ Resolved 2 simple TODOs
└─ Changed 4 var → let

⏱️  Completed in 1.2s
```

## What It Skips

- Complex logic changes
- Anything requiring human judgment
- TODOs that need investigation
- Breaking changes
- Performance optimizations

## Safety

- Only makes changes with 99% confidence
- Skips anything that might change behavior
- Creates backup before major changes