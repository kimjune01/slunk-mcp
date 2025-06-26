# TODO Sweep - Find and Organize All TODOs

Search the codebase for TODO, FIXME, HACK, and XXX comments, categorize them, and create an action plan.

## Instructions

1. **Search for All TODO Comments**
   - Search for patterns: `TODO`, `FIXME`, `HACK`, `XXX`, `BUG`, `OPTIMIZE`
   - Include variations: `// TODO:`, `/* TODO */`, `# TODO`, etc.
   - Search in all relevant file types: `.swift`, `.md`, `.yml`, `.sh`

2. **Categorize by Priority**
   - **P0 (Critical)**: Security issues, data corruption risks, crashes
   - **P1 (High)**: User-facing bugs, performance issues, broken features
   - **P2 (Medium)**: Code quality improvements, refactoring opportunities
   - **P3 (Low)**: Nice-to-have improvements, documentation updates

3. **Categorize by Effort**
   - **Quick (< 15 min)**: Simple fixes, typos, missing imports
   - **Medium (15-60 min)**: Small refactors, adding missing validation
   - **Large (> 1 hour)**: Architecture changes, major refactoring

4. **Action Plan**
   - **Immediate**: Fix all Quick + P0/P1 items now
   - **This Sprint**: Address Medium + P1 items
   - **Backlog**: Create GitHub issues for Large items
   - **Document**: Note any TODOs that provide valuable context

5. **Report Format**
   ```
   ## TODO Analysis Report
   
   ### Summary
   - Total TODOs found: X
   - Fixed immediately: Y
   - Scheduled for sprint: Z
   - Added to backlog: W
   
   ### Quick Fixes Completed
   - [File:Line] Description of fix
   
   ### Sprint Items
   - [File:Line] Description - Estimated effort
   
   ### Backlog Items Created
   - [File:Line] Description - GitHub issue #123
   
   ### Context TODOs (Keeping)
   - [File:Line] Valuable context, keeping as documentation
   ```

## Success Criteria

- All critical TODOs addressed or escalated
- Quick fixes implemented immediately  
- Clear action plan for remaining items
- Reduced technical debt
- Better code maintainability