# Build Check - Comprehensive Build and Test Validation

Perform a thorough build and test cycle to ensure code quality and catch any issues.

## Instructions

1. **Pre-Build Cleanup**
   - Clean any previous build artifacts
   - Remove derived data if needed
   - Check for any build configuration issues

2. **Build Process**
   - Execute: `xcodebuild clean -project slunk-swift.xcodeproj -scheme slunk-swift`
   - Execute: `xcodebuild build -project slunk-swift.xcodeproj -scheme slunk-swift`
   - Capture and analyze any warnings or errors
   - Check build time for performance regressions

3. **Test Execution**
   - Execute: `xcodebuild test -project slunk-swift.xcodeproj -scheme slunk-swift`
   - Analyze test results and coverage
   - Identify flaky or failing tests
   - Check test execution time

4. **Static Analysis**
   - Review compiler warnings
   - Check for any static analyzer findings
   - Look for potential runtime issues

5. **Dependency Check**
   - Verify all Swift Package dependencies resolve correctly
   - Check for any version conflicts
   - Ensure no missing or broken dependencies

6. **Report Generation**
   ```
   ## Build Check Report
   
   ### Build Status: ✅ PASS / ❌ FAIL
   - Build time: X seconds
   - Warnings: X
   - Errors: X
   
   ### Test Results: ✅ PASS / ❌ FAIL  
   - Tests run: X
   - Passed: X
   - Failed: X
   - Test time: X seconds
   
   ### Issues Found
   - [List any warnings, errors, or concerns]
   
   ### Recommendations
   - [Actions to address any issues]
   ```

## Success Criteria

- Clean build with no errors
- All tests passing
- Minimal warnings (ideally zero)
- Reasonable build and test times
- All dependencies resolved correctly

## When to Run

- Before committing significant changes
- As part of checkpoint process  
- Before creating releases
- When dependencies are updated
- After major refactoring