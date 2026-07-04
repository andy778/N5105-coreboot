#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# sync_board.sh - Sync the board port from coreboot/ into the coreboot tree.
# Called by build.sh and setup_coreboot.sh; safe to run repeatedly.
#
# Kconfig layout in the coreboot tree:
#   coreboot/Kconfig             -> src/mainboard/techvision/Kconfig                (vendor)
#   coreboot/vendor.Kconfig.name -> src/mainboard/techvision/Kconfig.name           (vendor menu)
#   coreboot/board.Kconfig       -> src/mainboard/techvision/tvi7309x/Kconfig       (board)
#   coreboot/Kconfig.name        -> src/mainboard/techvision/tvi7309x/Kconfig.name  (board menu)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COREBOOT_DIR="$PROJECT_DIR/coreboot-build"
BOARD_SRC="$PROJECT_DIR/coreboot"
BOARD_DEST="$COREBOOT_DIR/src/mainboard/techvision/tvi7309x"
VENDOR_DIR="$(dirname "$BOARD_DEST")"

if [ ! -d "$COREBOOT_DIR" ]; then
	echo "[ERROR] coreboot tree not found at $COREBOOT_DIR" >&2
	echo "[ERROR] Run ./scripts/setup_coreboot.sh first" >&2
	exit 1
fi

# Start from a clean board directory so renamed/removed files don't linger
rm -rf "$BOARD_DEST"
mkdir -p "$BOARD_DEST"

cp -v "$BOARD_SRC"/*.c "$BOARD_SRC"/*.h "$BOARD_SRC"/*.cb "$BOARD_SRC"/*.asl \
      "$BOARD_SRC"/*.vbt "$BOARD_SRC"/board_info.txt \
      "$BOARD_SRC"/Kconfig.name "$BOARD_SRC"/Makefile.mk "$BOARD_DEST/"

cp -v "$BOARD_SRC/Kconfig"             "$VENDOR_DIR/Kconfig"
cp -v "$BOARD_SRC/vendor.Kconfig.name" "$VENDOR_DIR/Kconfig.name"
cp -v "$BOARD_SRC/board.Kconfig"       "$BOARD_DEST/Kconfig"
