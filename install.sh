#!/bin/sh
# Installs the Gutenprint 5.3.5 driver (built for this Mac) for the Canon PIXMA MP540 and adds the print queue.
# Writes only to /Library/Printers/Gutenprint and /Library/Printers/PPDs. Run with sudo.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
DEST=/Library/Printers/Gutenprint
PPD_DIR=/Library/Printers/PPDs/Contents/Resources
PPD=$PPD_DIR/Canon-PIXMA-MP540-Gutenprint.ppd
QUEUE=Canon_MP540

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

mkdir -p "$DEST" "$PPD_DIR"
cp -R "$HERE/payload/Gutenprint/" "$DEST/"
cp "$HERE/payload/ppd/Canon-PIXMA-MP540-Gutenprint.ppd" "$PPD"

# cupsd refuses to run a filter that is not owned by root or is writable by others.
chown -R root:wheel "$DEST" "$PPD"
chmod -R go-w "$DEST"
chmod 755 "$DEST/filter/rastertogutenprint.5.3"
chmod 644 "$PPD"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

URI=$(lpinfo -v 2>/dev/null | awk '/^direct usb:\/\/Canon\/MP540/ {print $2; exit}')
if [ -z "$URI" ]; then
  echo "Driver installed. Printer not found on USB: plug it in, turn it on, then run this script again."
  exit 0
fi

lpadmin -p "$QUEUE" -E -v "$URI" -P "$PPD" -D "Canon PIXMA MP540" -L "USB" \
  -o printer-is-shared=false -o PageSize=A4
cupsenable "$QUEUE"
cupsaccept "$QUEUE"
echo "Queue '$QUEUE' created on $URI."
