# Slack Thread Detection Implementation Plan

## Current State
- Successfully detect and parse main channel messages
- Extract workspace, channel, sender, and message content
- Missing: Thread/reply detection when sidebar opens

## Problem
When users click "replies" on a Slack message, a sidebar opens showing the thread conversation. Currently, our parser only detects the main channel messages and ignores this thread sidebar content.

## Inspiration from Reference Implementation

**Reference:** `/scraper/Traversal/SlackParser.swift` contains a proven thread detection implementation.

### Key Insights from Reference Code
1. **Thread View Detection Pattern** (lines 74-76):
   ```swift
   if viewContentsDescription == "Threads" {
       return try await processThreadView(viewContents, workspace: workspace, deadline: deadline)
   }
   ```

2. **Thread Processing Strategy** (lines 104-186):
   - Uses state machine approach: `.searchingForHeader` → `.processingMessages`
   - Looks for `threads_view_heading` DOM identifier
   - Extracts channel name and participants from header
   - Processes messages until `threads_view_footer`

3. **Thread Content Detection** (lines 317-346):
   - Uses rule-based parsing with collectors
   - Detects thread buttons: `hasAttribute(.title, containsAny: ["reply", "replies"])`
   - Identifies thread groups: `hasChild(matching: Matchers.hasAttribute(.value, substring: "Last reply"))`
   - Appends thread info to message content: `"(threadInfo.joined(separator: ", "))"`

## Proposed Solution

### Phase 1: Thread View Detection  
**Based on reference lines 72-76**

1. **Extend SlackWorkspaceParser**
   - Add `detectThreadView()` method
   - Check if `viewContents.getAttributeValue(.description) == "Threads"`
   - Return thread view type (main threads view vs. specific thread)

2. **Extend SlackElementFinder**
   - Add `findThreadViewHeader()` method using DOM identifier pattern
   - Look for elements with `domIdentifier` starting with `"threads_view_heading"`
   - Add `findThreadViewFooter()` for boundary detection

### Phase 2: Thread Message Parsing
**Based on reference lines 104-186**

1. **Create SlackThreadParser**
   - Implement state machine: `searchingForHeader`, `processingMessages`
   - Extract channel name and participants from header children
   - Process messages between header and footer boundaries
   - Reuse existing `SlackMessageParser.processMessageElement()` for individual messages

2. **Thread Context Extraction**
   - Parse header children: `headerChildren[0]` = channel, `headerChildren[1]` = participants
   - Generate full channel name: `workspace + ", " + channelName + " with " + participants`
   - Track thread boundaries using `threads_view_footer` DOM identifier

### Phase 3: Data Model Updates

1. **Update SlackMessage Model**
   - Add `isThreadReply: Bool` property
   - Add `parentMessageId: String?` property
   - Add `threadParticipants: String?` property

2. **Update SlackConversation Model**
   - Add `threadMessages: [SlackMessage]` property
   - Add `threadInfo: ThreadInfo?` struct with channel and participants

### Phase 4: Integration with Current Architecture

1. **Update SlackUIParser.parseCurrentConversation()**
   ```swift
   // After Step 6: Extract channel information
   let viewContentsDescription = try await viewContents.getAttributeValue(.description) as? String
   
   if viewContentsDescription == "Threads" {
       return try await threadParser.parseThreadView(viewContents, workspace: finalWorkspace, deadline: deadline)
   }
   ```

2. **Hybrid Detection Strategy**
   - Parse main channel messages as normal
   - Additionally check for thread view state
   - Return separate conversations for main channel vs. thread view
   - Use same component architecture: `SlackElementFinder`, `SlackMessageParser`, `SlackWorkspaceParser`

## Implementation Strategy

### Step 1: Thread View State Detection
**Reference: SlackParser.swift:72-76**
- Add thread view detection to `SlackWorkspaceParser`
- Check `viewContents.getAttributeValue(.description)` for "Threads"
- Implement basic logging to confirm thread state detection

### Step 2: Thread Header/Footer Detection  
**Reference: SlackParser.swift:132-148**
- Extend `SlackElementFinder` with DOM identifier matching
- Look for `threads_view_heading` and `threads_view_footer` patterns
- Extract channel name and participants from header children

### Step 3: Thread Message Processing
**Reference: SlackParser.swift:164-168**
- Create `SlackThreadParser` with state machine logic
- Reuse `SlackMessageParser.processMessageElement()` for consistency
- Handle message boundaries between header and footer

### Step 4: Content Enhancement Detection
**Reference: SlackParser.swift:317-346**
- Detect thread buttons and reply indicators in main channel messages
- Add thread context to message content when thread info is present
- Implement rule-based collection similar to reference implementation

## Testing Plan

**Please keep me in the loop for testing** - I'll need your help to:

1. **Thread View Detection Testing**
   - Navigate to Slack threads view (main threads list)
   - Open specific thread conversations
   - Verify detection of thread state vs. main channel state
   - Test thread view description parsing

2. **Thread Message Parsing Testing**
   - Open threads with different message counts (1-2 replies vs. many)
   - Test threads in different channels (public, private, DM)
   - Verify header parsing (channel name + participants)
   - Check message boundaries and content extraction

3. **Integration Testing**
   - Ensure main channel parsing continues to work
   - Test switching between main channel and thread views
   - Verify performance impact of additional thread detection logic

4. **Edge Cases from Reference Implementation**
   - Test thread buttons with "reply"/"replies" text (reference line 321)
   - Verify attachment detection in threads (reference line 327)
   - Test "Last reply" thread group detection (reference line 335)

## Technical Implementation Details

### Architecture Integration
- **SlackUIParser**: Add thread detection logic after step 6 (channel extraction)
- **SlackWorkspaceParser**: Add `detectThreadView()` method
- **SlackElementFinder**: Add DOM identifier search methods
- **New SlackThreadParser**: Handle state machine and message processing

### Key Reference Patterns to Adopt
1. **State Machine Pattern** (lines 111-114):
   ```swift
   enum ThreadViewState { case searchingForHeader, processingMessages }
   ```

2. **DOM Identifier Matching** (line 137):
   ```swift
   domId.starts(with: "threads_view_heading")
   ```

3. **Header Parsing Pattern** (lines 141-144):
   ```swift
   channelName = try await headerChildren[0].getValue() ?? ""
   participants = try await headerChildren[1].getValue() ?? ""
   ```

4. **Thread Content Detection** (lines 317-346):
   - Rule-based parsing with collectors
   - Thread button detection by title attributes
   - Content enhancement with thread information

## Next Steps

1. **Start with Step 1**: Add basic thread view detection to `SlackWorkspaceParser`
2. **Test detection**: Verify thread state recognition with your help
3. **Implement Step 2**: Add DOM identifier matching for headers/footers  
4. **Build Step 3**: Create `SlackThreadParser` with state machine logic
5. **Enhance Step 4**: Add thread content detection to main channel messages

The reference implementation provides a proven roadmap - we can adapt its patterns to our current LBAccessibility-based architecture while maintaining consistency with our existing component structure.

Ready to start with Step 1 when you are - just let me know when you'd like to test thread detection scenarios!