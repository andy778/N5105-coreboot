# N5105-coreboot
Investigate if it's possible to have coreboot bios on Topton N5105 to remove all toughts of suspicios software [N5105 Soft Router 4x 2.5G i226 LAN](https://www.toptonpc.com/product/12th-gen-intel-n100-firewall-computer-n6000-n5105-n5100-soft-router-4x-2-5g-i226-lan-industrial-fanless-mini-pc-pfsense-pve-esxi/?_gl=1*1akq4mb*_up*MQ..*_ga*MTYxMTY3ODA0My4xNzUyMTYzOTI1*_ga_5D4NM9G62C*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjgkajU0JGwwJGgw*_ga_F8C2ET9T2F*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjkkajUzJGwwJGgyMDgxMTgwOTM)

## Hypotheis 
Investgigate if it's possible to have coreboot on this Topton N5105 firewall as latest coreboot release [25.06](https://blogs.coreboot.org/blog/2025/07/04/announcing-the-coreboot-release-25-06/) mentions [Topton](https://doc.coreboot.org/mainboard/topton/adl/x2f-n100.html),  CWWK CW-ADL-4L-V1.0 and CW-ADLNTB-1C2L-V3.0

* ~~Add pictures of the motherboard~~ Done
* ~~Search on internet if somone have done anything for this alreday~~ No
* ~~Does there exist any bios update for this firewall~~ No 
* ~~What flash chipsets are used can I read them with the equipment I have~~ Maybe 
* Can one figure out settings for coreboot with binwalk, ghidra, ...


## Reverse engineering 
From the [top](images/N5105_top.png) picture one get out the serial number [1338NP-12](https://www.bkipc.com/en/product/BKHD-1338NP-12-4L.html) and that gives it's actually BKHD that it's the manufacturer. 

Looks like they have a [BIOS](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) but they have only made on version of it and it's the same I have installed [AMI BIOS 2.22.1282](images/ami_bios.png)

## Read flash 
### Read with flashrom with [OPNsense](https://opnsense.org/) 25.1
Tried if flashrom that one use for [Protectli](https://teklager.se/en/knowledge-base/apu-bios-upgrade/) but this seems to complain

```
# Install flashrom on opnsence
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
Looking inside the [BIOS](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) one see thay have made a Fpt.efi binary and the actual 16Mb bios is inside 1.bin and 1.nsh is a script using both files   

### Read with FT232H 

The 25Q80DVSIG is very close to the EN24A201S and condencator so getting and SOTC 8 testclip is impossible. 

```
flashrom -p ft2232_spi:type=232H -c W25Q128.V -r oldbios.bin
```
## Inspect the the rom file

* [1.bin](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) and [oldbios.bin](roms/oldbios.bin) have same size 16M
* [1.bin](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) and [oldbios.bin](roms/oldbios.bin) differs in checksum (md5sum *.bin)


## Hardware 

## Datasheets 
| Description            | IC           |
| ---                    |---           |
| flash                  |4 x [Winbond 25Q28JVSO](https://www.alldatasheet.com/html-pdf/932084/WINBOND/25Q80DVSIG/2115/7/25Q80DVSIG.html)      |
| flash                  |1 x [Winbond 25Q80DVSIG](https://www.alldatasheet.com/datasheet-pdf/pdf/932084/WINBOND/25Q80DVSIG.html)              |
| isolation transformers |4 x EN24A201S|
