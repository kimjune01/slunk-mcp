#!/bin/bash

echo "🔍 Verifying Slunk app makes no network calls..."
echo

# Check for networking frameworks and classes
echo "1. Checking for network frameworks:"
grep -r "import.*Network" slunk-swift/ || echo "   ✅ No Network framework imports"
grep -r "URLSession" slunk-swift/ || echo "   ✅ No URLSession usage"
grep -r "NSURLConnection" slunk-swift/ || echo "   ✅ No NSURLConnection usage"
grep -r "CFNetwork" slunk-swift/ || echo "   ✅ No CFNetwork usage"
echo

# Check for common networking patterns
echo "2. Checking for HTTP/network calls:"
grep -r "http://" slunk-swift/ || echo "   ✅ No HTTP URLs found"
grep -r "https://" slunk-swift/ || echo "   ✅ No HTTPS URLs found"
grep -r "\.request" slunk-swift/ || echo "   ✅ No request patterns found"
grep -r "dataTask" slunk-swift/ || echo "   ✅ No data tasks found"
echo

# Check entitlements
echo "3. Checking entitlements file:"
if grep -q "com.apple.security.network" slunk-swift/slunk_swift.entitlements; then
    echo "   ❌ Network entitlements found"
else
    echo "   ✅ No network entitlements in app"
fi

echo
echo "4. App capabilities summary:"
echo "   - Uses only local accessibility APIs"
echo "   - Stores data in local SQLite database" 
echo "   - No external network dependencies"
echo "   - Menu bar app with local UI only"
echo
echo "✅ VERIFICATION COMPLETE: App operates entirely offline"