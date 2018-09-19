//--------------------------------------------------------------------------------------
// File: EffectBinaryFormat.h

// Direct3D11 Effects Binary Format
// This is the binary file interface shared between the Effects
// compiler and runtime.

// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// http://go.microsoft.com/fwlink/p/?LinkId:=271568
//--------------------------------------------------------------------------------------
unit FX11.EffectBinaryFormat;

{$mode delphi}{$H+}

interface

uses
    Windows, Classes, SysUtils,
    DX12.D3D11, DX12.D3DX11;

//////////////////////////////////////////////////////////////////////////
// Version Control
//////////////////////////////////////////////////////////////////////////


type
    TEVersionTag = record
        m_pName: PAnsiChar;
        m_Version: DWORD;
        m_Tag: uint32;
    end;


// versions must be listed in ascending order
const
    g_EffectVersions: array [0..2] of TEVersionTag = (
        (m_pName: 'fx_4_0';
        m_Version: (Ord('F') shl 24) or (Ord('X') shl 16) or
        ((4) shl 8) or (0);
        m_Tag: $FEFF1001),
        (m_pName: 'fx_4_1';
        m_Version: (Ord('F') shl 24) or (Ord('X') shl 16) or
        ((4) shl 8) or (1);
        m_Tag: $FEFF1011),
        (m_pName: 'fx_5_0';
        m_Version: (Ord('F') shl 24) or (Ord('X') shl 16) or
        ((5) shl 8) or (0);
        m_Tag: $FEFF2001));

   // private flags
        c_IsTBuffer : uint32 = (1 shl 0);
       c_IsSingle : uint32= (1 shl 1);
type

    //////////////////////////////////////////////////////////////////////////
    // Reflection & Type structures
    //////////////////////////////////////////////////////////////////////////

    // Enumeration of the possible left-hand side values of an assignment,
    // divided up categorically by the type of block they may appear in
    TELhsType = (
        ELHS_Invalid,

        // Pass block assignment types

        ELHS_PixelShaderBlock,
        // SBlock *pValue points to the block to apply
        ELHS_VertexShaderBlock,
        ELHS_GeometryShaderBlock,
        ELHS_RenderTargetView,
        ELHS_DepthStencilView,

        ELHS_RasterizerBlock,
        ELHS_DepthStencilBlock,
        ELHS_BlendBlock,

        ELHS_GenerateMips,
        // This is really a call to D3D.GenerateMips

        // Various SAssignment.Value.*

        ELHS_DS_StencilRef,             // SAssignment.Value.pdValue
        ELHS_B_BlendFactor,
        // D3D11_BLEND_CONFIG.BlendFactor, points to a float4
        ELHS_B_SampleMask,              // D3D11_BLEND_CONFIG.SampleMask

        ELHS_GeometryShaderSO,
        // When setting SO assignments, GeometryShaderSO precedes the actual GeometryShader assn

        ELHS_ComputeShaderBlock,
        ELHS_HullShaderBlock,
        ELHS_DomainShaderBlock,

        // Rasterizer

        ELHS_FillMode = $20000,
        ELHS_CullMode,
        ELHS_FrontCC,
        ELHS_DepthBias,
        ELHS_DepthBiasClamp,
        ELHS_SlopeScaledDepthBias,
        ELHS_DepthClipEnable,
        ELHS_ScissorEnable,
        ELHS_MultisampleEnable,
        ELHS_AntialiasedLineEnable,

        // Sampler

        ELHS_Filter = $30000,
        ELHS_AddressU,
        ELHS_AddressV,
        ELHS_AddressW,
        ELHS_MipLODBias,
        ELHS_MaxAnisotropy,
        ELHS_ComparisonFunc,
        ELHS_BorderColor,
        ELHS_MinLOD,
        ELHS_MaxLOD,
        ELHS_Texture,

        // DepthStencil

        ELHS_DepthEnable = $40000,
        ELHS_DepthWriteMask,
        ELHS_DepthFunc,
        ELHS_StencilEnable,
        ELHS_StencilReadMask,
        ELHS_StencilWriteMask,
        ELHS_FrontFaceStencilFailOp,
        ELHS_FrontFaceStencilDepthFailOp,
        ELHS_FrontFaceStencilPassOp,
        ELHS_FrontFaceStencilFunc,
        ELHS_BackFaceStencilFailOp,
        ELHS_BackFaceStencilDepthFailOp,
        ELHS_BackFaceStencilPassOp,
        ELHS_BackFaceStencilFunc,

        // BlendState

        ELHS_AlphaToCoverage = $50000,
        ELHS_BlendEnable,
        ELHS_SrcBlend,
        ELHS_DestBlend,
        ELHS_BlendOp,
        ELHS_SrcBlendAlpha,
        ELHS_DestBlendAlpha,
        ELHS_BlendOpAlpha,
        ELHS_RenderTargetWriteMask);

    TEBlockType = (
        EBT_Invalid,
        EBT_DepthStencil,
        EBT_Blend,
        EBT_Rasterizer,
        EBT_Sampler,
        EBT_Pass);

    TEVarType = (
        EVT_Invalid,
        EVT_Numeric,
        EVT_Object,
        EVT_Struct,
        EVT_Interface);

    TEScalarType = (
        EST_Invalid,
        EST_Float,
        EST_Int,
        EST_UInt,
        EST_Bool,
        EST_Count);

    TENumericLayout = (
        ENL_Invalid,
        ENL_Scalar,
        ENL_Vector,
        ENL_Matrix,
        ENL_Count);

    TEObjectType = (
        EOT_Invalid,
        EOT_String,
        EOT_Blend,
        EOT_DepthStencil,
        EOT_Rasterizer,
        EOT_PixelShader,
        EOT_VertexShader,
        EOT_GeometryShader,              // Regular geometry shader
        EOT_GeometryShaderSO,
        // Geometry shader with a attached StreamOut decl
        EOT_Texture,
        EOT_Texture1D,
        EOT_Texture1DArray,
        EOT_Texture2D,
        EOT_Texture2DArray,
        EOT_Texture2DMS,
        EOT_Texture2DMSArray,
        EOT_Texture3D,
        EOT_TextureCube,
        EOT_ConstantBuffer,
        EOT_RenderTargetView,
        EOT_DepthStencilView,
        EOT_Sampler,
        EOT_Buffer,
        EOT_TextureCubeArray,
        EOT_Count,
        EOT_PixelShader5,
        EOT_VertexShader5,
        EOT_GeometryShader5,
        EOT_ComputeShader5,
        EOT_HullShader5,
        EOT_DomainShader5,
        EOT_RWTexture1D,
        EOT_RWTexture1DArray,
        EOT_RWTexture2D,
        EOT_RWTexture2DArray,
        EOT_RWTexture3D,
        EOT_RWBuffer,
        EOT_ByteAddressBuffer,
        EOT_RWByteAddressBuffer,
        EOT_StructuredBuffer,
        EOT_RWStructuredBuffer,
        EOT_RWStructuredBufferAlloc,
        EOT_RWStructuredBufferConsume,
        EOT_AppendStructuredBuffer,
        EOT_ConsumeStructuredBuffer);




    // Effect file format structures /////////////////////////////////////////////
    // File format:
    //   File header (SBinaryHeader Header)
    //   Unstructured data block (uint8_t[Header.cbUnstructured))
    //   Structured data block
    //     ConstantBuffer (SBinaryConstantBuffer CB) * Header.Effect.cCBs
    //       uint32  NumAnnotations
    //       Annotation data (SBinaryAnnotation) * (NumAnnotations) *this structure is variable sized
    //       Variable data (SBinaryNumericVariable Var) * (CB.cVariables)
    //         uint32  NumAnnotations
    //         Annotation data (SBinaryAnnotation) * (NumAnnotations) *this structure is variable sized
    //     Object variables (SBinaryObjectVariable Var) * (Header.cObjectVariables) *this structure is variable sized
    //       uint32  NumAnnotations
    //       Annotation data (SBinaryAnnotation) * (NumAnnotations) *this structure is variable sized
    //     Interface variables (SBinaryInterfaceVariable Var) * (Header.cInterfaceVariables) *this structure is variable sized
    //       uint32  NumAnnotations
    //       Annotation data (SBinaryAnnotation) * (NumAnnotations) *this structure is variable sized
    //     Groups (SBinaryGroup Group) * Header.cGroups
    //       uint32  NumAnnotations
    //       Annotation data (SBinaryAnnotation) * (NumAnnotations) *this structure is variable sized
    //       Techniques (SBinaryTechnique Technique) * Group.cTechniques
    //         uint32  NumAnnotations
    //         Annotation data (SBinaryAnnotation) * (NumAnnotations) *this structure is variable sized
    //         Pass (SBinaryPass Pass) * Technique.cPasses
    //           uint32  NumAnnotations
    //           Annotation data (SBinaryAnnotation) * (NumAnnotations) *this structure is variable sized
    //           Pass assignments (SBinaryAssignment) * Pass.cAssignments

    TSVarCounts = record
        cCBs: uint32;
        cNumericVariables: uint32;
        cObjectVariables: uint32;
    end;

    { TSBinaryHeader }

    TSBinaryHeader = record
        Tag: uint32;    // should be equal to c_EffectFileTag
        // this is used to identify ASCII vs Binary files

        Effect: TSVarCounts;
        Pool: TSVarCounts;

        cTechniques: uint32;
        cbUnstructured: uint32;

        cStrings: uint32;
        cShaderResources: uint32;

        cDepthStencilBlocks: uint32;
        cBlendStateBlocks: uint32;
        cRasterizerStateBlocks: uint32;
        cSamplers: uint32;
        cRenderTargetViews: uint32;
        cDepthStencilViews: uint32;

        cTotalShaders: uint32;
        cInlineShaders: uint32;
        // of the aforementioned shaders, the number that are defined inline within pass blocks
        function RequiresPool(): boolean;
    end;


    { TSBinaryHeader5 }

    TSBinaryHeader5 = record
        Tag: uint32;    // should be equal to c_EffectFileTag
        // this is used to identify ASCII vs Binary files

        Effect: TSVarCounts;
        Pool: TSVarCounts;

        cTechniques: uint32;
        cbUnstructured: uint32;

        cStrings: uint32;
        cShaderResources: uint32;

        cDepthStencilBlocks: uint32;
        cBlendStateBlocks: uint32;
        cRasterizerStateBlocks: uint32;
        cSamplers: uint32;
        cRenderTargetViews: uint32;
        cDepthStencilViews: uint32;

        cTotalShaders: uint32;
        cInlineShaders: uint32;
        // of the aforementioned shaders, the number that are defined inline within pass blocks
        cGroups: uint32;
        cUnorderedAccessViews: uint32;
        cInterfaceVariables: uint32;
        cInterfaceVariableElements: uint32;
        cClassInstanceElements: uint32;

        function RequiresPool(): boolean;
    end;



    // Constant buffer definition
    TSBinaryConstantBuffer = record
        oName: uint32;
        // Offset to constant buffer name
        Size: uint32;                 // Size, in bytes
        Flags: uint32;
        cVariables: uint32;
        // # of variables inside this buffer
        ExplicitBindPoint: uint32;
        // Defined if the effect file specifies a bind point using the register keyword
        // otherwise, -1
    end;

    TSBinaryAnnotation = record
        oName: uint32;                // Offset to variable name
        oType: uint32;
        // Offset to type information (SBinaryType)

        // For numeric annotations:
        // uint32  oDefaultValue;     // Offset to default initializer value

        // For string annotations:
        // uint32  oStringOffsets[Elements]; // Elements comes from the type data at oType
    end;

    TSBinaryNumericVariable = record
        oName: uint32;                // Offset to variable name
        oType: uint32;
        // Offset to type information (SBinaryType)
        oSemantic: uint32;            // Offset to semantic information
        Offset: uint32;               // Offset in parent constant buffer
        oDefaultValue: uint32;        // Offset to default initializer value
        Flags: uint32;                // Explicit bind point
    end;

    TSBinaryInterfaceVariable = record
        oName: uint32;                // Offset to variable name
        oType: uint32;
        // Offset to type information (SBinaryType)
        oDefaultValue: uint32;
        // Offset to default initializer array (SBinaryInterfaceInitializer[Elements])
        Flags: uint32;
    end;

    TSBinaryInterfaceInitializer = record
        oInstanceName: uint32;
        ArrayIndex: uint32;
    end;

    TSBinaryObjectVariable = record
        oName: uint32;                // Offset to variable name
        oType: uint32;
        // Offset to type information (SBinaryType)
        oSemantic: uint32;            // Offset to semantic information
        ExplicitBindPoint: uint32;
        // Used when a variable has been explicitly bound (register(XX)). -1 if not

        // Initializer data:

        // The type structure pointed to by oType gives you Elements,
        // VarType (must be EVT_Object), and ObjectType

        // For ObjectType = EOT_Blend, EOT_DepthStencil, EOT_Rasterizer, EOT_Sampler
        // struct
        // begin
        //   uint32  cAssignments;
        //   SBinaryAssignment Assignments[cAssignments];
        // } Blocks[Elements]

        // For TEObjectType = EOT_Texture*, EOT_Buffer
        // <nothing>

        // For TEObjectType = EOT_*Shader, EOT_String
        // uint32  oData[Elements]; // offsets to a shader data block or a nullptr-terminated string

        // For TEObjectType = EOT_GeometryShaderSO
        //   SBinaryGSSOInitializer[Elements]

        // For TEObjectType = EOT_*Shader5
        //   SBinaryShaderData5[Elements]
    end;

    TSBinaryGSSOInitializer = record
        oShader: uint32;              // Offset to shader bytecode data block
        oSODecl: uint32;              // Offset to StreamOutput decl string
    end;

    TSBinaryShaderData5 = record
        oShader: uint32;              // Offset to shader bytecode data block
        oSODecls: array[0..3] of uint32;
        // Offset to StreamOutput decl strings
        cSODecls: uint32;             // Count of valid oSODecls entries.
        RasterizedStream: uint32;     // Which stream is used for rasterization
        cInterfaceBindings: uint32;   // Count of interface bindings.
        oInterfaceBindings: uint32;
        // Offset to SBinaryInterfaceInitializer[cInterfaceBindings].
    end;

    TSBinaryMember = record
        oName: uint32;
        // Offset to structure member name ("m_pFoo")
        oSemantic: uint32;      // Offset to semantic ("POSITION0")
        Offset: uint32;
        // Offset, in bytes, relative to start of parent structure
        oType: uint32;          // Offset to member's type descriptor
    end;

    TSBinaryType = record
        oTypeName: uint32;
        // Offset to friendly type name ("float4", "VS_OUTPUT")
        VarType: TEVarType;        // Numeric, Object, or Struct
        Elements: uint32;       // # of array elements (0 for non-arrays)
        TotalSize: uint32;
        // Size in bytes; not necessarily Stride * Elements for arrays
        // because of possible gap left in final register
        Stride: uint32;
        // If an array, this is the spacing between elements.
        // For unpacked arrays, always divisible by 16-bytes (1 register).
        // No support for packed arrays
        PackedSize: uint32;
        // Size, in bytes, of this data typed when fully packed

        // the data that follows depends on the VarType:
        // Numeric: SType.SNumericType
        // Object:  TEObjectType
        // Struct:
        //   struct
        //   begin
        //        uint32          cMembers;
        //        SBinaryMembers    Members[cMembers];
        //   } MemberInfo
        //   struct
        //   begin
        //        uint32              oBaseClassType;  // Offset to type information (SBinaryType)
        //        uint32              cInterfaces;
        //        uint32              oInterfaceTypes[cInterfaces];
        //   } SBinaryTypeInheritance
        // Interface: (nothing)
    end;

    TSBinaryNumericType = bitpacked record
        NumericLayout: TENumericLayout; // 0..7;
        //    // scalar (1x1), vector (1xN), matrix (NxN)
        ScalarType: TEScalarType; // 0..31;
        // float32, int32, int8, etc.
        Rows: 0..7;    // 1 <= Rows <= 4
        Columns: 0..7;    // 1 <= Columns <= 4
        IsColumnMajor: boolean; // 0..1   // applies only to matrices
        IsPackedArray: boolean; // 0..1
        // if this is an array, indicates whether elements should be greedily packed
        {$WARNING Check this for 4 byte boundry}
        _Temp: 0..65535;
    end;

    TSBinaryTypeInheritance = record
        oBaseClass: uint32;
        // Offset to base class type info or 0 if no base class.
        cInterfaces: uint32;

        // Followed by uint32[cInterfaces] with offsets to the type
        // info of each interface.
    end;

    TSBinaryGroup = record
        oName: uint32;
        cTechniques: uint32;
    end;

    TSBinaryTechnique = record
        oName: uint32;
        cPasses: uint32;
    end;

    TSBinaryPass = record
        oName: uint32;
        cAssignments: uint32;
    end;

    TECompilerAssignmentType = (
        ECAT_Invalid,
        // Assignment-specific data (always in the unstructured blob)
        ECAT_Constant,                  // -N SConstant structures
        ECAT_Variable,
        // -nullptr terminated string with variable name ("foo")
        ECAT_ConstIndex,                // -SConstantIndex structure
        ECAT_VariableIndex,             // -SVariableIndex structure
        ECAT_ExpressionIndex,           // -SIndexedObjectExpression structure
        ECAT_Expression,                // -Data block containing FXLVM code
        ECAT_InlineShader,              // -Data block containing shader
        ECAT_InlineShader5
        // -Data block containing shader with extended 5.0 data (SBinaryShaderData5)
        );


    TConstantIndex = record
        oArrayName: uint32;
        Index: uint32;
    end;

    TVariableIndex = record
        oArrayName: uint32;
        oIndexVarName: uint32;
    end;

    TIndexedObjectExpression = record
        oArrayName: uint32;
        oCode: uint32;
    end;

    TInlineShader = record
        oShader: uint32;
        oSODecl: uint32;
    end;


    TBinaryAssignment = record
        iState: uint32;                // index into g_lvGeneral
        Index: uint32;
        // the particular index to assign to (see g_lvGeneral to find the # of valid indices)
        AssignmentType: TECompilerAssignmentType;
        oInitializer: uint32;         // Offset of assignment-specific data
{         SConstantIndex:TSConstantIndex;
         SVariableIndex:TSVariableIndex;
         SIndexedObjectExpression: TSIndexedObjectExpression;
       SInlineShader:TSInlineShader; }
    end;

    TBinaryConstant = record
        _Type: TEScalarType;
        case integer of
            0: (bValue: boolean);
            1: (iValue: integer);
            2: (fValue: single);
    end;





function IsObjectTypeHelper(InVarType: TEVarType;
    InObjType: TEObjectType; TargetObjType: TEObjectType): boolean;
function IsSamplerHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;

function IsStateBlockObjectHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
function IsShaderHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;

function IsShader5Helper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;

function IsInterfaceHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;

function IsShaderResourceHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;

function IsUnorderedAccessViewHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;


function IsRenderTargetViewHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;

function IsDepthStencilViewHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;

function IsObjectAssignmentHelper(LhsType: TELhsType): boolean;

function IsEqual (a: TEObjectType; b: TEObjectType): boolean;
function LogicalOr (a: TEObjectType; b: TEObjectType): TEObjectType;



implementation

   function IsEqual (a: TEObjectType; b: TEObjectType): boolean;
begin
    result:=(ord(a)=ord(b));
end;

   function LogicalOr(a: TEObjectType; b: TEObjectType): TEObjectType;
   begin
       result:=TEObjectType(ord(a) or ord(b));
   end;

function IsObjectTypeHelper(InVarType: TEVarType;
    InObjType: TEObjectType; TargetObjType: TEObjectType): boolean; inline;
begin
    Result := (InVarType = EVT_Object) and (InObjType = TargetObjType);
end;



function IsSamplerHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and (InObjType = EOT_Sampler);
end;



function IsStateBlockObjectHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and
        ((InObjType = EOT_Blend) or (InObjType = EOT_DepthStencil) or
        (InObjType = EOT_Rasterizer) or IsSamplerHelper(InVarType, InObjType));
end;



function IsShaderHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and
        ((InObjType = EOT_VertexShader) or (InObjType =
        EOT_VertexShader5) or (InObjType = EOT_HullShader5) or
        (InObjType = EOT_DomainShader5) or (InObjType =
        EOT_ComputeShader5) or (InObjType = EOT_GeometryShader) or
        (InObjType = EOT_GeometryShaderSO) or
        (InObjType = EOT_GeometryShader5) or
        (InObjType = EOT_PixelShader) or (InObjType =
        EOT_PixelShader5));
end;



function IsShader5Helper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and
        ((InObjType = EOT_VertexShader5) or (InObjType =
        EOT_HullShader5) or (InObjType = EOT_DomainShader5) or
        (InObjType = EOT_ComputeShader5) or (InObjType =
        EOT_GeometryShader5) or (InObjType = EOT_PixelShader5));
end;



function IsInterfaceHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    // ToDo UNREFERENCED_PARAMETER(InObjType);
    Result := (InVarType = EVT_Interface);
end;



function IsShaderResourceHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and
        ((InObjType = EOT_Texture) or (InObjType = EOT_Texture1D) or
        (InObjType = EOT_Texture1DArray) or
        (InObjType = EOT_Texture2D) or (InObjType = EOT_Texture2DArray) or
        (InObjType = EOT_Texture2DMS) or
        (InObjType = EOT_Texture2DMSArray) or (InObjType = EOT_Texture3D) or
        (InObjType = EOT_TextureCube) or
        (InObjType = EOT_TextureCubeArray) or (InObjType = EOT_Buffer) or
        (InObjType = EOT_StructuredBuffer) or
        (InObjType = EOT_ByteAddressBuffer));
end;



function IsUnorderedAccessViewHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and
        ((InObjType = EOT_RWTexture1D) or (InObjType =
        EOT_RWTexture1DArray) or (InObjType = EOT_RWTexture2D) or
        (InObjType = EOT_RWTexture2DArray) or
        (InObjType = EOT_RWTexture3D) or (InObjType = EOT_RWBuffer) or
        (InObjType = EOT_RWByteAddressBuffer) or
        (InObjType = EOT_RWStructuredBuffer) or
        (InObjType = EOT_RWStructuredBufferAlloc) or
        (InObjType = EOT_RWStructuredBufferConsume) or
        (InObjType = EOT_AppendStructuredBuffer) or
        (InObjType = EOT_ConsumeStructuredBuffer));
end;



function IsRenderTargetViewHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and (InObjType = EOT_RenderTargetView);
end;



function IsDepthStencilViewHelper(InVarType: TEVarType;
    InObjType: TEObjectType): boolean;
begin
    Result := (InVarType = EVT_Object) and (InObjType = EOT_DepthStencilView);
end;



function IsObjectAssignmentHelper(LhsType: TELhsType): boolean;
begin
    case (LhsType) of
        ELHS_VertexShaderBlock,
        ELHS_HullShaderBlock,
        ELHS_DepthStencilView,
        ELHS_GeometryShaderBlock,
        ELHS_PixelShaderBlock,
        ELHS_ComputeShaderBlock,
        ELHS_DepthStencilBlock,
        ELHS_RasterizerBlock,
        ELHS_BlendBlock,
        ELHS_Texture,
        ELHS_RenderTargetView,
        ELHS_DomainShaderBlock:
            Result := True;
        else
            Result := False;
    end;
end;



{ TSBinaryHeader5 }

function TSBinaryHeader5.RequiresPool(): boolean;
begin
    Result := (Pool.cCBs <> 0) or (Pool.cNumericVariables <> 0) or
        (Pool.cObjectVariables <> 0);
end;

{ TSBinaryHeader }

function TSBinaryHeader.RequiresPool(): boolean;
begin
    Result := (Pool.cCBs <> 0) or (Pool.cNumericVariables <> 0) or
        (Pool.cObjectVariables <> 0);
end;

{$C+}
initialization
    Assert(sizeof(TSBinaryHeader) = 76, 'FX11 binary size mismatch');

    Assert(sizeof(TSVarCounts) = 12,
        'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryHeader5) = 96, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryConstantBuffer) = 20, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryAnnotation) = 8, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryNumericVariable) = 24, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryInterfaceVariable) = 16,
        'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryInterfaceInitializer) = 8,
        'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryObjectVariable) = 16, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryGSSOInitializer) = 8, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryShaderData5) = 36, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryType) = 24, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryMember) = 16, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryNumericType) = 4,
        'FX11 binary size mismatch' + IntToStr(sizeof(TSBinaryNumericType)));
    Assert(sizeof(TSBinaryTypeInheritance) = 8, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryGroup) = 8, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryTechnique) = 8, 'FX11 binary size mismatch');
    Assert(sizeof(TSBinaryPass) = 8, 'FX11 binary size mismatch');
    Assert(sizeof(TBinaryAssignment) = 16, 'FX11 binary size mismatch' );
    Assert( sizeof(TConstantIndex) = 8, 'FX11 binary size mismatch' );
    Assert( sizeof(TVariableIndex) = 8, 'FX11 binary size mismatch' );
    Assert( sizeof(TIndexedObjectExpression) = 8, 'FX11 binary size mismatch' );
    Assert( sizeof(TInlineShader) = 8, 'FX11 binary size mismatch' );


end.
