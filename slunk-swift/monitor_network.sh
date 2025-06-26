#!/bin/bash

echo "🌐 Monitoring network activity for Slunk app..."
echo "Instructions:"
echo "1. Run this script"
echo "2. Launch Slunk app"
echo "3. Use the app normally for 2-3 minutes"
echo "4. Press Ctrl+C to stop monitoring"
echo "5. Review the output - should show NO network connections"
echo

# Find the app process
APP_NAME="slunk-swift"
echo "Looking for app process..."

# Monitor with lsof for network connections
echo "Starting network monitoring (press Ctrl+C to stop)..."
echo "Monitoring all network connections from $APP_NAME..."

while true; do
    PID=$(pgrep -f "$APP_NAME" | head -1)
    if [ ! -z "$PID" ]; then
        echo "Found $APP_NAME with PID: $PID"
        echo "Network connections:"
        lsof -p $PID -i | grep -v "COMMAND" || echo "   ✅ No network connections found"
        echo "---"
    else
        echo "App not running, waiting..."
    fi
    sleep 5
done