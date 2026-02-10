unit PMon;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Grids, IniFiles, Variables, StdCtrls, Main, ExtDlgs,
  Menus;

type
  TPMonForm = class(TForm)
    PMonGrid: TStringGrid;
    Splitter1: TSplitter;
    PMonTimer: TTimer;
    Comb: TComboBox;
    Panel1: TPanel;
    ImgPopup: TPopupMenu;
    Savetofile1: TMenuItem;
    SavePicDlg: TSavePictureDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure PMonGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure PMonTimerTimer(Sender: TObject);
    procedure PMonGridDblClick(Sender: TObject);
    procedure PMonGridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure CombExit(Sender: TObject);
    procedure PMonGridSetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: String);
    procedure GraphDblClick(Sender: TObject);
    procedure UpdateParams;
    procedure Savetofile1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  PMonForm: TPMonForm;

  StayOnTopFlag: Boolean;
  RefreshInt: Integer;

  ProcSwitchMask, ChangedFlag: array [0..255] of Boolean;
  Accumulation, ProcSel, CodeSels, MaxPerf, AveragePerf, MinPerf, BuffPtr: array [0..255] of Longint;
  StateMask, YScale: array [0..255] of Byte;
  MaxBuffer, AverageBuffer, MinBuffer: array [0..255,0..255] of Longint;
  Img: array [0..255] of TImage;
  CoreList: array [0..255] of Byte;

implementation

uses ComCtrls;

{$R *.dfm}

// PMon create at the start
procedure TPMonForm.FormCreate(Sender: TObject);
var
   A: Longint;
   INI: TIniFile;
begin
for A:=0 to 255 do Img[A]:=nil;
for A:=0 to 255 do BuffPtr[A]:=0;
INI:=TiniFile.Create(extractfilepath(paramstr(0))+'CoreExplorer.ini');
if INI<>nil then
   begin
   StayOnTopFlag:=INI.ReadBool('Performance monitor','StayOnTop',false);
   RefreshInt:=INI.ReadInteger('Performance monitor','Refresh',1);
   // read individual parameters
   for A:=1 to 255 do
       begin
       Accumulation[A]:=INI.ReadInteger('Performance monitor','Accumulation '+IntToStr(A),10000);
       ProcSwitchMask[A]:=INI.ReadBool('Performance monitor','Process switch time '+IntToStr(A),false);
       StateMask[A]:=INI.ReadInteger('Performance monitor','State mask '+IntToStr(A),0);
       ProcSel[A]:=INI.ReadInteger('Performance monitor','Process selector '+IntToStr(A),0);
       CodeSels[A]:=INI.ReadInteger('Performance monitor','Code selector '+IntToStr(A),0);
       end;
   INI.Free;
   end;
PMonGrid.Cells[0,0]:='Stay on top';
PMonGrid.Cells[0,1]:='Refresh interval';
end;

// close monitor
procedure TPMonForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
   A: Longint;
   INI: TIniFile;
begin
PMonTimer.Enabled:=false;
PME:=false;
INI:=TIniFile.Create(extractfilepath(paramstr(0))+'CoreExplorer.ini');
if INI<>nil then
   begin
   INI.WriteBool('Performance monitor','StayOnTop',StayOnTopFlag);
   INI.WriteInteger('Performance monitor','Refresh',RefreshInt);
   // write individual parameters
   for A:=1 to 255 do
       begin
       INI.WriteInteger('Performance monitor','Accumulation '+IntToStr(A),Accumulation[A]);
       INI.WriteBool('Performance monitor','Process switch time '+IntToStr(A),ProcSwitchMask[A]);
       INI.WriteInteger('Performance monitor','State mask '+IntToStr(A),StateMask[A]);
       INI.WriteInteger('Performance monitor','Process selector '+IntToStr(A),ProcSel[A]);
       INI.WriteInteger('Performance monitor','Code selector '+IntToStr(A),CodeSels[A]);
       end;
   INI.Free;
   end;
for A:=0 to 255 do
    if Img[A]<>nil then
       begin
       Panel1.RemoveControl(Img[A]);
       Img[A].Destroy;
       Img[A]:=nil;
       end;
end;

// show again
procedure TPMonForm.FormShow(Sender: TObject);
var
   A,B,C,D: Longint;
   Rect: TRect;
begin
B:=0;
for A:=0 to MainForm.Tree.Items.Count-1 do
    if MainForm.Tree.Items[A].Parent=nil then
       begin
       CoreList[B]:=MainForm.Tree.Items[A].StateIndex;
       Inc(B);
       end;
PMonGrid.RowCount:=2+9*B;
A:=0;
for D:=0 to MainForm.Tree.Items.Count-1 do
    if MainForm.Tree.Items[D].Parent=nil then
       begin
       PMonGrid.Cells[0,2+9*A]:='Core';
       PMonGrid.Cells[1,2+9*A]:=IntToHex(MainForm.Tree.Items[D].StateIndex,2);
       B:=MainForm.Tree.Items[D].StateIndex;
       ChangedFlag[B]:=true;
       PMonGrid.Cells[0,3+9*A]:='Accumulation time, µs';
       PMonGrid.Cells[1,3+9*A]:=FloatToStrF(Accumulation[B]/100,ffGeneral,4,4);
       PMonGrid.Cells[0,4+9*A]:='Including proc. switching time';
       if ProcSwitchMask[B] then PMonGrid.Cells[1,4+9*A]:='Yes'
                            else PMonGrid.Cells[1,4+9*A]:='No';
       PMonGrid.Cells[0,5+9*A]:='Performance only for state';
       case StateMask[B] of
            0: PMonGrid.Cells[1,5+9*A]:='Ever';
            1: PMonGrid.Cells[1,5+9*A]:='Sleep state';
            2: PMonGrid.Cells[1,5+9*A]:='Exception';
            3: PMonGrid.Cells[1,5+9*A]:='Interrupt';
            4: PMonGrid.Cells[1,5+9*A]:='System messages';
            5: PMonGrid.Cells[1,5+9*A]:='Regular messages';
            end;
       PMonGrid.Cells[0,6+9*A]:='Process selector';
       PMonGrid.Cells[1,6+9*A]:=IntToHex(ProcSel[B],6);
       PMonGrid.Cells[0,7+9*A]:='Code selector';
       PMonGrid.Cells[1,7+9*A]:=IntToHex(CodeSels[B],6);
       PMonGrid.Cells[0,8+9*A]:='Max. performance';
       PMonGrid.Cells[1,8+9*A]:='0';
       PMonGrid.Cells[0,9+9*A]:='Average performance';
       PMonGrid.Cells[1,9+9*A]:='0';
       PMonGrid.Cells[0,10+9*A]:='Min. performance';
       PMonGrid.Cells[1,10+9*A]:='0';
       // creating graphics
       Img[B]:=TImage.Create(Panel1);
       Img[B].OnDblClick:=GraphDblClick;
       Img[B].PopupMenu:=ImgPopup;
       Img[B].Top:=A*10+10;
       Img[B].Left:=10;
       Img[B].Stretch:=true;
       Img[B].Center:=true;
       Img[B].Height:=10;
       YScale[B]:=4;
       Img[B].Picture.Bitmap.Width:=1280;
       Img[B].Picture.Bitmap.Height:=20+YScale[B]*100;
       Img[B].Canvas.Brush.Color:=$00606060;
       Rect.Left:=0; Rect.Top:=0; Rect.Right:=1280; Rect.Bottom:=420;
       Img[B].Canvas.FillRect(Rect);
       Img[B].Canvas.Pen.Color:=$FFFFFF;
       Img[B].Canvas.Pen.Width:=2;
       Img[B].Canvas.MoveTo(0,1);
       Img[B].Canvas.LineTo(1280,1);
       Img[B].Canvas.MoveTo(0,418);
       Img[B].Canvas.LineTo(1280,418);
       Img[B].Canvas.Pen.Color:=$808080;
       Img[B].Canvas.Pen.Width:=1;
       // output core number
       Img[B].Canvas.Font.Name:=PMonGrid.Font.Name;
       Img[B].Canvas.Font.Size:=8;
       Img[B].Canvas.Font.Color:=clWhite;
       Img[B].Canvas.TextOut(5,5,'Core '+IntToHex(B,2));
       for C:=0 to YScale[B] do
           begin
           Img[B].Canvas.MoveTo(0,10+C*100);
           Img[B].Canvas.LineTo(1280,10+C*100);
           end;
       Panel1.InsertControl(Img[B]);
       Img[B].Align:=alTop;
       BuffPtr[B]:=0;
       Inc(A);
       end;
// setting timer interval
PMonTimer.Interval:=200*(RefreshInt+1);
UpdateParams;
PMonTimer.Enabled:=true;
FormResize(Sender);
end;


procedure TPMonForm.UpdateParams;
var
   A,B,C: Longint;
   Buff: array [0..2] of Longword;
   Rect: TRect;
   F: Boolean;
begin
F:=False;
for A:=0 to MainForm.Tree.Items.Count-1 do
    if MainForm.Tree.Items[A].Parent=nil then
       begin
       B:=MainForm.Tree.Items[A].StateIndex;
       if ChangedFlag[B] then
          begin
          F:=True;
          Buff[0]:=CodeSels[B];
          Buff[1]:=ProcSel[B];
          Buff[2]:=Accumulation[B] or (StateMask[B] shl 28);
          if ProcSwitchMask[B] then Buff[2]:=Buff[2] or $80000000;
          if A<>0 then WriteObject(3,$70,12,@Buff,'@'+IntToHex(B,2))
                  else WriteObject(3,$70,12,@Buff,'');
          if ProcSwitchMask[B] then PMonGrid.Cells[1,4+9*A]:='Yes'
                               else PMonGrid.Cells[1,4+9*A]:='No';
          PMonGrid.Refresh;
          ChangedFlag[B]:=false;
          end;
       end;
if F then for A:=0 to MainForm.Tree.Items.Count-1 do
   if MainForm.Tree.Items[A].Parent=nil then
      begin
      B:=MainForm.Tree.Items[A].StateIndex;
      // refresh images
      Img[B].Canvas.Brush.Color:=$00606060;
      Rect.Left:=0; Rect.Top:=0; Rect.Right:=1280; Rect.Bottom:=420;
      Img[B].Canvas.FillRect(Rect);
      Img[B].Canvas.Pen.Color:=$FFFFFF;
      Img[B].Canvas.Pen.Width:=2;
      Img[B].Canvas.MoveTo(0,1);
      Img[B].Canvas.LineTo(1280,1);
      Img[B].Canvas.MoveTo(0,418);
      Img[B].Canvas.LineTo(1280,418);
      Img[B].Canvas.Pen.Color:=$808080;
      Img[B].Canvas.Pen.Width:=1;
      for C:=0 to YScale[B] do
          begin
          Img[B].Canvas.MoveTo(0,10+C*100);
          Img[B].Canvas.LineTo(1280,10+C*100);
          end;
      BuffPtr[B]:=0;
      end;
end;


// refresh grid
procedure TPMonForm.FormResize(Sender: TObject);
var
   A,B: Longint;
begin
B:=0;
for A:=0 to 255 do if Img[A]<>nil then Inc(B);
for A:=0 to 255 do
    if Img[A]<>nil then Img[A].Height:=Panel1.Height div B;
if StayOnTopFlag then PMonGrid.Cells[1,0]:='Yes'
                 else PMonGrid.Cells[1,0]:='No';
PMonGrid.Cells[1,1]:=FloatToStrf(0.2*(RefreshInt+1),ffGeneral,3,3)+'s';
PMonGrid.DefaultRowHeight:=PMonGrid.Canvas.TextHeight('W!|')+2;
Comb.Height:=PMonGrid.DefaultRowHeight;
PMonGrid.ColWidths[0]:=PMonGrid.Canvas.TextWidth('Include proc. switching time')+10;
B:=0;
for A:=0 to PMonGrid.RowCount-1 do
    if B<PMonGrid.Canvas.TextWidth(PMonGrid.Cells[1,A]) then B:=PMonGrid.Canvas.TextWidth(PMonGrid.Cells[1,A]);
PMonGrid.ColWidths[1]:=B+20;
PMonGrid.Refresh;
end;

// drawing grid
procedure TPMonForm.PMonGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   X,Y: Longint;
begin
if Frac((ARow-2)/9)=0 then PMonGrid.Canvas.Font.Style:=[fsBold]
                      else PMonGrid.Canvas.Font.Style:=[];
if (ACol<>0)or(Frac((ARow-2)/9)=0) then
   begin
   PMonGrid.Canvas.Font.Color:=clWindowText;
   if (Frac((ARow-8)/9.0)=0) and (ARow>3) then PMonGrid.Canvas.Font.Color:=$00003FFF;
   if (Frac((ARow-9)/9.0)=0) and (ARow>3) then PMonGrid.Canvas.Font.Color:=$001FFF3F;
   if (Frac((ARow-10)/9.0)=0) and (ARow>3) then PMonGrid.Canvas.Font.Color:=$00FF7F00;
   Y:=(Rect.Bottom-Rect.Top-PMonGrid.Canvas.TextHeight('W|')) div 2;
   X:=(Rect.Right-Rect.Left-PMonGrid.Canvas.TextWidth(PMonGrid.Cells[ACol,ARow])) div 2;
   PMonGrid.Canvas.TextRect(Rect,X+Rect.Left,Y+Rect.Top,PMonGrid.Cells[ACol,ARow]);
   end;
end;

// reading performance results
procedure TPMonForm.PMonTimerTimer(Sender: TObject);
var
   Buff: array [0..3] of Longword;
   A,B,C,D: Longint;
   S: String;
begin
if StayOnTopFlag then PMonForm.FormStyle:=fsStayOnTop
                 else PMonForm.FormStyle:=fsNormal;
D:=0;
if PME then
for B:=0 to MainForm.Tree.Items.Count-1 do
    if MainForm.Tree.Items[B].Parent=nil then
    begin
    // read state from processor
    C:=MainForm.Tree.Items[B].StateIndex;
    S:='';
    if B<>0 then S:='@'+IntToHex(C,2);
    if ReadPerformance(@Buff,S) then
       begin
       Img[C].Canvas.Pen.Mode:=pmXOR;
       Img[C].Canvas.Pen.Width:=2;
       if BuffPtr[C]=256 then
          begin
          // if graph must be shifted
          Img[C].Canvas.Pen.Color:=$001f3FFF xor $00404040;
          Img[C].Canvas.MoveTo(0,10+YScale[C]*100-Round(MaxBuffer[C][0]*100/Accumulation[C]));
          for A:=1 to 255 do Img[C].Canvas.LineTo(A*5,10+YScale[C]*100-Round(MaxBuffer[C][A]*100/Accumulation[C]));
          Img[C].Canvas.Pen.Color:=$001FFF3F xor $00404040;
          Img[C].Canvas.MoveTo(0,10+YScale[C]*100-Round(AverageBuffer[C][0]*100/Accumulation[C]));
          for A:=1 to 255 do Img[C].Canvas.LineTo(A*5,10+YScale[C]*100-Round(AverageBuffer[C][A]*100/Accumulation[C]));
          Img[C].Canvas.Pen.Color:=$00FF7F00 xor $00404040;
          Img[C].Canvas.MoveTo(0,10+YScale[C]*100-Round(MinBuffer[C][0]*100/Accumulation[C]));
          for A:=1 to 255 do Img[C].Canvas.LineTo(A*5,10+YScale[C]*100-Round(MinBuffer[C][A]*100/Accumulation[C]));
          Dec(BuffPtr[C]);
          for A:=0 to 254 do
              begin
              MaxBuffer[C][A]:=MaxBuffer[C][A+1];
              AVerageBuffer[C][A]:=AverageBuffer[C][A+1];
              MinBuffer[C][A]:=MinBuffer[C][A+1];
              end;
          Img[C].Canvas.Pen.Color:=$001f3FFF xor $00404040;
          Img[C].Canvas.MoveTo(0,10+YScale[C]*100-Round(MaxBuffer[C][0]*100/Accumulation[C]));
          for A:=1 to 254 do Img[C].Canvas.LineTo(A*5,10+YScale[C]*100-Round(MaxBuffer[C][A]*100/Accumulation[C]));
          Img[C].Canvas.Pen.Color:=$001FFF3F xor $00404040;
          Img[C].Canvas.MoveTo(0,10+YScale[C]*100-Round(AverageBuffer[C][0]*100/Accumulation[C]));
          for A:=1 to 254 do Img[C].Canvas.LineTo(A*5,10+YScale[C]*100-Round(AverageBuffer[C][A]*100/Accumulation[C]));
          Img[C].Canvas.Pen.Color:=$00FF7F00 xor $00404040;
          Img[C].Canvas.MoveTo(0,10+YScale[C]*100-Round(MinBuffer[C][0]*100/Accumulation[C]));
          for A:=1 to 254 do Img[C].Canvas.LineTo(A*5,10+YScale[C]*100-Round(MinBuffer[C][A]*100/Accumulation[C]));
          end;
       AveragePerf[C]:=Buff[0];
       MinPerf[C]:=Buff[2];
       MaxPerf[C]:=Buff[3];
       MaxBuffer[C][BuffPtr[C]]:=MaxPerf[C];
       MinBuffer[C][BuffPtr[C]]:=MinPerf[C];
       AverageBuffer[C][BuffPtr[C]]:=AveragePerf[C];
       if BuffPtr[C]<>0 then
          begin
          // draw last line segment
          Img[C].Canvas.Pen.Color:=$001f3FFF xor $00404040;
          Img[C].Canvas.MoveTo((BuffPtr[C]-1)*5,10+YScale[C]*100-Round(MaxBuffer[C][BuffPtr[C]-1]*100/Accumulation[C]));
          Img[C].Canvas.LineTo((BuffPtr[C])*5,10+YScale[C]*100-Round(MaxBuffer[C][BuffPtr[C]]*100/Accumulation[C]));
          Img[C].Canvas.Pen.Color:=$001FFF3F xor $00404040;
          Img[C].Canvas.MoveTo((BuffPtr[C]-1)*5,10+YScale[C]*100-Round(AverageBuffer[C][BuffPtr[C]-1]*100/Accumulation[C]));
          Img[C].Canvas.LineTo((BuffPtr[C])*5,10+YScale[C]*100-Round(AverageBuffer[C][BuffPtr[C]]*100/Accumulation[C]));
          Img[C].Canvas.Pen.Color:=$00FF7F00 xor $00404040;
          Img[C].Canvas.MoveTo((BuffPtr[C]-1)*5,10+YScale[C]*100-Round(MinBuffer[C][BuffPtr[C]-1]*100/Accumulation[C]));
          Img[C].Canvas.LineTo((BuffPtr[C])*5,10+YScale[C]*100-Round(MinBuffer[C][BuffPtr[C]]*100/Accumulation[C]));
          end;
       PMonGrid.Cells[1,8+D*9]:=FloatToStrF(MaxPerf[C]/Accumulation[C],ffGeneral,5,5);
       PMonGrid.Cells[1,9+D*9]:=FloatToStrF(AveragePerf[C]/Accumulation[C],ffGeneral,5,5);
       PMonGrid.Cells[1,10+D*9]:=FloatToStrF(MinPerf[C]/Accumulation[C],ffGeneral,5,5);
       Inc(BuffPtr[C]);
       end;
    Inc(D);
    end;
PMonGrid.Refresh;
end;

// change boolean values
procedure TPMonForm.PMonGridDblClick(Sender: TObject);
var
   A: Integer;
begin
if (PMonGrid.Selection.Top=0) then
   begin
   StayOnTopFlag:=not StayOnTopFlag;
   if StayOnTopFlag then PMonForm.FormStyle:=fsStayOnTop
                    else PMonForm.FormStyle:=fsNormal;
   FormResize(Sender);
   end;
if Frac((PMonGrid.Selection.Top-4)/9)=0 then
   begin
   A:=Round(Int((PMonGrid.Selection.Top-4)/9));
   A:=HexToInt(PMonGrid.Cells[1,2+A*9]);
   ProcSwitchMask[A]:= not ProcSwitchMask[A];
   ChangedFlag[A]:=true;
   UpdateParams;
   end;
end;

// edit grid
procedure TPMonForm.PMonGridSelectCell(Sender: TObject; ACol,
  ARow: Integer; var CanSelect: Boolean);
var
   A: Longint;
begin
Comb.Visible:=false;
if PMonGrid.Tag<>0 then
   begin
   ChangedFlag[PMonGrid.Tag]:=true;
   UpdateParams;
   PMonGrid.Tag:=0;
   end;
if (ARow>2) and ((Frac((ARow-3)/9)=0) or (Frac((ARow-6)/9)=0) or (Frac((ARow-7)/9)=0)) then PMonGrid.Options:=PMonGrid.Options+[goEditing, goAlwaysShowEditor]
                                                                                       else PMonGrid.Options:=PMonGrid.Options-[goEditing, goAlwaysShowEditor];
if (ARow=1) then
   begin
   Comb.Items.Clear;
   Comb.Items.Text:='0.2s'+Chr(13)+Chr(10)+'0.4s'+Chr(13)+Chr(10)+'0.6s'+Chr(13)+Chr(10)+'0.8s'+Chr(13)+Chr(10)+'1.0s'+Chr(13)+Chr(10)+
                    '1.2s'+Chr(13)+Chr(10)+'1.4s'+Chr(13)+Chr(10)+'1.6s'+Chr(13)+Chr(10)+'1.8s'+Chr(13)+Chr(10)+'2.0s';
   Comb.Left:=PMonGrid.ColWidths[0]+2;
   Comb.Top:=PMonGrid.DefaultRowHeight+1;
   Comb.Width:=PMonGrid.ColWidths[1];
   Comb.Tag:=1;
   Comb.ItemIndex:=RefreshInt;
   Comb.Visible:=true;
   end;
if (ARow>3) and (Frac((ARow-5)/9)=0) then
   begin
   Comb.Items.Clear;
   Comb.Items.Text:='Ever'+Chr(13)+Chr(10)+'Sleep state'+Chr(13)+Chr(10)+'Exception'+Chr(13)+Chr(10)+'Interrupt'+Chr(13)+Chr(10)+
                    'System messages'+Chr(13)+Chr(10)+'Regular messages';
   Comb.Left:=PMonGrid.ColWidths[0]+2;
   Comb.Top:=(PMonGrid.DefaultRowHeight+1)*ARow;
   Comb.Width:=PMonGrid.ColWidths[1];
   Comb.Tag:=ARow;
   A:=Round(Int((ARow-5)/9));
   A:=CoreList[A];
   Comb.ItemIndex:=StateMask[A];
   Comb.Visible:=true;
   end;
end;

// exit from combo
procedure TPMonForm.CombExit(Sender: TObject);
var
   A: Longint;
begin
if (Comb.Tag=1)
   then begin
        RefreshInt:=Comb.ItemIndex;
        PMonTimer.Interval:=200*(RefreshInt+1);
        PMonGrid.Cells[1,1]:=Comb.Items.Strings[Comb.ItemIndex];
        PMonGrid.Refresh;
        end
   else begin
        A:=Round(Int((Comb.Tag-5)/9));
        A:=CoreList[A];
        StateMask[A]:=Comb.ItemIndex;
        ChangedFlag[A]:=true;
        PMonGrid.Cells[1,Comb.Tag]:=Comb.Items.Strings[Comb.ItemIndex];
        PMonGrid.Refresh;
        UpdateParams;
        end;
if Comb.Tag<>0 then PMonGrid.Cells[1,Comb.Tag]:=Comb.Items.Strings[Comb.ItemIndex];
Comb.Tag:=0;
end;

// end of editing parameters
procedure TPMonForm.PMonGridSetEditText(Sender: TObject; ACol,
  ARow: Integer; const Value: String);
var
   A,B: Longint;
begin
if (ARow>2) and (Length(Value)<>0) then
begin
if Frac((ARow-3)/9)=0 then
   begin
   A:=Round(Int((ARow-3)/9));
   A:=CoreList[A];
   B:=Round(StrToFloat(PMonGrid.Cells[ACol,ARow])/0.01);
   if B<>0 then Accumulation[A]:=B;
   PMonGrid.Tag:=A;
   end;
if Frac((ARow-6)/9)=0 then
   begin
   A:=Round(Int((ARow-6)/9));
   A:=CoreList[A];
   ProcSel[A]:=HexToInt(PMonGrid.Cells[ACol,ARow]);
   PMonGrid.Tag:=A;
   end;
if Frac((ARow-7)/9)=0 then
   begin
   A:=Round(Int((ARow-7)/9));
   A:=CoreList[A];
   CodeSels[A]:=HexToInt(PMonGrid.Cells[ACol,ARow]);
   PMonGrid.Tag:=A;
   end;
end;
end;

// Start-stop pmon
procedure TPMonForm.GraphDblClick(Sender: TObject);
begin
PMonTimer.Enabled:=not PMonTimer.Enabled;
if PMonTimer.Enabled then Caption:='Performance monitor'
                     else Caption:='Performance monitor /stopped/';
end;

procedure TPMonForm.Savetofile1Click(Sender: TObject);
var
   B,C: Longint;
begin
if SavePicDlg.Execute then
   for B:=0 to 255 do
       if CoreList[B]=0 then Break
       else begin
       C:=CoreList[B];
       Img[C].Picture.SaveToFile(SavePicDlg.FileName+IntToStr(C));
       end;
end;

end.
