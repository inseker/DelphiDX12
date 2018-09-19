//--------------------------------------------------------------------------------------
// File: EffectStateBase11.h

// Direct3D 11 Effects States Header

// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// http://go.microsoft.com/fwlink/p/?LinkId:=271568
//--------------------------------------------------------------------------------------

unit FX11.EffectStateBase11;

{$mode delphi}{$H+}

interface

uses
    Windows, Classes, SysUtils,
    FX11.EffectBinaryFormat,
    DX12.D3DCommon;

type
    //////////////////////////////////////////////////////////////////////////
    // Effect HLSL states and late resolve lists
    //////////////////////////////////////////////////////////////////////////
    PRValue = ^TRValue;

    TRValue = record
        m_pName: PAnsiChar;
        m_Value: uint32;
    end;

//    TELhsType = integer;

    TLValue = record
        m_pName: PAnsiChar;           // name of the LHS side of expression
        m_BlockType: TEBlockType;        // type of block it can appear in
        m_Type: TD3D_SHADER_VARIABLE_TYPE;    // data type allows
        m_Cols: uint32;
        // number of [m_Type]'s required (1 for a scalar, 4 for a vector)
        m_Indices: uint32;
        // max index allowable (if LHS is an array; otherwise this is 1)
        m_VectorScalar: boolean;
        // can be both vector and scalar (setting as a scalar sets all m_Indices values simultaneously)
        m_pRValue: PRValue;
        // pointer to table of allowable RHS "late resolve" values
        m_LhsType: TELhsType;
        // ELHS_* enum value that corresponds to this entry
        m_Offset: uint32;
        // offset into the given block type where this value should be written
        m_Stride: uint32;
        // for vectors, byte stride between two consecutive values. if 0, m_Type's size is used
    end;

const
    RVALUE_END: TRValue = (m_pName: nil; m_Value: 0);
// ToDo  LVALUE_END: TLValue =( m_pName: nil; m_Type: D3D_SVT_UINT; m_Cols: 0;m_Indices: 0; 0; m_pRValue: nil );

var
    g_lvGeneralCount: uint32;
    g_lvGeneral: array of TLValue;

implementation

end.
