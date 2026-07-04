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

# Ensure board port is up-to-date (shared logic with setup_coreboot.sh)
info "Syncing board port files..."
"$SCRIPT_DIR/sync_board.sh"

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
if [ ! -f "$BLOB_DIR/Fsp.fd" ]; then
	warn "Missing: $BLOB_DIR/Fsp.fd (Jasper Lake FSP -- ROM would not boot without it)"
	MISSING_BLOBS=1
fi

if [ "$MISSING_BLOBS" -eq 1 ]; then
	error "Intel blobs are missing. IFD/ME come from the stock ROM:"
	echo ""
	echo "  make -C util/ifdtool"
	echo "  util/ifdtool/ifdtool -x $PROJECT_DIR/roms/oldbios.bin"
	echo "  mkdir -p $BLOB_DIR"
	echo "  mv flashregion_0_flashdescriptor.bin $BLOB_DIR/descriptor.bin"
	echo "  mv flashregion_2_intel_me.bin $BLOB_DIR/me.bin"
	echo ""
	echo "Fsp.fd is downloaded from dasharo-blobs."
	echo "Re-run ./scripts/setup_coreboot.sh to fetch/extract everything automatically."
	exit 1
fi

# ── Configure ──────────────────────────────────────────────────────────

# If existing .config isn't for our board, wipe it
if [ -f .config ] && ! grep -q "^CONFIG_BOARD_TECHVISION_TVI7309X=y" .config; then
	warn ".config is not for TVI7309X; regenerating from defconfig"
	rm -f .config
fi

# If the defconfig changed since .config was generated, regenerate so
# defconfig updates actually take effect (menuconfig tweaks are lost --
# run `make savedefconfig` and update coreboot/defconfig to keep them)
if [ -f .config ] && [ "$DEFCONFIG" -nt .config ]; then
	warn "defconfig is newer than .config; regenerating"
	rm -f .config
fi

if [ ! -f .config ]; then
	if [ ! -f "$DEFCONFIG" ]; then
		error "Missing $DEFCONFIG"
		exit 1
	fi
	info "Applying defconfig..."
	cp "$DEFCONFIG" .config
	# Force vendor + board selection BEFORE olddefconfig so selects propagate
	sed -i '/^CONFIG_VENDOR_/d; /^CONFIG_BOARD_/d; /^CONFIG_MAINBOARD_/d' .config
	echo 'CONFIG_VENDOR_TECHVISION=y' >> .config
	echo 'CONFIG_BOARD_TECHVISION_TVI7309X=y' >> .config
fi

info "Running olddefconfig to resolve symbol dependencies..."
make olddefconfig

# Sanity check: JSL must be selected
if ! grep -q "^CONFIG_SOC_INTEL_JASPERLAKE=y" .config; then
	error "Jasper Lake SoC not selected after olddefconfig — Kconfig is broken"
	error "Check that src/mainboard/techvision/tvi7309x/Kconfig selects SOC_INTEL_JASPERLAKE"
	exit 1
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
