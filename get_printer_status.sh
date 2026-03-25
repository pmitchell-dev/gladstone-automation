#!/bin/bash
# Brother Printer Status Scraper
PRINTER_IP="192.168.50.56"
OUTPUT_FILE="/home/pi/printer_data/status.html"

# Ensure the directory exists
mkdir -p /home/pi/printer_data

# Use a standard GET request with a browser User-Agent
# We add -L to follow any redirects and -o to save the file
curl -sL -A "Mozilla/5.0" "http://$PRINTER_IP/home/status.html" -o "$OUTPUT_FILE"

# Check if the file was actually created and has content
if [ -s "$OUTPUT_FILE" ]; then
    echo "✅ Brother Printer status updated at $(date)"
else
    echo "⚠️ Warning: Could not reach printer at $PRINTER_IP or page is empty."
fi
