unit Uart;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, Variables, Async32;

type
  TUartForm = class(TForm)
    CancelBtn: TBitBtn;
    OKBtn: TBitBtn;
    USBBox: TComboBox;
    Label1: TLabel;
    procedure FormActivate(Sender: TObject);
    procedure USBBoxChange(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  UartForm: TUartForm;

//  USBDevice: String;

implementation

function FT_GetNumDevices(pvArg1:Pointer;pvArg2:Pointer;dwFlags:Longword) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_ListDevices';
function FT_ListDevices(pvArg1:Dword;pvArg2:Pointer;dwFlags:Dword) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_ListDevices';

{$R *.dfm}

{
    Creating device list
}
procedure TUartForm.FormActivate(Sender: TObject);
var
   A,B,C: LongInt;
   FT_Device_String_Buffer : Array [1..50] of Char;
   S: String;
begin
A:=0;
USBBox.Items.Clear;
USBBox.Text:='';
if Tag=0 then
begin
FT_GetNumDevices(@A,Nil,FT_LIST_NUMBER_ONLY);
if A>0 then
   for B:=1 to A do
       if FT_ListDevices(B-1,@FT_Device_String_Buffer,(FT_OPEN_BY_SERIAL_NUMBER or FT_LIST_BY_INDEX))=FT_OK then
          begin
          C:=1; S:='';
          while FT_Device_String_Buffer[C] <> Chr(0) do
                begin
                S:=S+FT_Device_String_Buffer[C];
                Inc(C);
                end;
          USBBox.Items.Add(S);
          end;
if USBBox.Items.Count<>0 then
   for A:=0 to USBBox.Items.Count-1 do
       if USBBox.Items.Strings[A]=USBDevice then
          begin
          USBBox.ItemIndex:=A;
          USBBox.Text:=USBBox.Items.Strings[A];
          Break;
          end;
end
else begin
for A:=1 to 32 do
    begin
    B:=FileOpen('COM'+IntToStr(A),fmOpenReadWrite);
    if B>0 then
       begin
       USBBox.Items.Add('COM'+IntToStr(A));
       FileClose(B);
       end;
    end;
if USBBox.Items.Count<>0 then
   for A:=0 to USBBox.Items.Count-1 do
       if USBBox.Items.Strings[A]=COMDevice then
          begin
          USBBox.ItemIndex:=A;
          USBBox.Text:=USBBox.Items.Strings[A];
          Break;
          end;
end;
OKBtn.Enabled:=false;
end;

procedure TUartForm.USBBoxChange(Sender: TObject);
begin
OKBtn.Enabled:=USBBox.Text<>'';
end;

end.
