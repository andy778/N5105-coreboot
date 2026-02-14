# AGENTS.md - N5105 Coreboot Porting Project

## Project Overview

This repo ports coreboot to a BKHD 1338NP-12 / Techvision TVI7309X rev B0
firewall board with Intel Celeron N5105 (Jasper Lake), 4x Intel I226-V 2.5G
NICs, ITE IT8613E Super I/O, and Winbond W25Q128JVSIQ 16MB SPI flash.
Goal: replace stock AMI BIOS to eliminate potential firmware backdoors.

Reference board port: Protectli vault_jsl (Dasharo coreboot fork).

## Repository Structure

```
files/                  # Hardware data dumps from the running system
  dmidecode.txt         # DMI/SMBIOS tables (Techvision TVI7309X B0)
  gpio.h                # GPIO pad config (inteltool + intelp2m -platform jsl)
  inteltool.log         # Raw inteltool -G output
  lspci.txt             # PCI device list
  lspcivvv.txt          # Verbose PCI topology
images/                 # Motherboard photos, BIOS screenshots
roms/                   # 16 MB ROM images
  oldbios.bin           # Dump read from flash via flashrom on Linux
  1.bin                 # Manufacturer-provided BIOS from bkipc.com
coreboot/               # Mainboard port source files (for copying into coreboot tree)
  Kconfig               # Board Kconfig options
  Kconfig.name          # Board menu name
  Makefile.mk           # Build rules
  devicetree.cb         # PCI device tree matching this board's lspci
  gpio.h                # GPIO config (copy of files/gpio.h)
  bootblock.c           # Early init: Super I/O, serial, watchdog
  romstage.c            # Memory init parameters (DDR4 SO-DIMM)
  mainboard.c           # Ramstage board init, SMBIOS
scripts/
  setup_coreboot.sh     # Clone coreboot, install board port, build toolchain
  build.sh              # Configure and build the ROM
```

## Hardware Summary

| Component       | Detail                                              |
|-----------------|-----------------------------------------------------|
| SoC             | Intel Celeron N5105 @ 2.00GHz (Jasper Lake, JSL)    |
| Board ID        | BKHD 1338NP-12 / Techvision TVI7309X rev B0         |
| RAM             | 2x DDR4 SO-DIMM 2667MHz (Kingston + Samsung, 16GB)  |
| Flash           | Winbond W25Q128JVSIQ, 16 MB, SOIC-8                 |
| Ethernet        | 4x Intel I226-V on PCIe RP5-RP8 (00:1c.4-00:1c.7)  |
| NVMe            | Samsung 980 on PCIe RP1 (00:1c.0 -> bus 01)         |
| Super I/O       | ITE IT8613E on eSPI (00:1f.0), base 0x2e            |
| SATA            | Intel JSL AHCI (00:17.0)                             |
| TPM             | Intel fTPM 2.0 (firmware)                            |
| ME              | Intel CSME 15.0.x (JSL)                              |
| Audio           | Intel JSL HD Audio (00:1f.3)                         |

## Build Commands

All builds run on Linux (Debian/Ubuntu recommended). This repo does NOT
contain the coreboot source tree -- the setup script clones it.

### Quick Start
```bash
# 1. Run setup (clones coreboot, installs deps, builds toolchain)
chmod +x scripts/setup_coreboot.sh
./scripts/setup_coreboot.sh

# 2. Build the ROM
chmod +x scripts/build.sh
./scripts/build.sh
```

### Manual Build
```bash
git clone https://review.coreboot.org/coreboot
cd coreboot && git submodule update --init --checkout

# Build cross-compiler (one-time, ~30 min)
make crossgcc-i386 CPUS=$(nproc)

# Copy board port into coreboot tree
mkdir -p src/mainboard/techvision/tvi7309x
cp ../coreboot/* src/mainboard/techvision/tvi7309x/

# Configure
make menuconfig
# Mainboard vendor -> Techvision
# Mainboard model  -> TVI7309X

# Build
make -j$(nproc)
# Output: build/coreboot.rom
```

### Key Make Targets
```bash
make menuconfig         # Interactive config
make savedefconfig      # Save minimal .config to defconfig
make V=1                # Verbose build output
make clean              # Remove build artifacts
make distclean          # Remove build + .config (REQUIRED when switching boards)
```

### Utility Commands
```bash
# Extract IFD/ME/BIOS regions from stock ROM
build/util/ifdtool/ifdtool -x roms/oldbios.bin

# Show flash descriptor layout
build/util/ifdtool/ifdtool -d roms/oldbios.bin

# Inspect CBFS contents of built ROM
build/util/cbfstool/cbfstool build/coreboot.rom print

# Read flash on target (Linux live boot)
sudo flashrom -p internal -r backup.bin

# Write flash on target
sudo flashrom -p internal -w build/coreboot.rom

# External programmer (FT232H)
flashrom -p ft2232_spi:type=232H -c W25Q128.V -r backup.bin
flashrom -p ft2232_spi:type=232H -c W25Q128.V -w build/coreboot.rom
```

## Flash Layout (from stock ROM)

| Region              | Start      | End        | Size   |
|---------------------|------------|------------|--------|
| Flash Descriptor    | 0x00000000 | 0x00000FFF | 4 KB   |
| ME Firmware         | 0x00001000 | 0x007FFFFF | ~8 MB  |
| BIOS                | 0x00800000 | 0x00FFFFFF | 8 MB   |

SPI configuration is locked, but all regions report read-write access.
CBFS_SIZE is set to 0x800000 (8 MB) to fit the BIOS region.

## Coreboot Coding Style

Full reference: https://doc.coreboot.org/contributing/coding_style.html

### Formatting
- **Tabs:** 8 characters. Never use spaces for indentation.
- **Line length:** 96 columns max (not 80).
- **No trailing whitespace** -- CI rejects it.
- **Braces:** K&R style. Opening brace on same line as if/for/while/switch.
  Opening brace on NEXT line for function definitions only.
- Omit braces for single-statement bodies unless one branch needs them.

### Naming
- Functions/variables: `lower_snake_case`
- Macros/enum values: `UPPER_SNAKE_CASE`
- No Hungarian notation. Short locals (i, tmp, ret) are fine.
- Globals must have descriptive names.

### Types
- Use `u8`/`u16`/`u32`/`u64` or `uint8_t` etc. -- both accepted.
- Avoid typedefs for structs/pointers.
- Return `enum cb_err` (`CB_SUCCESS`=0, `CB_ERR`=-1) from action functions.

### Includes
- `#include <file.h>` for all normal includes.
- `#include "file.h"` only for local headers in the same directory.
- Local includes after all angle-bracket includes.
- `<kconfig.h>`, `<rules.h>`, `<commonlib/bsd/compiler.h>` are auto-included.

### Comments
- Prefer C89 `/* ... */`. C99 `//` acceptable for single lines.
- Tell WHAT the code does, not HOW.

### Error Handling
- Log with `printk(BIOS_ERR, ...)` and return error codes. Continue booting.
- `die()` only when no way to continue (failed stage load, memory init).
- `assert()` for programmer logic errors only, never for hardware checks.

### Kconfig
- One tab indent under `config`. Help text: one tab + two spaces.

## Safety Warnings

- ALWAYS keep a verified backup of oldbios.bin before flashing.
- Have an external SPI programmer (FT232H + SOIC-8 clip) for recovery.
- The flash chip is physically close to other components -- use care.
- Never flash a ROM built for a different board.
- Run `make distclean` when switching board configurations.
- Test with serial console connected (COM1 at 115200 baud).
