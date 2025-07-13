# N5105-coreboot
Investigate if it's possible to have coreboot BIOS on Topton N5105 to remove all thoughts of suspicious software [N5105 Soft Router 4x 2.5G i226 LAN](https://www.toptonpc.com/product/12th-gen-intel-n100-firewall-computer-n6000-n5105-n5100-soft-router-4x-2-5g-i226-lan-industrial-fanless-mini-pc-pfsense-pve-esxi/?_gl=1*1akq4mb*_up*MQ..*_ga*MTYxMTY3ODA0My4xNzUyMTYzOTI1*_ga_5D4NM9G62C*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjgkajU0JGwwJGgw*_ga_F8C2ET9T2F*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjkkajUzJGwwJGgyMDgxMTgwOTM)

## Hypothesis 
Investigate if it's possible to have coreboot on this Topton N5105 firewall as the latest coreboot release [25.06](https://blogs.coreboot.org/blog/2025/07/04/announcing-the-coreboot-release-25-06/) mentions [Topton](https://doc.coreboot.org/mainboard/topton/adl/x2f-n100.html), CWWK CW-ADL-4L-V1.0 and CW-ADLNTB-1C2L-V3.0

* ~~Add pictures of the motherboard~~ Done
* ~~Search on the internet if someone has done anything for this already~~ No
* ~~Does there exist any BIOS update for this firewall~~ No 
* ~~What flash chipsets are used? Can I read them with the equipment I have?~~ Maybe 
* Can one figure out settings for coreboot with Ghidra, ...

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

## Investigate from OS

Use [inteltool](https://doc.coreboot.org/util/intelp2m/index.html) to get [inteltool.log](files/inteltool.log) data to generate [gpio.h](files/gpio.h)

```
sudo inteltool -G > inteltool.log
# This generates gpio.h in output directory 
intelp2m -platform jsl -file inteltool.log
```

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
