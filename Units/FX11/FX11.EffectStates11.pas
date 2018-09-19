unit FX11.EffectStates11;

{$mode delphi}{$H+}

interface

uses
    Windows, Classes, SysUtils,
    FX11.Effect,
    FX11.EffectStateBase11,FX11.EffectBinaryFormat,
    DX12.D3DCommon;


//////////////////////////////////////////////////////////////////////////
// Effect HLSL late resolve lists (state values)
//////////////////////////////////////////////////////////////////////////


const
    g_rvNULL: array [0..1] of TRValue = (
        (m_pName: 'nullptr'; m_Value: 0),
        (m_pName: nil; m_Value: 0));

    g_rvBOOL: array [0..2] of TRValue = (
        (m_pName: 'false'; m_Value: 0),
        (m_pName: 'true'; m_Value: 1),
        (m_pName: nil; m_Value: 0));


    g_lvGeneral: array [0..0] of TLValue = (
        (m_pName: 'RasterizerState';
        m_BlockType: EBT_Pass;
        m_Type: D3D_SVT_RASTERIZER;
        m_Cols: 1;

        m_Indices: 1;

        m_VectorScalar: False;

        m_pRValue: nil;

        m_LhsType: ELHS_RasterizerBlock;

//ToDo m_Offset: Uint32(NativeUInt(@TSPassBlock(nil^).BackingStore.pRasterizerBlock));
    //   m_Offset:  NativeUInt(PBackingStore(@PSPassBlock(nil).BackingStore));
        m_Offset: 0;
        m_Stride: 0));


implementation

end.
