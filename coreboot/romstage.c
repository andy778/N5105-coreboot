/* SPDX-License-Identifier: GPL-2.0-or-later */

/*
 * Romstage memory init for BKHD 1338NP-12 / Techvision TVI7309X B0
 *
 * This board has 2x DDR4 SO-DIMM slots populated:
 *   Channel A: Kingston 8GB DDR4-2667 (9905711-053.A00G)
 *   Channel B: Samsung 8GB DDR4-2667 (M471A1K43CB1-CTD)
 *
 * Memory training parameters are configured for DDR4 SO-DIMM.
 * SPD data is read from CBFS (dumped from the DIMMs).
 *
 * NOTE: The DQ/DQS maps below are initial estimates based on the
 * Protectli vault_jsl reference. They may need adjustment based on
 * the actual board routing. If memory training fails, these maps
 * are the first thing to investigate.
 */

#include <console/console.h>
#include <soc/gpio.h>
#include <soc/meminit.h>
#include <soc/romstage.h>

#include "gpio.h"

static const struct mb_cfg memcfg_cfg = {

	/*
	 * DQ byte map: maps each byte lane to physical DQ pins.
	 * This is board-layout dependent. Starting with identity map
	 * matching the Protectli vault_jsl reference board.
	 */
	.dq_map[DDR_CH0] = {
		{0xf, 0xf0},
		{0xf, 0xf0},
		{0xff, 0x0},
		{0x0, 0x0},
		{0x0, 0x0},
		{0x0, 0x0}
	},
	.dq_map[DDR_CH1] = {
		{0xf, 0xf0},
		{0xf, 0xf0},
		{0xff, 0x0},
		{0x0, 0x0},
		{0x0, 0x0},
		{0x0, 0x0}
	},

	/* DQS byte map: maps strobe signals to byte lanes */
	.dqs_map[DDR_CH0] = {0, 1, 2, 3, 4, 5, 6, 7},
	.dqs_map[DDR_CH1] = {0, 1, 2, 3, 4, 5, 6, 7},

	/*
	 * RCOMP resistor and target values for DDR4.
	 * These are typical values for Jasper Lake SO-DIMM configurations.
	 */
	.rcomp_resistor = {100, 100, 100},
	.rcomp_targets = {60, 40, 30, 20, 30},

	/* Enable Early Command Training */
	.ect = 1,

	/* Board type: ULT/ULX (mobile/embedded) */
	.UserBd = BOARD_TYPE_ULT_ULX,
};

void mainboard_memory_init_params(FSPM_UPD *memupd)
{
	const struct spd_info board_spd_info = {
		.read_type = READ_SPD_CBFS,
		.spd_spec.spd_index = 0,
	};

	memcfg_init(&memupd->FspmConfig, &memcfg_cfg, &board_spd_info, false);

	/* Both SO-DIMM slots are populated on this board */

	/* Configure GPIO pads for memory init */
	gpio_configure_pads(gpio_table, ARRAY_SIZE(gpio_table));
}
