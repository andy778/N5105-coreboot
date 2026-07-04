/* SPDX-License-Identifier: GPL-2.0-or-later */

/*
 * Romstage memory init for BKHD 1338NP-12 / Techvision TVI7309X B0
 *
 * This board has 2x DDR4 SO-DIMM slots (one per channel), populated with:
 *   Channel A (slot at SMBus 0x50): Kingston 8GB DDR4-2667 (9905711-053.A00G)
 *   Channel B (slot at SMBus 0x52): Samsung 8GB DDR4-2667 (M471A1K43CB1-CTD)
 *
 * SPD is read from the DIMMs over SMBus at runtime, so each channel
 * trains with its own module's timings and DIMM swaps keep working.
 *
 * dq_map/dqs_map are intentionally not set: per soc/meminit.h they are
 * only consumed for LPDDR4 designs and are ignored for DDR4.
 */

#include <console/console.h>
#include <soc/gpio.h>
#include <soc/meminit.h>
#include <soc/romstage.h>

#include "gpio.h"

static const struct mb_cfg memcfg_cfg = {
	/*
	 * RCOMP resistor and target values for DDR4.
	 * Verified identical to the Protectli vault_jsl (Dasharo)
	 * reference board (DDR4 SO-DIMM on Jasper Lake).
	 */
	.rcomp_resistor = {100, 100, 100},
	.rcomp_targets = {60, 40, 30, 20, 30},

	/* Enable Early Command Training */
	.ect = 1,

	/* Board type: ULT/ULX (mobile/embedded), as on vault_jsl */
	.UserBd = BOARD_TYPE_ULT_ULX,
};

void mainboard_memory_init_params(FSPM_UPD *memupd)
{
	/*
	 * SPD SMBus addresses (8-bit): index 0/1 = channel 0 DIMM 0/1,
	 * index 2/3 = channel 1 DIMM 0/1. One slot per channel here.
	 */
	const struct spd_info board_spd_info = {
		.read_type = READ_SMBUS,
		.spd_spec.spd_smbus_address = {0xa0, 0x00, 0xa4, 0x00},
	};

	memcfg_init(&memupd->FspmConfig, &memcfg_cfg, &board_spd_info, false);

	/* Configure GPIO pads for memory init */
	gpio_configure_pads(gpio_table, ARRAY_SIZE(gpio_table));
}
