#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# setup_coreboot.sh - Clone coreboot, install board port, build toolchain
#
# Targets a BKHD 1338NP-12 / Techvision TVI7309X B0 (Jasper Lake N5105)
# Reference: Protectli vault_jsl (Dasharo)
#
# Usage: ./scripts/setup_coreboot.sh [--skip-toolchain]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COREBOOT_DIR="$PROJECT_DIR/coreboot-build"
BOARD_SRC="$PROJECT_DIR/coreboot"
BOARD_DEST="src/mainboard/techvision/tvi7309x"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Step 1: Install build dependencies ──────────────────────────────────

install_deps() {
	info "Installing build dependencies..."

	if command -v apt-get &>/dev/null; then
		sudo apt-get update
		sudo apt-get install -y \
			bison build-essential curl flex git gnat \
			libncurses-dev libssl-dev zlib1g-dev pkgconf \
			m4 wget python3 python-is-python3 \
			flashrom ifdtool
	elif command -v dnf &>/dev/null; then
		sudo dnf install -y \
			git make gcc-gnat flex bison xz bzip2 gcc g++ \
			ncurses-devel wget zlib-devel patch \
			openssl-devel pkgconf flashrom
	elif command -v pacman &>/dev/null; then
		sudo pacman -S --needed \
			base-devel curl git gcc-ada ncurses zlib \
			openssl python flashrom
	else
		error "Unsupported package manager. Install deps manually:"
		echo "  bison build-essential curl flex git gnat libncurses-dev"
		echo "  libssl-dev zlib1g-dev pkgconf m4 wget flashrom"
		exit 1
	fi
}

# ── Step 2: Clone coreboot ──────────────────────────────────────────────

clone_coreboot() {
	if [ -d "$COREBOOT_DIR/.git" ]; then
		info "coreboot already cloned at $COREBOOT_DIR"
		return
	fi

	info "Cloning coreboot..."
	git clone https://review.coreboot.org/coreboot "$COREBOOT_DIR"

	info "Initializing submodules..."
	cd "$COREBOOT_DIR"
	git submodule update --init --checkout

	# Enable binary blobs (needed for Intel FSP and ME)
	info "Enabling blobs submodule..."
	git submodule update --init 3rdparty/blobs
	git submodule update --init 3rdparty/fsp
	git submodule update --init 3rdparty/intel-microcode
}

# ── Step 3: Build cross-compiler toolchain ──────────────────────────────

build_toolchain() {
	if [ "${1:-}" = "--skip-toolchain" ]; then
		warn "Skipping toolchain build (--skip-toolchain)"
		return
	fi

	cd "$COREBOOT_DIR"

	if [ -f "util/crossgcc/xgcc/bin/i386-elf-gcc" ]; then
		info "i386 cross-compiler already built"
		return
	fi

	info "Building i386 cross-compiler toolchain (this takes 20-40 min)..."
	make crossgcc-i386 CPUS="$(nproc)"
}

# ── Step 4: Install board port files ────────────────────────────────────

install_board_port() {
	if [ ! -d "$BOARD_SRC" ] || [ -z "$(ls -A "$BOARD_SRC" 2>/dev/null)" ]; then
		error "No board port files found in $BOARD_SRC"
		error "Expected files: Kconfig, Kconfig.name, devicetree.cb, etc."
		exit 1
	fi

	info "Installing board port to $BOARD_DEST ..."
	"$SCRIPT_DIR/sync_board.sh"
	info "Board port installed."
}

# ── Step 5: Download Jasper Lake FSP ────────────────────────────────────
#
# JSL FSP binaries are NOT in the public IntelFsp/FSP repo. Dasharo
# redistributes Intel's JasperLakeFspBinPkg (from the JSL_BIOS_3332_00
# kit) for their Protectli vault_jsl port; coreboot splits the combined
# FSP.fd into FSP-M/FSP-S at build time.

FSP_URL="https://raw.githubusercontent.com/Dasharo/dasharo-blobs/main/protectli/vault_jsl/JasperLakeFspBinPkg/FSP.fd"
FSP_SHA256="ab04314cce7fd51073331b98c796bcb6e74df59028db6a96df6561aba30f15d3"

download_fsp() {
	local BLOB_DIR="$COREBOOT_DIR/3rdparty/blobs/mainboard/techvision/tvi7309x"
	local FSP_FD="$BLOB_DIR/Fsp.fd"

	if [ -f "$FSP_FD" ] && echo "$FSP_SHA256  $FSP_FD" | sha256sum -c --quiet - 2>/dev/null; then
		info "Jasper Lake FSP already present and verified."
		return
	fi

	info "Downloading Jasper Lake FSP from dasharo-blobs..."
	mkdir -p "$BLOB_DIR"
	curl -sL -o "$FSP_FD" "$FSP_URL"

	if ! echo "$FSP_SHA256  $FSP_FD" | sha256sum -c --quiet -; then
		error "FSP.fd checksum mismatch -- refusing to use it"
		rm -f "$FSP_FD"
		exit 1
	fi
	info "FSP verified: $FSP_FD"
}

# ── Step 6: Extract blobs from stock ROM ────────────────────────────────

extract_blobs() {
	cd "$COREBOOT_DIR"
	local STOCK_ROM="$PROJECT_DIR/roms/oldbios.bin"
	local BLOB_DIR="$COREBOOT_DIR/3rdparty/blobs/mainboard/techvision/tvi7309x"

	if [ ! -f "$STOCK_ROM" ]; then
		warn "Stock ROM not found at $STOCK_ROM"
		warn "You need oldbios.bin to extract IFD and ME firmware."
		warn "Read it with: flashrom -p internal -r oldbios.bin"
		return
	fi

	info "Building ifdtool..."
	make -C util/ifdtool

	info "Extracting flash regions from stock ROM..."
	mkdir -p "$BLOB_DIR"
	util/ifdtool/ifdtool -x "$STOCK_ROM"

	# ifdtool outputs: flashregion_0_flashdescriptor.bin,
	#                   flashregion_1_bios.bin,
	#                   flashregion_2_intel_me.bin
	if [ -f "flashregion_0_flashdescriptor.bin" ]; then
		mv flashregion_0_flashdescriptor.bin "$BLOB_DIR/descriptor.bin"
		info "  Extracted: descriptor.bin"
	fi
	if [ -f "flashregion_2_intel_me.bin" ]; then
		mv flashregion_2_intel_me.bin "$BLOB_DIR/me.bin"
		info "  Extracted: me.bin"
	fi
	# Clean up the BIOS region extract (we don't need it)
	rm -f flashregion_1_bios.bin

	info "Blobs extracted to $BLOB_DIR"
	info ""
	info "Optional: Minimize ME firmware to reduce attack surface:"
	info "  python3 util/me_cleaner/me_cleaner.py -S $BLOB_DIR/me.bin"
}

# ── Main ────────────────────────────────────────────────────────────────

main() {
	info "=== N5105 Coreboot Setup ==="
	info "Board: BKHD 1338NP-12 / Techvision TVI7309X B0"
	info "SoC:   Intel Celeron N5105 (Jasper Lake)"
	info ""

	install_deps
	clone_coreboot
	build_toolchain "$@"
	install_board_port
	download_fsp
	extract_blobs

	info ""
	info "=== Setup complete ==="
	info ""
	info "Next steps:"
	info "  1. Review/edit the board config:"
	info "     $COREBOOT_DIR/$BOARD_DEST/devicetree.cb"
	info ""
	info "  2. Build the ROM:"
	info "     ./scripts/build.sh"
	info ""
	info "  3. The output ROM will be at:"
	info "     $COREBOOT_DIR/build/coreboot.rom"
}

main "$@"
