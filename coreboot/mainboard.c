/* SPDX-License-Identifier: GPL-2.0-or-later */

/*
 * Ramstage mainboard init for BKHD 1338NP-12 / Techvision TVI7309X B0
 *
 * Configures PCIe root port parameters, SMBIOS tables, and FSP
 * silicon init overrides for the Jasper Lake N5105 platform.
 */

#include <device/device.h>
#include <smbios.h>
#include <soc/ramstage.h>

smbios_enclosure_type smbios_mainboard_enclosure_type(void)
{
	return SMBIOS_ENCLOSURE_LOW_PROFILE_DESKTOP;
}

u8 smbios_mainboard_feature_flags(void)
{
	return SMBIOS_FEATURE_FLAGS_HOSTING_BOARD |
	       SMBIOS_FEATURE_FLAGS_REPLACEABLE;
}

const char *smbios_system_sku(void)
{
	return "TVI7309X";
}

void mainboard_silicon_init_params(FSP_S_CONFIG *params)
{
	/* Enable ACS and AER on all PCIe root ports */
	for (uint8_t i = 0; i < CONFIG_MAX_ROOT_PORTS; i++) {
		params->PcieRpAcsEnabled[i] = 1;
		params->PcieRpAdvancedErrorReporting[i] = 1;
		params->PcieRpLtrEnable[i] = 1;
		params->PcieRpMaxPayload[i] = 1; /* 256 bytes */
		params->PcieRpSlotImplemented[i] = 1;
	}

	/*
	 * Disable HWP (Hardware P-states). HWP can be too aggressive
	 * with power saving and limits I226-V throughput.
	 * Let Linux use acpi-cpufreq governor instead of intel_pstate.
	 */
	params->Hwp = 0;

	/*
	 * SSID programming is skipped by default in JSL FSP when
	 * SiSsidTablePtr is null (which is our case).
	 */
}

struct chip_operations mainboard_ops = {
	.enable_dev = NULL,
};
