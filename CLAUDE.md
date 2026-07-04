# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo ports coreboot to a BKHD 1338NP-12 / Techvision TVI7309X rev B0 firewall board (Intel Celeron N5105 / Jasper Lake). The goal is to replace the stock AMI BIOS to eliminate potential firmware backdoors. The reference port is [Protectli vault_jsl](https://github.com/Dasharo/coreboot/tree/dasharo/src/mainboard/protectli/vault_jsl).

The `coreboot/` directory holds the board port source files (copied into the coreboot tree during build). The coreboot tree itself lives in `coreboot-build/` and is NOT tracked in git.

## Build Commands

```bash
# First-time setup: clone coreboot, install deps, build cross-compiler, extract blobs
./scripts/setup_coreboot.sh
# Optional flag to skip cross-compiler build (~30 min): --skip-toolchain

# Build the ROM (syncs coreboot/ into coreboot-build tree, then make)
./scripts/build.sh

# Interactive Kconfig editor
./scripts/build.sh menuconfig

# Clean build artifacts only
./scripts/build.sh clean

# Full clean including .config (REQUIRED when switching board configurations)
./scripts/build.sh distclean
```

Output ROM: `coreboot-build/build/coreboot.rom` (16 MB)

### Manual build (inside coreboot-build/)
```bash
make menuconfig         # Mainboard vendor: Techvision, model: TVI7309X
make savedefconfig      # Save minimal .config back to defconfig
make V=1                # Verbose output
make -j$(nproc)
```

### Utility commands
```bash
# Inspect CBFS contents of built ROM
build/util/cbfstool/cbfstool build/coreboot.rom print

# Extract IFD/ME/BIOS regions from stock ROM
build/util/ifdtool/ifdtool -x roms/oldbios.bin
build/util/ifdtool/ifdtool -d roms/oldbios.bin   # show layout

# Read/write flash on target (Linux)
sudo flashrom -p internal -r backup.bin
sudo flashrom -p internal -w build/coreboot.rom

# External programmer (FT232H + SOIC-8 clip)
flashrom -p ft2232_spi:type=232H -c W25Q128.V -r backup.bin
flashrom -p ft2232_spi:type=232H -c W25Q128.V -w build/coreboot.rom
```

## Repository Structure

```
coreboot/           Board port source (copied into coreboot tree by build scripts)
coreboot-build/     Cloned coreboot tree (not in git)
files/              Hardware dumps: dmidecode, inteltool GPIO, lspci
roms/               16 MB ROM images (oldbios.bin = flashrom dump, 1.bin = vendor)
scripts/            setup_coreboot.sh, build.sh
```

## Hardware Summary

| Component  | Detail |
|------------|--------|
| SoC        | Intel Celeron N5105 (Jasper Lake) |
| Board ID   | BKHD 1338NP-12 / Techvision TVI7309X rev B0 |
| RAM        | 2x DDR4 SO-DIMM 2667MHz (16 GB total) |
| Flash      | Winbond W25Q128JVSIQ, 16 MB SOIC-8, SPI |
| Ethernet   | 4x Intel I226-V on PCIe RP5-RP8 (00:1c.4–00:1c.7) |
| NVMe       | Samsung 980 on PCIe RP1 (00:1c.0 → bus 01) |
| Super I/O  | ITE IT8613E on eSPI (00:1f.0), base 0x2e |
| TPM        | Intel fTPM 2.0 (CRB MMIO at 0xfed40000) |

## Flash Layout

| Region           | Range                     | Size  |
|------------------|---------------------------|-------|
| Flash Descriptor | 0x00000000–0x00000FFF     | 4 KB  |
| ME Firmware      | 0x00001000–0x007FFFFF     | ~8 MB |
| BIOS             | 0x00800000–0x00FFFFFF     | 8 MB  |

`CBFS_SIZE` is 0x800000 (8 MB) to fit the BIOS region.

Blobs live in `coreboot-build/3rdparty/blobs/mainboard/techvision/tvi7309x/`:
- `descriptor.bin`, `me.bin` — extracted from the stock ROM by setup_coreboot.sh
- `Fsp.fd` — Jasper Lake FSP (not in the public IntelFsp/FSP repo; downloaded
  by setup_coreboot.sh from Dasharo's dasharo-blobs with SHA256 verification,
  split into FSP-M/FSP-S at build time via `FSP_FULL_FD`)

## Coreboot Coding Style

- **Indentation:** tabs, 8 characters wide. Never spaces.
- **Line length:** 96 columns max.
- **Braces:** K&R style — opening brace on same line for control flow; on next line for function definitions only. Omit braces for single-statement bodies unless one branch needs them.
- **Naming:** `lower_snake_case` for functions/variables; `UPPER_SNAKE_CASE` for macros/enum values. No Hungarian notation.
- **Types:** Use `u8`/`u16`/`u32`/`u64` or `uint8_t` equivalents. Avoid typedefs for structs/pointers. Return `enum cb_err` (`CB_SUCCESS`=0, `CB_ERR`=-1) from action functions.
- **Includes:** `<angle_brackets>` for all normal headers; `"quotes"` only for local headers in the same directory. Local includes after all angle-bracket includes.
- **Comments:** C89 `/* ... */` preferred; C99 `//` acceptable for single lines.
- **Error handling:** log with `printk(BIOS_ERR, ...)` and return error codes — continue booting. Use `die()` only when there is no way to continue. Use `assert()` for programmer logic errors only, never for hardware checks.
- **No trailing whitespace** — CI will reject it.

Full style reference: https://doc.coreboot.org/contributing/coding_style.html

## Safety

- Always keep a verified backup of `roms/oldbios.bin` before flashing anything.
- Have an FT232H + SOIC-8 clip ready for recovery before the first flash attempt.
- Run `make distclean` when switching board configurations.
- Test with serial console on COM1 at 115200 baud to diagnose first-boot issues.
