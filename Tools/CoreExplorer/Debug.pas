unit Debug;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, Grids, ExtCtrls, Variables, Menus;

type
  TDebugForm = class(TForm)
    DebugTab: TTabControl;
    CodeGrid: TStringGrid;
    Panel1: TPanel;
    GPRGrid: TStringGrid;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    CSRGrid: TStringGrid;
    ADRGrid: TStringGrid;
    CodePopMenu: TPopupMenu;
    RunItem: TMenuItem;
    StepItem: TMenuItem;
    RTCItem: TMenuItem;
    BKPTItem: TMenuItem;
    CloseItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure GPRGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure FormActivate(Sender: TObject);
    procedure ADRGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure DebugTabChange(Sender: TObject);
    procedure RefreshPSO;
    procedure RefreshCode;
    procedure CSRGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure CodeGridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure CodeGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure ShowPSO(Indx: Integer);
    procedure BKPTItemClick(Sender: TObject);
    procedure CloseItemClick(Sender: TObject);
    procedure RunItemClick(Sender: TObject);
    procedure StepItemClick(Sender: TObject);
    procedure RTCItemClick(Sender: TObject);
    function GetBreakpointIndex(Indx: Integer): Integer;
    procedure CloseAll;
    procedure SetGPRGrid(Mode: Integer);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  DebugForm: TDebugForm;

  NextBuffer: Integer;

implementation

uses Types, Main;

{$R *.dfm}

{
    Creating window at the application startup
}
procedure TDebugForm.FormCreate(Sender: TObject);
var
   A: Longint;
begin
NextBuffer:=0;
DebugTab.Tag:=0;
for A:=0 to 31 do CodeList[A]:=TStringList.Create;
DebugIndex:=-1;
for A:=0 to 31 do PSOSelector[A]:=-1;
DMode:=false;

CodeGrid.Cells[0,0]:='Offset';
CodeGrid.Cells[1,0]:='Code';
CodeGrid.Cells[2,0]:='Instruction';
CodeGrid.ColWidths[0]:=CodeGrid.Canvas.TextWidth('WWWWWWWW');
CodeGrid.ColWidths[1]:=CodeGrid.ColWidths[0];
CodeGrid.ColWidths[2]:=CodeGrid.Width-CodeGrid.ColWidths[0]-CodeGrid.ColWidths[1]-10;
CodeGrid.DefaultRowHeight:=CodeGrid.Canvas.TextHeight('W')+4;

ADRGrid.Cells[0,0]:='Address pair';
ADRGrid.Cells[1,0]:='Selector';
ADRGrid.Cells[2,0]:='Offset';
for A:=1 to 8 do ADRGrid.Cells[0,A]:='MAR'+IntToStr(A-1)+' (ADR'+IntToStr(1+(A-1)*2)+':ADR'+IntToStr((A-1)*2)+')';
ADRGrid.ColWidths[0]:=ADRGrid.Canvas.TextWidth('WWWW (WWWW:WWWW)');
ADRGrid.ColWidths[1]:=ADRGrid.Canvas.TextWidth('XXXXXXXX')+10;
ADRGrid.ColWidths[2]:=ADRGrid.Canvas.TextWidth('XXXXXXXXXX')+10;
ADRGrid.DefaultRowHeight:=ADRGrid.Canvas.TextHeight('W')+4;
ADRGrid.Height:=(ADRGrid.DefaultRowHeight+1)*9+3;


CSRGrid.Cells[0,0]:='Process state';
CSRGrid.ColWidths[0]:=CSRGrid.Canvas.TextWidth('Process state')+10;
CSRGrid.Cells[1,0]:='Messages';
CSRGrid.ColWidths[1]:=CSRGrid.Canvas.TextWidth('Messages')+10;
CSRGrid.Cells[2,0]:='Proc. switching';
CSRGrid.ColWidths[2]:=CSRGrid.Canvas.TextWidth('Proc. switching')+10;
CSRGrid.Cells[3,0]:='Interrupts';
CSRGrid.ColWidths[3]:=CSRGrid.Canvas.TextWidth('Interrupts')+10;
CSRGrid.Cells[4,0]:='Sys. errors';
CSRGrid.ColWidths[4]:=CSRGrid.Canvas.TextWidth('Sys. errors')+10;
CSRGrid.Cells[5,0]:='CPL';
CSRGrid.ColWidths[5]:=CSRGrid.Canvas.TextWidth('CPL')+10;
CSRGrid.Cells[6,0]:='Task ID';
CSRGrid.ColWidths[6]:=CSRGrid.Canvas.TextWidth('Task ID')+10;
CSRGrid.DefaultRowHeight:=CSRGrid.Canvas.TextHeight('A')+4;
CSRGrid.Height:=(CSRGrid.DefaultRowHeight+1)*2+3;

DTab:=DebugTab;

end;

// Draw GPR grid
procedure TDebugForm.GPRGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   X,Y: Longint;
begin
GPRGrid.Canvas.Font.Color:=clBlack;
if (ACol*ARow)>0 then
   if ((ARow and 1)<>0) then GPRGrid.Canvas.Brush.Color:=$F0F0F0
                        else GPRGrid.Canvas.Brush.Color:=$E0E0E0;
X:=((Rect.Right-Rect.Left)-GPRGrid.Canvas.TextWidth(GPRGrid.Cells[ACol,ARow])) div 2;
Y:=((Rect.Bottom-Rect.Top)-GPRGrid.Canvas.TextHeight('W')) div 2;
GPRGrid.Canvas.TextRect(Rect,Rect.Left+X,Rect.Top+Y,GPRGrid.Cells[ACol,ARow]);
end;

{
    Activation new debug session
}
procedure TDebugForm.FormActivate(Sender: TObject);
var
   A, Sel, Offs, Indx: Longint;
   Inst: LongWord;
   B: Byte;
   F: Boolean;
   Buff: array [0..15] of Byte;
begin
DMode:=true;
if Tag<>0 then
   if DebugTab.Tabs.Count<32 then
begin
if DebugTab.Tabs.Count>0 then
   begin
   // store current code grid context
   B:=DebugTab.Tag;
   CodeList[B].Clear;
   for A:=1 to CodeGrid.RowCount-1 do CodeList[B].Add(CodeGrid.Cells[0,A]+'|'+CodeGrid.Cells[1,A]+'|'+CodeGrid.Cells[2,A]);
   end;
F:=false;
if DebugTab.Tabs.Count=0 then DebugTab.Tabs.Add(IntToHex(Tag,8))
   else begin
   // checkin for present tab
   for A:=0 to DebugTab.Tabs.Count-1 do
       if HexToInt(DebugTab.Tabs.Strings[A])=Tag then
          begin
          F:=true;
          DebugTab.TabIndex:=A;
          Break;
          end;
   if not F then
      begin
      DebugTab.Tabs.Add(IntToHex(Tag,8));
      DebugTab.TabIndex:=DebugTab.Tabs.Count-1;
      end;
   end;
Indx:=DebugTab.TabIndex;
if not F then
   begin
   // create prefix
   A:=Tag;
   if (A and $FF000000)=0 then VPref[Indx]:=''
                          else VPref[Indx]:='@'+IntToHex(A shr 24,2);

   // get the PSO Selector from the process object
   ReadObject(Tag and $FFFFFF,$048,4,@Buff,VPref[Indx]);
   PSOSelector[Indx]:=Buff[2]*65536 + Buff[1]*256 + Buff[0];
   end;
RefreshPSO;
RefreshCode;
// set the stop point and run the process
if not F then
   begin
   // read stopped instruction
   BreakFlags[Indx]:=1;                           // only one breakpoint for first start
   if CodeModes[Indx]=0
      then begin
           Sel:=PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568];
           Offs:=PSO16Buffer[Indx,11]*16777216 + PSO16Buffer[Indx,10]*65536 + PSO16Buffer[Indx,9]*256 + PSO16Buffer[Indx,8];
           if ReadObject(Sel,Offs,4,@BreakInst[Indx,0],VPref[Indx]) then
              begin
              BreakOffset[Indx,0]:=Offs;
              Inst:=$005C;
              if WriteBlocked(Sel,Offs,2,@Inst,VPref[Indx]) then RunProcess(Tag);
              end;
           end
      else begin
           Sel:=PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952];
           Offs:=PSO32Buffer[Indx,11]*16777216 + PSO32Buffer[Indx,10]*65536 + PSO32Buffer[Indx,9]*256 + PSO32Buffer[Indx,8];
           if ReadObject(Sel,Offs,4,@BreakInst[Indx,0],VPref[Indx]) then
              begin
              BreakOffset[Indx,0]:=Offs;
              Inst:=$0CC;
              if WriteBlocked(Sel,Offs,4,@Inst,VPref[Indx]) then RunProcess(Tag);
              end;
           end;
   end;
DebugTab.Tag:=DebugTab.TabIndex;
end;
Tag:=0;
DebugIndex:=DebugTab.TabIndex;
end;

// draw address registers grid
procedure TDebugForm.ADRGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   X,Y: Longint;
begin
ADRGrid.Canvas.Font.Color:=clBlack;
if (ACol*ARow)>0 then
   if ((ARow and 1)<>0) then ADRGrid.Canvas.Brush.Color:=$F0F0F0
                        else ADRGrid.Canvas.Brush.Color:=$E0E0E0;
X:=((Rect.Right-Rect.Left)-ADRGrid.Canvas.TextWidth(ADRGrid.Cells[ACol,ARow])) div 2;
Y:=((Rect.Bottom-Rect.Top)-ADRGrid.Canvas.TextHeight('W')) div 2;
ADRGrid.Canvas.TextRect(Rect,Rect.Left+X,Rect.Top+Y,ADRGrid.Cells[ACol,ARow]);
end;

{
change process
}
procedure TDebugForm.DebugTabChange(Sender: TObject);
var
   A,B: Longint;
   S: String;
   Rect: TGridRect;
begin
if Sender=nil
   then begin
        RefreshPSO;
        //RefreshCode;
        B:=DebugTab.Tag;
        Rect:=CodeGrid.Selection;
        for A:=1 to CodeGrid.RowCount-1 do
            if HexToInt(CodeGrid.Cells[0,A])=BreakOffset[B,ActiveBkpt] then Rect.Top:=A;
        Rect.Bottom:=Rect.Top;
        CodeGrid.Selection:=Rect;
        CodeGrid.Refresh;
        end
   else begin
        // store code table context
        B:=DebugTab.Tag;
        if B>=0 then
           begin
           CodeList[B].Clear;
           for A:=1 to CodeGrid.RowCount-1 do CodeList[B].Add(CodeGrid.Cells[0,A]+'|'+CodeGrid.Cells[1,A]+'|'+CodeGrid.Cells[2,A]);
           end;
        B:=DebugTab.TabIndex;
        if B>=0 then
           begin
           CodeGrid.RowCount:=CodeList[B].Count+1;
           for A:=0 to CodeList[B].Count-1 do
               begin
               S:=CodeList[B].Strings[A];
               CodeGrid.Cells[0,A+1]:=Copy(S,1,Pos('|',S)-1);
               Delete(S,1,Pos('|',S));
               CodeGrid.Cells[1,A+1]:=Copy(S,1,Pos('|',S)-1);
               Delete(S,1,Pos('|',S));
               CodeGrid.Cells[2,A+1]:=S;
               end;
           ShowPSO(B);
           end;
        DebugTab.Tag:=B;
        DebugIndex:=DebugTab.TabIndex;
        end;
end;

{
procedure for refresh PSO
}
procedure TDebugForm.RefreshPSO;
var
   B, Indx: Longint;
   Buff: array [0..15] of Byte;
begin
Indx:=DebugTab.TabIndex;
// read pointer to the context
if ReadObject(PSOSelector[Indx],$34,12,@Buff,VPref[Indx]) then
   begin
   B:=(Buff[3]*16777216 + Buff[2]*65536 + Buff[1]*256 + Buff[0])+(Buff[11]*16777216 + Buff[10]*65536 + Buff[9]*256 + Buff[8])+8;
   ReadObject(PSOSelector[Indx],B,4,@Buff,VPref[Indx]);
   CodeModes[Indx]:=Buff[3] and $F8;
   if CodeModes[Indx]=0
      then begin
           ReadObject(PSOSelector[Indx],B,256,@PSO16Buffer[Indx,0],VPref[Indx]);
           ReadObject(PSOSelector[Indx],B+256,256,@PSO16Buffer[Indx,256],VPref[Indx]);
           ReadObject(PSOSelector[Indx],B+512,80,@PSO16Buffer[Indx,512],VPref[Indx]);
           end
      else begin
           ReadObject(PSOSelector[Indx],B,256,@PSO32Buffer[Indx,0],VPref[Indx]);
           ReadObject(PSOSelector[Indx],B+256,256,@PSO32Buffer[Indx,256],VPref[Indx]);
           ReadObject(PSOSelector[Indx],B+512,256,@PSO32Buffer[Indx,512],VPref[Indx]);
           ReadObject(PSOSelector[Indx],B+768,208,@PSO32Buffer[Indx,768],VPref[Indx]);
           end;
   end;
ShowPSO(Indx);
end;

{
Total refresh code buffer
}
procedure TDebugForm.RefreshCode;
var
   A,B,C,D,E,CodeEnd,Indx: Longint;
   Buff: array [0..255] of Byte;
   S,T: String;
begin
Indx:=DebugTab.TabIndex;
// calculate code object limit
if CodeModes[Indx]=0 then C:=(PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568])*32 // code selector as offset to the DT
                     else C:=(PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952])*32;
ReadObject(11,C+8,16,@Buff,VPref[Indx]);
while (Buff[3] or Buff[2] or Buff[1] or Buff[0])<>0 do
      begin
      C:=(Buff[2]*65536 + Buff[1]*256 + Buff[0])*32;
      ReadObject(11,C+8,16,@Buff,VPref[Indx]);
      end;
B:=Buff[15]*16777216 + Buff[14]*65536 + Buff[13]*256 + Buff[12];
while (Buff[7] or Buff[6] or Buff[5] or Buff[4])<>0 do
      begin
      C:=(Buff[6]*65536 + Buff[5]*256 + Buff[4])*32;
      ReadObject(11,C+8,16,@Buff,VPref[Indx]);
      B:=B+((Buff[15]*16777216 + Buff[14]*65536 + Buff[13]*256 + Buff[12])-(Buff[11]*16777216 + Buff[10]*65536 + Buff[9]*256 + Buff[8]));
      end;
CodeLimit[Indx]:=B*32;
if CodeModes[Indx]=0 then B:=(PSO16Buffer[Indx,11]*16777216 + PSO16Buffer[Indx,10]*65536 + PSO16Buffer[Indx,9]*256 + PSO16Buffer[Indx,8]) and $FFFFFFE0
                     else B:=(PSO32Buffer[Indx,11]*16777216 + PSO32Buffer[Indx,10]*65536 + PSO32Buffer[Indx,9]*256 + PSO32Buffer[Indx,8]) and $FFFFFFE0;
CodeEnd:=B;
if (B+256)>CodeLimit[Indx] then C:=CodeLimit[Indx]-B
                           else C:=256;
if CodeModes[Indx]=0 then A:=PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568]        // code selector
                     else A:=PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952];
if ReadObject(A,B,C,@Buff,VPref[Indx]) then CodeEnd:=B+C;
// output code to the grid
A:=B;
CodeGrid.RowCount:=1;
D:=0;
while A<CodeEnd do
      begin
      for E:=0 to 31 do
          if (A=BreakOffset[Indx,E])and(BreakFlags[Indx] and (1 shl E)<>0) then Move(BreakInst[Indx,E],Buff[D],4);
      Disassm(@Buff[D],CodeEnd,CodeModes[Indx] shr 3,C,S);
      CodeGrid.RowCount:=CodeGrid.RowCount+1;
      CodeGrid.Cells[0,CodeGrid.RowCount-1]:=IntToHex(A,8);
      T:='';
      for E:=0 to C-1 do T:=T+IntToHex(Buff[D+C-E-1],2);
      CodeGrid.Cells[1,CodeGrid.RowCount-1]:=T;
      if Pos(';',S)=0 then CodeGrid.Cells[2,CodeGrid.RowCount-1]:=S
                      else CodeGrid.Cells[2,CodeGrid.RowCount-1]:=Copy(S,1,Pos(';',S)-1);
      A:=A+C;
      D:=D+C;
      end;
CodeGrid.FixedRows:=1;
end;

{
    Draw CSR Grid
}
procedure TDebugForm.CSRGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   X,Y: Longint;
begin
X:=((Rect.Right-Rect.Left)-CSRGrid.Canvas.TextWidth(CSRGrid.Cells[ACol,ARow])) div 2;
Y:=((Rect.Bottom-Rect.Top)-CSRGrid.Canvas.TextHeight('W')) div 2;
CSRGrid.Canvas.TextRect(Rect,Rect.Left+X,Rect.Top+Y,CSRGrid.Cells[ACol,ARow]);
end;

{
Scroll up or down
}
procedure TDebugForm.CodeGridSelectCell(Sender: TObject; ACol,
  ARow: Integer; var CanSelect: Boolean);
var
   A,B,C,D,E,Indx: Longint;
   SList: TStringList;
   S,T: String;
   Buff: array [0..31] of Byte;
begin
B:=HexToInt(CodeGrid.Cells[0,ARow]);
Indx:=DebugTab.TabIndex;
if Indx>=0 then
begin
if (ARow=1) and (B<>0) then
   begin
   // reading upper 32 bytes
   if CodeModes[Indx]=0 then A:=PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568] // code selector
                        else A:=PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952];
   B:=B-32;                                                                      // new offset
   ReadObject(A,B,32,@Buff,VPref[Indx]);
   // convert readed 32 bytes to the code
   SList:=TStringList.Create;
   A:=0;
   while A<32 do
         begin
         for D:=0 to 31 do
             if ((A+B)=BreakOffset[Indx,D])and((BreakFlags[Indx] and (1 shl D))<>0) then
                if CodeModes[Indx]=0 then Move(BreakInst[Indx,D],Buff[A],2)
                                     else Move(BreakInst[Indx,D],Buff[A],4);
         Disassm(@Buff[A],32,CodeModes[Indx] shr 3,D,S);
         T:='';
         for C:=0 to D-1 do T:=T+IntToHex(Buff[A+D-C-1],2);
         if Pos(';',S)=0 then SList.Add(IntToHex(B+A,8)+'|'+T+'|'+S+'|')
            else begin
                 T:=IntToHex(B+A,8)+'|'+T+'|'+Copy(S,1,Pos(';',S)-1)+'|';
                 Delete(S,1,Pos(';',S));
                 SList.Add(T+S);
                 end;
         A:=A+D;
         end;
   B:=CodeGrid.RowCount-1;                                               // Old number of strings in the grid
   CodeGrid.RowCount:=CodeGrid.RowCount+SList.Count;
   for A:=1 to B do
       begin
       CodeGrid.Cells[0,CodeGrid.RowCount-A]:=CodeGrid.Cells[0,CodeGrid.RowCount-A-SList.Count];
       CodeGrid.Cells[1,CodeGrid.RowCount-A]:=CodeGrid.Cells[1,CodeGrid.RowCount-A-SList.Count];
       CodeGrid.Cells[2,CodeGrid.RowCount-A]:=CodeGrid.Cells[2,CodeGrid.RowCount-A-SList.Count];
       end;
   for A:=1 to SList.Count do
       begin
       S:=SList.Strings[A-1];
       CodeGrid.Cells[0,A]:=Copy(S,1,Pos('|',S)-1);
       Delete(S,1,Pos('|',S));
       CodeGrid.Cells[1,A]:=Copy(S,1,Pos('|',S)-1);
       Delete(S,1,Pos('|',S));
       CodeGrid.Cells[2,A]:=S;
       end;
   SList.Destroy;
   if CodeGrid.RowCount>257 then CodeGrid.RowCount:=257;
   end;
if (ARow=(CodeGrid.RowCount-1))and(CodeGrid.RowCount>1) then
   begin
   // try to read next 32 bytes
   if CodeModes[Indx]=0 then A:=PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568] // code selector
                        else A:=PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952];
   B:=B+(Length(CodeGrid.Cells[1,ARow])shr 1);
   if (B+32)>CodeLimit[Indx] then C:=CodeLimit[Indx]-B
                             else C:=32;
   if C>0 then
   begin
   ReadObject(A,B,C,@Buff,VPref[Indx]);
   // convert readed 32 bytes to the code
   SList:=TStringList.Create;
   A:=0;
   while A<C do
         begin
         for D:=0 to 31 do
             if ((A+B)=BreakOffset[Indx,D])and((BreakFlags[Indx] and (1 shl D))<>0) then
                if CodeModes[Indx]=0 then Move(BreakInst[Indx,D],Buff[A],2)
                                     else Move(BreakInst[Indx,D],Buff[A],4);
         Disassm(@Buff[A],C,CodeModes[Indx] shr 3,D,S);
         T:='';
         for E:=0 to D-1 do T:=T+IntToHex(Buff[A+D-E-1],2);
         if Pos(';',S)=0 then SList.Add(IntToHex(B+A,8)+'|'+T+'|'+S+'|')
            else begin
                 T:=IntToHex(B+A,8)+'|'+T+'|'+Copy(S,1,Pos(';',S)-1)+'|';
                 Delete(S,1,Pos(';',S));
                 SList.Add(T+S);
                 end;
         A:=A+D;
         end;
   if CodeGrid.RowCount<257 then B:=CodeGrid.RowCount
                            else B:=CodeGrid.RowCount-SList.Count;
   if CodeGrid.RowCount<257 then CodeGrid.RowCount:=CodeGrid.RowCount+SList.Count
      else for A:=1 to CodeGrid.RowCount-SList.Count-1 do
               begin
               CodeGrid.Cells[0,A]:=CodeGrid.Cells[0,A+SList.Count];
               CodeGrid.Cells[1,A]:=CodeGrid.Cells[1,A+SList.Count];
               CodeGrid.Cells[2,A]:=CodeGrid.Cells[2,A+SList.Count];
               end;
   for A:=0 to SList.Count-1 do
       begin
       S:=SList.Strings[A];
       CodeGrid.Cells[0,A+B]:=Copy(S,1,Pos('|',S)-1);
       Delete(S,1,Pos('|',S));
       CodeGrid.Cells[1,A+B]:=Copy(S,1,Pos('|',S)-1);
       Delete(S,1,Pos('|',S));
       CodeGrid.Cells[2,A+B]:=S;
       end;
   SList.Destroy;
   end;
   end;
end;
end;

{
Checking color change
}
procedure TDebugForm.CodeGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   A,B, Indx: Longint;
begin
CodeGrid.Canvas.Font.Color:=clBlack;
if ARow<>0 then
   begin
   Indx:=DebugTab.TabIndex;
   CodeGrid.Canvas.Brush.Color:=clWindow;
   for B:=0 to 31 do
       if (((BreakFlags[Indx] shr B)and 1)<>0) and (HexToInt(CodeGrid.Cells[0,ARow])=BreakOffset[Indx,B]) then CodeGrid.Canvas.Brush.Color:=$E0E0FF;
   if CodeModes[Indx]=0 then A:=PSO16Buffer[Indx,11]*16777216 + PSO16Buffer[Indx,10]*65536 + PSO16Buffer[Indx,9]*256 + PSO16Buffer[Indx,8]
                        else A:=PSO32Buffer[Indx,11]*16777216 + PSO32Buffer[Indx,10]*65536 + PSO32Buffer[Indx,9]*256 + PSO32Buffer[Indx,8];
   if HexToInt(CodeGrid.Cells[0,ARow])=A then CodeGrid.Canvas.Brush.Color:=$FFE0E0;
   end;
A:=(CodeGrid.DefaultRowHeight-CodeGrid.Canvas.TextHeight('W')) shr 1;
Indx:=(CodeGrid.ColWidths[ACol]-CodeGrid.Canvas.TextWidth(CodeGrid.Cells[ACol,ARow])) shr 1;
if (ACol=2) and (ARow<>0) then CodeGrid.Canvas.TextRect(Rect,Rect.Left+4,Rect.Top+A,CodeGrid.Cells[ACol,ARow])
                          else CodeGrid.Canvas.TextRect(Rect,Rect.Left+Indx,Rect.Top+A,CodeGrid.Cells[ACol,ARow]);
end;

{
    Display selected PSO into tables
}
procedure TDebugForm.ShowPSO(Indx: Integer);
var
   A,B: Longint;
   S: String;
begin
if CodeModes[Indx]=0
   then begin
        //      output GPR & AFR
        if GPRGrid.RowCount<>17 then SetGPRGrid(0);
        for A:=0 to 15 do
            begin
            S:='';
            for B:=0 to 7 do S:=S+IntToHex(PSO16Buffer[Indx,208+(7-B)+A*8],2);
            for B:=0 to 7 do S:=S+IntToHex(PSO16Buffer[Indx,80+(7-B)+A*8],2);
            GPRGrid.Cells[1,1+A]:=S;
            // operand size
            case ((PSO16Buffer[Indx,336+3+A*8] and 1) shl 2) or (PSO16Buffer[Indx,336+2+A*8] shr 6) of
                 0: GPRGrid.Cells[2,1+A]:='Byte';
                 1: GPRGrid.Cells[2,1+A]:='Word';
                 2: GPRGrid.Cells[2,1+A]:='DWord';
                 3: GPRGrid.Cells[2,1+A]:='QWord';
                 4: GPRGrid.Cells[2,1+A]:='OWord';
                 5: GPRGrid.Cells[2,1+A]:='OWord';
                 6: GPRGrid.Cells[2,1+A]:='OWord';
                 7: GPRGrid.Cells[2,1+A]:='No data';
                 end;
            // address mode
            case ((PSO16Buffer[Indx,336+3+A*8] shr 1) and 7) of
                 0: GPRGrid.Cells[3,1+A]:='[AR]';
                 1: GPRGrid.Cells[3,1+A]:='[AR]+R';
                 2: GPRGrid.Cells[3,1+A]:='[R]';
                 3: GPRGrid.Cells[3,1+A]:='[AR+R]';
                 4: GPRGrid.Cells[3,1+A]:='[AR]+os';
                 5: GPRGrid.Cells[3,1+A]:='[AR]-os';
                 6: GPRGrid.Cells[3,1+A]:='[AR+R]+os';
                 7: GPRGrid.Cells[3,1+A]:='[AR+R]-os';
                 end;
            // LI counters
            GPRGrid.Cells[4,1+A]:=IntToStr(PSO16Buffer[Indx,336+3+A*8] shr 4);
            // flags
            GPRGrid.Cells[5,1+A]:=IntToStr((PSO16Buffer[Indx,336+2+A*8] shr 5) and 1);
            GPRGrid.Cells[6,1+A]:=IntToStr((PSO16Buffer[Indx,336+2+A*8] shr 4) and 1);
            GPRGrid.Cells[7,1+A]:=IntToStr((PSO16Buffer[Indx,336+2+A*8] shr 3) and 1);
            GPRGrid.Cells[8,1+A]:=IntToStr((PSO16Buffer[Indx,336+2+A*8] shr 2) and 1);
            GPRGrid.Cells[9,1+A]:=IntToStr((PSO16Buffer[Indx,336+2+A*8] shr 1) and 1);
            GPRGrid.Cells[10,1+A]:=IntToStr(PSO16Buffer[Indx,336+2+A*8] and 1);
            GPRGrid.Cells[11,1+A]:=IntToStr((PSO16Buffer[Indx,336+1+A*8] shr 7) and 1);
            GPRGrid.Cells[12,1+A]:=IntToHex(PSO16Buffer[Indx,336+1+A*8],2)+IntToHex(PSO16Buffer[Indx,336+A*8],2);
            end;
        // ADR's
        for A:=0 to 6 do
            begin
            ADRGrid.Cells[1,1+A]:=IntToHex(PSO16Buffer[Indx,464+8+3+A*16],2)+IntToHex(PSO16Buffer[Indx,464+8+2+A*16],2)+IntToHex(PSO16Buffer[Indx,464+8+1+A*16],2)+IntToHex(PSO16Buffer[Indx,464+8+A*16],2);
            ADRGrid.Cells[2,1+A]:=IntToHex(PSO16Buffer[Indx,464+4+A*16],2)+IntToHex(PSO16Buffer[Indx,464+3+A*16],2)+IntToHex(PSO16Buffer[Indx,464+2+A*16],2)+IntToHex(PSO16Buffer[Indx,464+1+A*16],2)+IntToHex(PSO16Buffer[Indx,464+A*16],2);
            end;
        A:=(PSO16Buffer[Indx,2] shr 2) and 3;
        ADRGrid.Cells[1,8]:=IntToHex(PSO16Buffer[Indx,16+8+3+A*16],2)+IntToHex(PSO16Buffer[Indx,16+8+2+A*16],2)+IntToHex(PSO16Buffer[Indx,16+8+1+A*16],2)+IntToHex(PSO16Buffer[Indx,16+8+A*16],2);
        ADRGrid.Cells[2,8]:=IntToHex(PSO16Buffer[Indx,16+4+A*16],2)+IntToHex(PSO16Buffer[Indx,16+3+A*16],2)+IntToHex(PSO16Buffer[Indx,16+2+A*16],2)+IntToHex(PSO16Buffer[Indx,16+1+A*16],2)+IntToHex(PSO16Buffer[Indx,16+A*16],2);
        // CSR status
        case (PSO16Buffer[Indx,3] and 7) of
             0: CSRGrid.Cells[0,1]:='Main code';
             1: CSRGrid.Cells[0,1]:='Sleep state';
             2: CSRGrid.Cells[0,1]:='Error proc.';
             3: CSRGrid.Cells[0,1]:='Interrupt';
             4: CSRGrid.Cells[0,1]:='Sys. message';
             5: CSRGrid.Cells[0,1]:='Reg. message';
             6,7: CSRGrid.Cells[0,1]:='';
             end;
        if (PSO16Buffer[Indx,2] and $80)<>0 then CSRGrid.Cells[1,1]:='Enabled'
                                            else CSRGrid.Cells[1,1]:='Disabled';
        if (PSO16Buffer[Indx,2] and $40)<>0 then CSRGrid.Cells[2,1]:='Enabled'
                                            else CSRGrid.Cells[2,1]:='Disabled';
        if (PSO16Buffer[Indx,2] and $20)<>0 then CSRGrid.Cells[3,1]:='Enabled'
                                            else CSRGrid.Cells[3,1]:='Disabled';
        if (PSO16Buffer[Indx,2] and $10)<>0 then CSRGrid.Cells[4,1]:='Enabled'
                                            else CSRGrid.Cells[4,1]:='Disabled';
        CSRGrid.Cells[5,1]:=IntToStr(A);
        CSRGrid.Cells[6,1]:=IntToHex(PSO16Buffer[Indx,1],2)+IntToHex(PSO16Buffer[Indx,0],2);
        end
   else begin
        //      output GPR & AFR
        if GPRGrid.RowCount<>33 then SetGPRGrid(1);
        for A:=0 to 31 do
            begin
            S:='';
            for B:=0 to 7 do S:=S+IntToHex(PSO32Buffer[Indx,336+(7-B)+A*8],2);
            for B:=0 to 7 do S:=S+IntToHex(PSO32Buffer[Indx,80+(7-B)+A*8],2);
            GPRGrid.Cells[1,1+A]:=S;
            // flags
            GPRGrid.Cells[2,1+A]:=IntToStr((PSO32Buffer[Indx,592+2+A*8] shr 5) and 1);
            GPRGrid.Cells[3,1+A]:=IntToStr((PSO32Buffer[Indx,592+2+A*8] shr 4) and 1);
            GPRGrid.Cells[4,1+A]:=IntToStr((PSO32Buffer[Indx,592+2+A*8] shr 3) and 1);
            GPRGrid.Cells[5,1+A]:=IntToStr((PSO32Buffer[Indx,592+2+A*8] shr 2) and 1);
            GPRGrid.Cells[6,1+A]:=IntToStr((PSO32Buffer[Indx,592+2+A*8] shr 1) and 1);
            GPRGrid.Cells[7,1+A]:=IntToStr(PSO32Buffer[Indx,592+2+A*8] and 1);
            GPRGrid.Cells[8,1+A]:=IntToStr((PSO32Buffer[Indx,592+1+A*8] shr 7) and 1);
            GPRGrid.Cells[9,1+A]:=IntToHex(PSO32Buffer[Indx,592+1+A*8],2)+IntToHex(PSO32Buffer[Indx,592+A*8],2);
            end;
        // ADR's
        for A:=0 to 6 do
            begin
            ADRGrid.Cells[1,1+A]:=IntToHex(PSO32Buffer[Indx,848+8+3+A*16],2)+IntToHex(PSO32Buffer[Indx,848+8+2+A*16],2)+IntToHex(PSO32Buffer[Indx,848+8+1+A*16],2)+IntToHex(PSO32Buffer[Indx,848+8+A*16],2);
            ADRGrid.Cells[2,1+A]:=IntToHex(PSO32Buffer[Indx,848+4+A*16],2)+IntToHex(PSO32Buffer[Indx,848+3+A*16],2)+IntToHex(PSO32Buffer[Indx,848+2+A*16],2)+IntToHex(PSO32Buffer[Indx,848+1+A*16],2)+IntToHex(PSO32Buffer[Indx,848+A*16],2);
            end;
        A:=(PSO32Buffer[Indx,2] shr 2) and 3;
        ADRGrid.Cells[1,8]:=IntToHex(PSO32Buffer[Indx,16+8+3+A*16],2)+IntToHex(PSO32Buffer[Indx,16+8+2+A*16],2)+IntToHex(PSO32Buffer[Indx,16+8+1+A*16],2)+IntToHex(PSO32Buffer[Indx,16+8+A*16],2);
        ADRGrid.Cells[2,8]:=IntToHex(PSO32Buffer[Indx,16+4+A*16],2)+IntToHex(PSO32Buffer[Indx,16+3+A*16],2)+IntToHex(PSO32Buffer[Indx,16+2+A*16],2)+IntToHex(PSO32Buffer[Indx,16+1+A*16],2)+IntToHex(PSO32Buffer[Indx,16+A*16],2);
        // CSR status
        case (PSO32Buffer[Indx,3] and 7) of
             0: CSRGrid.Cells[0,1]:='Main code';
             1: CSRGrid.Cells[0,1]:='Sleep state';
             2: CSRGrid.Cells[0,1]:='Error proc.';
             3: CSRGrid.Cells[0,1]:='Interrupt';
             4: CSRGrid.Cells[0,1]:='Sys. message';
             5: CSRGrid.Cells[0,1]:='Reg. message';
             6,7: CSRGrid.Cells[0,1]:='';
             end;
        if (PSO32Buffer[Indx,2] and $80)<>0 then CSRGrid.Cells[1,1]:='Enabled'
                                            else CSRGrid.Cells[1,1]:='Disabled';
        if (PSO32Buffer[Indx,2] and $40)<>0 then CSRGrid.Cells[2,1]:='Enabled'
                                            else CSRGrid.Cells[2,1]:='Disabled';
        if (PSO32Buffer[Indx,2] and $20)<>0 then CSRGrid.Cells[3,1]:='Enabled'
                                            else CSRGrid.Cells[3,1]:='Disabled';
        if (PSO32Buffer[Indx,2] and $10)<>0 then CSRGrid.Cells[4,1]:='Enabled'
                                            else CSRGrid.Cells[4,1]:='Disabled';
        CSRGrid.Cells[5,1]:=IntToStr(A);
        CSRGrid.Cells[6,1]:=IntToHex(PSO32Buffer[Indx,1],2)+IntToHex(PSO32Buffer[Indx,0],2);
        end;
end;

{
      Set or reset breakpoint
}
procedure TDebugForm.BKPTItemClick(Sender: TObject);
var
   A,B,C,Indx: Integer;
   F: Boolean;
   Inst: LongWord;
begin
Indx:=DebugTab.TabIndex;
if Indx>=0 then
begin
// check
F:=false;
B:=HexToInt(CodeGrid.Cells[0,CodeGrid.Selection.Top]);                          // code offset
if CodeModes[Indx]=0 then C:=PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568] // code selector
                     else C:=PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952];
for A:=0 to 31 do
    if ((BreakFlags[Indx] shr A)and 1)<>0 then
       if BreakOffset[Indx,A]=B then
          begin
          F:=true;
          Break;
          end;
if not F
   then begin
        // set breakpoint
        for A:=0 to 31 do
            if (BreakFlags[Indx] and (1 shl A))=0 then
               begin
               // if empty entry found set the breakpoint
               BreakOffset[Indx,A]:=B;
               BreakFlags[Indx]:=BreakFlags[Indx] or (1 shl A);
               ReadObject(C,B,4,@BreakInst[Indx,A],VPref[Indx]);
               if CodeModes[Indx]=0
                  then begin
                       // set breakpoint
                       Inst:=$2FF0;
                       WriteBlocked(C,B,2,@Inst,VPref[Indx]);
                       end
                  else begin
                       // set breakpoint
                       Inst:=$CC;
                       WriteBlocked(C,B,4,@Inst,VPref[Indx]);
                       end;
               Break;
               end;
        end
   else begin
        // reset breakpoint
        BreakFlags[Indx]:=BreakFlags[Indx] and (not (1 shl A));
        if CodeModes[Indx]=0 then WriteBlocked(C,B,2,@BreakInst[Indx,A],VPref[Indx])
                             else WriteBlocked(C,B,4,@BreakInst[Indx,A],VPref[Indx]);
        end;
CodeGrid.Repaint;
end;
end;

{
    Terminate debug session
}
procedure TDebugForm.CloseItemClick(Sender: TObject);
var
   A,B, CSel, Indx: Longint;
begin
Indx:=DebugTab.TabIndex;
if Indx>=0 then
begin
if CodeModes[Indx]=0 then CSel:=PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568]
                     else CSel:=PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952];
// stop the process
StopProcess(HexToInt(DebugTab.Tabs.Strings[Indx]));
// reset all breakpoints
for B:=0 to 31 do
    if (BreakFlags[Indx] and (1 shl B))<>0 then
       if CodeModes[Indx]=0 then WriteObject(CSel,BreakOffset[Indx,B],2,@BreakInst[Indx,B],VPref[Indx])
                            else WriteObject(CSel,BreakOffset[Indx,B],4,@BreakInst[Indx,B],VPref[Indx]);
A:=Indx;
if DebugTab.TabIndex<>(DebugTab.Tabs.Count-1) then
   while A<>(DebugTab.Tabs.Count-1) do
         begin
         for B:=0 to 31 do
             begin
             BreakOffset[A,B]:=BreakOffset[A+1,B];
             BreakInst[A,B]:=BreakInst[A+1,B];
             end;
         BreakFlags[A]:=BreakFlags[A+1];
         CodeLimit[A]:=CodeLimit[A+1];
         Move(PSO16Buffer[A+1,0],PSO16Buffer[A,0],592);
         Move(PSO32Buffer[A+1,0],PSO32Buffer[A,0],976);
         PSOSelector[A]:=PSOSelector[A+1];
         CodeList[A].Clear;
         for B:=0 to CodeList[A+1].Count-1 do CodeList[A].Add(CodeList[A+1].Strings[B]);
         Inc(A);
         end;
DebugTab.Tabs.Delete(DebugTab.TabIndex);
DebugTab.Tag:=-1;
if DebugTab.Tabs.Count=0 then Close
   else begin
   DebugTab.TabIndex:=0;
   DebugTabChange(Sender);
   end;
end;
DebugIndex:=DebugTab.TabIndex;
end;

{
run process
}
procedure TDebugForm.RunItemClick(Sender: TObject);
var
   B,CSel,COff,Indx: Longint;
begin
Indx:=DebugTab.TabIndex;
if Indx>=0 then
begin
// reset current breakpoint
if CodeModes[Indx]=0
   then begin
        CSel:=PSO16Buffer[Indx,570]*65536 + PSO16Buffer[Indx,569]*256 + PSO16Buffer[Indx,568];
        COff:=PSO16Buffer[Indx,11]*16777216 + PSO16Buffer[Indx,10]*65536 + PSO16Buffer[Indx,9]*256 + PSO16Buffer[Indx,8];
        end
   else begin
        CSel:=PSO32Buffer[Indx,954]*65536 + PSO32Buffer[Indx,953]*256 + PSO32Buffer[Indx,952];
        COff:=PSO32Buffer[Indx,11]*16777216 + PSO32Buffer[Indx,10]*65536 + PSO32Buffer[Indx,9]*256 + PSO32Buffer[Indx,8];
        end;
for B:=0 to 31 do
    if ((BreakFlags[Indx] and (1 shl B))<>0) and (BreakOffset[Indx,B]=COff) then
       begin
       if CodeModes[Indx]=0 then WriteBlocked(CSel,COff,2,@BreakInst[Indx,B],VPref[Indx]) // close active breakpoint
                            else WriteBlocked(CSel,COff,4,@BreakInst[Indx,B],VPref[Indx]);
       BreakFlags[Indx]:=BreakFlags[Indx] and (not(1 shl B));
       Break;
       end;
CodeGrid.Repaint;
end;
end;

{
Perform step
}
procedure TDebugForm.StepItemClick(Sender: TObject);
var
   A,B,C,D,E,Indx,BI: Longint;
   Inst, JNear: Longword;
   //E: DWord;
   SSel,SOff: Longint;
begin
Indx:=DebugTab.TabIndex;
if Indx>=0 then
begin
// search focused breakpoint
BI:=GetBreakpointIndex(Indx);
if BI>=0 then
begin
B:=BreakOffset[Indx,BI];                                                                                     // current breakpoint
if CodeModes[Indx]<>0 then C:=B+4
   else if (BreakInst[Indx,BI] and $0FF)=$0FC then C:=B+4
                                              else C:=B+2;                                // new instruction offset
// checking instruction that must be executed
if CodeModes[Indx]=0
   // X16 code mode
   then begin
        // code selector
        D:=0;
        Move(PSO16Buffer[Indx,568],D,3);
        if ((BreakInst[Indx,BI] and 15)=2)and((BreakInst[Indx,BI] and $F000)=$1000) then
           begin
           // JCL
           A:=(BreakInst[Indx,BI] shr 4) and 15;
           E:=PSO16Buffer[Indx,336+3+A*8]*16777216 + PSO16Buffer[Indx,336+2+A*8]*65536 + PSO16Buffer[Indx,336+1+A*8]*256 + PSO16Buffer[Indx,336+A*8];
           A:=(BreakInst[Indx,BI] shr 8) and 15;
           case (A and 7) of
                0: E:=((E shr 16) and 1) xor (A shr 3);          // ZF
                1: E:=((E shr 15) and 1) xor (A shr 3);          // CF15
                2: E:=((E shr 17) and 1) xor (A shr 3);          // SF
                3: E:=((E shr 18) and 1) xor (A shr 3);          // OF
                4: E:=((E shr 19) and 1) xor (A shr 3);          // IF
                5: E:=((E shr 20) and 1) xor (A shr 3);          // NF
                6: E:=((E shr 21) and 1) xor (A shr 3);          // DBF
                7: E:=1;
                end;
           if E<>0 then
              begin
              //      if branch condition true
              if (BreakInst[Indx,BI] and $80000000)=0 then A:=((BreakInst[Indx,BI] shr 16) and LongInt($FFFF))
                                                      else A:=(BreakInst[Indx,BI] shr 16) or Longint($FFFF0000);
              A:=A shl 1;
              C:=B+A;
              end;
           end;
        if ((BreakInst[Indx,BI] and 15)=2)and((BreakInst[Indx,BI] and $F000)<>$1000) then
           begin
           // JC
           A:=(BreakInst[Indx,BI] shr 4) and 15;
           E:=PSO16Buffer[Indx,336+3+A*8]*16777216 + PSO16Buffer[Indx,336+2+A*8]*65536 + PSO16Buffer[Indx,336+1+A*8]*256 + PSO16Buffer[Indx,336+A*8];
           A:=(BreakInst[Indx,BI] shr 8) and 15;
           case (A and 7) of
                0: E:=((E shr 16) and 1) xor (A shr 3);          // ZF
                1: E:=((E shr 15) and 1) xor (A shr 3);          // CF15
                2: E:=((E shr 17) and 1) xor (A shr 3);          // SF
                3: E:=((E shr 18) and 1) xor (A shr 3);          // OF
                4: E:=((E shr 19) and 1) xor (A shr 3);          // IF
                5: E:=((E shr 20) and 1) xor (A shr 3);          // NF
                6: E:=((E shr 21) and 1) xor (A shr 3);          // DBF
                7: E:=1;
                end;
           if E<>0 then
              begin
              //      if branch condition true
              if (BreakInst[Indx,BI] and $8000)=0 then A:=((BreakInst[Indx,BI] shr 12) and 15)
                                                  else A:=(BreakInst[Indx,BI] shr 12) or Longint($FFFFFFF0);
              A:=A shl 1;
              C:=B+A;
              end;
           end;
        // JNEAR
        if (BreakInst[Indx,BI] and 127)=$5C then
           if (BreakInst[Indx,BI] and $8000)=0 then C:=B+(((BreakInst[Indx,BI] shr 7)and 255) shl 1)
                                               else C:=B+(((BreakInst[Indx,BI] shr 7)or Longint($FFFFFF00)) shl 1);
        // LOOP
        if (BreakInst[Indx,BI] and 15)=1 then
           begin
           A:=(BreakInst[Indx,BI] shr 12) and 15;                    //GPR index
           E:=PSO16Buffer[Indx,80+3+A*8]*16777216 + PSO16Buffer[Indx,80+2+A*8]*65536 + PSO16Buffer[Indx,80+1+A*8]*256 + PSO16Buffer[Indx,80+A*8];    //GPR context
           if E>1 then C:=B+(((BreakInst[Indx,BI] shr 4) or Longint($FFFFFF00))shl 1);
           end;
        // JUMP or CALL
        if ((BreakInst[Indx,BI] and $0FFF)=$0BF0) or ((BreakInst[Indx,BI] and $0FFF)=$0CF0) then
           begin
           A:=(BreakInst[Indx,BI] shr 12) and 15;                    //GPR index
           C:=PSO16Buffer[Indx,80+3+A*8]*16777216 + PSO16Buffer[Indx,80+2+A*8]*65536 + PSO16Buffer[Indx,80+1+A*8]*256 + PSO16Buffer[Indx,80+A*8];    //GPR context
           end;
        // RET
        if (BreakInst[Indx,BI] and $FFFF)=$0FF0 then
           begin
           A:=(PSO16Buffer[Indx,2] shr 2) and 3;                                                  // reading CPL
           SSel:=PSO16Buffer[Indx,24+3+A*16]*16777216 + PSO16Buffer[Indx,24+2+A*16]*65536 + PSO16Buffer[Indx,24+1+A*16]*256 + PSO16Buffer[Indx,24+A*16];
           SOff:=PSO16Buffer[Indx,16+3+A*16]*16777216 + PSO16Buffer[Indx,16+2+A*16]*65536 + PSO16Buffer[Indx,16+1+A*16]*256 + PSO16Buffer[Indx,16+A*16];
           ReadObject(SSel,SOff,4,@C,VPref[Indx]);
           end;
        end
   // X32 code mode
   else begin
        // code selector
        D:=0;
        Move(PSO32Buffer[Indx,952],D,3);
        // JUMPR or CALLR
        if ((BreakInst[Indx,BI] and $FF)=$C2)or((BreakInst[Indx,BI] and $FF)=$C3) then
           begin
           A:=(BreakInst[Indx,BI] shr 24) and 31;                    //GPR index
           Move(PSO32Buffer[Indx,80+A*8],C,4);                       //GPR context
           end;
        // JC or JNC
        if ((BreakInst[Indx,BI] and $FF)=$C4)or((BreakInst[Indx,BI] and $FF)=$C5) then
           begin
           A:=(BreakInst[Indx,BI] shr 24) and 31;
           Move(PSO32Buffer[Indx,592+A*8],E,4);
           A:=(BreakInst[Indx,BI] shr 29) and 7;
           case (A and 7) of
                0: E:=((E shr 16) and 1) xor (BreakInst[Indx,BI] and 1);          // ZF
                1: E:=((E shr 15) and 1) xor (BreakInst[Indx,BI] and 1);          // CF
                2: E:=((E shr 17) and 1) xor (BreakInst[Indx,BI] and 1);          // SF
                3: E:=((E shr 18) and 1) xor (BreakInst[Indx,BI] and 1);          // OF
                4: E:=((E shr 19) and 1) xor (BreakInst[Indx,BI] and 1);          // IF
                5: E:=((E shr 20) and 1) xor (BreakInst[Indx,BI] and 1);          // NF
                6: E:=((E shr 21) and 1) xor (BreakInst[Indx,BI] and 1);          // DF
                7: E:=1;
                end;
           if E<>0 then
              begin
              //      if branch condition true
              if (BreakInst[Indx,BI] and $800000)=0 then A:=((BreakInst[Indx,BI] shr 8) and $FFFF)
                                                    else A:=(BreakInst[Indx,BI] shr 8) or Longint($FFFF0000);
              A:=A shl 2;
              C:=B+A;
              end;
           end;
        // LOOP
        if (BreakInst[Indx,BI] and $FF)=$C6 then
           begin
           A:=(BreakInst[Indx,BI] shr 24) and 31;                    //GPR index
           Move(PSO32Buffer[Indx,80+A*8],E,4);                       //GPR context
           if E>1 then
              if (BreakInst[Indx,BI] and $800000)=0 then C:=B+(((BreakInst[Indx,BI] shr 8) and $FFFF)shl 2)
                                                    else C:=B+(((BreakInst[Indx,BI] shr 8) or Longint($FFFF0000))shl 2);
           end;
        // RET
        if (BreakInst[Indx,BI] and $FF)=$C8 then
           begin
           A:=(PSO32Buffer[Indx,2] shr 2) and 3;                                                  // reading CPL
           Move(PSO32Buffer[Indx,24+A*16],SSel,4);
           Move(PSO32Buffer[Indx,16+A*16],Soff,4);
           ReadObject(SSel,SOff,4,@C,VPref[Indx]);
           end;
        // JUMPI/CALLI
        if (BreakInst[Indx,BI] and $FE)=$CA then
           begin
           if (BreakInst[Indx,BI] and $80000000)=0 then A:=((BreakInst[Indx,BI] shr 8) and $FFFFFF)
                                                   else A:=(BreakInst[Indx,BI] shr 8) or Longint($FF000000);
           A:=A shl 2;
           C:=B+A;
           end;
        end;

// read code from new breakpoint location
ReadObject(D,C,4,@Inst,VPref[Indx]);
if CodeModes[Indx]=0
   then begin
        // set new breakpoint
        JNear:=$2FF0;
        // if not ENDMSG instruction
        if (BreakInst[Indx,BI] and $FFFF)<>$1FF0 then WriteBlocked(D,C,2,@JNear,VPref[Indx]);
        // reset old breakpoint
        WriteBlocked(D,B,2,@BreakInst[Indx,BI],VPref[Indx]);
        end
   else begin
        // set new breakpoint
        JNear:=$CC;
        // if not ENDMSG instruction
        if (BreakInst[Indx,BI] and $FF)<>$C9 then WriteBlocked(D,C,4,@JNear,VPref[Indx]);
        // reset old breakpoint
        WriteBlocked(D,B,4,@BreakInst[Indx,BI],VPref[Indx]);
        end;
BreakInst[Indx,BI]:=Inst;
BreakOffset[Indx,BI]:=C;
ReadObject(D,B,4,@E,VPref[Indx]);
end;
end;
end;


{
 Execute Run to cursor position
}
procedure TDebugForm.RTCItemClick(Sender: TObject);
var
   B,C,D,Indx,BI: Longint;
   Inst,Bkpt: LongWord;
begin
Indx:=DebugTab.TabIndex;
if Indx>=0 then
begin
B:=HexToInt(CodeGrid.Cells[0,CodeGrid.Selection.Top]);                          // code offset
if CodeModes[Indx]=0
   then begin
        // code selector
        Move(PSO16Buffer[Indx,568],C,4);
        // set BKPT instruction on cursor location
        ReadObject(C,B,4,@Inst,VPref[Indx]);
        Bkpt:=$2FF0;
        WriteObject(C,B,2,@Bkpt,VPref[Indx]);
        // reset current code position
        BI:=GetBreakpointIndex(Indx);
        if BI>=0 then
           begin
           D:=PSO16Buffer[Indx,11]*16777216 + PSO16Buffer[Indx,10]*65536 + PSO16Buffer[Indx,9]*256 + PSO16Buffer[Indx,8];     // current code offset
           WriteBlocked(C,D,2,@BreakInst[Indx,BI],VPref[Indx]);
           BreakInst[Indx,BI]:=Inst;
           BreakOffset[Indx,BI]:=B;
           ReadObject(C,0,4,@D,VPref[Indx]);
           end;
        end
   else begin
        // code selector
        Move(PSO32Buffer[Indx,952],C,4);
        // set BKPT instruction on cursor location
        ReadObject(C,B,4,@Inst,VPref[Indx]);
        Bkpt:=$0CC;
        WriteObject(C,B,4,@Bkpt,VPref[Indx]);
        // reset current code position
        BI:=GetBreakpointIndex(Indx);
        if BI>=0 then
           begin
           Move(PSO32Buffer[Indx,8],D,4);         // current code offset
           WriteBlocked(C,D,4,@BreakInst[Indx,BI],VPref[Indx]);
           BreakInst[Indx,BI]:=Inst;
           BreakOffset[Indx,BI]:=B;
           ReadObject(C,0,4,@D,VPref[Indx]);
           end;
        end;
end;
end;

{
Search breakpoint by current code offset
}
function TDebugForm.GetBreakpointIndex(Indx: Integer): Integer;
var
   A,B: Longint;
begin
Result:=-1;
// current code offset
if CodeModes[Indx]=0 then Move(PSO16Buffer[Indx,8],B,4)
                     else Move(PSO32Buffer[Indx,8],B,4);
for A:=0 to 31 do
    if (BreakOffset[Indx,A]=B) and ((BreakFlags[Indx] and (1 shl A))<>0) then
       begin
       Result:=A;
       Break;
       end;
end;

// close all, if connection terminated
procedure TDebugForm.CloseAll;
begin
while DebugTab.Tabs.Count<>0 do
      begin
      DebugTab.TabIndex:=DebugTab.Tabs.Count-1;
      CloseItemClick(DebugTab);
      end;
Close;
end;

// Prepare GPR Grid for proper architecture
procedure TDebugForm.SetGPRGrid(Mode: Integer);
var
   A: Longint;
begin
if Mode=0
   then begin
        // for x16 architecture
        GPRGrid.RowCount:=17;
        GPRGrid.ColCount:=13;
        GPRGrid.Cells[0,0]:='Register';
        GPRGrid.Cells[1,0]:='Value';
        GPRGrid.Cells[2,0]:='Size';
        GPRGrid.Cells[3,0]:='AMODE';
        GPRGrid.Cells[4,0]:='LI';
        GPRGrid.Cells[5,0]:='DBF';
        GPRGrid.Cells[6,0]:='NF';
        GPRGrid.Cells[7,0]:='IF';
        GPRGrid.Cells[8,0]:='OF';
        GPRGrid.Cells[9,0]:='SF';
        GPRGrid.Cells[10,0]:='ZF';
        GPRGrid.Cells[11,0]:='CF';
        GPRGrid.Cells[12,0]:='CF[15:0]';

        for A:=1 to 17 do GPRGrid.Cells[0,A]:='R'+IntToStr(A-1);
        GPRGrid.DefaultRowHeight:=GPRGrid.Canvas.TextHeight('|')+4;
        GPRGrid.ColWidths[0]:=GPRGrid.Canvas.TextWidth('R15')+4;
        GPRGrid.ColWidths[1]:=GPRGrid.Canvas.TextWidth('WWWWWWWWWWWWWWWWWWWWW')+4;
        GPRGrid.ColWidths[2]:=GPRGrid.Canvas.TextWidth('DWORD')+4;
        GPRGrid.ColWidths[3]:=GPRGrid.Canvas.TextWidth('[R+AR]+os')+4;
        GPRGrid.ColWidths[4]:=GPRGrid.Canvas.TextWidth('00')+4;
        GPRGrid.ColWidths[5]:=GPRGrid.Canvas.TextWidth('DBF')+6;
        GPRGrid.ColWidths[6]:=GPRGrid.Canvas.TextWidth('NF')+6;
        GPRGrid.ColWidths[7]:=GPRGrid.ColWidths[6];
        GPRGrid.ColWidths[8]:=GPRGrid.ColWidths[6];
        GPRGrid.ColWidths[9]:=GPRGrid.ColWidths[6];
        GPRGrid.ColWidths[10]:=GPRGrid.ColWidths[6];
        GPRGrid.ColWidths[11]:=GPRGrid.ColWidths[6];
        GPRGrid.ColWidths[12]:=GPRGrid.Canvas.TextWidth(GPRGrid.Cells[12,0])+8;
        end
   else begin
        // for x32 architecture
        GPRGrid.RowCount:=33;
        GPRGrid.ColCount:=10;
        GPRGrid.Cells[0,0]:='Register';
        GPRGrid.Cells[1,0]:='Value';
        GPRGrid.Cells[2,0]:='DF';
        GPRGrid.Cells[3,0]:='NF';
        GPRGrid.Cells[4,0]:='IF';
        GPRGrid.Cells[5,0]:='OF';
        GPRGrid.Cells[6,0]:='SF';
        GPRGrid.Cells[7,0]:='ZF';
        GPRGrid.Cells[8,0]:='CF';
        GPRGrid.Cells[9,0]:='CF[15:0]';

        for A:=1 to 33 do GPRGrid.Cells[0,A]:='R'+IntToStr(A-1);
        GPRGrid.DefaultRowHeight:=GPRGrid.Canvas.TextHeight('A')+4;
        GPRGrid.ColWidths[0]:=GPRGrid.Canvas.TextWidth('R32')+4;
        GPRGrid.ColWidths[1]:=GPRGrid.Canvas.TextWidth('WWWWWWWWWWWWWWWWWWWWW')+4;
        GPRGrid.ColWidths[2]:=GPRGrid.Canvas.TextWidth('DF')+6;
        GPRGrid.ColWidths[3]:=GPRGrid.ColWidths[2];
        GPRGrid.ColWidths[4]:=GPRGrid.ColWidths[2];
        GPRGrid.ColWidths[5]:=GPRGrid.ColWidths[2];
        GPRGrid.ColWidths[6]:=GPRGrid.ColWidths[2];
        GPRGrid.ColWidths[7]:=GPRGrid.ColWidths[2];
        GPRGrid.ColWidths[8]:=GPRGrid.ColWidths[2];
        GPRGrid.ColWidths[9]:=GPRGrid.Canvas.TextWidth(GPRGrid.Cells[9,0])+8;
        end;
end;

// close debug window
procedure TDebugForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
DMode:=false;
end;

end.
