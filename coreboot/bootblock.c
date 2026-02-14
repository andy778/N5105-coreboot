/* SPDX-License-Identifier: GPL-2.0-or-later */

/*
 * Bootblock early init for BKHD 1338NP-12 / Techvision TVI7309X B0
 *
 * Initializes the ITE IT8613E Super I/O for serial console output
 * and disables the watchdog timer to prevent unexpected resets.
 */

#include <bootblock_common.h>
#include <device/pnp_ops.h>
#include <superio/ite/common/ite.h>
#include <superio/ite/it8613e/it8613e.h>

#define SERIAL1_DEV PNP_DEV(0x2e, IT8613E_SP1)
#define GPIO_DEV PNP_DEV(0x2e, IT8613E_GPIO)

void bootblock_mainboard_early_init(void)
{
	/* Kill the watchdog before it resets us */
	ite_kill_watchdog(GPIO_DEV);

	/* Enable serial port for console output at 0x3f8 (COM1) */
	ite_enable_serial(SERIAL1_DEV, CONFIG_TTYS0_BASE);
}
