#!/bin/bash

# ==========================================================
# BROTHER HL-L2405W STATUS SCRAPER (GLADSTONE PI 5)
# ==========================================================
# PURPOSE:
# Connects to the local network printer to capture the 
# current status page (toner levels, errors, etc.) for
# processing by other Gladstone monitoring scripts.
# ==========================================================

# --- CONFIGURATION ---
# The static IP of the Brother printer on the Gladstone network
PRINTER_IP="192.168.50.56"
# Local path where the raw HTML data will be saved
OUTPUT_FILE="/home/pi/printer_data/status.html"

# Ensure the destination directory exists before downloading
mkdir -p /home/pi/printer_data

# --- DATA ACQUISITION ---
# We use a full Chrome User-Agent to bypass "Please Login" redirects.
# -sL: Silent mode and follow redirects
# -k: Ignore SSL certificate warnings (since printer uses self-signed certs)
# -A: Mimics a Windows Chrome browser to ensure the printer serves the full page
echo "📡 Attempting to poll Brother printer at $PRINTER_IP..."

curl -sL -k -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
     "http://$PRINTER_IP/home/status.html" -o "$OUTPUT_FILE"

# --- VALIDATION & FALLBACK ---
# Check the downloaded file for the string "Toner Level" to confirm 
# we actually got the data and not just a login/error page.
if grep -qi "Toner Level" "$OUTPUT_FILE"; then
    echo "✅ Brother Status Captured successfully."
else
    # If HTTP fails or is blocked, attempt to pull via HTTPS as a fallback
    echo "⚠️ Public page blocked or inaccessible. Trying HTTPS fallback..."
    curl -sL -k -A "Mozilla/5.0" "https://$PRINTER_IP/home/status.html" -o "$OUTPUT_FILE"
fi
