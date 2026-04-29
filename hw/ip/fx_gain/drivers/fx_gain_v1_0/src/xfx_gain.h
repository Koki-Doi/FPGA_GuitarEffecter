// ==============================================================
// Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC v2019.1 (64-bit)
// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// ==============================================================
#ifndef XFX_GAIN_H
#define XFX_GAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/***************************** Include Files *********************************/
#ifndef __linux__
#include "xil_types.h"
#include "xil_assert.h"
#include "xstatus.h"
#include "xil_io.h"
#else
#include <stdint.h>
#include <assert.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stddef.h>
#endif
#include "xfx_gain_hw.h"

/**************************** Type Definitions ******************************/
#ifdef __linux__
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
#else
typedef struct {
    u16 DeviceId;
    u32 Ctrl_BaseAddress;
} XFx_gain_Config;
#endif

typedef struct {
    u32 Ctrl_BaseAddress;
    u32 IsReady;
} XFx_gain;

/***************** Macros (Inline Functions) Definitions *********************/
#ifndef __linux__
#define XFx_gain_WriteReg(BaseAddress, RegOffset, Data) \
    Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))
#define XFx_gain_ReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))
#else
#define XFx_gain_WriteReg(BaseAddress, RegOffset, Data) \
    *(volatile u32*)((BaseAddress) + (RegOffset)) = (u32)(Data)
#define XFx_gain_ReadReg(BaseAddress, RegOffset) \
    *(volatile u32*)((BaseAddress) + (RegOffset))

#define Xil_AssertVoid(expr)    assert(expr)
#define Xil_AssertNonvoid(expr) assert(expr)

#define XST_SUCCESS             0
#define XST_DEVICE_NOT_FOUND    2
#define XST_OPEN_DEVICE_FAILED  3
#define XIL_COMPONENT_IS_READY  1
#endif

/************************** Function Prototypes *****************************/
#ifndef __linux__
int XFx_gain_Initialize(XFx_gain *InstancePtr, u16 DeviceId);
XFx_gain_Config* XFx_gain_LookupConfig(u16 DeviceId);
int XFx_gain_CfgInitialize(XFx_gain *InstancePtr, XFx_gain_Config *ConfigPtr);
#else
int XFx_gain_Initialize(XFx_gain *InstancePtr, const char* InstanceName);
int XFx_gain_Release(XFx_gain *InstancePtr);
#endif

void XFx_gain_Start(XFx_gain *InstancePtr);
u32 XFx_gain_IsDone(XFx_gain *InstancePtr);
u32 XFx_gain_IsIdle(XFx_gain *InstancePtr);
u32 XFx_gain_IsReady(XFx_gain *InstancePtr);
void XFx_gain_EnableAutoRestart(XFx_gain *InstancePtr);
void XFx_gain_DisableAutoRestart(XFx_gain *InstancePtr);

void XFx_gain_Set_gain_q2_14_V(XFx_gain *InstancePtr, u32 Data);
u32 XFx_gain_Get_gain_q2_14_V(XFx_gain *InstancePtr);
void XFx_gain_Set_use_reg_V(XFx_gain *InstancePtr, u32 Data);
u32 XFx_gain_Get_use_reg_V(XFx_gain *InstancePtr);

void XFx_gain_InterruptGlobalEnable(XFx_gain *InstancePtr);
void XFx_gain_InterruptGlobalDisable(XFx_gain *InstancePtr);
void XFx_gain_InterruptEnable(XFx_gain *InstancePtr, u32 Mask);
void XFx_gain_InterruptDisable(XFx_gain *InstancePtr, u32 Mask);
void XFx_gain_InterruptClear(XFx_gain *InstancePtr, u32 Mask);
u32 XFx_gain_InterruptGetEnabled(XFx_gain *InstancePtr);
u32 XFx_gain_InterruptGetStatus(XFx_gain *InstancePtr);

#ifdef __cplusplus
}
#endif

#endif
