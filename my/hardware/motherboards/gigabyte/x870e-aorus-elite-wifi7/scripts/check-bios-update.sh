#!/usr/bin/env bash
set -euo pipefail

# BIOS Update Checker for Gigabyte X870E AORUS Elite WiFi7
# This script checks your current BIOS version and provides instructions
# for downloading the latest BIOS from Gigabyte's website.

MOTHERBOARD="X870E AORUS ELITE WIFI7"
SUPPORT_URL="https://www.gigabyte.com/Motherboard/X870E-AORUS-ELITE-WIFI7-rev-10/support#support-dl-bios"
DOWNLOAD_DIR="${HOME}/Downloads/bios"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════════════"
echo "  Gigabyte X870E AORUS Elite WiFi7 - BIOS Update Checker"
echo "═══════════════════════════════════════════════════════════════════"
echo

# Get current BIOS version
if [ -f /sys/class/dmi/id/bios_version ]; then
    CURRENT_VERSION=$(cat /sys/class/dmi/id/bios_version)
    CURRENT_DATE=$(cat /sys/class/dmi/id/bios_date)
    echo -e "${BLUE}Current BIOS:${NC}"
    echo "  Version: ${CURRENT_VERSION}"
    echo "  Date:    ${CURRENT_DATE}"
    
    # Check if it's a beta BIOS
    if [[ "$CURRENT_VERSION" == *"b"* ]]; then
        echo -e "  ${YELLOW}⚠️  WARNING: You're running a BETA BIOS!${NC}"
    fi
else
    echo -e "${RED}Error: Cannot read BIOS version${NC}"
    CURRENT_VERSION="Unknown"
fi

echo
echo -e "${BLUE}Motherboard:${NC} $MOTHERBOARD"
echo

# Check if we can reach Gigabyte's website
echo "Checking Gigabyte support page..."
if curl -s -f -I --max-time 5 "$SUPPORT_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Website is accessible"
else
    echo -e "${YELLOW}⚠${NC}  Cannot verify website accessibility"
fi

echo
echo "════════════════════════════════════════════════════════════════════"
echo "  Manual Download Instructions"
echo "════════════════════════════════════════════════════════════════════"
echo
echo "1. Visit the support page in your browser:"
echo -e "   ${BLUE}${SUPPORT_URL}${NC}"
echo
echo "2. Look for the 'BIOS' section and find the latest stable version"
echo "   (avoid versions with 'b' suffix - those are beta)"
echo
echo "3. Download the BIOS ZIP file to:"
echo "   ${DOWNLOAD_DIR}"
echo
echo "4. Extract the ZIP file"
echo

# Create download directory
mkdir -p "$DOWNLOAD_DIR"

# Check if there are existing BIOS files
EXISTING_FILES=$(find "$DOWNLOAD_DIR" -name "*.zip" -o -name "*.exe" -o -name "*.bin" 2>/dev/null | wc -l)
if [ "$EXISTING_FILES" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found existing files in ${DOWNLOAD_DIR}:"
    find "$DOWNLOAD_DIR" -name "*.zip" -o -name "*.exe" -o -name "*.bin" 2>/dev/null | while read file; do
        SIZE=$(du -h "$file" | cut -f1)
        echo "  - $(basename "$file") ($SIZE)"
    done
    echo
fi

echo "════════════════════════════════════════════════════════════════════"
echo "  BIOS Update Methods"
echo "════════════════════════════════════════════════════════════════════"
echo
echo "Method 1: Q-Flash (Recommended)"
echo "  1. Copy extracted BIOS file to USB drive (FAT32 formatted)"
echo "  2. Reboot and press 'Del' or 'F2' to enter BIOS"
echo "  3. Press 'F8' for Q-Flash"
echo "  4. Select the BIOS file from USB"
echo "  5. Follow on-screen instructions"
echo
echo "Method 2: Q-Flash Plus (No CPU/RAM needed)"
echo "  1. Format USB drive as FAT32"
echo "  2. Rename BIOS file to exactly: GIGABYTE.bin"
echo "  3. Place file in root of USB drive"
echo "  4. Power off system completely"
echo "  5. Insert USB into Q-Flash Plus port (usually white USB port)"
echo "  6. Press Q-Flash Plus button on motherboard rear I/O"
echo "  7. Wait for LED to stop flashing (3-8 minutes)"
echo
echo "Method 3: @BIOS Utility (Windows only)"
echo "  - Download @BIOS utility from Gigabyte website"
echo "  - Run in Windows to update BIOS"
echo

echo "════════════════════════════════════════════════════════════════════"
echo "  After BIOS Update"
echo "════════════════════════════════════════════════════════════════════"
echo
echo "1. Clear CMOS / Load Optimized Defaults"
echo "2. Check these settings:"
echo "   - AMD CBS → CPU Common Options → Downcore Control = Disabled"
echo "   - AMD CBS → CPU Common Options → SMT Control = Auto/Enabled"
echo "   - AMD CBS → CPU Common Options → CCD Control = All enabled"
echo "3. Save and exit"
echo "4. Boot into Linux and verify:"
echo "   lscpu | grep 'CPU(s)'"
echo "   # Should show 32 CPUs (16 cores × 2 threads)"
echo
echo "════════════════════════════════════════════════════════════════════"

# Offer to open browser
if command -v xdg-open >/dev/null 2>&1; then
    echo
    read -p "Open support page in browser? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Opening browser..."
        xdg-open "$SUPPORT_URL" 2>/dev/null &
    fi
fi

echo
echo "Download directory: ${DOWNLOAD_DIR}"
echo "Support URL: ${SUPPORT_URL}"
echo
