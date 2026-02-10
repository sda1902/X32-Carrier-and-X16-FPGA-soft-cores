unit Auto;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, ExtCtrls, StdCtrls, Buttons, Variables;

type
  TAutoForm = class(TForm)
    Panel1: TPanel;
    AutoGrid: TStringGrid;
    OkBtn: TBitBtn;
    CancelBtn: TBitBtn;
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure AutoGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure AutoGridKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure AutoGridSetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: String);
    procedure OkBtnClick(Sender: TObject);
    procedure AutoGridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure AutoGridDblClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  AutoForm: TAutoForm;

implementation

{$R *.dfm}

// form show
procedure TAutoForm.FormShow(Sender: TObject);
var
   A,B: Longint;
   Buff: array [0..63] of Char;
   F: Boolean;
begin
AutoGrid.RowCount:=2;
AutoGrid.Cells[0,0]:='Process name';
AutoGrid.Cells[1,0]:='CPU';
AutoGrid.Cells[2,0]:='Parameter';
AutoGrid.Cells[3,0]:='Run';
AutoGrid.Cells[0,1]:='';
AutoGrid.Cells[1,1]:='';
AutoGrid.Cells[2,1]:='';
AutoGrid.Cells[3,1]:='';
// refresh autorun list
Buff[0]:=#$0b;
WriteObject(FlashCtrlSel,2,1,@Buff,'');
F:=true;
A:=64;
while F do
      begin
      if not ReadObject(FlashDataSel,A,64,@Buff,'') then F:=false
         else if Buff[0]=#$FF then F:=false
                 else begin
                 AutoGrid.Cells[0,AutoGrid.RowCount-1]:=StrPas(Buff);
                 AutoGrid.Cells[1,AutoGrid.RowCount-1]:=IntToHex(Ord(Buff[59]),2);
                 Move(Buff[60],B,4);
                 AutoGrid.Cells[2,AutoGrid.RowCount-1]:=IntToHex(B,8);
                 if Ord(Buff[58])=0 then AutoGrid.Cells[3,AutoGrid.RowCount-1]:='No'
                                    else AutoGrid.Cells[3,AutoGrid.RowCount-1]:='Yes';
                 A:=A+64;
                 F:=A<>4096;
                 AutoGrid.RowCount:=AutoGrid.RowCount+1;
                 AutoGrid.Cells[0,AutoGrid.RowCount-1]:='';
                 AutoGrid.Cells[1,AutoGrid.RowCount-1]:='';
                 AutoGrid.Cells[2,AutoGrid.RowCount-1]:='';
                 AutoGrid.Cells[3,AutoGrid.RowCount-1]:='';
                 end;
      end;
if AutoGrid.RowCount>2 then AutoGrid.RowCount:=AutoGrid.RowCount-1;
// modify flag
AutoGrid.Tag:=0;
end;

procedure TAutoForm.FormResize(Sender: TObject);
begin
OkBtn.Left:=Width-OkBtn.Width-CancelBtn.Width-15;
CancelBtn.Left:=Width-CancelBtn.Width-10;
AutoGrid.ColWidths[0]:=AutoGrid.Width-9-AutoGrid.Canvas.TextWidth('CPUWWWWWWWWWWW');
AutoGrid.ColWidths[1]:=AutoGrid.Canvas.TextWidth('CPU')+4;
AutoGrid.ColWidths[2]:=AutoGrid.Canvas.TextWidth('WWWWWWWW');
AutoGrid.ColWidths[3]:=AutoGrid.Canvas.TextWidth('WWW');
AutoGrid.DefaultRowHeight:=AutoGrid.Canvas.TextHeight('|')+2;
end;

procedure TAutoForm.AutoGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   X,Y: Longint;
begin
if (Sender as TStringGrid).Cells[ACol,ARow]<>'' then
   begin
   Y:=(Rect.Bottom-Rect.Top-(Sender as TSTringGrid).Canvas.TextHeight('W')) div 2;
   X:=(Rect.Right-Rect.Left-(Sender as TSTringGrid).Canvas.TextWidth((Sender as TSTringGrid).Cells[ACol,ARow])) div 2;
   (Sender as TSTringGrid).Canvas.TextRect(Rect,X+Rect.Left,Y+Rect.Top,(Sender as TSTringGrid).Cells[ACol,ARow]);
   end;
end;

// check the up and down keys
procedure TAutoForm.AutoGridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if Key=VK_Up then
   if (Length(AutoGrid.Cells[0,AutoGrid.RowCount-1])=0)and(Length(AutoGrid.Cells[1,AutoGrid.RowCount-1])=0)and(Length(AutoGrid.Cells[2,AutoGrid.RowCount-1])=0) then
      if AutoGrid.RowCount>2 then AutoGrid.RowCount:=AutoGrid.RowCount-1;
if Key=VK_Down then
   if (Length(AutoGrid.Cells[0,AutoGrid.RowCount-1])<>0)and(Length(AutoGrid.Cells[1,AutoGrid.RowCount-1])<>0)and(Length(AutoGrid.Cells[2,AutoGrid.RowCount-1])<>0) then
      if AutoGrid.RowCount<63 then AutoGrid.RowCount:=AutoGrid.RowCount+1;
end;

// if table modified
procedure TAutoForm.AutoGridSetEditText(Sender: TObject; ACol,
  ARow: Integer; const Value: String);
begin
AutoGrid.Tag:=1;
end;

// OK btn click
procedure TAutoForm.OkBtnClick(Sender: TObject);
var
   A,B,C: Longint;
   Buff: array [0..4095] of Char;
   Bf: array [0..63] of Char;
   Bb: Byte;
begin
if AutoGrid.Tag<>0 then
   if Application.MessageBox('Do You want to erase old and write new autorun block ?','Need a confirmation',mb_YesNo)=IDYes then
      begin
      Screen.Cursor:=crHourGlass;
      FillChar(Buff,4096,255);
      A:=64;
      for B:=1 to AutoGrid.RowCount-1 do
          if (Length(AutoGrid.Cells[0,B])<>0)and(Length(AutoGrid.Cells[0,B])<57) then
             begin
             StrPCopy(Bf,AutoGrid.Cells[0,B]);
             Move(Bf[0],Buff[A],Length(AutoGrid.Cells[0,B])+1);
             if Length(AutoGrid.Cells[1,B])=0 then Buff[A+59]:=#0
                                              else Buff[A+59]:=Chr(HexToInt(AutoGrid.Cells[1,B]));
             if Length(AutoGrid.Cells[2,B])=0 then C:=0
                                              else C:=HexToInt(AutoGrid.Cells[2,B]);
             if CompareStr('Yes',AutoGrid.Cells[3,B])=0 then Buff[A+58]:=Chr($0FF)
                                                        else Buff[A+58]:=#0;

             Move(C,Buff[A+60],4);
             A:=A+64;
             end;
      // erase block 0
      Bf[0]:=#6;
      WriteObject(FlashWBSel,0,1,@Bf,'');
      Bf[0]:=#1;
      Bf[1]:=#0;
      WriteObject(FlashCtrlSel,0,2,@Bf,'');
      C:=$20;
      Move(c,Bf[0],4);
      WriteObject(FlashWBSel,0,4,@Bf,'');
      Bf[0]:=#4;
      Bf[1]:=#0;
      WriteObject(FlashCtrlSel,0,2,@Bf,'');
      Sleep(500);
      Bf[0]:=#2;
      Bf[1]:=#0;
      Bf[3]:=#0;
      Bf[4]:=#4;
      Bf[5]:=#1;
      Bf[6]:=#0;
      Bf[7]:=#6;
      for A:=0 to 15 do
          begin
          Bb:=255;
          Bf[2]:=Chr(A);
          for B:=0 to 255 do Bb:=Bb and Ord(Buff[B+A*256]);
          if Bb=255 then Break
             else
             // enable write operation
             if not WriteObject(FlashWBSel,0,1,@Bf[7],'') then Break
                else if not WriteObject(FlashCtrlSel,0,2,@Bf[5],'') then Break
                     // write 256 byte page
                     else if not WriteObject(FlashWBSel,0,4,@Bf,'') then Break
                          else if not WriteObject(FlashWBSel,4,256,@Buff[A*256],'') then Break
                               else if not WriteObject(FlashCtrlSel,0,2,@Bf[4],'') then Break
                                    else Sleep(50);
          end;
      Screen.Cursor:=crDefault;
      end;
end;

procedure TAutoForm.AutoGridSelectCell(Sender: TObject; ACol,
  ARow: Integer; var CanSelect: Boolean);
begin
if ACol=3 then AutoGrid.Options:=AutoGrid.Options-[goEditing]
          else AutoGrid.Options:=AutoGrid.Options + [goEditing];
end;

procedure TAutoForm.AutoGridDblClick(Sender: TObject);
begin
if AutoGrid.Selection.Left=3 then
   if CompareStr('Yes',AutoGrid.Cells[3,AutoGrid.Selection.Top])=0 then AutoGrid.Cells[3,AutoGrid.Selection.Top]:='No'
                                                                   else AutoGrid.Cells[3,AutoGrid.Selection.Top]:='Yes';
end;

end.
