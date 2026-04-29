// ==============================================================
// Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC v2019.1 (64-bit)
// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// ==============================================================
/***************************** Include Files *********************************/
#include "xfx_gain.h"

/************************** Function Implementation *************************/
#ifndef __linux__
int XFx_gain_CfgInitialize(XFx_gain *InstancePtr, XFx_gain_Config *ConfigPtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(ConfigPtr != NULL);

    InstancePtr->Ctrl_BaseAddress = ConfigPtr->Ctrl_BaseAddress;
    InstancePtr->IsReady = XIL_COMPONENT_IS_READY;

    return XST_SUCCESS;
}
#endif

void XFx_gain_Start(XFx_gain *InstancePtr) {
    u32 Data;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_AP_CTRL) & 0x80;
    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_AP_CTRL, Data | 0x01);
}

u32 XFx_gain_IsDone(XFx_gain *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_AP_CTRL);
    return (Data >> 1) & 0x1;
}

u32 XFx_gain_IsIdle(XFx_gain *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_AP_CTRL);
    return (Data >> 2) & 0x1;
}

u32 XFx_gain_IsReady(XFx_gain *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_AP_CTRL);
    // check ap_start to see if the pcore is ready for next input
    return !(Data & 0x1);
}

void XFx_gain_EnableAutoRestart(XFx_gain *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_AP_CTRL, 0x80);
}

void XFx_gain_DisableAutoRestart(XFx_gain *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_AP_CTRL, 0);
}

void XFx_gain_Set_gain_q2_14_V(XFx_gain *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_GAIN_Q2_14_V_DATA, Data);
}

u32 XFx_gain_Get_gain_q2_14_V(XFx_gain *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_GAIN_Q2_14_V_DATA);
    return Data;
}

void XFx_gain_Set_use_reg_V(XFx_gain *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_USE_REG_V_DATA, Data);
}

u32 XFx_gain_Get_use_reg_V(XFx_gain *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_USE_REG_V_DATA);
    return Data;
}

void XFx_gain_InterruptGlobalEnable(XFx_gain *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_GIE, 1);
}

void XFx_gain_InterruptGlobalDisable(XFx_gain *InstancePtr) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_GIE, 0);
}

void XFx_gain_InterruptEnable(XFx_gain *InstancePtr, u32 Mask) {
    u32 Register;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Register =  XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_IER);
    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_IER, Register | Mask);
}

void XFx_gain_InterruptDisable(XFx_gain *InstancePtr, u32 Mask) {
    u32 Register;

    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Register =  XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_IER);
    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_IER, Register & (~Mask));
}

void XFx_gain_InterruptClear(XFx_gain *InstancePtr, u32 Mask) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XFx_gain_WriteReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_ISR, Mask);
}

u32 XFx_gain_InterruptGetEnabled(XFx_gain *InstancePtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    return XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_IER);
}

u32 XFx_gain_InterruptGetStatus(XFx_gain *InstancePtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    return XFx_gain_ReadReg(InstancePtr->Ctrl_BaseAddress, XFX_GAIN_CTRL_ADDR_ISR);
}

