unit Variables;

interface

uses
    Classes, SysUtils, Types, ComCtrls, Comm;

Type FT_Result = Integer;

type
    TP = array [0..0] of Byte;
    PP = ^TP;

procedure GetWord(var S: String; var T: String);
function HexToInt(Src: String): Int64;
function ReadObject(Selector, Offset: Longint; Count: Word; DST: Pointer; Pref: String): Boolean;
function WriteObject(Selector, Offset: Longint; Count: Word; SRC: PByteArray; Pref: String): Boolean;
procedure AsciiToBuff(Src: Pointer; Dst: PByteArray; MaxCount: Longint);
procedure RemoveFirstSpaces(var S: String);
function ReadWholeObject(Obj: Longint; Pref: String; var Buff: PP): Longint;
function GetObjectLength(Pref: String; Sel: Longint): Longint;
function ReadPartialObject(Selector, Offset, Count: Longint; var Buff: PP; Pref: string): Boolean;
function WriteBlocked(Selector, Offset: Longint; Count: Word; SRC: PByteArray; Pref: String): Boolean;
function ReadPerformance(DST: Pointer; Pref: String): Boolean;
function RunProcess(Selector: Longint): Boolean;
procedure Disassm(Src: Pointer; Lim, ISet: Longint; var ILen: Longint; var Assm: String);
function StopProcess(Selector: Longint): Boolean;
procedure ReadBkpt;
procedure ReadDMA(var Buff: PP; Pref: String);

var

{
0 - port closed
1 - port opened but no connection to the processor system
}
MainState: Longint;

USBDevice, COMDevice, CP, ParamString: string;

ISetList: TStringList;

CoreBuff: array [0..255] of Byte;

//Instruction references
IRefList: array [0..31] of TStringList;

CoreNode: TTreeNode;

FT_HANDLE : Longword = 0;
FT_In_Buffer : Array[0..32767] of Char;
FT_Out_Buffer : Array[0..32767] of Char;

BinaryMode: Boolean=true;
RefreshInterval: Longint=1;
AutoRefresh: Boolean=false;
BS: Longint=256;
FTECode: Byte;
Baud: Byte=0;

// pre-defined selectors
CodeSel: Longint=1;
IOSel: Longint=2;
SysSel: Longint=3;
WholeRAMSel: Longint=4;
StackSel: Longint=5;
PSOSel: Longint=8;
IntSel: Longint=9;
ProcessSel: Longint=10;
DescriptorSel: Longint=11;
ServiceSel: Longint=12;
BreakpointSel: Longint=14;
ErrorSel: Longint=15;
FlashCtrlSel: Longint=16;
FlashDataSel: Longint=17;
FlashWBSel: Longint=18;

MasterCPU: Byte;

PME: Boolean = false;

ObjStart, ObjLength: Longint;

EFlags: array [0..31] of Boolean;

CodeList: array [0..31] of TStringList;
PSOSelector: array [0..31] of Longint;
BreakFlags: array [0..31] of Longint;
CodeLimit: array [0..31] of Longint;
BreakOffset: array [0..31,0..31] of Longint;              // offsets for breakpoints
BreakInst: array [0..31,0..31] of Longint;                   // replaced instructions for x32
PSO16Buffer: array [0..31,0..591] of Byte;                      // x16 PSO
PSO32Buffer: array [0..31,0..975] of Byte;                      // x32 PSO
CodeModes: array [0..31] of Byte;                               // x16 or x32 selection
VPref: array [0..31] of String;
DTab: TTabControl;
ActiveBkpt: Longint;
DebugIndex: Integer;
DMode: Boolean;



Const
// FT_Result Values
    FT_OK = 0;
    FT_INVALID_HANDLE = 1;
    FT_DEVICE_NOT_FOUND = 2;
    FT_DEVICE_NOT_OPENED = 3;
    FT_IO_ERROR = 4;
    FT_INSUFFICIENT_RESOURCES = 5;
    FT_INVALID_PARAMETER = 6;
    FT_SUCCESS = FT_OK;
// FT_Open_Ex Flags
    FT_OPEN_BY_SERIAL_NUMBER = 1;
    FT_OPEN_BY_DESCRIPTION = 2;
// FT_List_Devices Flags
    FT_LIST_NUMBER_ONLY = $80000000;
    FT_LIST_BY_INDEX = $40000000;
    FT_LIST_ALL = $20000000;
// Baud Rate Selection
    FT_BAUD_300 = 300;
    FT_BAUD_600 = 600;
    FT_BAUD_1200 = 1200;
    FT_BAUD_2400 = 2400;
    FT_BAUD_4800 = 4800;
    FT_BAUD_9600 = 9600;
    FT_BAUD_14400 = 14400;
    FT_BAUD_19200 = 19200;
    FT_BAUD_38400 = 38400;
    FT_BAUD_57600 = 57600;
    FT_BAUD_115200 = 115200;
    FT_BAUD_230400 = 230400;
    FT_BAUD_460800 = 460800;
    FT_BAUD_921600 = 921600;
    FT_BAUD_1500000 = 1500000;
// Data Bits Selection
    FT_DATA_BITS_7 = 7;
    FT_DATA_BITS_8 = 8;
// Stop Bits Selection
    FT_STOP_BITS_1 = 0;
    FT_STOP_BITS_2 = 2;
// Parity Selection
    FT_PARITY_NONE = 0;
    FT_PARITY_ODD = 1;
    FT_PARITY_EVEN = 2;
    FT_PARITY_MARK = 3;
    FT_PARITY_SPACE = 4;
// Flow Control Selection
    FT_FLOW_NONE = $0000;
    FT_FLOW_RTS_CTS = $0100;
    FT_FLOW_DTR_DSR = $0200;
    FT_FLOW_XON_XOFF = $0400;
// Purge Commands
    FT_PURGE_RX = 1;
    FT_PURGE_TX = 2;
// Notification Events
    FT_EVENT_RXCHAR = 1;
    FT_EVENT_MODEM_STATUS = 2;
// IO Buffer Sizes
    FT_In_Buffer_Size = $8000;    // 32k
    FT_In_Buffer_Index = FT_In_Buffer_Size - 1;
    FT_Out_Buffer_Size = $8000;    // 32k
    FT_Out_Buffer_Index = FT_Out_Buffer_Size - 1;
// DLL Name
    FT_DLL_Name = 'ftd2xx.dll';

implementation

function FT_Read(ftHandle:Dword; FTInBuf : Pointer; BufferSize : LongInt; ResultPtr : Pointer ) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_Read';
function FT_Write(ftHandle:Dword; FTOutBuf : Pointer; BufferSize : LongInt; ResultPtr : Pointer ) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_Write';


// extract first word from string
procedure GetWord(var S: String; var T: String);
var
   A: Longint;
begin
T:='';
if S<>'' then
   begin
   while (S[1]=' ')or(S[1]=#9) do
         begin
         Delete(S,1,1);
         if Length(S)=0 then Break;
         end;
   if S<>'' then
      begin
      if (Ord(S[1])<$30)or(S[1]='[')or(S[1]=']')or(S[1]='{')or(S[1]='}')or(S[1]=';')or(S[1]='=')or(S[1]=':')or(S[1]='''') then T:=S[1]
         else for A:=1 to Length(S) do
              if (Ord(S[A])>=$30)and(S[A]<>'[')and(S[A]<>']')and(S[A]<>'{')and(S[A]<>'}')and(S[A]<>';')and(S[A]<>'=')and(S[A]<>':') then T:=T+S[A]
                                                                                                                                    else Break;
      end;
   Delete(S,1,Length(T));
   end;
end;

{
    Convertation HEX string to Int64
}
function HexToInt(Src: String): Int64;
var
   A: Int64;
   S: String;
begin
A:=0;
S:=Src;
while Length(S)<>0 do
      begin
      if Ord(S[1])>$39 then A:=(A shl 4) or ((Ord(S[1]) - $37) and 15)
                       else A:=(A shl 4) or (Ord(S[1]) and 15);
      Delete(S,1,1);
      end;
Result:=A;
end;

{
Read data from selected object and at selected offset
}
function ReadObject(Selector, Offset: Longint; Count: Word; DST: Pointer; Pref: String): Boolean;
var
   A,B,C: Longint;
   S,Len: String;
   DS: PByteArray;
begin
Len:='';
if BinaryMode
   then begin
        S:='RO R'+IntToHex(Selector,6)+' '+IntToHex(Offset,8)+' '+IntToStr(Count)+Chr(13);
        if Length(Pref)<>0 then Len:=IntToHex(Length(S),4);
        S:=Pref+Len+S;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        B:=Length(S)+3+Count+1-Length(Pref)-Length(Len);
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
                         else begin
                         Sleep(B);
                         A:=Com.Comm1.Read(FT_In_Buffer,B);
                         end;
        if A<>B then Result:=false
           else begin
           A:=StrPos(FT_In_Buffer,'RO ')-@FT_In_Buffer[0];
           if A<>0 then
              begin
              for C:=0 to B-1 do FT_In_Buffer[C]:=FT_In_Buffer[C+A];
              if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer[B-A],A,@C)
                               else C:=Com.Comm1.Read(FT_In_Buffer[B-A],A);
              end;
           Result:=true;
           DS:=Dst;
           for A:=0 to Count-1 do DS[A]:=Ord(FT_In_Buffer[Length(S)+3+A-Length(Pref)-Length(Len)]);
           if FT_In_Buffer[B-1]=#$BB then ReadBkpt;
           end;
        end
   else begin
        S:='RO '+IntToHex(Selector,6)+' '+IntToHex(Offset,8)+' '+IntToStr(Count)+Chr(13);
        if Length(Pref)<>0 then Len:=IntToHex(Length(S),4);
        S:=Pref+Len+S;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        B:=Length(S)+3+(((Count-1) shr 4)+1)*2+Count*3+3-Length(Pref)-Length(Len);
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
                         else begin
                         Sleep(B);
                         A:=Com.Comm1.Read(FT_In_Buffer,B);
                         end;
        FT_In_Buffer[A]:=Chr(0);
        if A<>B then Result:=false
           else begin
           A:=StrPos(FT_In_Buffer,'RO ')-@FT_In_Buffer[0];
           if A<>0 then
              begin
              for C:=0 to B-1 do FT_In_Buffer[C]:=FT_In_Buffer[C+A];
              if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer[B-A],A,@C)
                               else C:=Com.Comm1.Read(FT_In_Buffer[B-A],A);
              end;
           Result:=True;
           AsciiToBuff(@FT_In_Buffer,DST,Count);
           if FT_In_Buffer[A-1]=#$BB then ReadBkpt;
           end;
        end;
end;

{
    Convert ASCII data to the binary
}
procedure AsciiToBuff(Src: Pointer; Dst: PByteArray; MaxCount: Longint);
var
   A: LongInt;
   S,T: String;
   Bt: byte;
begin
S:=StrPas(Src);
T:=Copy(S,1,2)+Chr(13)+Chr(10);
if Pos(T,S)<>0 then
   begin
   Delete(S,1,Pos(T,S)+3);
   A:=0;
   while (A<MaxCount)and(Length(S)>2) do
         begin
         if (S[1]=Chr(32))or(S[1]=Chr(13))or(S[1]=Chr(10)) then Delete(S,1,1)
            else begin
            if Ord(S[1])>$39 then Bt:=(Ord(S[1])-55) shl 4
                             else Bt:=(Ord(S[1]) and 15) shl 4;
            if Ord(S[2])>$39 then Bt:=Bt or (Ord(S[2])-55)
                             else Bt:=Bt or (Ord(S[2]) and 15);
            Dst[A]:=Bt;
            Inc(A);
            Delete(S,1,2);
            end;
         end;
   end;
end;

{
    Write data to the object
}
function WriteObject(Selector, Offset: Longint; Count: Word; SRC: PByteArray; Pref: String): Boolean;
var
   A,B: Longint;
   S, Len: String;
begin
if BinaryMode
   then begin
        S:='WO R'+IntToHex(Selector,6)+' '+IntToHex(Offset,8)+' '+IntToStr(Count)+Chr(13);
        if Length(Pref)<>0 then Len:=IntToHex(Length(S),4)
                           else Len:='';
        S:=Pref+Len+S;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        B:=Length(S)+3-Length(Pref)-Length(Len);
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
           else begin
           Sleep(B);
           A:=Com.Comm1.Read(FT_In_Buffer,B);
           end;
        FTECode:=1;
        if A<>B then Result:=False
           else begin
           Result:=true;
           if Length(Pref)<>0 then
              begin
              S:=Pref+IntToHex(Count,4);
              StrPCopy(FT_Out_Buffer,S);
              if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                               else Com.Comm1.Write(FT_Out_Buffer,Length(S));
              end;
           if USBDevice<>'' then FT_Write(FT_Handle,SRC,Count,@A)
                            else Com.Comm1.Write(SRC[0],Count);
           if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,3,@A)
              else begin
              Sleep(Count);
              A:=Com.Comm1.Read(FT_In_Buffer,3);
              end;
           Result:=(A=3);
           if (A<>3) then FTECode:=2
                     else FTECode:=0;
           if (FT_In_Buffer[2]=#$BB)and(A=3) then ReadBkpt;
           end;
        end
   else begin
        S:='WO '+IntToHex(Selector,6)+' '+IntToHex(Offset,8)+' '+IntToStr(Count)+Chr(13);
        if Length(Pref)<>0 then Len:=IntToHex(Length(S),4)
                           else Len:='';
        S:=Pref+Len+S;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        B:=Length(S)+3-Length(Pref)-Length(Len);
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
           else begin
           Sleep(B);
           A:=Com.Comm1.Read(FT_In_Buffer,B);
           end;
        FTECode:=1;
        if A<>B then Result:=False
           else begin
           Result:=true;
           S:='';
           B:=0;
           while B<>Count do
                 begin
                 S:=S+' '+IntToHex(SRC[B],2);
                 Inc(B);
                 end;
           if Length(Pref)<>0 then Len:=IntToHex(Length(S),4)
                              else Len:='';
           S:=Pref+Len+S;
           StrPCopy(FT_Out_Buffer,S);
           if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                            else Com.Comm1.Write(FT_Out_Buffer,Length(S));

           if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,3,@A)
              else begin
              Sleep(Length(S));
              A:=Com.Comm1.Read(FT_In_Buffer,3);
              end;
           Result:=(A=3);
           if (A<>3) then FTECode:=2
                     else FTECode:=0;
           if (FT_In_Buffer[2]=#$BB)and(A=3) then ReadBkpt;
           end;
        end;
end;

//------------------------------------------------------------------------------
// remove first spaces
procedure RemoveFirstSpaces(var S: String);
begin
if Length(S)<>0 then
   while (S[1]=' ')or(S[1]=#9) do
         begin
         Delete(S,1,1);
         if Length(S)=0 then Break;
         end;
end;

//------------------------------------------------------------------------------
// Read whole object
function ReadWholeObject(Obj: Longint; Pref: String; var Buff: PP): Longint;
var
   A,B,C: Longint;
begin
Result:=0;
A:=GetObjectLength(Pref,Obj);
if A>0 then
   begin
   GetMem(Buff,A);
   B:=0;
   while B<>A do
         begin
         if (A-B)>=BS then C:=BS
                      else C:=A-B;
         if not ReadObject(Obj,B,C,@Buff[B],Pref) then Break
            else begin
            B:=B+C;
            Result:=B;
            end;
         end;
   end;
end;

//------------------------------------------------------------------------------
// Get object length
function GetObjectLength(Pref: String; Sel: Longint): Longint;
var
   A,B: Longint;
   S, Ln: String;
begin
Result:=0;
S:='GL '+IntToHex(Sel,6)+#13;
if Length(Pref)<>0 then Ln:=IntToHex(Length(S),4)
                   else Ln:='';
S:=Pref+Ln+S;
StrPCopy(FT_Out_Buffer,S);
if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                 else Com.Comm1.Write(FT_Out_Buffer,Length(S));
B:=26;
if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
   else begin
   Sleep(Length(S)+B);
   A:=Com.Comm1.Read(FT_In_Buffer,B);
   end;
if A=B then
   begin
   FT_In_Buffer[A]:=#0;
   S:=StrPas(FT_In_Buffer);
   Delete(S,1,11);
   Result:=StrToIntDef(Copy(S,1,12),0);
   end;
end;

//------------------------------------------------------------------------------
// Read partial data from object
function ReadPartialObject(Selector, Offset, Count: Longint; var Buff: PP; Pref: string): Boolean;
var
   A, B: Longint;
begin
A:=GetObjectLength(Pref,Selector);
if A=0 then Result:=false
   else if A<(Offset+Count) then Result:=false
        else begin
             GetMem(Buff,Count);
             A:=0;
             Result:=true;
             while A<Count do
                   begin
                   if Count-A>=BS then B:=BS
                                  else B:=Count-A;
                   if ReadObject(Selector,Offset+A,B,@Buff[A],Pref) then A:=A+B
                      else begin
                           FreeMem(Buff);
                           Result:=false;
                           Break;
                           end;
                   end;
             end;

end;

{
    Write data to the object in blocked mode
}
function WriteBlocked(Selector, Offset: Longint; Count: Word; SRC: PByteArray; Pref: String): Boolean;
var
   A,B: Longint;
   S, Len: String;
begin
if BinaryMode
   then begin
        S:='WB R'+IntToHex(Selector,6)+' '+IntToHex(Offset,8)+' '+IntToStr(Count)+Chr(13);
        if Length(Pref)<>0 then Len:=IntToHex(Length(S),4)
                           else Len:='';
        S:=Pref+Len+S;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        B:=Length(S)+3-Length(Pref)-Length(Len);
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
           else begin
           Sleep(Length(S)+B);
           A:=Com.Comm1.Read(FT_In_Buffer,B);
           end;
        if A<>B then Result:=False
           else begin
           Result:=true;
           if Length(Pref)<>0 then
              begin
              S:=Pref+IntToHex(Count,4);
              StrPCopy(FT_Out_Buffer,S);
              if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                               else Com.Comm1.Write(FT_Out_Buffer,Length(S));
              end;
           if USBDevice<>''
              then begin
                   FT_Write(FT_Handle,SRC,Count,@A);
                   FT_Read(FT_Handle,@FT_In_Buffer,3,@A);
                   end
              else begin
                   Com.Comm1.Write(SRC[0],Count);
                   Sleep(Count);
                   A:=Com.Comm1.Read(FT_In_Buffer,3);
                   end;
           Result:=(A=3);
           if (FT_In_Buffer[2]=#$BB)and(A=3) then ReadBkpt;
           end;
        end
   else begin
        S:='WB '+IntToHex(Selector,6)+' '+IntToHex(Offset,8)+' '+IntToStr(Count)+Chr(13);
        if Length(Pref)<>0 then Len:=IntToHex(Length(S),4)
                           else Len:='';
        S:=Pref+Len+S;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        B:=Length(S)+3-Length(Pref)-Length(Len);
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
           else begin
           Sleep(Length(S)+B);
           A:=Com.Comm1.Read(FT_In_Buffer,B);
           end;
        if A<>B then Result:=False
           else begin
           Result:=true;
           S:='';
           B:=0;
           while B<>Count do
                 begin
                 S:=S+' '+IntToHex(SRC[B],2);
                 Inc(B);
                 end;
           if Length(Pref)<>0 then Len:=IntToHex(Length(S),4)
                              else Len:='';
           S:=Pref+Len+S;
           StrPCopy(FT_Out_Buffer,S);
           if USBDevice<>''
              then begin
                   FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                   FT_Read(FT_Handle,@FT_In_Buffer,3,@A);
                   end
              else begin
                   Com.Comm1.Write(FT_Out_Buffer,Length(S));
                   Sleep(Length(S));
                   A:=Com.Comm1.Read(FT_In_Buffer,3);
                   end;
           Result:=(A=3);
           if (FT_In_Buffer[2]=#$BB)and(A=3) then ReadBkpt;
           end;
        end;
end;

// read performance monitor data
function ReadPerformance(DST: Pointer; Pref: String): Boolean;
var
   A: Longint;
   Buff: array [0..3] of longword;
   S, Len: String;
   DS: PByteArray;
begin
S:='GP '+Chr(13);
if Length(Pref)<>0 then Len:=IntToHex(Length(S),4)
                   else Len:='';
S:=Pref+Len+S;
StrPCopy(FT_Out_Buffer,S);
if USBDevice<>''
   then begin
        FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
        FT_Read(FT_Handle,@FT_In_Buffer,41,@A);
        end
   else begin
        Com.Comm1.Write(FT_Out_Buffer,Length(S));
        Sleep(Length(S)+41);
        A:=Com.Comm1.Read(FT_In_Buffer,41);
        end;
if A<>41 then Result:=false
   else begin
   Result:=true;
   FT_In_Buffer[A]:=Chr(0);
   S:=StrPas(FT_In_Buffer);
   Buff[0]:=HexToInt(Copy(S,8+6,8));
   Buff[1]:=HexToInt(Copy(S,6,8));
   Buff[2]:=HexToInt(Copy(S,6+16+1+8,8));
   Buff[3]:=HexToInt(Copy(S,6+16+1,8));
   DS:=DST;
   Move(Buff[0],DS[0],16);
   if FT_In_Buffer[40]=#$BB then ReadBkpt;
   end;
end;

{
    Run process
}
function RunProcess(Selector: Longint): Boolean;
var
   A: Longint;
   S: String;
begin
S:='RP '+IntToHex(Selector and $FFFFFF,6)+Chr(13);
if (Selector and $FF000000)<>0 then S:='@'+IntToHex(Selector shr 24,2)+IntToHex(Length(S),4)+S;
StrPCopy(FT_Out_Buffer,S);
FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
Result:=(A=16);
if (FT_In_Buffer[15]=#$BB)and(A=16) then ReadBkpt;
end;

{
     Disassembling by using configuration of the instruction set
}
procedure Disassm(Src: Pointer; Lim, ISet: Longint; var ILen: Longint; var Assm: String);
var
   Ae, Be, Ce, De, Fmask, Fvalue: Int64;
   A, B, C, Fsize, Fpos: Longint;
   S,T,U,W,X,Y: String;
   SBuff: array [0..7] of Byte;
   DS: PByteArray;
begin
Assm:='';
ILen:=0;
DS:=Src;
if IRefList[ISet].Count=0 then
   if Length(ISetList[ISet])<>0 then IRefList[ISet].LoadFromFile(ISetList[ISet]);
if IRefList[ISet].Count>0 then
   begin
   A:=0;
   // search start of the instruction list
   while A<IRefList[ISet].Count do
         begin
         S:=AnsiUpperCase(IRefList[ISet].Strings[A]);
         GetWord(S,T);
         Inc(A);
         if CompareStr(T,'INSTRUCTIONS')=0 then Break;
         end;
   // set the default instruction length
   Delete(S,1,Pos('SIZE',S)+4);
   GetWord(S,T);
   B:=StrToInt(T);
   ILen:=1+((B-1) shr 3);
   if A<IRefList[ISet].Count then
      while A<IRefList[ISet].Count do
            begin
            // if instruction section found
            S:=AnsiUpperCase(IRefList[ISet].Strings[A]);
            RemoveFirstSpaces(S);
            if Pos('ENDOF',S)=1 then Break;
            if (Pos(';',S)<>0)and(Pos('=',S)<>0) then
               begin
               T:=S;                                 // will be OpCode
               U:=S;                                 // will be byte count and mask also control transfer parameter
               Delete(T,1,Pos('=',T));
               GetWord(T,W);                         // W - opcode
               W:=Copy(W,1,Pos('H',W)-1);
               Ae:=HexToint(W);                      // Ae - opcode
               Delete(U,1,Pos(';',U));               // can contain control transfer parameter
               GetWord(U,T);
               B:=StrToIntDef(T,0);                  // number of bytes in the instruction
               GetWord(U,T);
               Y:=U;
               RemoveFirstSpaces(Y);
               T:=Copy(T,1,Pos('H',T)-1);
               Be:=HexToInt(T);                      // opcode mask
               if (B<=Lim)and(B<9) then
                  begin
                  ILen:=B;
                  Move(DS[0],SBuff[0],B);
                  Ce:=0;
                  while B<>0 do
                        begin
                        Ce:=(Ce shl 8) or SBuff[B-1];
                        Dec(B);
                        end;
                  if Ae=(Be and Ce) then
                     begin
                     // if opcode found
                     S:=Copy(S,1,Pos('=',S)-1);
                     GetWord(S,Assm);                // set the instruction mnemonic
                     Assm:=Assm+#$20+#$20;
                     while Length(S)<>0 do
                           begin
                           GetWord(S,T);
                           // search word T in the fields list
                           C:=0;
                           while C<IRefList[ISet].Count do
                                 begin
                                 U:=AnsiUpperCase(IRefList[ISet].Strings[C]);
                                 GetWord(U,W);
                                 if CompareStr(W,'FIELD')<>0 then Inc(C)
                                    else begin
                                    // if field record
                                    GetWord(U,W);
                                    if CompareStr(W,T)<>0 then Inc(C)
                                       else begin
                                       // if field found
                                       Fsize:=0; Fpos:=0;
                                       while Length(U)<>0 do
                                             begin
                                             GetWord(U,W);
                                             if CompareStr(W,'SIZE')=0 then
                                                begin
                                                Delete(U,1,1);
                                                GetWord(U,W);
                                                Fsize:=StrToIntDef(W,0);
                                                end;
                                             if CompareStr(W,'POSITION')=0 then
                                                begin
                                                Delete(U,1,1);
                                                GetWord(U,W);
                                                Fpos:=StrToIntDef(W,0);
                                                end;
                                             end;
                                       if Fsize<>0 then
                                          begin
                                          // search for field mnemonic
                                          Fmask:=-1;
                                          Fmask:=not(Fmask shl Fsize);
                                          Fvalue:=(Ce shr Fpos)and Fmask;
                                          if Length(Y)<>0 then
                                             if Pos(T,Y)=1 then
                                                begin
                                                // transfer control field
                                                Delete(Y,1,Pos(',',Y)-1);
                                                case Fsize of
                                                  0..4: Y:=IntToHex(Fvalue,1)+Y;
                                                  5..8: Y:=IntToHex(Fvalue,2)+Y;
                                                  9..12: Y:=IntToHex(Fvalue,3)+Y;
                                                  13..16: Y:=IntToHex(Fvalue,4)+Y;
                                                  17..20: Y:=IntToHex(Fvalue,5)+Y;
                                                  21..24: Y:=IntToHex(Fvalue,6)+Y;
                                                  25..28: Y:=IntToHex(Fvalue,7)+Y;
                                                  29..32: Y:=IntToHex(Fvalue,8)+Y;
                                                  33..36: Y:=IntToHex(Fvalue,9)+Y;
                                                  37..40: Y:=IntToHex(Fvalue,10)+Y;
                                                  41..44: Y:=IntToHex(Fvalue,11)+Y;
                                                  45..48: Y:=IntToHex(Fvalue,12)+Y;
                                                  49..52: Y:=IntToHex(Fvalue,13)+Y;
                                                  53..56: Y:=IntToHex(Fvalue,14)+Y;
                                                  57..60: Y:=IntToHex(Fvalue,15)+Y;
                                                  else Y:=IntToHex(Fvalue,16)+Y;
                                                  end;
                                                end;
                                          Inc(C);
                                          while C<IRefList[ISet].Count do
                                                begin
                                                U:=AnsiUpperCase(IRefList[ISet].Strings[C]);
                                                GetWord(U,W);
                                                if CompareStr(W,'ENDOF')=0 then C:=IRefList[ISet].Count
                                                   else if Pos('=',U)=0 then Inc(C)
                                                        else begin
                                                        Delete(U,1,Pos('=',U));
                                                        GetWord(U,X);
                                                        if Pos('H',X)=0 then De:=StrToIntDef(X,0)
                                                           else begin
                                                           X:=Copy(X,1,Pos('H',X)-1);
                                                           De:=HexToInt(X);
                                                           end;
                                                        if De<>Fvalue then Inc(C)
															                             else begin
															                             Assm:=Assm+W;
															                             Break;
															                             end;
                                                        end;
                                                end;
                                          if C=IRefList[ISet].Count then
                                             case Fsize of
                                                  0..4: Assm:=Assm+IntToHex(Fvalue,1);
                                                  5..8: Assm:=Assm+IntToHex(Fvalue,2);
                                                  9..12: Assm:=Assm+IntToHex(Fvalue,3);
                                                  13..16: Assm:=Assm+IntToHex(Fvalue,4);
                                                  17..20: Assm:=Assm+IntToHex(Fvalue,5);
                                                  21..24: Assm:=Assm+IntToHex(Fvalue,6);
                                                  25..28: Assm:=Assm+IntToHex(Fvalue,7);
                                                  29..32: Assm:=Assm+IntToHex(Fvalue,8);
                                                  33..36: Assm:=Assm+IntToHex(Fvalue,9);
                                                  37..40: Assm:=Assm+IntToHex(Fvalue,10);
                                                  41..44: Assm:=Assm+IntToHex(Fvalue,11);
                                                  45..48: Assm:=Assm+IntToHex(Fvalue,12);
                                                  49..52: Assm:=Assm+IntToHex(Fvalue,13);
                                                  53..56: Assm:=Assm+IntToHex(Fvalue,14);
                                                  57..60: Assm:=Assm+IntToHex(Fvalue,15);
                                                  else Assm:=Assm+IntToHex(Fvalue,16);
                                                  end;
                                          end;
                                       T:='';
                                       Break;
                                       end;
                                    end;
                                 end;
                           if C=IRefList[ISet].Count then Assm:=Assm+T;
                           end;
                     if Length(Y)<>0 then Assm:=Assm+';'+Y;
                     Break;
                     end;
                  end;
               end;
            Inc(A);
            end;
   if Length(Assm)=0 then
      for A:=0 to ILen-1 do
          Assm:=Assm+IntToHex(DS[A],2);
   end;
end;

{
    Stop process
}
function StopProcess(Selector: Longint): Boolean;
var
   A: Longint;
   S: String;
begin
S:='SP '+IntToHex(Selector and $FFFFFF,6)+Chr(13);
if (Selector and $FF000000)<>0 then S:='@'+IntToHex(Selector shr 24,2)+IntToHex(Length(S),4)+S;
StrPCopy(FT_Out_Buffer,S);
FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
Result:=(A=16);
if (FT_In_Buffer[15]=#$BB)and(A=16) then ReadBkpt;
end;

//------------------------------------------------------------------------------
// read breakpoint codes from the board
procedure ReadBkpt;
var
   A,B,C: Longint;
   Al,IP,PSO: Longword;
   S: String;
   F: Boolean;
begin
A:=0;
while CoreBuff[A]<>0 do
    begin
    S:='RB '+#13;
    if A>0 then S:='@'+IntToHex(CoreBuff[A],2)+'0004'+S;
    StrPCopy(FT_Out_Buffer,S);
    FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@B);
    FT_Read(FT_Handle,@FT_In_Buffer,23,@B);
    if B=23 then
       begin
       // if answer received
       FT_In_Buffer[B]:=#0;
       S:=StrPas(FT_In_Buffer);
       S:=Copy(S,6,16);
       Al:=HexToInt(S);
       FT_Read(FT_Handle,@FT_In_Buffer,1+Al*18,@B);
       if (Al>0)and(B=(1+Al*18)) then
          begin
          // if breakpoint list readed
          FT_In_Buffer[B]:=#0;
          S:=StrPas(FT_In_Buffer);
          while Length(S)>16 do
                begin
                IP:=HexToInt(Copy(S,1,8));
                Delete(S,1,8);
                PSO:=HexToInt(Copy(S,1,8)) and $FFFFFF;
                // search process
                for B:=0 to 15 do
                    if (PSO=PSOSelector[B])and((A=0)or(CompareStr('@'+IntToHex(CoreBuff[A],2),VPref[B])=0)) then
                       begin
                       F:=false;
                       for C:=0 to 15 do
                           if IP=BreakOffset[B,C] then
                              begin
                              F:=true;
                              ActiveBkpt:=C;
                              Break;
                              end;
                       if not F then
                          begin
                          // if offset of breakpoint is unknown
                          for C:=0 to 15 do
                              if (BreakFlags[B] and (1 shl C))=0 then
                                 begin
                                 BreakOffset[B,C]:=IP;
                                 BreakFlags[B]:=BreakFlags[B] or (1 shl C);
                                 if CodeModes[B]=0 then BreakInst[B,C]:=$2FF0
                                                   else BreakInst[B,C]:=$CC;
                                 ActiveBkpt:=C;
                                 Break;
                                 end;
                          end;
                       if (B=DebugIndex)and(DMode) then DTab.OnChange(nil);
                       end;
                end;
          end;
       end;
    Inc(A);
    end;
end;

//------------------------------------------------------------------------------
// Read DMA registers
procedure ReadDMA(var Buff: PP; Pref: String);
var
   Al: array [0..2] of Int64;
   A,B,C,D: Longint;
begin
GetMem(Buff,4096);
FillChar(Buff[0],4096,0);
C:=0;
for A:=0 to 63 do
    begin
    // set channel
    WriteObject(SysSel,$48,1,@A,Pref);
    Al[0]:=0;
    if ReadObject(SysSel,$48,2,@D,Pref)
       then begin
       if (D and $40)=0 then Break;
       B:=D and $FC3F;
       WriteObject(SysSel,$48,2,@B,Pref);
       if ReadObject(SysSel,$48,24,@Al[0],Pref) then Move(Al[0],Buff[C],24);
       if (Al[0] and $40)=0 then Break;
       B:=(D and $FC7F) or $100;
       WriteObject(SysSel,$48,2,@B,Pref);
       if ReadObject(SysSel,$48,8,@Al[0],Pref) then Move(Al[0],Buff[C+24],8);
       B:=(D and $FC7F) or $380;
       WriteObject(SysSel,$48,2,@B,Pref);
       if ReadObject(SysSel,$48,24,@Al[0],Pref) then Move(Al[0],Buff[C+24+8],24);
       end;
    C:=C+56;
    end;
end;

end.
