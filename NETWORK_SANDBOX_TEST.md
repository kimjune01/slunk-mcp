# Network Sandbox Verification Guide

## Quick Test Steps

1. **Build and run the app:**
   ```bash
   xcodebuild -project slunk-swift/slunk-swift.xcodeproj -scheme slunk-swift build
   open /Users/junekim/Library/Developer/Xcode/DerivedData/slunk-swift-*/Build/Products/Debug/slunk-swift.app
   ```

2. **Test network blocking:**
   - Launch the app
   - Check Console.app for sandbox violation messages
   - Look for entries containing "deny network-outbound" or similar

3. **Expected behavior:**
   - ✅ App launches normally
   - ✅ Local functionality works (UI, database, accessibility)
   - ❌ Any network requests should fail silently or with errors
   - ✅ Console shows sandbox violations for network attempts

## What to Look For

### In Console.app:
- Filter by process name "slunk-swift"
- Look for messages like: `sandbox: deny(1) network-outbound`

### In the app:
- MCP server should still work (uses stdio, not network)
- Slack monitoring should work (uses local accessibility APIs)
- Database operations should work (local SQLite)

## If Network Requests Still Work

The sandbox isn't properly applied. Check:
1. Entitlements file is properly linked in Xcode project
2. App is code-signed with the entitlements
3. No cached/unsigned version is running

## Rollback (if needed)

To re-enable network access, change in `slunk_swift.entitlements`:
```xml
<key>com.apple.security.network.client</key>
<true/>
```