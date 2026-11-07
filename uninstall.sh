#!/bin/sh
# Removes the Canon_MP540 queue and everything install.sh installed. Run with sudo.
set -u

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

lpadmin -x Canon_MP540 2>/dev/null || true
rm -rf /Library/Printers/Gutenprint
rm -f /Library/Printers/PPDs/Contents/Resources/Canon-PIXMA-MP540-Gutenprint.ppd
echo "Uninstalled."
