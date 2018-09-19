unit FX11.D3DXGlobal;

{$mode delphi}

interface

uses
  Windows,Classes, SysUtils;


type
  //////////////////////////////////////////////////////////////////////////
// CEffectVector - A vector implementation
//////////////////////////////////////////////////////////////////////////
   TEffectVector<T> = class

   end;


procedure D3DXDebugPrintf( lvl:UINT;  szFormat:LPCSTR);
function D3DX11DebugMute( mute:boolean):boolean;

implementation

var
    s_mute : boolean = false;

procedure D3DXDebugPrintf(lvl: UINT; szFormat: LPCSTR);
begin
     if (s_mute) then
        Exit;
    OutputDebugStringA(pAnsiChar('Effects11: '+szFormat));
end;

function D3DX11DebugMute(mute: boolean): boolean;
begin
    result:= s_mute;
    s_mute := mute;
end;

end.

