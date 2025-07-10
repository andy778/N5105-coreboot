# N5105-coreboot
Topton N5105 coreboot investigation [N5105 Soft Router 4x 2.5G i226 LAN](https://www.toptonpc.com/product/12th-gen-intel-n100-firewall-computer-n6000-n5105-n5100-soft-router-4x-2-5g-i226-lan-industrial-fanless-mini-pc-pfsense-pve-esxi/?_gl=1*1akq4mb*_up*MQ..*_ga*MTYxMTY3ODA0My4xNzUyMTYzOTI1*_ga_5D4NM9G62C*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjgkajU0JGwwJGgw*_ga_F8C2ET9T2F*czE3NTIxNjM5MjIkbzEkZzEkdDE3NTIxNjM5MjkkajUzJGwwJGgyMDgxMTgwOTM)

## Hypotheis 
Investgigate if it's possible to have coreboot on this Topton N5105 firewall as latest coreboot release [25.06](https://blogs.coreboot.org/blog/2025/07/04/announcing-the-coreboot-release-25-06/) mentions [Topton](https://doc.coreboot.org/mainboard/topton/adl/x2f-n100.html),  CWWK CW-ADL-4L-V1.0 and CW-ADLNTB-1C2L-V3.0

* ~~ Add pictures of the motherboard ~~
* Search on internet if somone have done anything for this alreday
* Does there exist any bios update for this firewall
* What flash chipsets are used can I read them with the equipment I have 
* Can one figure out settings for coreboot with binwalk, ghidra, ...


## Reverse engineering 
From the [top](images/N5105_top.png) picture one get out the serial number [1338NP-12](https://www.bkipc.com/en/product/BKHD-1338NP-12-4L.html) and that gives it's actually BKHD that it's the manufacturer. 

Looks like they have a [BIOS](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) but they have only made on version of it and it's the same I have installed [AMI BIOS 2.22.1282](images/ami_bios.png)

### Update / Read flash 
Tried if flashrom that one use for [Protectli](https://teklager.se/en/knowledge-base/apu-bios-upgrade/) but this seems to complain

pkg install -y flashrom
flashrom -p internal -r oldbios.bin 


Looking inside the [BIOS](https://www.bkipc.com/en/download/file-1338NP-12-4L.html) one see thay have made a Fpt.efi binary and the actual 16Mb bios is inside 1.bin and 1.nsh is a script using both files   


## Hardware 

## Datasheets 
| Description | IC           |
| ---         |---           |
| flash       |4 x [Winbond 25Q28JVSO](https://www.alldatasheet.com/html-pdf/932084/WINBOND/25Q80DVSIG/2115/7/25Q80DVSIG.html)      |
| flash       |1 x [Winbond 25Q80DVSIG](https://www.alldatasheet.com/datasheet-pdf/pdf/932084/WINBOND/25Q80DVSIG.html)              |
