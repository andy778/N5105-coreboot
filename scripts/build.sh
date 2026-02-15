#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# build.sh - Configure and build coreboot ROM for Techvision TVI7309X
#
# Usage:
#   ./scripts/build.sh              # Full build with defconfig
#   ./scripts/build.sh menuconfig   # Open interactive config
#   ./scripts/build.sh clean        # Clean build artifacts
#   ./scripts/build.sh distclean    # Full clean including .config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COREBOOT_DIR="$PROJECT_DIR/coreboot-build"
BOARD_SRC="$PROJECT_DIR/coreboot"
BOARD_DEST="src/mainboard/techvision/tvi7309x"
DEFCONFIG="$BOARD_SRC/defconfig"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [ ! -d "$COREBOOT_DIR" ]; then
	error "coreboot tree not found at $COREBOOT_DIR"
	error "Run ./scripts/setup_coreboot.sh first"
	exit 1
fi

cd "$COREBOOT_DIR"

# Ensure board port is up-to-date
info "Syncing board port files..."
mkdir -p "$BOARD_DEST"
# Copy board-specific files (not Kconfig - handled separately)
cp -v "$BOARD_SRC"/*.c "$BOARD_SRC"/*.h "$BOARD_SRC"/*.cb \
      "$BOARD_SRC"/Kconfig.name \
      "$BOARD_SRC"/Makefile.mk "$BOARD_DEST/" 2>/dev/null || true
# Copy vendor Kconfig to parent directory
if [ -f "$BOARD_SRC/Kconfig" ]; then
    mkdir -p "$(dirname "$BOARD_DEST")"
    cp -v "$BOARD_SRC/Kconfig" "$(dirname "$BOARD_DEST")/" 2>/dev/null || true
fi

# Handle subcommands
case "${1:-build}" in
	menuconfig)
		info "Opening menuconfig..."
		make menuconfig
		exit 0
		;;
	clean)
		info "Cleaning build artifacts..."
		make clean
		exit 0
		;;
	distclean)
		info "Full clean (build + config)..."
		make distclean
		exit 0
		;;
	build)
		;;
	*)
		error "Unknown command: $1"
		echo "Usage: $0 [build|menuconfig|clean|distclean]"
		exit 1
		;;
esac

# ── Verify required blobs ──────────────────────────────────────────────

BLOB_DIR="3rdparty/blobs/mainboard/techvision/tvi7309x"
MISSING_BLOBS=0

if [ ! -f "$BLOB_DIR/descriptor.bin" ]; then
	warn "Missing: $BLOB_DIR/descriptor.bin"
	MISSING_BLOBS=1
fi
if [ ! -f "$BLOB_DIR/me.bin" ]; then
	warn "Missing: $BLOB_DIR/me.bin"
	MISSING_BLOBS=1
fi

if [ "$MISSING_BLOBS" -eq 1 ]; then
	error "Intel blobs are missing. Extract them from the stock ROM:"
	echo ""
	echo "  make -C util/ifdtool"
	echo "  util/ifdtool/ifdtool -x $PROJECT_DIR/roms/oldbios.bin"
	echo "  mkdir -p $BLOB_DIR"
	echo "  mv flashregion_0_flashdescriptor.bin $BLOB_DIR/descriptor.bin"
	echo "  mv flashregion_2_intel_me.bin $BLOB_DIR/me.bin"
	echo ""
	echo "Or re-run ./scripts/setup_coreboot.sh to extract automatically."
	exit 1
fi

# ── Configure ──────────────────────────────────────────────────────────

if [ ! -f .config ]; then
	if [ -f "$DEFCONFIG" ]; then
		info "Applying defconfig..."
		# Remove any board-specific lines from defconfig before applying
		grep -v "BOARD_TECHVISION\|VENDOR_TECHVISION" "$DEFCONFIG" > /tmp/defconfig.tmp
		cp /tmp/defconfig.tmp .config
		rm /tmp/defconfig.tmp
	else
		warn "No .config found. Run: $0 menuconfig"
		exit 1
	fi
fi

# Patch config 
info "Patching config for TVI7309X board..."
# Disable emulation vendor first
sed -i 's/^CONFIG_VENDOR_EMULATION=y/# CONFIG_VENDOR_EMULATION is not set/' .config 2>/dev/null || true
# Add techvision vendor if not present
if ! grep -q "^CONFIG_VENDOR_TECHVISION=y" .config 2>/dev/null; then
	echo 'CONFIG_VENDOR_TECHVISION=y' >> .config
fi

# Run olddefconfig to set defaults but ignore errors from unknown symbols
make olddefconfig 2>&1 || true

# Add the board config after olddefconfig
if ! grep -q "^CONFIG_BOARD_TECHVISION_TVI7309X=y" .config 2>/dev/null; then
	echo 'CONFIG_BOARD_TECHVISION_TVI7309X=y' >> .config
fi

# ── Build ──────────────────────────────────────────────────────────────

info "Building coreboot ROM..."
make -j"$(nproc)"

ROM="build/coreboot.rom"
if [ -f "$ROM" ]; then
	SIZE=$(stat -c%s "$ROM" 2>/dev/null || stat -f%z "$ROM" 2>/dev/null)
	info ""
	info "=== Build successful ==="
	info "ROM: $COREBOOT_DIR/$ROM ($SIZE bytes)"
	info ""
	info "Inspect contents:"
	info "  build/util/cbfstool/cbfstool $ROM print"
	info ""
	info "Flash to target (from Linux on the device):"
	info "  sudo flashrom -p internal -w $ROM"
	info ""
	info "Flash via external programmer:"
	info "  flashrom -p ft2232_spi:type=232H -c W25Q128.V -w $ROM"
else
	error "Build failed -- no ROM produced"
	exit 1
fi
