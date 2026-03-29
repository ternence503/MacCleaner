#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$DIR/MacCleaner.sh"

if [ ! -f "$SCRIPT" ]; then
    echo "Error: MacCleaner.sh not found"
    echo "Make sure MacCleaner.sh is in the same folder as this file"
    read -rp "Press Enter to exit..."
    exit 1
fi

chmod +x "$SCRIPT"
bash "$SCRIPT"
