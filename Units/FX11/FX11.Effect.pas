//--------------------------------------------------------------------------------------
// File: Effect.h

//  Direct3D 11 Effects Header for ID3DX11Effect Implementation

// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// http://go.microsoft.com/fwlink/p/?LinkId=271568
//--------------------------------------------------------------------------------------

unit FX11.Effect;


interface

uses
    Windows, Classes, SysUtils,
    DX12.DCommon,
    DX12.D3DCommon,
    DX12.D3D11,
    DX12.D3DX11Effect,
    DX12.D3D9Types,
    DX12.D3DX10,
    FX11.EffectBinaryFormat;

const
    c_InvalidIndex: UINT_PTR = uint32(-1);
    c_ScalarSize {: uint32} = sizeof(uint32);
    // packing rule constants
    c_ScalarsPerRegister {: uint32} = 4;
    c_RegisterSize = c_ScalarsPerRegister * c_ScalarSize; // must be a power of 2!!

type

    PSBaseBlock = ^TSBaseBlock;
    PSShaderBlock = ^TSShaderBlock;
    PSPassBlock = ^TSPassBlock;
    PSClassInstance = pointer;// ^TSClassInstance;
    PSInterface = ^TSInterface;
    PSShaderResource = ^TSShaderResource;
    PSUnorderedAccessView = ^TSUnorderedAccessView;
    PSRenderTargetView = ^TSRenderTargetView;
    PSDepthStencilView = ^TSDepthStencilView;
    PSSamplerBlock = ^TSSamplerBlock;
    PSDepthStencilBlock = ^TSDepthStencilBlock;
    PSBlendBlock = ^TSBlendBlock;
    PSRasterizerBlock = ^TSRasterizerBlock;
    PSString = ^TSString;
    PD3DShaderVTable = ^TD3DShaderVTable;
    PSClassInstanceGlobalVariable = ^TSClassInstanceGlobalVariable;

    PSAssignment = ^TSAssignment;
    PSVariable = ^TSVariable;
    PGlobalVariable = ^TGlobalVariable;
    PSAnnotation = ^TSAnnotation;
    PSConstantBuffer = ^TSConstantBuffer;

    TEffect = class;
    TSSamplerBlock = class;
    TSDepthStencilBlock = class;
    TSBlendBlock = class;
    TSRasterizerBlock = class;
    TSPassBlock = class;

    TSShaderBlock = class;
    TSShaderResource = class;

    TSClassInstanceGlobalVariable = class; // ToDo


    TELhsType = integer;

    // Allows the use of 32-bit and 64-bit timers depending on platform type
    TTimer = size_t;

    //////////////////////////////////////////////////////////////////////////
    // Reflection & Type structures
    //////////////////////////////////////////////////////////////////////////

    // CEffectMatrix is used internally instead of single arrays
    TEffectMatrix = record
        case integer of
            0: (_11, _12, _13, _14: single;
                _21, _22, _23, _24: single;
                _31, _32, _33, _34: single;
                _41, _42, _43, _44: single;

            );
            1: (m: array[0..3, 0..3] of single);

    end;
    PEffectMatrix = ^TEffectMatrix;

    TEffectVector4 = record
        x: single;
        y: single;
        z: single;
        w: single;
    end;
    PEffectVector4 = ^TEffectVector4;

    TUDataPointer = record
        case integer of
            0: (pGeneric: pointer);
            1: (pNumeric: PByte);
            2: (pNumericFloat: PSingle);
            3: (pNumericDword: Puint32);
            4: (pNumericInt: Pinteger);
            5: (pNumericBool: Pboolean);
            6: (pString: PSString);
            7: (pShader: PSShaderBlock);
            8: (pBlock: PSBaseBlock);
            9: (pBlend: PSBlendBlock);
            10: (pDepthStencil: PSDepthStencilBlock);
            11: (pRasterizer: PSRasterizerBlock);
            12: (pInterface: PInterface);
            13: (pShaderResource: PSShaderResource);
            14: (pUnorderedAccessView: PSUnorderedAccessView);
            15: (pRenderTargetView: PSRenderTargetView);
            16: (pDepthStencilView: PSDepthStencilView);
            17: (pSampler: PSSamplerBlock);
            18: (pVector: PEffectVector4);
            19: (pMatrix: PEffectMatrix);
            20: (Offset: UINT_PTR);

    end;

    TEMemberDataType = (
        MDT_ClassInstance,
        MDT_BlendState,
        MDT_DepthStencilState,
        MDT_RasterizerState,
        MDT_SamplerState,
        MDT_Buffer,
        MDT_ShaderResourceView);


    TMemberDataPointerData = record
        case integer of
            0: (pGeneric: ^IUnknown);
            1: (pD3DClassInstance: PID3D11ClassInstance);
            2: (pD3DEffectsManagedBlendState: pointer {ID3D11BlendState});
            3: (pD3DEffectsManagedDepthStencilState: pointer { ID3D11DepthStencilState});
            4: (pD3DEffectsManagedRasterizerState: pointer {ID3D11RasterizerState});
            5: (pD3DEffectsManagedSamplerState: pointer {ID3D11SamplerState});
            6: (pD3DEffectsManagedConstantBuffer: pointer { ID3D11Buffer});
            7: (pD3DEffectsManagedTextureBuffer: pointer {ID3D11ShaderResourceView});
    end;
    PMemberDataPointerData = ^TMemberDataPointerData;

    TMemberDataPointer = record
        _Type: TEMemberDataType;
        Data: TMemberDataPointerData;
    end;
    PMemberDataPointer = ^TMemberDataPointer;


    TStructType = record
        pMembers: PSVariable;              // array of type instances describing structure members
        Members: uint32;
        ImplementsInterface: boolean;    // true if this type implements an interface
        HasSuperClass: boolean;          // true if this type has a parent class
    end;

    TSTypeData = record
        case integer of
            0: (NumericType: TSBinaryNumericType);
            1: (ObjectType: TEObjectType);         // not all values of EObjectType are valid here (e.g. constant buffer)
            2: (StructType: TStructType);
            3: (InterfaceType: pointer);          // nothing for interfaces
    end;

    { TSType }

    TSType = class(ID3DX11EffectType)
        VarType: TEVarType;        // numeric, object, struct
        Elements: uint32;       // # of array elements (0 for non-arrays)
        pTypeName: PAnsichar;     // friendly name of the type: "VS_OUTPUT", "float4", etc.

        // *Size and stride values are always 0 for object types
        // *Annotations adhere to packing rules (even though they do not reside in constant buffers)
        //      for consistency's sake

        // Packing rules:
        // *Structures and array elements are always register aligned
        // *Single-row values (or, for column major matrices, single-column) are greedily
        //  packed unless doing so would span a register boundary, in which case they are
        //  register aligned

        TotalSize: uint32;      // Total size of this data type in a constant buffer from
        // start to finish (padding in between elements is included,
        // but padding at the end is not since that would require
        // knowledge of the following data type).

        Stride: uint32;         // Number of bytes to advance between elements.
        // Typically a multiple of 16 for arrays, vectors, matrices.
        // For scalars and small vectors/matrices, this can be 4 or 8.

        PackedSize: uint32;     // Size, in bytes, of this data typed when fully packed

        Data: TSTypeData;

        constructor Create;
        destructor Destroy; override;
        function IsEqual(pOtherType: TSType): boolean;
        function IsObjectType(ObjType: TEObjectType): boolean;
        function IsShader(): boolean;
        function BelongsInConstantBuffer(): boolean;
        function IsStateBlockObject(): boolean;
        function IsClassInstance(): boolean;
        function IsInterface(): boolean;
        function IsShaderResource(): boolean;
        function IsUnorderedAccessView(): boolean;
        function IsSampler(): boolean;
        function IsRenderTargetView(): boolean;
        function IsDepthStencilView(): boolean;
        function GetTotalUnpackedSize(IsSingleElement: boolean): uint32;
        function GetTotalPackedSize(IsSingleElement: boolean): uint32;
        function GetDescHelper(out pDesc: TD3DX11_EFFECT_TYPE_DESC; IsSingleElement: boolean): HRESULT;

        // ID3DX11EffectType
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall;
        function GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
        function GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberName(Index: UINT32): LPCSTR; stdcall;
        function GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
    end;

    // Represents a type structure for a single element.
    // It seems pretty trivial, but it has a different virtual table which enables
    // us to accurately represent a type that consists of a single element

    { TSingleElementType }

    TSingleElementType = class(ID3DX11EffectType)
    public
        pType: TSType;
        constructor Create;
        destructor Destroy; override;

        // ID3DX11EffectType
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall;
        function GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
        function GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberName(Index: UINT32): LPCSTR; stdcall;
        function GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
    end;

    //////////////////////////////////////////////////////////////////////////
    // Block definitions
    //////////////////////////////////////////////////////////////////////////

    { TSBaseBlock }

    TSBaseBlock = class
        BlockType: TEBlockType;
        IsUserManaged: boolean;
        AssignmentCount: uint32;
        pAssignments: PSAssignment;
        function ApplyAssignments(pEffect: TEffect): boolean;
        function AsSampler(): TSSamplerBlock; inline;
        function AsDepthStencil(): TSDepthStencilBlock; inline;
        function AsBlend(): TSBlendBlock; inline;
        function AsRasterizer(): TSRasterizerBlock; inline;
        function AsPass(): TSPassBlock; inline;
    end;


    { TTechnique }

    TSTechnique = class(TInterfacedObject, ID3DX11EffectTechnique)

        pName: PAnsichar;

        PassCount: uint32;
        pPasses: PSPassBlock;

        AnnotationCount: uint32;
        pAnnotations: PSAnnotation;

        InitiallyValid: boolean;
        HasDependencies: boolean;
        constructor Create;
        destructor Destroy; override;
        // ID3DX11EffectTechnique
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_TECHNIQUE_DESC): HResult; stdcall;

        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;

        function GetPassByIndex(Index: UINT32): ID3DX11EffectPass; stdcall;
        function GetPassByName(Name: LPCSTR): ID3DX11EffectPass; stdcall;

        function ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;
    end;

    PSTechnique = ^TSTechnique;



    { TSGroup }

    TSGroup = class(TInterfacedObject, ID3DX11EffectGroup)

        pName: Pansichar;

        TechniqueCount: uint32;
        pTechniques: PSTechnique;

        AnnotationCount: uint32;
        pAnnotations: PSAnnotation;

        InitiallyValid: boolean;
        HasDependencies: boolean;

        // ID3DX11EffectGroup
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_GROUP_DESC): HResult; stdcall;

        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;

        function GetTechniqueByIndex(Index: UINT32): ID3DX11EffectTechnique; stdcall;
        function GetTechniqueByName(Name: LPCSTR): ID3DX11EffectTechnique; stdcall;
    end;


    TGSSODesc = record
        case integer of
            0: (pEntry: PD3D11_SO_DECLARATION_ENTRY);
            1: (pEntryDesc: PAnsichar);

    end;

    TBackingStore = record
        pBlendState: ID3D11BlendState;
        BlendFactor: array [0..3] of single;
        SampleMask: uint32;
        pDepthStencilState: ID3D11DepthStencilState;
        StencilRef: uint32;
        GSSODesc: TGSSODesc;

        // Pass assignments can write directly into these
        pBlendBlock: TSBlendBlock;
        pDepthStencilBlock: TSDepthStencilBlock;
        pRasterizerBlock: TSRasterizerBlock;
        RenderTargetViewCount: uint32;
{ ToDo               pRenderTargetViews: array[0..D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT-1] of TRenderTargetView;
               pDepthStencilView:TDepthStencilView;
                    pVertexShaderBlock:TShaderBlock;
                    pPixelShaderBlock:TShaderBlock;
                    pGeometryShaderBlock:TShaderBlock;
                    pComputeShaderBlock:TShaderBlock;
                    pDomainShaderBlock:TShaderBlock;
                    pHullShaderBlock:TShaderBlock;  }
    end;


    { TSPassBlock }

    TSPassBlock = class(TSBaseBlock, ID3DX11EffectPass)
        BackingStore: TBackingStore;
        pName: PAnsichar;
        AnnotationCount: uint32;
        pAnnotations: PSAnnotation;

        pEffect: TEffect;

        InitiallyValid: boolean;         // validity of all state objects and shaders in pass upon BindToDevice
        HasDependencies: boolean;
        // if pass expressions or pass state blocks have dependencies on variables (if true, IsValid != InitiallyValid possibly)
        constructor Create;
        destructor Destroy; override;
        procedure ApplyPassAssignments();
        function CheckShaderDependencies(const pBlock: TSShaderBlock): boolean;
        function CheckDependencies(): boolean;
        // template<EObjectType EShaderType>
        function GetShaderDescHelper(out pDesc: TD3DX11_PASS_SHADER_DESC): HRESULT;

        // ID3DX11EffectPass
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_PASS_DESC): HResult; stdcall;

        function GetVertexShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetGeometryShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetPixelShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetHullShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetDomainShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetComputeShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;

        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;

        function Apply(Flags: UINT32; pContext: ID3D11DeviceContext): HResult; stdcall;

        function ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;

    end;

    { TSDepthStencilBlock }

    TSDepthStencilBlock = class(TSBaseBlock)
        pDSObject: ID3D11DepthStencilState;
        BackingStore: TD3D11_DEPTH_STENCIL_DESC;
        IsValid: boolean;
        constructor Create;
    end;



    { TSBlendBlock }

    TSBlendBlock = class(TSBaseBlock)
        pBlendObject: ID3D11BlendState;
        BackingStore: TD3D11_BLEND_DESC;
        IsValid: boolean;
        constructor Create;
    end;

    { TSRasterizerBlock }

    TSRasterizerBlock = class(TSBaseBlock)
        pRasterizerObject: ID3D11RasterizerState;
        BackingStore: TD3D11_RASTERIZER_DESC;
        IsValid: boolean;
        constructor Create;
    end;

    TBackingStoreSamplerBlock = record
        SamplerDesc: TD3D11_SAMPLER_DESC;
        // Sampler "TEXTURE" assignments can write directly into this
        pTexture: TSShaderResource;
    end;

    { TSSamplerBlock }

    TSSamplerBlock = class(TSBaseBlock)
        pD3DObject: ID3D11SamplerState;
        BackingStore: TBackingStoreSamplerBlock;
        constructor Create;
    end;

    { TSInterface }

    TSInterface = class
        pClassInstance: TSClassInstanceGlobalVariable;
        constructor Create;
    end;


    { TShaderResource }

    TSShaderResource = class
        pShaderResource: ID3D11ShaderResourceView;
        constructor Create;
    end;

    { TUnorderedAccessView }

    TSUnorderedAccessView = class
        pUnorderedAccessView: ID3D11UnorderedAccessView;
        constructor Create;
    end;

    { TSRenderTargetView }

    TSRenderTargetView = class
        pRenderTargetView: ID3D11RenderTargetView;
        constructor Create;
    end;

    { TSDepthStencilView }

    TSDepthStencilView = class
        pDepthStencilView: ID3D11DepthStencilView;
        constructor Create;
    end;

    { TSShaderDependency }

    TSShaderDependency <T, D3DTYPE> = class
        StartIndex: uint32;
        Count: uint32;
        ppFXPointers: T;              // Array of ptrs to FX objects (CBs, TShaderResources, etc)
        ppD3DObjects: D3DTYPE;              // Array of ptrs to matching D3D objects
        constructor Create;
        destructor Destroy; override;
    end;


    TShaderCBDependency = TSShaderDependency<PSConstantBuffer, PID3D11Buffer>;
    PShaderCBDependency = ^TShaderCBDependency;

    TShaderSamplerDependency = TSShaderDependency<PSSamplerBlock, PID3D11SamplerState>;
    PShaderSamplerDependency = ^TShaderSamplerDependency;

    TShaderResourceDependency = TSShaderDependency<PSShaderResource, PID3D11ShaderResourceView>;
    PShaderResourceDependency = ^  TShaderResourceDependency;

    TUnorderedAccessViewDependency = TSShaderDependency<PSUnorderedAccessView, PID3D11UnorderedAccessView>;
    PUnorderedAccessViewDependency = ^ TUnorderedAccessViewDependency;

    TInterfaceDependency = TSShaderDependency<PInterface, PID3D11ClassInstance>;
    PInterfaceDependency = ^  TInterfaceDependency;


    // Shader VTables are used to eliminate branching in ApplyShaderBlock.
    // The effect owns one D3DShaderVTables for each shader stage
    TD3DShaderVTable = record
    (*
    void ( __stdcall ID3D11DeviceContext::*pSetShader)( pShader:ID3D11DeviceChild; ppClassInstances:PID3D11ClassInstance;  NumClassInstances:uint32);
    void ( __stdcall ID3D11DeviceContext::*pSetConstantBuffers)( StartConstantSlot:uint32;  NumBuffers:uint32; pBuffers :PID3D11Buffer);
    void ( __stdcall ID3D11DeviceContext::*pSetSamplers)(uint32 Offset, uint32 NumSamplers, ID3D11SamplerState*const* pSamplers);
    void ( __stdcall ID3D11DeviceContext::*pSetShaderResources)(uint32 Offset, uint32 NumResources, ID3D11ShaderResourceView *const *pResources);
    HRESULT ( __stdcall ID3D11Device::*pCreateShader)(const void *pShaderBlob, size_t ShaderBlobSize, ID3D11ClassLinkage* pClassLinkage, ID3D11DeviceChild **ppShader);
*)
    end;

    TESigType = (
        ST_Input,
        ST_Output,
        ST_PatchConstant
        );

    TInterfaceParameter = record
        pName: PAnsiChar;
        Index: uint32;
    end;
    PInterfaceParameter = ^TInterfaceParameter;

    // this data is classified as reflection-only and will all be discarded at runtime
    TReflectionData = record
        pBytecode: PByte;
        BytecodeLength: uint32;
        pStreamOutDecls: array[0..3] of PAnsiChar;        // set with ConstructGSWithSO
        RasterizedStream: uint32;           // set with ConstructGSWithSO
        IsNullGS: boolean;
        pReflection: ID3D11ShaderReflection;
        InterfaceParameterCount: uint32;    // set with BindInterfaces (used for function interface parameters)
        pInterfaceParameters: PInterfaceParameter;      // set with BindInterfaces (used for function interface parameters)
    end;

    PReflectionData = ^TReflectionData;

    { TSShaderBlock }

    TSShaderBlock = class
        IsValid: boolean;
        pVT: PD3DShaderVTable;

        // This value is nil if the shader is nil or was never initialized
        pReflectionData: PReflectionData;

        pD3DObject: ID3D11DeviceChild;

        CBDepCount: uint32;
        pCBDeps: PShaderCBDependency;

        SampDepCount: uint32;
        pSampDeps: PShaderSamplerDependency;

        InterfaceDepCount: uint32;
        pInterfaceDeps: PInterfaceDependency;

        ResourceDepCount: uint32;
        pResourceDeps: PShaderResourceDependency;

        UAVDepCount: uint32;
        pUAVDeps: PUnorderedAccessViewDependency;

        TBufferDepCount: uint32;
        ppTbufDeps: PSConstantBuffer; // **

        pInputSignatureBlob: ID3DBlob;   // The input signature is separated from the bytecode because it
        // is always available, even after Optimize() has been called.
        constructor Create(pVirtualTable: PD3DShaderVTable = nil);
        destructor Destroy; override;
        function GetShaderType(): TEObjectType;

        function OnDeviceBind(): HRESULT;

        // Public API helpers
        function ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HRESULT;

        function GetShaderDesc(out pDesc: TD3DX11_EFFECT_SHADER_DESC; IsInline: boolean): HRESULT;

        function GetVertexShader(out ppVS: ID3D11VertexShader): HRESULT;
        function GetGeometryShader(out ppGS: ID3D11GeometryShader): HRESULT;
        function GetPixelShader(out ppPS: ID3D11PixelShader): HRESULT;
        function GetHullShader(out ppHS: ID3D11HullShader): HRESULT;
        function GetDomainShader(out ppDS: ID3D11DomainShader): HRESULT;
        function GetComputeShader(out ppCS: ID3D11ComputeShader): HRESULT;

        function GetSignatureElementDesc(SigType: TESigType; Element: uint32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HRESULT;
    end;


    { TSString }

    TSString = class
        pString: PAnsiChar;
        constructor Create;
    end;



    //////////////////////////////////////////////////////////////////////////
    // Global Variable & Annotation structure/interface definitions
    //////////////////////////////////////////////////////////////////////////


    // This is a general structure that can describe
    // annotations, variables, and structure members


    TMemberData = record
        case integer of

            0: (MemberDataOffsetPlus4: uint32);  // 4 added so that 0 = nil can represent "unused"
            1: (pMemberData: PMemberDataPointer);
    end;

    { TSVariable }

    TSVariable = class

        // For annotations/variables/variable members:
        // 1) If numeric, pointer to data (for variables: points into backing store,
        //      for annotations, points into reflection heap)
        // OR
        // 2) If object, pointer to the block. If object array, subsequent array elements are found in
        //      contiguous blocks; the Nth block is found by ((<SpecificBlockType> *) pBlock) + N
        //      (this is because variables that are arrays of objects have their blocks allocated contiguously)

        // For structure members:
        //    Offset of this member (in bytes) from parent structure (structure members must be numeric/struct)
        Data: TUDataPointer;
        MemberData: TMemberData;

        pType: TSType;
        pName: PAnsichar;
        pSemantic: PAnsichar;
        ExplicitBindPoint: uint32;
        constructor Create;
        destructor Destroy; override;
    end;

    // Template definitions for all of the various ID3DX11EffectVariable specializations
    //--------------------------------------------------------------------------------------
    // File: EffectVariable.inl

    // Direct3D 11 Effects Variable reflection template
    // These templates define the many Effect variable types.

    // Copyright (c) Microsoft Corporation. All rights reserved.
    // Licensed under the MIT License.

    // http://go.microsoft.com/fwlink/p/?LinkId=271568
    //--------------------------------------------------------------------------------------


    //////////////////////////////////////////////////////////////////////////
    // Invalid variable forward defines
    //////////////////////////////////////////////////////////////////////////

    TEffectInvalidScalarVariable = class;
    TEffectInvalidVectorVariable = class;
    TEffectInvalidMatrixVariable = class;
    TEffectInvalidStringVariable = class;
    TEffectInvalidClassInstanceVariable = class;
    TEffectInvalidInterfaceVariable = class;
    TEffectInvalidShaderResourceVariable = class;
    TEffectInvalidUnorderedAccessViewVariable = class;
    TEffectInvalidRenderTargetViewVariable = class;
    TEffectInvalidDepthStencilViewVariable = class;
    TEffectInvalidConstantBuffer = class;
    TEffectInvalidShaderVariable = class;
    TEffectInvalidBlendVariable = class;
    TEffectInvalidDepthStencilVariable = class;
    TEffectInvalidRasterizerVariable = class;
    TEffectInvalidSamplerVariable = class;
    TEffectInvalidTechnique = class;
    TEffectInvalidPass = class;
    TEffectInvalidType = class;



    TETemplateVarType = (
        ETVT_Bool,
        ETVT_Int,
        ETVT_Float,
        ETVT_bool_);

    //////////////////////////////////////////////////////////////////////////
    // Invalid effect variable struct definitions
    //////////////////////////////////////////////////////////////////////////

    { TEffectInvalidType }

    TEffectInvalidType = class(TInterfacedObject, ID3DX11EffectType)
        // ID3DX11EffectType
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall;
        function GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
        function GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberName(Index: UINT32): LPCSTR; stdcall;
        function GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
    end;


    { TEffectInvalidVariable }

    TEffectInvalidVariable = class(ID3DX11EffectVariable)
    public
        // ID3DX11EffectVariable
        function IsValid(): boolean; stdcall;
        function GetType(): ID3DX11EffectType; stdcall;
        function GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall;
        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
        function GetMemberByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
        function GetMemberBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall;
        function GetElement(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall;
        function AsScalar(): ID3DX11EffectScalarVariable; stdcall;
        function AsVector(): ID3DX11EffectVectorVariable; stdcall;
        function AsMatrix(): ID3DX11EffectMatrixVariable; stdcall;
        function AsString(): ID3DX11EffectStringVariable; stdcall;
        function AsClassInstance(): ID3DX11EffectClassInstanceVariable; stdcall;
        function AsInterface(): ID3DX11EffectInterfaceVariable; stdcall;
        function AsShaderResource(): ID3DX11EffectShaderResourceVariable; stdcall;
        function AsUnorderedAccessView(): ID3DX11EffectUnorderedAccessViewVariable; stdcall;
        function AsRenderTargetView(): ID3DX11EffectRenderTargetViewVariable; stdcall;
        function AsDepthStencilView(): ID3DX11EffectDepthStencilViewVariable; stdcall;
        function AsConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall;
        function AsShader(): ID3DX11EffectShaderVariable; stdcall;
        function AsBlend(): ID3DX11EffectBlendVariable; stdcall;
        function AsDepthStencil(): ID3DX11EffectDepthStencilVariable; stdcall;
        function AsRasterizer(): ID3DX11EffectRasterizerVariable; stdcall;
        function AsSampler(): ID3DX11EffectSamplerVariable; stdcall;
        function SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
        function GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
    end;

    { TEffectInvalidScalarVariable }

    TEffectInvalidScalarVariable = class(TEffectInvalidVariable, ID3DX11EffectScalarVariable)
    public
        // ID3DX11EffectScalarVariable
        function SetFloat(Value: single): HResult; stdcall;
        function GetFloat(out pValue: single): HResult; stdcall;

        function SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;

        function SetInt(Value: integer): HResult; stdcall;
        function GetInt(out pValue: integer): HResult; stdcall;

        function SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;

        function SetBool(const Value: boolean): HResult; stdcall;
        function GetBool(out pValue: boolean): HResult; stdcall;

        function SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;


    { TEffectInvalidVectorVariable }

    TEffectInvalidVectorVariable = class(TEffectInvalidVariable, ID3DX11EffectVectorVariable)
    public
        // ID3DX11EffectVectorVariable
        function SetBoolVector(const pData: TBoolVector): HResult; stdcall;
        function SetIntVector(const pData: TIntVector): HResult; stdcall;
        function SetFloatVector(const pData: TFloatVector): HResult; stdcall;

        function GetBoolVector(out pData: TBoolVector): HResult; stdcall;
        function GetIntVector(out pData: TIntVector): HResult; stdcall;
        function GetFloatVector(out pData: TFloatVector): HResult; stdcall;

        function SetBoolVectorArray(pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function SetIntVectorArray(pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function SetFloatVectorArray(pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;

        function GetBoolVectorArray(out pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetIntVectorArray(out pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetFloatVectorArray(out pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;

    { TEffectInvalidMatrixVariable }

    TEffectInvalidMatrixVariable = class(TEffectInvalidVariable, ID3DX11EffectMatrixVariable)
    public
        // ID3DX11EffectMatrixVariable
        function SetMatrix(const pData: TD3DXMATRIX): HResult; stdcall;
        function GetMatrix(out pData: TD3DXMATRIX): HResult; stdcall;

        function SetMatrixArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetMatrixArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;

        function SetMatrixPointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetMatrixPointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall;

        function SetMatrixTranspose(const pData: TD3DXMATRIX): HResult; stdcall;
        function GetMatrixTranspose(out pData: TD3DXMATRIX): HResult; stdcall;

        function SetMatrixTransposeArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetMatrixTransposeArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;

        function SetMatrixTransposePointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetMatrixTransposePointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;

    { TEffectInvalidStringVariable }

    TEffectInvalidStringVariable = class(TEffectInvalidVariable, ID3DX11EffectStringVariable)
    public
        // ID3DX11EffectStringVariable
        function GetString(out ppString: PAnsiChar): HResult; stdcall;
        function GetStringArray(out ppStrings: PAnsiChar; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;

    { TEffectInvalidClassInstanceVariable }

    TEffectInvalidClassInstanceVariable = class(TEffectInvalidVariable, ID3DX11EffectClassInstanceVariable)
    public
        // ID3DX11EffectClassInstanceVariable
        function GetClassInstance(out ppClassInstance: ID3D11ClassInstance): HResult; stdcall;
    end;


    { TEffectInvalidInterfaceVariable }

    TEffectInvalidInterfaceVariable = class(TEffectInvalidVariable, ID3DX11EffectInterfaceVariable)

    public
        // ID3DX11EffectInterfaceVariable
        function SetClassInstance(pEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall;
        function GetClassInstance(out ppEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall;
    end;


    { TEffectInvalidShaderResourceVariable }

    TEffectInvalidShaderResourceVariable = class(TEffectInvalidVariable, ID3DX11EffectShaderResourceVariable)

    public
        // ID3DX11EffectShaderResourceVariable
        function SetResource(pResource: ID3D11ShaderResourceView): HResult; stdcall;
        function GetResource(out ppResource: ID3D11ShaderResourceView): HResult; stdcall;

        function SetResourceArray(ppResources: PID3D11ShaderResourceView; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetResourceArray(out ppResources: PID3D11ShaderResourceView; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;


    { TEffectInvalidUnorderedAccessViewVariable }

    TEffectInvalidUnorderedAccessViewVariable = class(TEffectInvalidVariable, ID3DX11EffectUnorderedAccessViewVariable)
    public
        // ID3DX11EffectUnorderedAccessViewVariable
        function SetUnorderedAccessView(pResource: ID3D11UnorderedAccessView): HResult; stdcall;
        function GetUnorderedAccessView(out ppResource: ID3D11UnorderedAccessView): HResult; stdcall;

        function SetUnorderedAccessViewArray(ppResources: PID3D11UnorderedAccessView; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetUnorderedAccessViewArray(out ppResources: ID3D11UnorderedAccessView; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;

    { TEffectInvalidRenderTargetViewVariable }

    TEffectInvalidRenderTargetViewVariable = class(TEffectInvalidVariable, ID3DX11EffectRenderTargetViewVariable)
    public
        // ID3DX11EffectRenderTargetViewVariable
        function SetRenderTarget(pResource: ID3D11RenderTargetView): HResult; stdcall;
        function GetRenderTarget(out ppResource: ID3D11RenderTargetView): HResult; stdcall;

        function SetRenderTargetArray(ppResources: PID3D11RenderTargetView; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetRenderTargetArray(out ppResources: PID3D11RenderTargetView; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;


    { TEffectInvalidDepthStencilViewVariable }

    TEffectInvalidDepthStencilViewVariable = class(TEffectInvalidVariable, ID3DX11EffectDepthStencilViewVariable)

    public
        // ID3DX11EffectDepthStencilViewVariable
        function SetDepthStencil(pResource: ID3D11DepthStencilView): HResult; stdcall;
        function GetDepthStencil(out ppResource: ID3D11DepthStencilView): HResult; stdcall;

        function SetDepthStencilArray(ppResources: PID3D11DepthStencilView; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetDepthStencilArray(out ppResources: PID3D11DepthStencilView; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;


    { TEffectInvalidConstantBuffer }

    TEffectInvalidConstantBuffer = class(TEffectInvalidVariable, ID3DX11EffectConstantBuffer)
    public
        // ID3DX11EffectConstantBuffer
        function SetConstantBuffer(pConstantBuffer: ID3D11Buffer): HResult; stdcall;
        function UndoSetConstantBuffer(): HResult; stdcall;
        function GetConstantBuffer(out ppConstantBuffer: ID3D11Buffer): HResult; stdcall;

        function SetTextureBuffer(pTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;
        function UndoSetTextureBuffer(): HResult; stdcall;
        function GetTextureBuffer(out ppTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;

    end;

    { TEffectInvalidShaderVariable }

    TEffectInvalidShaderVariable = class(TEffectInvalidVariable, ID3DX11EffectShaderVariable)
    public
        // ID3DX11EffectShaderVariable
        function GetShaderDesc(ShaderIndex: UINT32; out pDesc: TD3DX11_EFFECT_SHADER_DESC): HResult; stdcall;

        function GetVertexShader(ShaderIndex: UINT32; out ppVS: ID3D11VertexShader): HResult; stdcall;
        function GetGeometryShader(ShaderIndex: UINT32; out ppGS: ID3D11GeometryShader): HResult; stdcall;
        function GetPixelShader(ShaderIndex: UINT32; out ppPS: ID3D11PixelShader): HResult; stdcall;
        function GetHullShader(ShaderIndex: UINT32; out ppHS: ID3D11HullShader): HResult; stdcall;
        function GetDomainShader(ShaderIndex: UINT32; out ppDS: ID3D11DomainShader): HResult; stdcall;
        function GetComputeShader(ShaderIndex: UINT32; out ppCS: ID3D11ComputeShader): HResult; stdcall;

        function GetInputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
        function GetOutputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
        function GetPatchConstantSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
            out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
    end;

    { TEffectInvalidBlendVariable }

    TEffectInvalidBlendVariable = class(TEffectInvalidVariable, ID3DX11EffectBlendVariable)
    public
        // ID3DX11EffectBlendVariable
        function GetBlendState(Index: UINT32; out ppState: ID3D11BlendState): HResult; stdcall;
        function SetBlendState(Index: UINT32; pState: ID3D11BlendState): HResult; stdcall;
        function UndoSetBlendState(Index: UINT32): HResult; stdcall;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_BLEND_DESC): HResult; stdcall;
    end;

    { TEffectInvalidDepthStencilVariable }

    TEffectInvalidDepthStencilVariable = class(TEffectInvalidVariable, ID3DX11EffectDepthStencilVariable)
    public
        // ID3DX11EffectDepthStencilVariable
        function GetDepthStencilState(Index: UINT32; out ppState: ID3D11DepthStencilState): HResult; stdcall;
        function SetDepthStencilState(Index: UINT32; pState: ID3D11DepthStencilState): HResult; stdcall;
        function UndoSetDepthStencilState(Index: UINT32): HResult; stdcall;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_DEPTH_STENCIL_DESC): HResult; stdcall;
    end;

    { TEffectInvalidRasterizerVariable }

    TEffectInvalidRasterizerVariable = class(TEffectInvalidVariable, ID3DX11EffectRasterizerVariable)
    public
        // ID3DX11EffectRasterizerVariable
        function GetRasterizerState(Index: UINT32; out ppState: ID3D11RasterizerState): HResult; stdcall;
        function SetRasterizerState(Index: UINT32; pState: ID3D11RasterizerState): HResult; stdcall;
        function UndoSetRasterizerState(Index: UINT32): HResult; stdcall;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_RASTERIZER_DESC): HResult; stdcall;
    end;

    { TEffectInvalidSamplerVariable }

    TEffectInvalidSamplerVariable = class(TEffectInvalidVariable, ID3DX11EffectSamplerVariable)
    public
        // ID3DX11EffectSamplerVariable
        function GetSampler(Index: UINT32; out ppSampler: ID3D11SamplerState): HResult; stdcall;
        function SetSampler(Index: UINT32; pSampler: ID3D11SamplerState): HResult; stdcall;
        function UndoSetSampler(Index: UINT32): HResult; stdcall;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_SAMPLER_DESC): HResult; stdcall;
    end;

    { TEffectInvalidPass }

    TEffectInvalidPass = class(ID3DX11EffectPass)
    public
        // ID3DX11EffectPass
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_PASS_DESC): HResult; stdcall;

        function GetVertexShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetGeometryShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetPixelShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetHullShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetDomainShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
        function GetComputeShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;

        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;

        function Apply(Flags: UINT32; pContext: ID3D11DeviceContext): HResult; stdcall;

        function ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;
    end;

    { TEffectInvalidTechnique }

    TEffectInvalidTechnique = class(TInterfacedObject, ID3DX11EffectTechnique)
    public
        // ID3DX11EffectTechnique
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_TECHNIQUE_DESC): HResult; stdcall;

        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;

        function GetPassByIndex(Index: UINT32): ID3DX11EffectPass; stdcall;
        function GetPassByName(Name: LPCSTR): ID3DX11EffectPass; stdcall;

        function ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;
    end;

    { TEffectInvalidGroup }

    TEffectInvalidGroup = class(TInterfacedObject, ID3DX11EffectGroup)
    public
        // ID3DX11EffectGroup
        function IsValid(): boolean; stdcall;
        function GetDesc(out pDesc: TD3DX11_GROUP_DESC): HResult; stdcall;

        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;

        function GetTechniqueByIndex(Index: UINT32): ID3DX11EffectTechnique; stdcall;
        function GetTechniqueByName(Name: LPCSTR): ID3DX11EffectTechnique; stdcall;
    end;



    //////////////////////////////////////////////////////////////////////////
    // TVariable - implements type casting and member/element retrieval
    //////////////////////////////////////////////////////////////////////////

    // requires that IBaseInterface contain SVariable's fields and support ID3DX11EffectVariable
    TVariable = class(TSVariable, ID3DX11EffectVariable)

        // ID3DX11EffectVariable
        function IsValid(): boolean; stdcall; virtual;
        function GetType(): ID3DX11EffectType; stdcall; virtual;
        function GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall; virtual;
        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; virtual;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; virtual;
        function GetMemberByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; virtual;
        function GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; virtual;
        function GetMemberBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall; virtual;
        function GetElement(Index: UINT32): ID3DX11EffectVariable; stdcall; virtual;
        function GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; virtual;
        function AsScalar(): ID3DX11EffectScalarVariable; stdcall; virtual;
        function AsVector(): ID3DX11EffectVectorVariable; stdcall; virtual;
        function AsMatrix(): ID3DX11EffectMatrixVariable; stdcall; virtual;
        function AsString(): ID3DX11EffectStringVariable; stdcall; virtual;
        function AsClassInstance(): ID3DX11EffectClassInstanceVariable; stdcall; virtual;
        function AsInterface(): ID3DX11EffectInterfaceVariable; stdcall; virtual;
        function AsShaderResource(): ID3DX11EffectShaderResourceVariable; stdcall; virtual;
        function AsUnorderedAccessView(): ID3DX11EffectUnorderedAccessViewVariable; stdcall; virtual;
        function AsRenderTargetView(): ID3DX11EffectRenderTargetViewVariable; stdcall; virtual;
        function AsDepthStencilView(): ID3DX11EffectDepthStencilViewVariable; stdcall; virtual;
        function AsConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; virtual;
        function AsShader(): ID3DX11EffectShaderVariable; stdcall; virtual;
        function AsBlend(): ID3DX11EffectBlendVariable; stdcall; virtual;
        function AsDepthStencil(): ID3DX11EffectDepthStencilVariable; stdcall; virtual;
        function AsRasterizer(): ID3DX11EffectRasterizerVariable; stdcall; virtual;
        function AsSampler(): ID3DX11EffectSamplerVariable; stdcall; virtual;
        function SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; virtual;
        function GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; virtual;
    end;

    //////////////////////////////////////////////////////////////////////////
    // TTopLevelVariable - functionality for annotations and global variables
    //////////////////////////////////////////////////////////////////////////


    TTopLevelVariable = class(TVariable)
        // Required to create member/element variable interfaces
        pEffect: TEffect;
        function GetEffect(): TEffect;
        constructor Create;
        destructor Destroy; override;
        function GetTotalUnpackedSize(): uint32;
        function GetType(): ID3DX11EffectType; stdcall; override;
        function GetTopLevelEntity(): TTopLevelVariable;
        function IsArray(): boolean;
    end;

    //////////////////////////////////////////////////////////////////////////
    // TMember - functionality for structure/array members of other variables
    //////////////////////////////////////////////////////////////////////////


    TMember = class(TVariable)
    public
        // Indicates that this is a single element of a containing array
        IsSingleElement: boolean;

        // Required to create member/element variable interfaces
        pTopLevelEntity: TTopLevelVariable;

        constructor Create;
        destructor Destroy; override;

        function GetEffect(): TEffect;


        function GetTotalUnpackedSize(): uint32;
        function GetType(): ID3DX11EffectType; stdcall; override;
        function GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall; override;
        function GetTopLevelEntity(): TTopLevelVariable;
        function IsArray(): boolean;
        function GetAnnotationByIndex(Index: uint32): ID3DX11EffectVariable; stdcall; override;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; override;
        // Annotations should never be able to go down this codepath
        procedure DirtyVariable();

    end;

    //////////////////////////////////////////////////////////////////////////
    // TAnnotation - functionality for top level annotations
    //////////////////////////////////////////////////////////////////////////

    TAnnotation = class(TTopLevelVariable)
        function GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall; override;
        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; override;
        procedure DirtyVariable();
    end;

    //////////////////////////////////////////////////////////////////////////
    // TGlobalVariable - functionality for top level global variables
    //////////////////////////////////////////////////////////////////////////


    TGlobalVariable = class(TTopLevelVariable)
        LastModifiedTime: TTimer;

        // if numeric, pointer to the constant buffer where this variable lives
        pCB: PSConstantBuffer;

        AnnotationCount: uint32;
        pAnnotations: PSAnnotation;

        constructor Create;
        destructor Destroy; override;

        function GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall; override;
        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; override;


        procedure DirtyVariable();
    end;

    //////////////////////////////////////////////////////////////////////////
    // TNumericVariable - implements raw set/get functionality
    //////////////////////////////////////////////////////////////////////////

    // IMPORTANT NOTE: All of these numeric & object aspect classes MUST NOT
    // add data members to the base variable classes.  Otherwise type sizes
    // will disagree between object & numeric variables and we cannot eaily
    // create arrays of global variables using SGlobalVariable

    // Requires that IBaseInterface have SVariable's members, GetTotalUnpackedSize() and DirtyVariable()
    // ToDo template<typename IBaseInterface, bool IsAnnotation>
    TNumericVariable = class(TVariable)
        function SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; override;
        function GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; override;
    end;

    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectScalarVariable (TFloatScalarVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    // toDo IsAnnotation

    { TFloatScalarVariable }

    TFloatScalarVariable = class(TNumericVariable, ID3DX11EffectScalarVariable)
    public
        // ID3DX11EffectScalarVariable
        function SetFloat(Value: single): HResult; stdcall; virtual;
        function GetFloat(out pValue: single): HResult; stdcall; virtual;

        function SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetInt(Value: integer): HResult; stdcall; virtual;
        function GetInt(out pValue: integer): HResult; stdcall; virtual;

        function SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetBool(const Value: boolean): HResult; stdcall; virtual;
        function GetBool(out pValue: boolean): HResult; stdcall; virtual;

        function SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;


    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectScalarVariable (TIntScalarVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    //template<typename IBaseInterface, bool IsAnnotation>

    { TIntScalarVariable }

    TIntScalarVariable = class(TNumericVariable, ID3DX11EffectScalarVariable)
    public
        // ID3DX11EffectScalarVariable
        function SetFloat(Value: single): HResult; stdcall; virtual;
        function GetFloat(out pValue: single): HResult; stdcall; virtual;

        function SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetInt(Value: integer): HResult; stdcall; virtual;
        function GetInt(out pValue: integer): HResult; stdcall; virtual;

        function SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetBool(const Value: boolean): HResult; stdcall; virtual;
        function GetBool(out pValue: boolean): HResult; stdcall; virtual;

        function SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;



    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectScalarVariable (TBoolScalarVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    //template<typename IBaseInterface, bool IsAnnotation>

    { TBoolScalarVariable }

    TBoolScalarVariable = class(TNumericVariable, ID3DX11EffectScalarVariable)
    public
        // ID3DX11EffectScalarVariable
        function SetFloat(Value: single): HResult; stdcall; virtual;
        function GetFloat(out pValue: single): HResult; stdcall; virtual;

        function SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetInt(Value: integer): HResult; stdcall; virtual;
        function GetInt(out pValue: integer): HResult; stdcall; virtual;

        function SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetBool(const Value: boolean): HResult; stdcall; virtual;
        function GetBool(out pValue: boolean): HResult; stdcall; virtual;

        function SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;


    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectVectorVariable (TVectorVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    // template<typename IBaseInterface, bool IsAnnotation, ETemplateVarType BaseType >

    { TVectorVariable }

    TVectorVariable = class(TNumericVariable, ID3DX11EffectVectorVariable)
    public
        // ID3DX11EffectVectorVariable
        function SetBoolVector(const pData: TBoolVector): HResult; stdcall; virtual;
        function SetIntVector(const pData: TIntVector): HResult; stdcall; virtual;
        function SetFloatVector(const pData: TFloatVector): HResult; stdcall; virtual;

        function GetBoolVector(out pData: TBoolVector): HResult; stdcall; virtual;
        function GetIntVector(out pData: TIntVector): HResult; stdcall; virtual;
        function GetFloatVector(out pData: TFloatVector): HResult; stdcall; virtual;

        function SetBoolVectorArray(pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function SetIntVectorArray(pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function SetFloatVectorArray(pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function GetBoolVectorArray(out pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetIntVectorArray(out pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetFloatVectorArray(out pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;



    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectVector4Variable (TVectorVariable implementation) [OPTIMIZED]
    //////////////////////////////////////////////////////////////////////////


    { TVector4Variable }

    TVector4Variable = class(TVectorVariable)

        function SetFloatVector(const pData: TFloatVector): HResult; stdcall; override;
        function GetFloatVector(out pData: TFloatVector): HResult; stdcall; override;

        function SetFloatVectorArray(pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall; override;
        function GetFloatVectorArray(out pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall; override;
    end;



    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectMatrixVariable (TMatrixVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    // template<typename IBaseInterface, bool IsAnnotation>

    { TMatrixVariable }

    TMatrixVariable = class(TNumericVariable, ID3DX11EffectMatrixVariable)
    public
        // ID3DX11EffectMatrixVariable
        function SetMatrix(const pData: TD3DXMATRIX): HResult; stdcall; virtual;
        function GetMatrix(out pData: TD3DXMATRIX): HResult; stdcall; virtual;

        function SetMatrixArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetMatrixArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetMatrixPointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetMatrixPointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetMatrixTranspose(const pData: TD3DXMATRIX): HResult; stdcall; virtual;
        function GetMatrixTranspose(out pData: TD3DXMATRIX): HResult; stdcall; virtual;

        function SetMatrixTransposeArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetMatrixTransposeArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;

        function SetMatrixTransposePointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetMatrixTransposePointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;


    // Optimize commonly used fast paths
    // (non-annotations only!)
    // template<typename IBaseInterface, bool IsColumnMajor>

    { TMatrix4x4Variable }

    TMatrix4x4Variable = class(TMatrixVariable)
    public
        function SetMatrix(const pData: TD3DXMATRIX): HResult; stdcall; override;
        function GetMatrix(out pData: TD3DXMATRIX): HResult; stdcall; override;

        function SetMatrixArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; override;
        function GetMatrixArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; override;


        function SetMatrixTranspose(const pData: TD3DXMATRIX): HResult; stdcall; override;
        function GetMatrixTranspose(out pData: TD3DXMATRIX): HResult; stdcall; override;

        function SetMatrixTransposeArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; override;
        function GetMatrixTransposeArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall; override;
    end;



    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectStringVariable (TStringVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    // template<typename IBaseInterface, bool IsAnnotation>

    { TStringVariable }

    TStringVariable = class(TVariable)
    public
        // ID3DX11EffectStringVariable
        function GetString(out ppString: PAnsiChar): HResult; stdcall; virtual;
        function GetStringArray(out ppStrings: PAnsiChar; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;


    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectClassInstanceVariable (TClassInstanceVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    //template<typename IBaseInterface>

    { TClassInstanceVariable }

    TClassInstanceVariable = class(TVariable, ID3DX11EffectClassInstanceVariable)
    public
        // ID3DX11EffectClassInstanceVariable
        function GetClassInstance(out ppClassInstance: ID3D11ClassInstance): HResult; stdcall;
    end;

    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectInterfaceVariable (TInterfaceVariable implementation)
    //////////////////////////////////////////////////////////////////////////

    //template<typename IBaseInterface>

    { TInterfaceVariable }

    TInterfaceVariable = class(TVariable, ID3DX11EffectInterfaceVariable)
    public
        // ID3DX11EffectInterfaceVariable
        function SetClassInstance(pEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall; virtual;
        function GetClassInstance(out ppEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall; virtual;
    end;


    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectShaderResourceVariable (TShaderResourceVariable implementation)
    //////////////////////////////////////////////////////////////////////////


    { TShaderResourceVariable }

    TShaderResourceVariable = class(TVariable, ID3DX11EffectShaderResourceVariable)
    public
        // ID3DX11EffectShaderResourceVariable
        function SetResource(pResource: ID3D11ShaderResourceView): HResult; stdcall; virtual;
        function GetResource(out ppResource: ID3D11ShaderResourceView): HResult; stdcall; virtual;

        function SetResourceArray(ppResources: PID3D11ShaderResourceView; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetResourceArray(out ppResources: PID3D11ShaderResourceView; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;

    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectUnorderedAccessViewVariable (TUnorderedAccessViewVariable implementation)
    //////////////////////////////////////////////////////////////////////////


    { TUnorderedAccessViewVariable }

    TUnorderedAccessViewVariable = class(TVariable, ID3DX11EffectUnorderedAccessViewVariable)
    public
        // ID3DX11EffectUnorderedAccessViewVariable
        function SetUnorderedAccessView(pResource: ID3D11UnorderedAccessView): HResult; stdcall; virtual;
        function GetUnorderedAccessView(out ppResource: ID3D11UnorderedAccessView): HResult; stdcall; virtual;

        function SetUnorderedAccessViewArray(ppResources: PID3D11UnorderedAccessView; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
        function GetUnorderedAccessViewArray(out ppResources: ID3D11UnorderedAccessView; Offset: UINT32; Count: UINT32): HResult; stdcall; virtual;
    end;


    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectRenderTargetViewVariable (TRenderTargetViewVariable implementation)
    //////////////////////////////////////////////////////////////////////////


    { TRenderTargetViewVariable }

    TRenderTargetViewVariable = class(TVariable, ID3DX11EffectRenderTargetViewVariable)
    public
        // ID3DX11EffectRenderTargetViewVariable
        function SetRenderTarget(pResource: ID3D11RenderTargetView): HResult; stdcall;
        function GetRenderTarget(out ppResource: ID3D11RenderTargetView): HResult; stdcall;

        function SetRenderTargetArray(ppResources: PID3D11RenderTargetView; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetRenderTargetArray(out ppResources: PID3D11RenderTargetView; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;



    //////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectDepthStencilViewVariable (TDepthStencilViewVariable implementation)
    //////////////////////////////////////////////////////////////////////////


    { TDepthStencilViewVariable }

    TDepthStencilViewVariable = class(TVariable, ID3DX11EffectDepthStencilViewVariable)
    public
        // ID3DX11EffectDepthStencilViewVariable
        function SetDepthStencil(pResource: ID3D11DepthStencilView): HResult; stdcall;
        function GetDepthStencil(out ppResource: ID3D11DepthStencilView): HResult; stdcall;

        function SetDepthStencilArray(ppResources: PID3D11DepthStencilView; Offset: UINT32; Count: UINT32): HResult; stdcall;
        function GetDepthStencilArray(out ppResources: PID3D11DepthStencilView; Offset: UINT32; Count: UINT32): HResult; stdcall;
    end;



    ////////////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectShaderVariable (TShaderVariable implementation)
    ////////////////////////////////////////////////////////////////////////////////


    { TShaderVariable }

    TShaderVariable = class(TVariable, ID3DX11EffectShaderVariable)
    public
        // ID3DX11EffectShaderVariable
        function GetShaderDesc(ShaderIndex: UINT32; out pDesc: TD3DX11_EFFECT_SHADER_DESC): HResult; stdcall;

        function GetVertexShader(ShaderIndex: UINT32; out ppVS: ID3D11VertexShader): HResult; stdcall;
        function GetGeometryShader(ShaderIndex: UINT32; out ppGS: ID3D11GeometryShader): HResult; stdcall;
        function GetPixelShader(ShaderIndex: UINT32; out ppPS: ID3D11PixelShader): HResult; stdcall;
        function GetHullShader(ShaderIndex: UINT32; out ppHS: ID3D11HullShader): HResult; stdcall;
        function GetDomainShader(ShaderIndex: UINT32; out ppDS: ID3D11DomainShader): HResult; stdcall;
        function GetComputeShader(ShaderIndex: UINT32; out ppCS: ID3D11ComputeShader): HResult; stdcall;

        function GetInputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
        function GetOutputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
        function GetPatchConstantSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
            out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
    end;


    ////////////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectBlendVariable (TBlendVariable implementation)
    ////////////////////////////////////////////////////////////////////////////////


    { TBlendVariable }

    TBlendVariable = class(TVariable, ID3DX11EffectBlendVariable)
    public
        // ID3DX11EffectBlendVariable
        function GetBlendState(Index: UINT32; out ppState: ID3D11BlendState): HResult; stdcall;
        function SetBlendState(Index: UINT32; pState: ID3D11BlendState): HResult; stdcall;
        function UndoSetBlendState(Index: UINT32): HResult; stdcall;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_BLEND_DESC): HResult; stdcall;
    end;

    ////////////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectDepthStencilVariable (TDepthStencilVariable implementation)
    ////////////////////////////////////////////////////////////////////////////////


    { TDepthStencilVariable }

    TDepthStencilVariable = class(TVariable, ID3DX11EffectDepthStencilVariable)
    public
        // ID3DX11EffectDepthStencilVariable
        function GetDepthStencilState(Index: UINT32; out ppState: ID3D11DepthStencilState): HResult; stdcall;
        function SetDepthStencilState(Index: UINT32; pState: ID3D11DepthStencilState): HResult; stdcall;
        function UndoSetDepthStencilState(Index: UINT32): HResult; stdcall;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_DEPTH_STENCIL_DESC): HResult; stdcall;
    end;



    ////////////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectRasterizerVariable (TRasterizerVariable implementation)
    ////////////////////////////////////////////////////////////////////////////////


    { TRasterizerVariable }

    TRasterizerVariable = class(TVariable, ID3DX11EffectRasterizerVariable)
    public

        // ID3DX11EffectRasterizerVariable
        function GetRasterizerState(Index: UINT32; out ppState: ID3D11RasterizerState): HResult; stdcall; virtual;
        function SetRasterizerState(Index: UINT32; pState: ID3D11RasterizerState): HResult; stdcall; virtual;
        function UndoSetRasterizerState(Index: UINT32): HResult; stdcall; virtual;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_RASTERIZER_DESC): HResult; stdcall; virtual;
        function IsValid(): boolean; stdcall; override;
    end;


    ////////////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectSamplerVariable (TSamplerVariable implementation)
    ////////////////////////////////////////////////////////////////////////////////


    { TSamplerVariable }

    TSamplerVariable = class(TVariable, ID3DX11EffectSamplerVariable)

    public

        // ID3DX11EffectSamplerVariable
        function GetSampler(Index: UINT32; out ppSampler: ID3D11SamplerState): HResult; stdcall;
        function SetSampler(Index: UINT32; pSampler: ID3D11SamplerState): HResult; stdcall;
        function UndoSetSampler(Index: UINT32): HResult; stdcall;
        function GetBackingStore(Index: UINT32; out pDesc: TD3D11_SAMPLER_DESC): HResult; stdcall;
    end;



    ////////////////////////////////////////////////////////////////////////////////
    // TUncastableVariable
    ////////////////////////////////////////////////////////////////////////////////


    TUncastableVariable = class(TVariable)
    public
        function AsScalar(): ID3DX11EffectScalarVariable; stdcall; override;
        function AsVector(): ID3DX11EffectVectorVariable; stdcall; override;
        function AsMatrix(): ID3DX11EffectMatrixVariable; stdcall; override;
        function AsString(): ID3DX11EffectStringVariable; stdcall; override;
        function AsClassInstance(): ID3DX11EffectClassInstanceVariable; stdcall; override;
        function AsInterface(): ID3DX11EffectInterfaceVariable; stdcall; override;
        function AsShaderResource(): ID3DX11EffectShaderResourceVariable; stdcall; override;
        function AsUnorderedAccessView(): ID3DX11EffectUnorderedAccessViewVariable; stdcall; override;

        function AsRenderTargetView(): ID3DX11EffectRenderTargetViewVariable; stdcall; override;
        function AsDepthStencilView(): ID3DX11EffectDepthStencilViewVariable; stdcall; override;
        function AsConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; override;
        function AsShader(): ID3DX11EffectShaderVariable; stdcall; override;
        function AsBlend(): ID3DX11EffectBlendVariable; stdcall; override;
        function AsDepthStencil(): ID3DX11EffectDepthStencilVariable; stdcall; override;
        function AsRasterizer(): ID3DX11EffectRasterizerVariable; stdcall; override;
        function AsSampler(): ID3DX11EffectSamplerVariable; stdcall; override;
    end;


    ////////////////////////////////////////////////////////////////////////////////
    // Macros to instantiate the myriad templates
    ////////////////////////////////////////////////////////////////////////////////


    TSClassInstanceGlobalVariable = class(TClassInstanceVariable);

    // Optimized matrix classes
(*
struct SMatrix4x4ColumnMajorGlobalVariable=class( TMatrix4x4Variable<TGlobalVariable<ID3DX11EffectMatrixVariable>, true> { IUNKNOWN_IMP(SMatrix4x4ColumnMajorGlobalVariable, ID3DX11EffectMatrixVariable, ID3DX11EffectVariable); };
struct SMatrix4x4RowMajorGlobalVariable : public TMatrix4x4Variable<TGlobalVariable<ID3DX11EffectMatrixVariable>, false> { IUNKNOWN_IMP(SMatrix4x4RowMajorGlobalVariable, ID3DX11EffectMatrixVariable, ID3DX11EffectVariable); };

struct SMatrix4x4ColumnMajorGlobalVariableMember : public TMatrix4x4Variable<TVariable<TMember<ID3DX11EffectMatrixVariable> >, true> { IUNKNOWN_IMP(SMatrix4x4ColumnMajorGlobalVariableMember, ID3DX11EffectMatrixVariable, ID3DX11EffectVariable); };
struct SMatrix4x4RowMajorGlobalVariableMember : public TMatrix4x4Variable<TVariable<TMember<ID3DX11EffectMatrixVariable> >, false> { IUNKNOWN_IMP(SMatrix4x4RowMajorGlobalVariableMember, ID3DX11EffectMatrixVariable, ID3DX11EffectVariable); };

// Optimized vector classes
struct SFloatVector4GlobalVariable : public TVector4Variable<TGlobalVariable<ID3DX11EffectVectorVariable> > { IUNKNOWN_IMP(SFloatVector4GlobalVariable, ID3DX11EffectVectorVariable, ID3DX11EffectVariable); };
struct SFloatVector4GlobalVariableMember : public TVector4Variable<TVariable<TMember<ID3DX11EffectVectorVariable> > > { IUNKNOWN_IMP(SFloatVector4GlobalVariableMember, ID3DX11EffectVectorVariable, ID3DX11EffectVariable); };
*)

    // These 3 classes should never be used directly

    // The "base" global variable struct (all global variables should be the same size in bytes,
    // but we pick this as the default).
    TSGlobalVariable = class(TGlobalVariable, ID3DX11EffectVariable)
    end;

    // The "base" annotation struct (all annotations should be the same size in bytes,
    // but we pick this as the default).
    TSAnnotation = class(TAnnotation, ID3DX11EffectVariable)
    end;

    // The "base" variable member struct (all annotation/global variable members should be the
    // same size in bytes, but we pick this as the default).
    TSMember = class(TMember, ID3DX11EffectVariable)
    end;




    ////////////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectShaderVariable (SAnonymousShader implementation)
    ////////////////////////////////////////////////////////////////////////////////

    { TAnonymousShader }

    TAnonymousShader = class(TUncastableVariable, ID3DX11EffectShaderVariable, ID3DX11EffectType)
        pShaderBlock: PSShaderBlock;
        constructor Create(pBlock: PSShaderBlock = nil);
        destructor Destroy; override;
        // ID3DX11EffectVariable
        function IsValid(): boolean; stdcall; override;
        function GetType(): ID3DX11EffectType; stdcall; override;
        function GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall; override; overload;
        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetMemberByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetMemberBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetElement(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; override;
        // other casts are handled by TUncastableVariable
        function AsShader(): ID3DX11EffectShaderVariable; stdcall; override;

        function SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; override;
        function GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; override;

        // ID3DX11EffectShaderVariable
        function GetShaderDesc(ShaderIndex: UINT32; out pDesc: TD3DX11_EFFECT_SHADER_DESC): HResult; stdcall; virtual;

        function GetVertexShader(ShaderIndex: UINT32; out ppVS: ID3D11VertexShader): HResult; stdcall; virtual;
        function GetGeometryShader(ShaderIndex: UINT32; out ppGS: ID3D11GeometryShader): HResult; stdcall; virtual;
        function GetPixelShader(ShaderIndex: UINT32; out ppPS: ID3D11PixelShader): HResult; stdcall; virtual;
        function GetHullShader(ShaderIndex: UINT32; out ppHS: ID3D11HullShader): HResult; stdcall; virtual;
        function GetDomainShader(ShaderIndex: UINT32; out ppDS: ID3D11DomainShader): HResult; stdcall; virtual;
        function GetComputeShader(ShaderIndex: UINT32; out ppCS: ID3D11ComputeShader): HResult; stdcall; virtual;

        function GetInputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult;
            stdcall; virtual;
        function GetOutputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult;
            stdcall; virtual;
        function GetPatchConstantSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
            out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall; virtual;

        // ID3DX11EffectType
        function GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall; virtual; overload;
        function GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall; virtual;
        function GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall; virtual;
        function GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall; virtual;
        function GetMemberName(Index: UINT32): LPCSTR; stdcall; virtual;
        function GetMemberSemantic(Index: UINT32): LPCSTR; stdcall; virtual;
    end;


    ////////////////////////////////////////////////////////////////////////////////
    // ID3DX11EffectConstantBuffer (SConstantBuffer implementation)
    ////////////////////////////////////////////////////////////////////////////////

    { TSConstantBuffer }

    TSConstantBuffer = class(TUncastableVariable, ID3DX11EffectConstantBuffer, ID3DX11EffectType)
        pD3DObject: ID3D11Buffer;
        TBuffer: TSShaderResource;            // nil iff IsTbuffer = false

        pBackingStore: PByte;
        Size: uint32;               // in bytes

        pName: PAnsiChar;

        AnnotationCount: uint32;
        pAnnotations: PSAnnotation;

        VariableCount: uint32;      // # of variables contained in this cbuffer
        pVariables: ^TSGlobalVariable;        // array of size [VariableCount], points into effect's contiguous variable list
        ExplicitBindPoint: uint32;  // Used when a CB has been explicitly bound (register(bXX)). -1 if not

        IsDirty: boolean;          // Set when any member is updated; cleared on CB apply
        IsTBuffer: boolean;        // true iff TBuffer.pShaderResource != nil
        IsUserManaged: boolean;    // Set if you don't want effects to update this buffer
        IsEffectOptimized: boolean;// Set if the effect has been optimized
        IsUsedByExpression: boolean;// Set if used by any expressions
        IsUserPacked: boolean;     // Set if the elements have user-specified offsets
        IsSingle: boolean;         // Set to true if you want to share this CB with cloned Effects
        IsNonUpdatable: boolean;   // Set to true if you want to share this CB with cloned Effects

        pEffect: TEffect;
        constructor Create;
        destructor Destroy; override;
        function ClonedSingle(): boolean;

        // ID3DX11EffectVariable
        function IsValid(): boolean; stdcall; override;
        function GetType(): ID3DX11EffectType; stdcall; override;
        function GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall; override; overload;
        function GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetMemberByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetMemberBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall; override;
        function GetElement(Index: UINT32): ID3DX11EffectVariable; stdcall; override;
        function GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; override;
        // other casts are handled by TUncastableVariable
        function AsConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall; override;

        function SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; override;
        function GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall; override;


        // ID3DX11EffectConstantBuffer
        function SetConstantBuffer(pConstantBuffer: ID3D11Buffer): HResult; stdcall;
        function UndoSetConstantBuffer(): HResult; stdcall;
        function GetConstantBuffer(out ppConstantBuffer: ID3D11Buffer): HResult; stdcall;

        function SetTextureBuffer(pTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;
        function UndoSetTextureBuffer(): HResult; stdcall;
        function GetTextureBuffer(out ppTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;

        // ID3DX11EffectType

        function GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall; overload;
        function GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
        function GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall;
        function GetMemberName(Index: UINT32): LPCSTR; stdcall;
        function GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
    end;


    //////////////////////////////////////////////////////////////////////////
    // Assignments
    //////////////////////////////////////////////////////////////////////////

    TERuntimeAssignmentType = (
        ERAT_Invalid,
        // [Destination] refers to the destination location, which is always the backing store of the pass/state block.
        // [Source] refers to the current source of data, always coming from either a constant buffer's
        //  backing store (for numeric assignments), an object variable's block array, or an anonymous (unowned) block

        // Numeric variables:
        ERAT_Constant,                  // Source is unused.
        // No dependencies; this assignment can be safely removed after load.
        ERAT_NumericVariable,           // Source points to the CB's backing store where the value lives.
        // 1 dependency: the variable itself.
        ERAT_NumericConstIndex,         // Source points to the CB's backing store where the value lives, offset by N.
        // 1 dependency: the variable array being indexed.
        ERAT_NumericVariableIndex,      // Source points to the last used element of the variable in the CB's backing store.
        // 2 dependencies: the index variable followed by the array variable.

        // Object variables:
        ERAT_ObjectInlineShader,        // An anonymous, immutable shader block pointer is copied to the destination immediately.
        // No dependencies; this assignment can be safely removed after load.
        ERAT_ObjectVariable,            // A pointer to the block owned by the object variable is copied to the destination immediately.
        // No dependencies; this assignment can be safely removed after load.
        ERAT_ObjectConstIndex,          // A pointer to the Nth block owned by an object variable is copied to the destination immediately.
        // No dependencies; this assignment can be safely removed after load.
        ERAT_ObjectVariableIndex       // Source points to the first block owned by an object variable array
        // (the offset from this, N, is taken from another variable).
        // 1 dependency: the variable being used to index the array.
        );

    TSAssignment = record
    end;




    //////////////////////////////////////////////////////////////////////////
    // Private effect heaps
    //////////////////////////////////////////////////////////////////////////

    // Used to efficiently reallocate data
    // 1) For every piece of data that needs reallocation, move it to its new location
    // and add an entry into the table
    // 2) For everyone that references one of these data blocks, do a quick table lookup
    // to find the old pointer and then replace it with the new one
    TSPointerMapping = record

    end;
    PSPointerMapping = ^TSPointerMapping;


    // Assist adding data to a block of memory
    TEffectHeap = class

    end;

    TEffectReflection = class
    public
        // Single memory block support
        m_Heap: TEffectHeap;
    end;


    { TEffect }

    TEffect = class(TInterfacedObject, ID3DX11Effect)
    public
        // ID3DX11Effect
        function IsValid(): boolean; stdcall;

        function GetDevice(out ppDevice: ID3D11Device): HResult; stdcall;

        function GetDesc(out pDesc: TD3DX11_EFFECT_DESC): HResult; stdcall;

        function GetConstantBufferByIndex(Index: UINT32): ID3DX11EffectConstantBuffer; stdcall;
        function GetConstantBufferByName(Name: LPCSTR): ID3DX11EffectConstantBuffer; stdcall;

        function GetVariableByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
        function GetVariableByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
        function GetVariableBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall;

        function GetGroupByIndex(Index: UINT32): ID3DX11EffectGroup; stdcall;
        function GetGroupByName(Name: LPCSTR): ID3DX11EffectGroup; stdcall;

        function GetTechniqueByIndex(Index: UINT32): ID3DX11EffectTechnique; stdcall;
        function GetTechniqueByName(Name: LPCSTR): ID3DX11EffectTechnique; stdcall;

        function GetClassLinkage(): ID3D11ClassLinkage; stdcall;

        function CloneEffect(Flags: UINT32; out ppClonedEffect: ID3DX11Effect): HResult; stdcall;
        function Optimize(): HResult; stdcall;
        function IsOptimized(): boolean; stdcall;
    end;

function GetBlockByIndex(VarType: TEVarType; ObjectType: TEObjectType; pBaseBlock: Pointer; Index: uint32): Pointer;

implementation

{ TSShaderDependency }

constructor TSShaderDependency<D3DTYPE, T>.Create;
begin
    StartIndex := 0;
    Count := 0;
    ppFXPointers := nil;
    ppD3DObjects := nil;
end;

destructor TSShaderDependency<D3DTYPE, T>.Destroy;
begin
    inherited Destroy;
end;

function GetBlockByIndex(VarType: TEVarType; ObjectType: TEObjectType;
  pBaseBlock: Pointer; Index: uint32): Pointer;
begin

end;

{ TSamplerVariable }

function TSamplerVariable.GetSampler(Index: UINT32; out
  ppSampler: ID3D11SamplerState): HResult; stdcall;
begin

end;

function TSamplerVariable.SetSampler(Index: UINT32; pSampler: ID3D11SamplerState
  ): HResult; stdcall;
begin

end;

function TSamplerVariable.UndoSetSampler(Index: UINT32): HResult; stdcall;
begin

end;

function TSamplerVariable.GetBackingStore(Index: UINT32; out
  pDesc: TD3D11_SAMPLER_DESC): HResult; stdcall;
begin

end;

{ TSConstantBuffer }

constructor TSConstantBuffer.Create;
begin

end;

destructor TSConstantBuffer.Destroy;
begin
  inherited Destroy;
end;

function TSConstantBuffer.ClonedSingle(): boolean;
begin

end;

function TSConstantBuffer.IsValid(): boolean; stdcall;
begin
  Result:=inherited IsValid();
end;

function TSConstantBuffer.GetType(): ID3DX11EffectType; stdcall;
begin
  Result:=inherited GetType();
end;

function TSConstantBuffer.GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC
  ): HResult; stdcall;
begin
  Result:=inherited GetDesc(pDesc);
end;

function TSConstantBuffer.GetAnnotationByIndex(Index: UINT32
  ): ID3DX11EffectVariable; stdcall;
begin
  Result:=inherited GetAnnotationByIndex(Index);
end;

function TSConstantBuffer.GetAnnotationByName(Name: LPCSTR
  ): ID3DX11EffectVariable; stdcall;
begin
  Result:=inherited GetAnnotationByName(Name);
end;

function TSConstantBuffer.GetMemberByIndex(Index: UINT32
  ): ID3DX11EffectVariable; stdcall;
begin
  Result:=inherited GetMemberByIndex(Index);
end;

function TSConstantBuffer.GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable;
  stdcall;
begin
  Result:=inherited GetMemberByName(Name);
end;

function TSConstantBuffer.GetMemberBySemantic(Semantic: LPCSTR
  ): ID3DX11EffectVariable; stdcall;
begin
  Result:=inherited GetMemberBySemantic(Semantic);
end;

function TSConstantBuffer.GetElement(Index: UINT32): ID3DX11EffectVariable;
  stdcall;
begin
  Result:=inherited GetElement(Index);
end;

function TSConstantBuffer.GetParentConstantBuffer(
  ): ID3DX11EffectConstantBuffer; stdcall;
begin
  Result:=inherited GetParentConstantBuffer();
end;

function TSConstantBuffer.AsConstantBuffer(): ID3DX11EffectConstantBuffer;
  stdcall;
begin
  Result:=inherited AsConstantBuffer();
end;

function TSConstantBuffer.SetRawValue(pData: Pointer; ByteOffset: UINT32;
  ByteCount: UINT32): HResult; stdcall;
begin
  Result:=inherited SetRawValue(pData, ByteOffset, ByteCount);
end;

function TSConstantBuffer.GetRawValue(out pData: Pointer; ByteOffset: UINT32;
  ByteCount: UINT32): HResult; stdcall;
begin
  Result:=inherited GetRawValue(pData, ByteOffset, ByteCount);
end;

function TSConstantBuffer.SetConstantBuffer(pConstantBuffer: ID3D11Buffer
  ): HResult; stdcall;
begin

end;

function TSConstantBuffer.UndoSetConstantBuffer(): HResult; stdcall;
begin

end;

function TSConstantBuffer.GetConstantBuffer(out ppConstantBuffer: ID3D11Buffer
  ): HResult; stdcall;
begin

end;

function TSConstantBuffer.SetTextureBuffer(
  pTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;

function TSConstantBuffer.UndoSetTextureBuffer(): HResult; stdcall;
begin

end;

function TSConstantBuffer.GetTextureBuffer(out
  ppTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;

function TSConstantBuffer.GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC
  ): HResult; stdcall;
begin

end;

function TSConstantBuffer.GetMemberTypeByIndex(Index: UINT32
  ): ID3DX11EffectType; stdcall;
begin

end;

function TSConstantBuffer.GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType;
  stdcall;
begin

end;

function TSConstantBuffer.GetMemberTypeBySemantic(Semantic: LPCSTR
  ): ID3DX11EffectType; stdcall;
begin

end;

function TSConstantBuffer.GetMemberName(Index: UINT32): LPCSTR; stdcall;
begin

end;

function TSConstantBuffer.GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
begin

end;

{ TRasterizerVariable }

function TRasterizerVariable.GetRasterizerState(Index: UINT32; out ppState: ID3D11RasterizerState): HResult; stdcall;
begin

end;



function TRasterizerVariable.SetRasterizerState(Index: UINT32; pState: ID3D11RasterizerState): HResult; stdcall;
begin

end;



function TRasterizerVariable.UndoSetRasterizerState(Index: UINT32): HResult;
    stdcall;
begin

end;



function TRasterizerVariable.GetBackingStore(Index: UINT32; out pDesc: TD3D11_RASTERIZER_DESC): HResult; stdcall;
begin

end;



function TRasterizerVariable.IsValid(): boolean; stdcall;
begin
    Result := inherited IsValid();
end;

{ TDepthStencilVariable }

function TDepthStencilVariable.GetDepthStencilState(Index: UINT32; out ppState: ID3D11DepthStencilState): HResult; stdcall;
begin

end;



function TDepthStencilVariable.SetDepthStencilState(Index: UINT32; pState: ID3D11DepthStencilState): HResult; stdcall;
begin

end;



function TDepthStencilVariable.UndoSetDepthStencilState(Index: UINT32): HResult; stdcall;
begin

end;



function TDepthStencilVariable.GetBackingStore(Index: UINT32; out pDesc: TD3D11_DEPTH_STENCIL_DESC): HResult; stdcall;
begin

end;

{ TBlendVariable }

function TBlendVariable.GetBlendState(Index: UINT32; out ppState: ID3D11BlendState): HResult; stdcall;
begin

end;



function TBlendVariable.SetBlendState(Index: UINT32; pState: ID3D11BlendState): HResult; stdcall;
begin

end;



function TBlendVariable.UndoSetBlendState(Index: UINT32): HResult; stdcall;
begin

end;



function TBlendVariable.GetBackingStore(Index: UINT32; out pDesc: TD3D11_BLEND_DESC): HResult; stdcall;
begin

end;

{ TShaderVariable }

function TShaderVariable.GetShaderDesc(ShaderIndex: UINT32; out pDesc: TD3DX11_EFFECT_SHADER_DESC): HResult; stdcall;
begin

end;



function TShaderVariable.GetVertexShader(ShaderIndex: UINT32; out ppVS: ID3D11VertexShader): HResult; stdcall;
begin

end;



function TShaderVariable.GetGeometryShader(ShaderIndex: UINT32; out ppGS: ID3D11GeometryShader): HResult; stdcall;
begin

end;



function TShaderVariable.GetPixelShader(ShaderIndex: UINT32; out ppPS: ID3D11PixelShader): HResult; stdcall;
begin

end;



function TShaderVariable.GetHullShader(ShaderIndex: UINT32; out ppHS: ID3D11HullShader): HResult; stdcall;
begin

end;



function TShaderVariable.GetDomainShader(ShaderIndex: UINT32; out ppDS: ID3D11DomainShader): HResult; stdcall;
begin

end;



function TShaderVariable.GetComputeShader(ShaderIndex: UINT32; out ppCS: ID3D11ComputeShader): HResult; stdcall;
begin

end;



function TShaderVariable.GetInputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult;
    stdcall;
begin

end;



function TShaderVariable.GetOutputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult;
    stdcall;
begin

end;



function TShaderVariable.GetPatchConstantSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
    out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
begin

end;

{ TRenderTargetViewVariable }

function TRenderTargetViewVariable.SetRenderTarget(pResource: ID3D11RenderTargetView): HResult; stdcall;
begin

end;



function TRenderTargetViewVariable.GetRenderTarget(out ppResource: ID3D11RenderTargetView): HResult; stdcall;
begin

end;



function TRenderTargetViewVariable.SetRenderTargetArray(ppResources: PID3D11RenderTargetView; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TRenderTargetViewVariable.GetRenderTargetArray(out ppResources: PID3D11RenderTargetView; Offset: UINT32;
    Count: UINT32): HResult; stdcall;
begin

end;

{ TAnonymousShader }

constructor TAnonymousShader.Create(pBlock: PSShaderBlock);
begin

end;



destructor TAnonymousShader.Destroy;
begin
    inherited Destroy;
end;



function TAnonymousShader.IsValid(): boolean; stdcall;
begin
    Result := inherited IsValid();
end;



function TAnonymousShader.GetType(): ID3DX11EffectType; stdcall;
begin
    Result := inherited GetType();
end;



function TAnonymousShader.GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall;
begin
    Result := inherited GetDesc(pDesc);
end;



function TAnonymousShader.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin
    Result := inherited GetAnnotationByIndex(Index);
end;



function TAnonymousShader.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
begin
    Result := inherited GetAnnotationByName(Name);
end;



function TAnonymousShader.GetMemberByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin
    Result := inherited GetMemberByIndex(Index);
end;



function TAnonymousShader.GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin
    Result := inherited GetMemberByName(Name);
end;



function TAnonymousShader.GetMemberBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall;
begin
    Result := inherited GetMemberBySemantic(Semantic);
end;



function TAnonymousShader.GetElement(Index: UINT32): ID3DX11EffectVariable;
    stdcall;
begin
    Result := inherited GetElement(Index);
end;



function TAnonymousShader.GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall;
begin
    Result := inherited GetParentConstantBuffer();
end;



function TAnonymousShader.AsShader(): ID3DX11EffectShaderVariable; stdcall;
begin
    Result := inherited AsShader();
end;



function TAnonymousShader.SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin
    Result := inherited SetRawValue(pData, ByteOffset, ByteCount);
end;



function TAnonymousShader.GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin
    Result := inherited GetRawValue(pData, ByteOffset, ByteCount);
end;



function TAnonymousShader.GetShaderDesc(ShaderIndex: UINT32; out pDesc: TD3DX11_EFFECT_SHADER_DESC): HResult; stdcall;
begin

end;



function TAnonymousShader.GetVertexShader(ShaderIndex: UINT32; out ppVS: ID3D11VertexShader): HResult; stdcall;
begin

end;



function TAnonymousShader.GetGeometryShader(ShaderIndex: UINT32; out ppGS: ID3D11GeometryShader): HResult; stdcall;
begin

end;



function TAnonymousShader.GetPixelShader(ShaderIndex: UINT32; out ppPS: ID3D11PixelShader): HResult; stdcall;
begin

end;



function TAnonymousShader.GetHullShader(ShaderIndex: UINT32; out ppHS: ID3D11HullShader): HResult; stdcall;
begin

end;



function TAnonymousShader.GetDomainShader(ShaderIndex: UINT32; out ppDS: ID3D11DomainShader): HResult; stdcall;
begin

end;



function TAnonymousShader.GetComputeShader(ShaderIndex: UINT32; out ppCS: ID3D11ComputeShader): HResult; stdcall;
begin

end;



function TAnonymousShader.GetInputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult;
    stdcall;
begin

end;



function TAnonymousShader.GetOutputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult;
    stdcall;
begin

end;



function TAnonymousShader.GetPatchConstantSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
    out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
begin

end;



function TAnonymousShader.GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall;
begin

end;



function TAnonymousShader.GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
begin

end;



function TAnonymousShader.GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType;
    stdcall;
begin

end;



function TAnonymousShader.GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall;
begin

end;



function TAnonymousShader.GetMemberName(Index: UINT32): LPCSTR; stdcall;
begin

end;



function TAnonymousShader.GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
begin

end;

{ TUncastableVariable }

function TUncastableVariable.AsScalar(): ID3DX11EffectScalarVariable; stdcall;
begin
    Result := inherited AsScalar();
end;



function TUncastableVariable.AsVector(): ID3DX11EffectVectorVariable; stdcall;
begin
    Result := inherited AsVector();
end;



function TUncastableVariable.AsMatrix(): ID3DX11EffectMatrixVariable; stdcall;
begin
    Result := inherited AsMatrix();
end;



function TUncastableVariable.AsString(): ID3DX11EffectStringVariable; stdcall;
begin
    Result := inherited AsString();
end;



function TUncastableVariable.AsClassInstance(): ID3DX11EffectClassInstanceVariable; stdcall;
begin
    Result := inherited AsClassInstance();
end;



function TUncastableVariable.AsInterface(): ID3DX11EffectInterfaceVariable;
    stdcall;
begin
    Result := inherited AsInterface();
end;



function TUncastableVariable.AsShaderResource(): ID3DX11EffectShaderResourceVariable; stdcall;
begin
    Result := inherited AsShaderResource();
end;



function TUncastableVariable.AsUnorderedAccessView(): ID3DX11EffectUnorderedAccessViewVariable; stdcall;
begin
    Result := inherited AsUnorderedAccessView();
end;



function TUncastableVariable.AsRenderTargetView(): ID3DX11EffectRenderTargetViewVariable; stdcall;
begin
    Result := inherited AsRenderTargetView();
end;



function TUncastableVariable.AsDepthStencilView(): ID3DX11EffectDepthStencilViewVariable; stdcall;
begin
    Result := inherited AsDepthStencilView();
end;



function TUncastableVariable.AsConstantBuffer(): ID3DX11EffectConstantBuffer;
    stdcall;
begin
    Result := inherited AsConstantBuffer();
end;



function TUncastableVariable.AsShader(): ID3DX11EffectShaderVariable; stdcall;
begin
    Result := inherited AsShader();
end;



function TUncastableVariable.AsBlend(): ID3DX11EffectBlendVariable; stdcall;
begin
    Result := inherited AsBlend();
end;



function TUncastableVariable.AsDepthStencil(): ID3DX11EffectDepthStencilVariable; stdcall;
begin
    Result := inherited AsDepthStencil();
end;



function TUncastableVariable.AsRasterizer(): ID3DX11EffectRasterizerVariable;
    stdcall;
begin
    Result := inherited AsRasterizer();
end;



function TUncastableVariable.AsSampler(): ID3DX11EffectSamplerVariable; stdcall;
begin
    Result := inherited AsSampler();
end;





{ TDepthStencilViewVariable }

function TDepthStencilViewVariable.SetDepthStencil(pResource: ID3D11DepthStencilView): HResult; stdcall;
begin

end;



function TDepthStencilViewVariable.GetDepthStencil(out ppResource: ID3D11DepthStencilView): HResult; stdcall;
begin

end;



function TDepthStencilViewVariable.SetDepthStencilArray(ppResources: PID3D11DepthStencilView; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TDepthStencilViewVariable.GetDepthStencilArray(out ppResources: PID3D11DepthStencilView; Offset: UINT32;
    Count: UINT32): HResult; stdcall;
begin

end;

{ TUnorderedAccessViewVariable }

function TUnorderedAccessViewVariable.SetUnorderedAccessView(pResource: ID3D11UnorderedAccessView): HResult; stdcall;
begin

end;



function TUnorderedAccessViewVariable.GetUnorderedAccessView(out ppResource: ID3D11UnorderedAccessView): HResult; stdcall;
begin

end;



function TUnorderedAccessViewVariable.SetUnorderedAccessViewArray(ppResources: PID3D11UnorderedAccessView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TUnorderedAccessViewVariable.GetUnorderedAccessViewArray(out ppResources: ID3D11UnorderedAccessView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TShaderResourceVariable }

function TShaderResourceVariable.SetResource(pResource: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;



function TShaderResourceVariable.GetResource(out ppResource: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;



function TShaderResourceVariable.SetResourceArray(ppResources: PID3D11ShaderResourceView; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TShaderResourceVariable.GetResourceArray(out ppResources: PID3D11ShaderResourceView; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TInterfaceVariable }

function TInterfaceVariable.SetClassInstance(pEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall;
begin

end;



function TInterfaceVariable.GetClassInstance(out ppEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall;
begin

end;

{ TClassInstanceVariable }

function TClassInstanceVariable.GetClassInstance(out ppClassInstance: ID3D11ClassInstance): HResult; stdcall;
begin

end;

{ TMatrix4x4Variable }

function TMatrix4x4Variable.SetMatrix(const pData: TD3DXMATRIX): HResult;
    stdcall;
begin
    Result := inherited SetMatrix(pData);
end;



function TMatrix4x4Variable.GetMatrix(out pData: TD3DXMATRIX): HResult; stdcall;
begin
    Result := inherited GetMatrix(pData);
end;



function TMatrix4x4Variable.SetMatrixArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin
    Result := inherited SetMatrixArray(pData, Offset, Count);
end;



function TMatrix4x4Variable.GetMatrixArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin
    Result := inherited GetMatrixArray(pData, Offset, Count);
end;



function TMatrix4x4Variable.SetMatrixTranspose(const pData: TD3DXMATRIX): HResult; stdcall;
begin
    Result := inherited SetMatrixTranspose(pData);
end;



function TMatrix4x4Variable.GetMatrixTranspose(out pData: TD3DXMATRIX): HResult; stdcall;
begin
    Result := inherited GetMatrixTranspose(pData);
end;



function TMatrix4x4Variable.SetMatrixTransposeArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin
    Result := inherited SetMatrixTransposeArray(pData, Offset, Count);
end;



function TMatrix4x4Variable.GetMatrixTransposeArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin
    Result := inherited GetMatrixTransposeArray(pData, Offset, Count);
end;

{ TMatrixVariable }

function TMatrixVariable.SetMatrix(const pData: TD3DXMATRIX): HResult; stdcall;
begin

end;



function TMatrixVariable.GetMatrix(out pData: TD3DXMATRIX): HResult; stdcall;
begin

end;



function TMatrixVariable.SetMatrixArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TMatrixVariable.GetMatrixArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TMatrixVariable.SetMatrixPointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TMatrixVariable.GetMatrixPointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TMatrixVariable.SetMatrixTranspose(const pData: TD3DXMATRIX): HResult;
    stdcall;
begin

end;



function TMatrixVariable.GetMatrixTranspose(out pData: TD3DXMATRIX): HResult;
    stdcall;
begin

end;



function TMatrixVariable.SetMatrixTransposeArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TMatrixVariable.GetMatrixTransposeArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TMatrixVariable.SetMatrixTransposePointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TMatrixVariable.GetMatrixTransposePointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TStringVariable }

function TStringVariable.GetString(out ppString: PAnsiChar): HResult; stdcall;
begin

end;



function TStringVariable.GetStringArray(out ppStrings: PAnsiChar; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TVector4Variable }

function TVector4Variable.SetFloatVector(const pData: TFloatVector): HResult;
    stdcall;
begin
    Result := inherited SetFloatVector(pData);
end;



function TVector4Variable.GetFloatVector(out pData: TFloatVector): HResult;
    stdcall;
begin
    Result := inherited GetFloatVector(pData);
end;



function TVector4Variable.SetFloatVectorArray(pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin
    Result := inherited SetFloatVectorArray(pData, Offset, Count);
end;



function TVector4Variable.GetFloatVectorArray(out pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin
    Result := inherited GetFloatVectorArray(pData, Offset, Count);
end;

{ TBoolScalarVariable }

function TBoolScalarVariable.SetFloat(Value: single): HResult; stdcall;
begin

end;



function TBoolScalarVariable.GetFloat(out pValue: single): HResult; stdcall;
begin

end;



function TBoolScalarVariable.SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TBoolScalarVariable.GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TBoolScalarVariable.SetInt(Value: integer): HResult; stdcall;
begin

end;



function TBoolScalarVariable.GetInt(out pValue: integer): HResult; stdcall;
begin

end;



function TBoolScalarVariable.SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TBoolScalarVariable.GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TBoolScalarVariable.SetBool(const Value: boolean): HResult; stdcall;
begin

end;



function TBoolScalarVariable.GetBool(out pValue: boolean): HResult; stdcall;
begin

end;



function TBoolScalarVariable.SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TBoolScalarVariable.GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TVectorVariable }

function TVectorVariable.SetBoolVector(const pData: TBoolVector): HResult;
    stdcall;
begin

end;



function TVectorVariable.SetIntVector(const pData: TIntVector): HResult;
    stdcall;
begin

end;



function TVectorVariable.SetFloatVector(const pData: TFloatVector): HResult;
    stdcall;
begin

end;



function TVectorVariable.GetBoolVector(out pData: TBoolVector): HResult;
    stdcall;
begin

end;



function TVectorVariable.GetIntVector(out pData: TIntVector): HResult; stdcall;
begin

end;



function TVectorVariable.GetFloatVector(out pData: TFloatVector): HResult;
    stdcall;
begin

end;



function TVectorVariable.SetBoolVectorArray(pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TVectorVariable.SetIntVectorArray(pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TVectorVariable.SetFloatVectorArray(pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TVectorVariable.GetBoolVectorArray(out pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TVectorVariable.GetIntVectorArray(out pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TVectorVariable.GetFloatVectorArray(out pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TIntScalarVariable }

function TIntScalarVariable.SetFloat(Value: single): HResult; stdcall;
begin

end;



function TIntScalarVariable.GetFloat(out pValue: single): HResult; stdcall;
begin

end;



function TIntScalarVariable.SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TIntScalarVariable.GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TIntScalarVariable.SetInt(Value: integer): HResult; stdcall;
begin

end;



function TIntScalarVariable.GetInt(out pValue: integer): HResult; stdcall;
begin

end;



function TIntScalarVariable.SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TIntScalarVariable.GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TIntScalarVariable.SetBool(const Value: boolean): HResult; stdcall;
begin

end;



function TIntScalarVariable.GetBool(out pValue: boolean): HResult; stdcall;
begin

end;



function TIntScalarVariable.SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TIntScalarVariable.GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TFloatScalarVariable }

function TFloatScalarVariable.SetFloat(Value: single): HResult; stdcall;
begin

end;



function TFloatScalarVariable.GetFloat(out pValue: single): HResult; stdcall;
begin

end;



function TFloatScalarVariable.SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TFloatScalarVariable.GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TFloatScalarVariable.SetInt(Value: integer): HResult; stdcall;
begin

end;



function TFloatScalarVariable.GetInt(out pValue: integer): HResult; stdcall;
begin

end;



function TFloatScalarVariable.SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TFloatScalarVariable.GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TFloatScalarVariable.SetBool(const Value: boolean): HResult; stdcall;
begin

end;



function TFloatScalarVariable.GetBool(out pValue: boolean): HResult; stdcall;
begin

end;



function TFloatScalarVariable.SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TFloatScalarVariable.GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TNumericVariable }

function TNumericVariable.SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin
    Result := inherited SetRawValue(pData, ByteOffset, ByteCount);
end;



function TNumericVariable.GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin
    Result := inherited GetRawValue(pData, ByteOffset, ByteCount);
end;

{ TGlobalVariable }

constructor TGlobalVariable.Create;
begin

end;



destructor TGlobalVariable.Destroy;
begin
    inherited Destroy;
end;



function TGlobalVariable.GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall;
begin
    Result := inherited GetDesc(pDesc);
end;



function TGlobalVariable.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin
    Result := inherited GetAnnotationByIndex(Index);
end;



function TGlobalVariable.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
begin
    Result := inherited GetAnnotationByName(Name);
end;



function TGlobalVariable.GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall;
begin
    Result := inherited GetParentConstantBuffer();
end;



procedure TGlobalVariable.DirtyVariable();
begin

end;

{ TAnnotation }

function TAnnotation.GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult;
    stdcall;
begin
    Result := inherited GetDesc(pDesc);
end;



function TAnnotation.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin
    Result := inherited GetAnnotationByIndex(Index);
end;



function TAnnotation.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin
    Result := inherited GetAnnotationByName(Name);
end;



function TAnnotation.GetParentConstantBuffer(): ID3DX11EffectConstantBuffer;
    stdcall;
begin
    Result := inherited GetParentConstantBuffer();
end;



procedure TAnnotation.DirtyVariable();
begin

end;

{ TMember }

constructor TMember.Create;
begin

end;



destructor TMember.Destroy;
begin
    inherited Destroy;
end;



function TMember.GetEffect(): TEffect;
begin

end;



function TMember.GetTotalUnpackedSize(): uint32;
begin

end;



function TMember.GetType(): ID3DX11EffectType; stdcall;
begin
    Result := inherited GetType();
end;



function TMember.GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult;
    stdcall;
begin
    Result := inherited GetDesc(pDesc);
end;



function TMember.GetTopLevelEntity(): TTopLevelVariable;
begin

end;



function TMember.IsArray(): boolean;
begin

end;



function TMember.GetAnnotationByIndex(Index: uint32): ID3DX11EffectVariable;
    stdcall;
begin
    Result := inherited GetAnnotationByIndex(Index);
end;



function TMember.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin
    Result := inherited GetAnnotationByName(Name);
end;



function TMember.GetParentConstantBuffer(): ID3DX11EffectConstantBuffer;
    stdcall;
begin
    Result := inherited GetParentConstantBuffer();
end;



procedure TMember.DirtyVariable();
begin

end;

{ TTopLevelVariable }

function TTopLevelVariable.GetEffect(): TEffect;
begin

end;



constructor TTopLevelVariable.Create;
begin

end;



destructor TTopLevelVariable.Destroy;
begin
    inherited Destroy;
end;



function TTopLevelVariable.GetTotalUnpackedSize(): uint32;
begin

end;



function TTopLevelVariable.GetType(): ID3DX11EffectType; stdcall;
begin
    Result := inherited GetType();
end;



function TTopLevelVariable.GetTopLevelEntity(): TTopLevelVariable;
begin

end;



function TTopLevelVariable.IsArray(): boolean;
begin

end;

{ TEffectInvalidGroup }

function TEffectInvalidGroup.IsValid(): boolean; stdcall;
begin

end;



function TEffectInvalidGroup.GetDesc(out pDesc: TD3DX11_GROUP_DESC): HResult;
    stdcall;
begin

end;



function TEffectInvalidGroup.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidGroup.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidGroup.GetTechniqueByIndex(Index: UINT32): ID3DX11EffectTechnique; stdcall;
begin

end;



function TEffectInvalidGroup.GetTechniqueByName(Name: LPCSTR): ID3DX11EffectTechnique; stdcall;
begin

end;

{ TVariable }

function TVariable.IsValid(): boolean; stdcall;
begin

end;



function TVariable.GetType(): ID3DX11EffectType; stdcall;
begin

end;



function TVariable.GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult;
    stdcall;
begin

end;



function TVariable.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TVariable.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TVariable.GetMemberByIndex(Index: UINT32): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TVariable.GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TVariable.GetMemberBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TVariable.GetElement(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TVariable.GetParentConstantBuffer(): ID3DX11EffectConstantBuffer;
    stdcall;
begin

end;



function TVariable.AsScalar(): ID3DX11EffectScalarVariable; stdcall;
begin

end;



function TVariable.AsVector(): ID3DX11EffectVectorVariable; stdcall;
begin

end;



function TVariable.AsMatrix(): ID3DX11EffectMatrixVariable; stdcall;
begin

end;



function TVariable.AsString(): ID3DX11EffectStringVariable; stdcall;
begin

end;



function TVariable.AsClassInstance(): ID3DX11EffectClassInstanceVariable;
    stdcall;
begin

end;



function TVariable.AsInterface(): ID3DX11EffectInterfaceVariable; stdcall;
begin

end;



function TVariable.AsShaderResource(): ID3DX11EffectShaderResourceVariable;
    stdcall;
begin

end;



function TVariable.AsUnorderedAccessView(): ID3DX11EffectUnorderedAccessViewVariable; stdcall;
begin

end;



function TVariable.AsRenderTargetView(): ID3DX11EffectRenderTargetViewVariable;
    stdcall;
begin

end;



function TVariable.AsDepthStencilView(): ID3DX11EffectDepthStencilViewVariable;
    stdcall;
begin

end;



function TVariable.AsConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall;
begin

end;



function TVariable.AsShader(): ID3DX11EffectShaderVariable; stdcall;
begin

end;



function TVariable.AsBlend(): ID3DX11EffectBlendVariable; stdcall;
begin

end;



function TVariable.AsDepthStencil(): ID3DX11EffectDepthStencilVariable; stdcall;
begin

end;



function TVariable.AsRasterizer(): ID3DX11EffectRasterizerVariable; stdcall;
begin

end;



function TVariable.AsSampler(): ID3DX11EffectSamplerVariable; stdcall;
begin

end;



function TVariable.SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin

end;



function TVariable.GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidVariable }

function TEffectInvalidVariable.IsValid(): boolean; stdcall;
begin

end;



function TEffectInvalidVariable.GetType(): ID3DX11EffectType; stdcall;
begin

end;



function TEffectInvalidVariable.GetDesc(out pDesc: TD3DX11_EFFECT_VARIABLE_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidVariable.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidVariable.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidVariable.GetMemberByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidVariable.GetMemberByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidVariable.GetMemberBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidVariable.GetElement(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidVariable.GetParentConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall;
begin

end;



function TEffectInvalidVariable.AsScalar(): ID3DX11EffectScalarVariable;
    stdcall;
begin

end;



function TEffectInvalidVariable.AsVector(): ID3DX11EffectVectorVariable;
    stdcall;
begin

end;



function TEffectInvalidVariable.AsMatrix(): ID3DX11EffectMatrixVariable;
    stdcall;
begin

end;



function TEffectInvalidVariable.AsString(): ID3DX11EffectStringVariable;
    stdcall;
begin

end;



function TEffectInvalidVariable.AsClassInstance(): ID3DX11EffectClassInstanceVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsInterface(): ID3DX11EffectInterfaceVariable;
    stdcall;
begin

end;



function TEffectInvalidVariable.AsShaderResource(): ID3DX11EffectShaderResourceVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsUnorderedAccessView(): ID3DX11EffectUnorderedAccessViewVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsRenderTargetView(): ID3DX11EffectRenderTargetViewVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsDepthStencilView(): ID3DX11EffectDepthStencilViewVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsConstantBuffer(): ID3DX11EffectConstantBuffer; stdcall;
begin

end;



function TEffectInvalidVariable.AsShader(): ID3DX11EffectShaderVariable;
    stdcall;
begin

end;



function TEffectInvalidVariable.AsBlend(): ID3DX11EffectBlendVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsDepthStencil(): ID3DX11EffectDepthStencilVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsRasterizer(): ID3DX11EffectRasterizerVariable; stdcall;
begin

end;



function TEffectInvalidVariable.AsSampler(): ID3DX11EffectSamplerVariable;
    stdcall;
begin

end;



function TEffectInvalidVariable.SetRawValue(pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidVariable.GetRawValue(out pData: Pointer; ByteOffset: UINT32; ByteCount: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidType }

function TEffectInvalidType.IsValid(): boolean; stdcall;
begin

end;



function TEffectInvalidType.GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidType.GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
begin

end;



function TEffectInvalidType.GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall;
begin

end;



function TEffectInvalidType.GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall;
begin

end;



function TEffectInvalidType.GetMemberName(Index: UINT32): LPCSTR; stdcall;
begin

end;



function TEffectInvalidType.GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
begin

end;

{ TEffectInvalidPass }

function TEffectInvalidPass.IsValid(): boolean; stdcall;
begin

end;



function TEffectInvalidPass.GetDesc(out pDesc: TD3DX11_PASS_DESC): HResult;
    stdcall;
begin

end;



function TEffectInvalidPass.GetVertexShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidPass.GetGeometryShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidPass.GetPixelShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidPass.GetHullShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidPass.GetDomainShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidPass.GetComputeShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidPass.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidPass.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidPass.Apply(Flags: UINT32; pContext: ID3D11DeviceContext): HResult; stdcall;
begin

end;



function TEffectInvalidPass.ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;
begin

end;

{ TEffectInvalidTechnique }

function TEffectInvalidTechnique.IsValid(): boolean; stdcall;
begin

end;



function TEffectInvalidTechnique.GetDesc(out pDesc: TD3DX11_TECHNIQUE_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidTechnique.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidTechnique.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffectInvalidTechnique.GetPassByIndex(Index: UINT32): ID3DX11EffectPass; stdcall;
begin

end;



function TEffectInvalidTechnique.GetPassByName(Name: LPCSTR): ID3DX11EffectPass; stdcall;
begin

end;



function TEffectInvalidTechnique.ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;
begin

end;

{ TEffectInvalidSamplerVariable }

function TEffectInvalidSamplerVariable.GetSampler(Index: UINT32; out ppSampler: ID3D11SamplerState): HResult; stdcall;
begin

end;



function TEffectInvalidSamplerVariable.SetSampler(Index: UINT32; pSampler: ID3D11SamplerState): HResult; stdcall;
begin

end;



function TEffectInvalidSamplerVariable.UndoSetSampler(Index: UINT32): HResult;
    stdcall;
begin

end;



function TEffectInvalidSamplerVariable.GetBackingStore(Index: UINT32; out pDesc: TD3D11_SAMPLER_DESC): HResult; stdcall;
begin

end;

{ TEffectInvalidRasterizerVariable }

function TEffectInvalidRasterizerVariable.GetRasterizerState(Index: UINT32; out ppState: ID3D11RasterizerState): HResult; stdcall;
begin

end;



function TEffectInvalidRasterizerVariable.SetRasterizerState(Index: UINT32; pState: ID3D11RasterizerState): HResult; stdcall;
begin

end;



function TEffectInvalidRasterizerVariable.UndoSetRasterizerState(Index: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidRasterizerVariable.GetBackingStore(Index: UINT32; out pDesc: TD3D11_RASTERIZER_DESC): HResult; stdcall;
begin

end;

{ TEffectInvalidDepthStencilVariable }

function TEffectInvalidDepthStencilVariable.GetDepthStencilState(Index: UINT32; out ppState: ID3D11DepthStencilState): HResult; stdcall;
begin

end;



function TEffectInvalidDepthStencilVariable.SetDepthStencilState(Index: UINT32; pState: ID3D11DepthStencilState): HResult; stdcall;
begin

end;



function TEffectInvalidDepthStencilVariable.UndoSetDepthStencilState(Index: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidDepthStencilVariable.GetBackingStore(Index: UINT32; out pDesc: TD3D11_DEPTH_STENCIL_DESC): HResult; stdcall;
begin

end;

{ TEffectInvalidBlendVariable }

function TEffectInvalidBlendVariable.GetBlendState(Index: UINT32; out ppState: ID3D11BlendState): HResult; stdcall;
begin

end;



function TEffectInvalidBlendVariable.SetBlendState(Index: UINT32; pState: ID3D11BlendState): HResult; stdcall;
begin

end;



function TEffectInvalidBlendVariable.UndoSetBlendState(Index: UINT32): HResult;
    stdcall;
begin

end;



function TEffectInvalidBlendVariable.GetBackingStore(Index: UINT32; out pDesc: TD3D11_BLEND_DESC): HResult; stdcall;
begin

end;

{ TEffectInvalidShaderVariable }

function TEffectInvalidShaderVariable.GetShaderDesc(ShaderIndex: UINT32; out pDesc: TD3DX11_EFFECT_SHADER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetVertexShader(ShaderIndex: UINT32; out ppVS: ID3D11VertexShader): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetGeometryShader(ShaderIndex: UINT32; out ppGS: ID3D11GeometryShader): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetPixelShader(ShaderIndex: UINT32; out ppPS: ID3D11PixelShader): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetHullShader(ShaderIndex: UINT32; out ppHS: ID3D11HullShader): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetDomainShader(ShaderIndex: UINT32; out ppDS: ID3D11DomainShader): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetComputeShader(ShaderIndex: UINT32; out ppCS: ID3D11ComputeShader): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetInputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
    out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetOutputSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
    out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
begin

end;



function TEffectInvalidShaderVariable.GetPatchConstantSignatureElementDesc(ShaderIndex: UINT32; Element: UINT32;
    out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HResult; stdcall;
begin

end;

{ TEffectInvalidConstantBuffer }

function TEffectInvalidConstantBuffer.SetConstantBuffer(pConstantBuffer: ID3D11Buffer): HResult; stdcall;
begin

end;



function TEffectInvalidConstantBuffer.UndoSetConstantBuffer(): HResult; stdcall;
begin

end;



function TEffectInvalidConstantBuffer.GetConstantBuffer(out ppConstantBuffer: ID3D11Buffer): HResult; stdcall;
begin

end;



function TEffectInvalidConstantBuffer.SetTextureBuffer(pTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;



function TEffectInvalidConstantBuffer.UndoSetTextureBuffer(): HResult; stdcall;
begin

end;



function TEffectInvalidConstantBuffer.GetTextureBuffer(out ppTextureBuffer: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;

{ TEffectInvalidDepthStencilViewVariable }

function TEffectInvalidDepthStencilViewVariable.SetDepthStencil(pResource: ID3D11DepthStencilView): HResult; stdcall;
begin

end;



function TEffectInvalidDepthStencilViewVariable.GetDepthStencil(out ppResource: ID3D11DepthStencilView): HResult; stdcall;
begin

end;



function TEffectInvalidDepthStencilViewVariable.SetDepthStencilArray(ppResources: PID3D11DepthStencilView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidDepthStencilViewVariable.GetDepthStencilArray(out ppResources: PID3D11DepthStencilView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidRenderTargetViewVariable }

function TEffectInvalidRenderTargetViewVariable.SetRenderTarget(pResource: ID3D11RenderTargetView): HResult; stdcall;
begin

end;



function TEffectInvalidRenderTargetViewVariable.GetRenderTarget(out ppResource: ID3D11RenderTargetView): HResult; stdcall;
begin

end;



function TEffectInvalidRenderTargetViewVariable.SetRenderTargetArray(ppResources: PID3D11RenderTargetView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidRenderTargetViewVariable.GetRenderTargetArray(out ppResources: PID3D11RenderTargetView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidUnorderedAccessViewVariable }

function TEffectInvalidUnorderedAccessViewVariable.SetUnorderedAccessView(pResource: ID3D11UnorderedAccessView): HResult; stdcall;
begin

end;



function TEffectInvalidUnorderedAccessViewVariable.GetUnorderedAccessView(out ppResource: ID3D11UnorderedAccessView): HResult; stdcall;
begin

end;



function TEffectInvalidUnorderedAccessViewVariable.SetUnorderedAccessViewArray(ppResources: PID3D11UnorderedAccessView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidUnorderedAccessViewVariable.GetUnorderedAccessViewArray(out ppResources: ID3D11UnorderedAccessView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidShaderResourceVariable }

function TEffectInvalidShaderResourceVariable.SetResource(pResource: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;



function TEffectInvalidShaderResourceVariable.GetResource(out ppResource: ID3D11ShaderResourceView): HResult; stdcall;
begin

end;



function TEffectInvalidShaderResourceVariable.SetResourceArray(ppResources: PID3D11ShaderResourceView; Offset: UINT32;
    Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidShaderResourceVariable.GetResourceArray(out ppResources: PID3D11ShaderResourceView;
    Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidInterfaceVariable }

function TEffectInvalidInterfaceVariable.SetClassInstance(pEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall;
begin

end;



function TEffectInvalidInterfaceVariable.GetClassInstance(out ppEffectClassInstance: ID3DX11EffectClassInstanceVariable): HResult; stdcall;
begin

end;

{ TEffectInvalidClassInstanceVariable }

function TEffectInvalidClassInstanceVariable.GetClassInstance(out ppClassInstance: ID3D11ClassInstance): HResult; stdcall;
begin

end;

{ TEffectInvalidStringVariable }

function TEffectInvalidStringVariable.GetString(out ppString: PAnsiChar): HResult; stdcall;
begin

end;



function TEffectInvalidStringVariable.GetStringArray(out ppStrings: PAnsiChar; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidMatrixVariable }

function TEffectInvalidMatrixVariable.SetMatrix(const pData: TD3DXMATRIX): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.GetMatrix(out pData: TD3DXMATRIX): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.SetMatrixArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.GetMatrixArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.SetMatrixPointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.GetMatrixPointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.SetMatrixTranspose(const pData: TD3DXMATRIX): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.GetMatrixTranspose(out pData: TD3DXMATRIX): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.SetMatrixTransposeArray(pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.GetMatrixTransposeArray(out pData: PD3DXMATRIX; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.SetMatrixTransposePointerArray(ppData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidMatrixVariable.GetMatrixTransposePointerArray(out ppData: Psingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidVectorVariable }

function TEffectInvalidVectorVariable.SetBoolVector(const pData: TBoolVector): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.SetIntVector(const pData: TIntVector): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.SetFloatVector(const pData: TFloatVector): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.GetBoolVector(out pData: TBoolVector): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.GetIntVector(out pData: TIntVector): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.GetFloatVector(out pData: TFloatVector): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.SetBoolVectorArray(pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.SetIntVectorArray(pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.SetFloatVectorArray(pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.GetBoolVectorArray(out pData: PBoolVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.GetIntVectorArray(out pData: PIntVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidVectorVariable.GetFloatVectorArray(out pData: PFloatVector; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TEffectInvalidScalarVariable }

function TEffectInvalidScalarVariable.SetFloat(Value: single): HResult; stdcall;
begin

end;



function TEffectInvalidScalarVariable.GetFloat(out pValue: single): HResult;
    stdcall;
begin

end;



function TEffectInvalidScalarVariable.SetFloatArray(pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidScalarVariable.GetFloatArray(out pData: PSingle; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidScalarVariable.SetInt(Value: integer): HResult; stdcall;
begin

end;



function TEffectInvalidScalarVariable.GetInt(out pValue: integer): HResult;
    stdcall;
begin

end;



function TEffectInvalidScalarVariable.SetIntArray(pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidScalarVariable.GetIntArray(out pData: PInteger; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidScalarVariable.SetBool(const Value: boolean): HResult;
    stdcall;
begin

end;



function TEffectInvalidScalarVariable.GetBool(out pValue: boolean): HResult;
    stdcall;
begin

end;



function TEffectInvalidScalarVariable.SetBoolArray(pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;



function TEffectInvalidScalarVariable.GetBoolArray(out pData: PBoolean; Offset: UINT32; Count: UINT32): HResult; stdcall;
begin

end;

{ TSPassBlock }

constructor TSPassBlock.Create;
begin

end;



destructor TSPassBlock.Destroy;
begin
    inherited Destroy;
end;



procedure TSPassBlock.ApplyPassAssignments();
begin

end;



function TSPassBlock.CheckShaderDependencies(const pBlock: TSShaderBlock): boolean;
begin

end;



function TSPassBlock.CheckDependencies(): boolean;
begin

end;



function TSPassBlock.GetShaderDescHelper(out pDesc: TD3DX11_PASS_SHADER_DESC): HRESULT;
begin

end;



function TSPassBlock.IsValid(): boolean; stdcall;
begin

end;



function TSPassBlock.GetDesc(out pDesc: TD3DX11_PASS_DESC): HResult; stdcall;
begin

end;



function TSPassBlock.GetVertexShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TSPassBlock.GetGeometryShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TSPassBlock.GetPixelShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TSPassBlock.GetHullShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TSPassBlock.GetDomainShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TSPassBlock.GetComputeShaderDesc(out pDesc: TD3DX11_PASS_SHADER_DESC): HResult; stdcall;
begin

end;



function TSPassBlock.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable; stdcall;
begin

end;



function TSPassBlock.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TSPassBlock.Apply(Flags: UINT32; pContext: ID3D11DeviceContext): HResult; stdcall;
begin

end;



function TSPassBlock.ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;
begin

end;

{ TSRasterizerBlock }

constructor TSRasterizerBlock.Create;
begin

end;

{ TSSamplerBlock }

constructor TSSamplerBlock.Create;
begin

end;

{ TEffect }

function TEffect.IsValid(): boolean; stdcall;
begin

end;



function TEffect.GetDevice(out ppDevice: ID3D11Device): HResult; stdcall;
begin

end;



function TEffect.GetDesc(out pDesc: TD3DX11_EFFECT_DESC): HResult; stdcall;
begin

end;



function TEffect.GetConstantBufferByIndex(Index: UINT32): ID3DX11EffectConstantBuffer; stdcall;
begin

end;



function TEffect.GetConstantBufferByName(Name: LPCSTR): ID3DX11EffectConstantBuffer; stdcall;
begin

end;



function TEffect.GetVariableByIndex(Index: UINT32): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TEffect.GetVariableByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TEffect.GetVariableBySemantic(Semantic: LPCSTR): ID3DX11EffectVariable; stdcall;
begin

end;



function TEffect.GetGroupByIndex(Index: UINT32): ID3DX11EffectGroup; stdcall;
begin

end;



function TEffect.GetGroupByName(Name: LPCSTR): ID3DX11EffectGroup; stdcall;
begin

end;



function TEffect.GetTechniqueByIndex(Index: UINT32): ID3DX11EffectTechnique;
    stdcall;
begin

end;



function TEffect.GetTechniqueByName(Name: LPCSTR): ID3DX11EffectTechnique;
    stdcall;
begin

end;



function TEffect.GetClassLinkage(): ID3D11ClassLinkage; stdcall;
begin

end;



function TEffect.CloneEffect(Flags: UINT32; out ppClonedEffect: ID3DX11Effect): HResult; stdcall;
begin

end;



function TEffect.Optimize(): HResult; stdcall;
begin

end;



function TEffect.IsOptimized(): boolean; stdcall;
begin

end;

{ TSVariable }

constructor TSVariable.Create;
begin
    ZeroMemory(@self, sizeof(TSVariable));
    ExplicitBindPoint := uint32(-1);
end;



destructor TSVariable.Destroy;
begin
    inherited Destroy;
end;

{ TSString }

constructor TSString.Create;
begin
    pString := nil;
end;

{ TSShaderBlock }

constructor TSShaderBlock.Create(pVirtualTable: PD3DShaderVTable);
begin

end;



destructor TSShaderBlock.Destroy;
begin
    inherited Destroy;
end;



function TSShaderBlock.GetShaderType(): TEObjectType;
begin

end;



function TSShaderBlock.OnDeviceBind(): HRESULT;
begin

end;



function TSShaderBlock.ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HRESULT;
begin

end;



function TSShaderBlock.GetShaderDesc(out pDesc: TD3DX11_EFFECT_SHADER_DESC; IsInline: boolean): HRESULT;
begin

end;



function TSShaderBlock.GetVertexShader(out ppVS: ID3D11VertexShader): HRESULT;
begin

end;



function TSShaderBlock.GetGeometryShader(out ppGS: ID3D11GeometryShader): HRESULT;
begin

end;



function TSShaderBlock.GetPixelShader(out ppPS: ID3D11PixelShader): HRESULT;
begin

end;



function TSShaderBlock.GetHullShader(out ppHS: ID3D11HullShader): HRESULT;
begin

end;



function TSShaderBlock.GetDomainShader(out ppDS: ID3D11DomainShader): HRESULT;
begin

end;



function TSShaderBlock.GetComputeShader(out ppCS: ID3D11ComputeShader): HRESULT;
begin

end;



function TSShaderBlock.GetSignatureElementDesc(SigType: TESigType; Element: uint32; out pDesc: TD3D11_SIGNATURE_PARAMETER_DESC): HRESULT;
begin

end;

{ TSDepthStencilView }

constructor TSDepthStencilView.Create;
begin
    pDepthStencilView := nil;
end;

{ TSRenderTargetView }

constructor TSRenderTargetView.Create;
begin
    pRenderTargetView := nil;
end;

{ TSUnorderedAccessView }

constructor TSUnorderedAccessView.Create;
begin
    pUnorderedAccessView := nil;
end;

{ TSShaderResource }

constructor TSShaderResource.Create;
begin
    pShaderResource := nil;
end;

{ TSInterface }

constructor TSInterface.Create;
begin
    pClassInstance := nil;
end;

{ TSBlendBlock }

constructor TSBlendBlock.Create;
begin

end;

{ TSDepthStencilBlock }

constructor TSDepthStencilBlock.Create;
begin
    inherited;
end;

{ TSGroup }

function TSGroup.IsValid(): boolean; stdcall;
begin

end;



function TSGroup.GetDesc(out pDesc: TD3DX11_GROUP_DESC): HResult; stdcall;
begin

end;



function TSGroup.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TSGroup.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TSGroup.GetTechniqueByIndex(Index: UINT32): ID3DX11EffectTechnique;
    stdcall;
begin

end;



function TSGroup.GetTechniqueByName(Name: LPCSTR): ID3DX11EffectTechnique;
    stdcall;
begin

end;

{ TSTechnique }

constructor TSTechnique.Create;
begin

end;



destructor TSTechnique.Destroy;
begin

end;



function TSTechnique.IsValid(): boolean; stdcall;
begin

end;



function TSTechnique.GetDesc(out pDesc: TD3DX11_TECHNIQUE_DESC): HResult;
    stdcall;
begin

end;



function TSTechnique.GetAnnotationByIndex(Index: UINT32): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TSTechnique.GetAnnotationByName(Name: LPCSTR): ID3DX11EffectVariable;
    stdcall;
begin

end;



function TSTechnique.GetPassByIndex(Index: UINT32): ID3DX11EffectPass; stdcall;
begin

end;



function TSTechnique.GetPassByName(Name: LPCSTR): ID3DX11EffectPass; stdcall;
begin

end;



function TSTechnique.ComputeStateBlockMask(var pStateBlockMask: TD3DX11_STATE_BLOCK_MASK): HResult; stdcall;
begin

end;

{ TSBaseBlock }

function TSBaseBlock.ApplyAssignments(pEffect: TEffect): boolean;
begin

end;



function TSBaseBlock.AsSampler(): TSSamplerBlock;
begin
    assert(BlockType = EBT_Sampler);
    Result := TSSamplerBlock(self);
end;



function TSBaseBlock.AsDepthStencil(): TSDepthStencilBlock;
begin
    assert(BlockType = EBT_DepthStencil);
    Result := TSDepthStencilBlock(self);
end;



function TSBaseBlock.AsBlend(): TSBlendBlock;
begin
    assert(BlockType = EBT_Blend);
    Result := TSBlendBlock(self);
end;



function TSBaseBlock.AsRasterizer(): TSRasterizerBlock;
begin
    assert(BlockType = EBT_Rasterizer);
    Result := TSRasterizerBlock(self);
end;



function TSBaseBlock.AsPass(): TSPassBlock;
begin
    assert(BlockType = EBT_Pass);
    Result := TSPassBlock(self);
end;

{ TSingleElementType }

constructor TSingleElementType.Create;
begin
    pType := nil;
end;



destructor TSingleElementType.Destroy;
begin

end;



function TSingleElementType.IsValid(): boolean; stdcall;
begin
    Result := True;
end;



function TSingleElementType.GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall;
begin
    Result := TSType(pType).GetDescHelper(pDesc, True);
end;



function TSingleElementType.GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
begin
    Result := TSType(pType).GetMemberTypeByIndex(Index);
end;



function TSingleElementType.GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall;
begin
    Result := TSType(pType).GetMemberTypeByName(Name);
end;



function TSingleElementType.GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType; stdcall;
begin
    Result := TSType(pType).GetMemberTypeBySemantic(Semantic);
end;



function TSingleElementType.GetMemberName(Index: UINT32): LPCSTR; stdcall;
begin
    Result := TSType(pType).GetMemberName(Index);
end;



function TSingleElementType.GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
begin
    Result := TSType(pType).GetMemberSemantic(Index);
end;


{ TSType }

constructor TSType.Create;
begin
    VarType := EVT_Invalid;
    Elements := 0;
    pTypeName := nil;
    TotalSize := 0;
    Stride := 0;
    PackedSize := 0;
    ZeroMemory(@Data.StructType, SizeOf(Data.StructType));

    assert(sizeof(Data.NumericType) <= sizeof(TStructType), 'SType union issue');
    assert(sizeof(Data.ObjectType) <= sizeof(TStructType), 'SType union issue');
    assert(sizeof(Data.InterfaceType) <= sizeof(TStructType), 'SType union issue');
end;



destructor TSType.Destroy;
begin

end;



function TSType.IsEqual(pOtherType: TSType): boolean;
begin

end;



function TSType.IsObjectType(ObjType: TEObjectType): boolean;
begin
    Result := IsObjectTypeHelper(VarType, Data.ObjectType, ObjType);
end;



function TSType.IsShader(): boolean;
begin
    Result := IsShaderHelper(VarType, Data.ObjectType);
end;



function TSType.BelongsInConstantBuffer(): boolean;
begin
    Result := (VarType = EVT_Numeric) or (VarType = EVT_Struct);
end;



function TSType.IsStateBlockObject(): boolean;
begin
    Result := IsStateBlockObjectHelper(VarType, Data.ObjectType);
end;



function TSType.IsClassInstance(): boolean;
begin
    Result := (VarType = EVT_Struct) and Data.StructType.ImplementsInterface;
end;



function TSType.IsInterface(): boolean;
begin
    Result := IsInterfaceHelper(VarType, Data.ObjectType);
end;



function TSType.IsShaderResource(): boolean;
begin
    Result := IsShaderResourceHelper(VarType, Data.ObjectType);
end;



function TSType.IsUnorderedAccessView(): boolean;
begin
    Result := IsUnorderedAccessViewHelper(VarType, Data.ObjectType);
end;



function TSType.IsSampler(): boolean;
begin
    Result := IsSamplerHelper(VarType, Data.ObjectType);
end;



function TSType.IsRenderTargetView(): boolean;
begin
    Result := IsRenderTargetViewHelper(VarType, Data.ObjectType);
end;



function TSType.IsDepthStencilView(): boolean;
begin
    Result := IsDepthStencilViewHelper(VarType, Data.ObjectType);
end;



function TSType.GetTotalUnpackedSize(IsSingleElement: boolean): uint32;
begin

end;



function TSType.GetTotalPackedSize(IsSingleElement: boolean): uint32;
begin

end;



function TSType.GetDescHelper(out pDesc: TD3DX11_EFFECT_TYPE_DESC; IsSingleElement: boolean): HRESULT;
begin

end;



function TSType.IsValid(): boolean; stdcall;
begin
    Result := True;
end;



function TSType.GetDesc(out pDesc: TD3DX11_EFFECT_TYPE_DESC): HResult; stdcall;
begin
    Result := GetDescHelper(pDesc, False);
end;



function TSType.GetMemberTypeByIndex(Index: UINT32): ID3DX11EffectType; stdcall;
begin

end;



function TSType.GetMemberTypeByName(Name: LPCSTR): ID3DX11EffectType; stdcall;
begin

end;



function TSType.GetMemberTypeBySemantic(Semantic: LPCSTR): ID3DX11EffectType;
    stdcall;
begin

end;



function TSType.GetMemberName(Index: UINT32): LPCSTR; stdcall;
begin

end;



function TSType.GetMemberSemantic(Index: UINT32): LPCSTR; stdcall;
begin

end;

end.
