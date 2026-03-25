#!/bin/bash
# Grabs the printer HTML directly to bypass the browser tool's "Search" logic
curl -s -A "Mozilla/5.0" http://192.168.50.56/home/status.html > ~/.openclaw/workspace/printer_status.html
echo "Printer status grabbed and saved to workspace."
