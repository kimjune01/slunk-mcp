# Doc Sync - Synchronize Documentation with Code

Update all project documentation to reflect current codebase state, features, and architecture.

## Instructions

1. **README.md Review**
   - Verify project description matches current functionality
   - Update feature list with any new capabilities
   - Check installation/setup instructions are accurate
   - Test all command examples work correctly
   - Update screenshots or demos if UI changed
   - Verify all links work and point to correct resources

2. **CLAUDE.md Maintenance**
   - Update MCP tool count (currently should be 8 tools, not 9)
   - Verify all development commands still work
   - Update architecture descriptions for any changes
   - Check that file paths and project structure are accurate
   - Update build commands if they've changed
   - Add any new troubleshooting information discovered

3. **Code Documentation**
   - Ensure all public APIs have proper doc comments
   - Update complex algorithm explanations
   - Verify code examples in comments still compile
   - Add missing parameter and return value documentation
   - Update architectural decision records (ADRs) if applicable

4. **API Documentation**
   - Review MCP tool descriptions for accuracy
   - Update parameter descriptions and examples
   - Verify return value formats match implementation
   - Check that tool usage examples are current

5. **Configuration Files**
   - Update any example configuration files
   - Verify environment variable documentation
   - Check Docker or deployment documentation if applicable
   - Update any CI/CD configuration documentation

6. **Changelog/Release Notes**
   - Document any breaking changes since last checkpoint
   - Note new features or significant improvements
   - Record any deprecated functionality
   - Update version numbers if applicable

7. **Documentation Quality Check**
   - Run spell check on all documentation
   - Verify consistent formatting and style
   - Check for broken internal links
   - Ensure examples use current syntax/APIs
   - Verify code blocks have proper language highlighting

## Validation Steps

1. **README Walkthrough**
   - Follow setup instructions as a new user would
   - Run all example commands provided
   - Verify prerequisites are complete and accurate

2. **Documentation Cross-Check**
   - Compare documented features with actual implementation
   - Verify tool counts and capabilities match code
   - Check that architectural diagrams reflect current design

3. **Link Validation**
   - Test all external links
   - Verify internal references point to correct sections
   - Check that file paths in documentation exist

## Success Criteria

- All documentation accurately reflects current codebase
- Setup instructions work for new developers
- Feature descriptions match implementation
- No broken links or references
- Consistent formatting and style throughout
- All code examples compile and work correctly

## Common Updates Needed

- Tool count corrections (8 tools, not 9 after removing intelligent_search)
- Build command updates
- New feature documentation
- Deprecated feature removal
- API parameter changes
- File structure modifications
- Performance characteristic updates