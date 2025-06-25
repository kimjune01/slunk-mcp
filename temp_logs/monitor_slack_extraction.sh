#!/bin/bash

# Monitor console logs for slunk-swift app
echo "🔍 Starting Slack extraction log monitoring..."
echo "Logs will be saved to: temp_logs/slack_extraction_logs.txt"
echo "Press Ctrl+C to stop monitoring"
echo ""

# Monitor logs and save to file
log stream --predicate 'process == "slunk-swift"' --style syslog | tee temp_logs/slack_extraction_logs.txt