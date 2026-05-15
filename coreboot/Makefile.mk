# SPDX-License-Identifier: GPL-2.0-only

bootblock-y += bootblock.c

romstage-y += romstage.c

ramstage-y += mainboard.c

# SPD data: hex file under spd/, combined into spd.bin via HAVE_SPD_IN_CBFS.
# Both channels use spd_index=0 (Kingston) in romstage.c; the Samsung DIMM
# is treated as compatible for first-boot since both are DDR4-2667 8GB.
SPD_SOURCES += kingston8gb
