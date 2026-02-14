# N5105-coreboot
Investigate if it's possible to have coreboot BIOS on Topton N5105 to remove all thoughts of suspicious software [N5105 Soft Router 4x 2.5G i226 LAN](https://www.toptonpc.com/product/12th-gen-intel-n100-firewall-computer-n6000-n5105-n5100-soft-router-4x-2-5g-i226-lan-industrial-fanless-mini-pc-pfsense-pve-esxi/?_gl=1*1akq4mb*_up*MQ..*_ga*MTYxMTY3ODA0My4xNzUyMTYzOTI1*_ga_5D4NM9G62C*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjgkajU0JGwwJGgw*_ga_F8C2ET9T2F*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjkkajUzJGwwJGgyMDgxMTgwOTM)

## Hypothesis 
Investigate if it's possible to have coreboot on this Topton N5105 firewall as the latest coreboot release [25.06](https://blogs.coreboot.org/blog/2025/07/04/announcing-the-coreboot-release-25-06/) mentions [Topton](https://doc.coreboot.org/mainboard/topton/adl/x2f-n100.html), CWWK CW-ADL-4L-V1.0 and CW-ADLNTB-1C2L-V3.0

- [x] Add pictures of the motherboard
- [x] Search on the internet if someone has done anything for this already
- [x] Does there exist any BIOS update for this firewall 
- [x] What flash chipsets are used? Can I read them with the equipment I have?
- [ ] Investigate probability for malware https://github.com/andy778/N5105-coreboot/issues/1 

## Reverse engineering 
From the [top](images/N5105_top.png) picture one gets the serial number [1338NP-12](https://www.bkipc.com/en/product/BKHD-1338NP-12-4L.html), and that shows it's actually BKHD that is the manufacturer. 

It looks like they have a [BIOS](https://www.bkipc.com/en/download/file-1338NP-12-4L.html), but they have only made one version of it, and it's the same I have installed [AMI BIOS 2.22.1282](images/ami_bios.png).

## Read flash 
### Read with flashrom with [OPNsense](https://opnsense.org/) 25.1
Tried using flashrom, which is used for [Protectli](https://teklager.se/en/knowledge-base/apu-bios-upgrade/), but this seems to complain:

```
# Install flashrom on opnsense
pkg install -y flashrom

flashrom -p internal:boardmismatch=force -r oldbios.bin
flashrom v1.3.0 on FreeBSD 14.2-RELEASE-p3 (amd64)
flashrom is free software, get the source code at https://flashrom.org
Using clock_gettime for delay loops (clk_id: 4, resolution: 1ns).
No DMI table found.
Found chipset "Intel Jasper Lake".
Enabling flash write... pcilib: This access method is not supported.
```
### Read with flashrom with [Kali Live Boot](https://www.kali.org/get-kali/#kali-platforms) 2025.2
```
sudo flashrom -p internal -r oldbios.bin
flashrom 1.4.0 on Linux 6.12.25-amd64 (x86_64)
flashrom is free software, get the source code at https://flashrom.org

No DMI table found.
Found chipset "Intel Jasper Lake".
Enabling flash write... SPI Configuration is locked down.
FREG0: Flash Descriptor region (0x00000000-0x00000fff) is read-write.
FREG1: BIOS region (0x00800000-0x00ffffff) is read-write.
FREG2: Management Engine region (0x00001000-0x007fffff) is read-write.
Enabling hardware sequencing because some important opcode is locked.
OK.
Found Winbond flash chip "W25Q128.V" (16384 kB, Programmer-specific) on internal.
Reading flash... done.
```

### Read with efi tools
Looking inside the [BIOS](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) one sees they have made an Fpt.efi binary and the actual 16Mb BIOS is inside 1.bin, and 1.nsh is a script using both files.   

### Read with FT232H 

The 25Q128JVSO is very close to the EN24A201S and capacitor, so getting an SOTC 8 test clip is very tricky, maybe some soldering or very samll testclips? 

```
flashrom -p ft2232_spi:type=232H -c W25Q128.V -r oldbios.bin
```
## Inspect the ROM file

* [1.bin](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) and [oldbios.bin](roms/oldbios.bin) have the same size 16M
* [1.bin](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) and [oldbios.bin](roms/oldbios.bin) differ in checksum (md5sum *.bin)
* Probability of malware in the AMI BIOS #1

## Investigate from OS

Use [inteltool](https://doc.coreboot.org/util/intelp2m/index.html) to get [inteltool.log](files/inteltool.log) data to generate [gpio.h](files/gpio.h)

```
sudo inteltool -G > inteltool.log
# This generates gpio.h in output directory 
intelp2m -platform jsl -file inteltool.log
```
## Template to start from?
Probably [Protectli V1*10](https://github.com/Dasharo/coreboot/tree/dasharo/src/mainboard/protectli/vault_jsl)

## Building coreboot

The board port source files live in `coreboot/` and the helper scripts in `scripts/`. The coreboot tree itself is cloned during setup -- it is not part of this repo.

### Build on Linux (recommended)

Debian/Ubuntu is the recommended build environment.

#### Quick start
```bash
# 1. Install dependencies, clone coreboot, build toolchain, extract blobs
chmod +x scripts/setup_coreboot.sh
./scripts/setup_coreboot.sh

# 2. Build the ROM
chmod +x scripts/build.sh
./scripts/build.sh

# Output: coreboot-build/build/coreboot.rom (16 MB)
```

#### Manual step-by-step
```bash
# Install build dependencies (Debian/Ubuntu)
sudo apt-get install -y bison build-essential curl flex git gnat \
    libncurses-dev libssl-dev zlib1g-dev pkgconf m4 wget flashrom

# Clone coreboot and initialise submodules
git clone https://review.coreboot.org/coreboot coreboot-build
cd coreboot-build
git submodule update --init --checkout
git submodule update --init 3rdparty/blobs
git submodule update --init 3rdparty/fsp
git submodule update --init 3rdparty/intel-microcode

# Build the cross-compiler (one-time, ~30 min)
make crossgcc-i386 CPUS=$(nproc)

# Copy the board port into the coreboot tree
mkdir -p src/mainboard/techvision/tvi7309x
cp ../coreboot/* src/mainboard/techvision/tvi7309x/

# Extract Intel Flash Descriptor and ME firmware from stock ROM
make -C util/ifdtool
util/ifdtool/ifdtool -x ../roms/oldbios.bin
mkdir -p 3rdparty/blobs/mainboard/techvision/tvi7309x
mv flashregion_0_flashdescriptor.bin 3rdparty/blobs/mainboard/techvision/tvi7309x/descriptor.bin
mv flashregion_2_intel_me.bin 3rdparty/blobs/mainboard/techvision/tvi7309x/me.bin
rm -f flashregion_1_bios.bin

# Configure (use the defconfig, or run `make menuconfig` to customise)
cp src/mainboard/techvision/tvi7309x/defconfig .config
make olddefconfig

# Build
make -j$(nproc)
# Output: build/coreboot.rom
```

### Build on Windows (via WSL2)

coreboot does **not** build natively on Windows. Use [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) with a Debian or Ubuntu distribution:

```powershell
# 1. Install WSL2 (from an Administrator PowerShell)
wsl --install -d Ubuntu

# 2. Reboot, then open the Ubuntu terminal
```

Inside the WSL2 Ubuntu terminal:
```bash
# Access the repo (assuming it is cloned under your Windows home directory)
cd /mnt/c/Users/$USER/N5105-coreboot

# From here the steps are identical to the Linux build above
chmod +x scripts/setup_coreboot.sh
./scripts/setup_coreboot.sh
./scripts/build.sh
```

> **Note:** Build performance is significantly better if the coreboot tree
> lives on the Linux filesystem (`~/coreboot-build`) rather than on the
> mounted Windows drive (`/mnt/c/...`). The setup script places it next
> to the repo by default.

### Flashing

```bash
# From Linux on the target device
sudo flashrom -p internal -w build/coreboot.rom

# Via external FT232H programmer
flashrom -p ft2232_spi:type=232H -c W25Q128.V -w build/coreboot.rom
```

## Coreboot port TODO

Before the coreboot ROM is ready for first boot, these items need attention:

- [ ] Dump SPD data from the installed DIMMs (`decode-dimms` or `i2cdump`) and add to CBFS
- [ ] Verify DQ/DQS memory maps -- currently copied from Protectli vault_jsl; may need tuning if memory training fails
- [ ] Extract VBT (Video BIOS Table) from stock ROM for display output (`cbfstool oldbios.bin extract -n vbt.bin`)
- [ ] Test with serial console connected (COM1, 115200 baud) to diagnose first-boot issues
- [ ] Have external SPI programmer (FT232H + SOIC-8 clip) ready for recovery before first flash
- [ ] Validate PCIe clock source assignment for the 4x I226-V NICs and NVMe slot
- [ ] Investigate probability for malware https://github.com/andy778/N5105-coreboot/issues/1

## Hardware 

## Datasheets 
| Description            | IC           |
| ---                    |---           |
| flash 128MBIT          |1 x [Winbond 25Q128JVSO](https://www.alldatasheet.com/datasheet-pdf/pdf/1243793/WINBOND/W25Q128JVSIQ.html)      |
| flash 8MBIT            |4 x [Winbond 25Q80DVSIG](https://www.alldatasheet.com/datasheet-pdf/pdf/932084/WINBOND/25Q80DVSIG.html)         |
| isolation transformers |4 x EN24A201S|
| Ethernet I226-V        |4 x S2453L30|
| Super I/O              |1 x IT8613E|
| Regulator              |1 x GS7166|
