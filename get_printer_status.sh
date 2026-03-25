#!/bin/bash
# High-Compatibility Scraper for HL-L2405W
PRINTER_IP="192.168.50.56"
OUTPUT_FILE="/home/pi/printer_data/status.html"

mkdir -p /home/pi/printer_data

# We use a full Chrome User-Agent to bypass the "Please Login" redirect
# and target the HTTP version first since your screenshot shows it working there.
curl -sL -k -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
     "http://$PRINTER_IP/home/status.html" -o "$OUTPUT_FILE"

# Check if we got the actual status or just the login page
if grep -qi "Toner Level" "$OUTPUT_FILE"; then
    echo "✅ Brother Status Captured."
else
    echo "⚠️ Public page blocked. Trying HTTPS fallback..."
    curl -sL -k -A "Mozilla/5.0" "https://$PRINTER_IP/home/status.html" -o "$OUTPUT_FILE"
fi
