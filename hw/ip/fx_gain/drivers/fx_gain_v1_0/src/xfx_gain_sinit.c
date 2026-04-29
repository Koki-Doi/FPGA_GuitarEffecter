// ==============================================================
// Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC v2019.1 (64-bit)
// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// ==============================================================
#ifndef __linux__

#include "xstatus.h"
#include "xparameters.h"
#include "xfx_gain.h"

extern XFx_gain_Config XFx_gain_ConfigTable[];

XFx_gain_Config *XFx_gain_LookupConfig(u16 DeviceId) {
	XFx_gain_Config *ConfigPtr = NULL;

	int Index;

	for (Index = 0; Index < XPAR_XFX_GAIN_NUM_INSTANCES; Index++) {
		if (XFx_gain_ConfigTable[Index].DeviceId == DeviceId) {
			ConfigPtr = &XFx_gain_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XFx_gain_Initialize(XFx_gain *InstancePtr, u16 DeviceId) {
	XFx_gain_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XFx_gain_LookupConfig(DeviceId);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XFx_gain_CfgInitialize(InstancePtr, ConfigPtr);
}

#endif

