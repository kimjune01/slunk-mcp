# Health - Project Health Check

Quick build and test validation (max 5 minutes).

## Auto-Detection & Execution

**Swift/iOS:**
```bash
xcodebuild build -project *.xcodeproj -scheme * && xcodebuild test -project *.xcodeproj -scheme *
```

**Node.js:**
```bash
npm run build && npm test
```

**Python:**
```bash
python -m pytest || python -m unittest discover
```

**Rust:**
```bash
cargo build && cargo test
```

**Go:**
```bash
go build ./... && go test ./...
```

## Output Format

```
✅ Build: PASS (2.3s)
✅ Tests: PASS (4/4 passed)
📊 Status: HEALTHY
```

OR

```
❌ Build: FAIL (3 errors)
⚠️  Tests: SKIP (build failed)
🔥 Status: BROKEN

Next: Fix build errors first
```

## Auto-fixes During Health Check

- Remove obviously unused imports
- Fix simple formatting issues
- Update obvious version mismatches

## When It Fails

1. Show first error only
2. Suggest most likely fix
3. Exit immediately (don't run more checks)