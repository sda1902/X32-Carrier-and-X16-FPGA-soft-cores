unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, Menus, ExtCtrls, StdCtrls, Variables, IniFiles, Grids,
  Async32;

type
  TMainForm = class(TForm)
    MainTimer: TTimer;
    CmdBox: TListBox;
    Splitter1: TSplitter;
    MainEdit: TMemo;
    Splitter2: TSplitter;
    Tree: TTreeView;
    Splitter3: TSplitter;
    RefTimer: TTimer;
    MainStatus: TStatusBar;
    REdit: TRichEdit;
    Grid: TStringGrid;
    EditMenu: TPopupMenu;
    Clear1: TMenuItem;
    GridMenu: TPopupMenu;
    Byte1: TMenuItem;
    Word1: TMenuItem;
    DWord1: TMenuItem;
    QWord1: TMenuItem;
    OWord1: TMenuItem;
    Radix1: TMenuItem;
    Integer321: TMenuItem;
    Integer641: TMenuItem;
    Float321: TMenuItem;
    Float641: TMenuItem;
    Viewobject1: TMenuItem;
    ViewasPSO1: TMenuItem;
    Deleteobject1: TMenuItem;
    N1: TMenuItem;
    OpnDlg: TOpenDialog;
    FilesBox: TListBox;
    FileSplitter: TSplitter;
    SaveDlg: TSaveDialog;
    FilesMenu: TPopupMenu;
    Loadtomemory1: TMenuItem;
    Delete1: TMenuItem;
    TreeMenu: TPopupMenu;
    Saveobjecttofile1: TMenuItem;
    SaveobjecttoFLASH1: TMenuItem;
    Viewobject2: TMenuItem;
    ViewasPSO2: TMenuItem;
    Deleteobject2: TMenuItem;
    N2: TMenuItem;
    Runprocess1: TMenuItem;
    Createsuspended1: TMenuItem;
    Stopprocess1: TMenuItem;
    Killprocess1: TMenuItem;
    Debugprocess1: TMenuItem;
    Passparameter1: TMenuItem;
    N3: TMenuItem;
    Refresh1: TMenuItem;
    N4: TMenuItem;
    Refresh2: TMenuItem;
    procedure CmdBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure MainTimerTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure CmdBoxDblClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Splitter1Moved(Sender: TObject);
    procedure TreeClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure TreeExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure CheckReceiver;
    procedure Clear1Click(Sender: TObject);
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure GridMenuPopup(Sender: TObject);
    procedure Byte1Click(Sender: TObject);
    procedure GridMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure GridMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure GridKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure GridDblClick(Sender: TObject);
    procedure ViewasPSO1Click(Sender: TObject);
    procedure Deleteobject1Click(Sender: TObject);
    procedure TreeCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure TreeDblClick(Sender: TObject);
    procedure RefreshDT;
    procedure RefreshTree;
    procedure RefreshFiles;
    procedure SetCC;
    procedure FilesMenuPopup(Sender: TObject);
    procedure Delete1Click(Sender: TObject);
    procedure Loadtomemory1Click(Sender: TObject);
    procedure TreeMenuPopup(Sender: TObject);
    procedure Saveobjecttofile1Click(Sender: TObject);
    procedure SaveobjecttoFLASH1Click(Sender: TObject);
    procedure Refresh1Click(Sender: TObject);
    procedure Viewobject2Click(Sender: TObject);
    procedure ViewasPSO2Click(Sender: TObject);
    procedure Deleteobject2Click(Sender: TObject);
    procedure Runprocess1Click(Sender: TObject);
    procedure Createsuspended1Click(Sender: TObject);
    procedure Stopprocess1Click(Sender: TObject);
    procedure Killprocess1Click(Sender: TObject);
    procedure Passparameter1Click(Sender: TObject);
    procedure Debugprocess1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses ISet, Sel, Uart, Obj, ProgressForm, Auto, Block, PMon, Debug, Comm;

function FT_OpenEx(pvArg1:Pointer;dwFlags:Dword;ftHandle:Pointer) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_OpenEx';
function FT_SetBaudRate(ftHandle:Dword;BaudRate:DWord) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_SetBaudRate';
function FT_SetDataCharacteristics(ftHandle:Dword;WordLength,StopBits,Parity:Byte) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_SetDataCharacteristics';
function FT_SetTimeouts(ftHandle:Dword;ReadTimeout,WriteTimeout:Dword) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_SetTimeouts';
function FT_Close(ftHandle:Dword) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_Close';
function FT_GetQueueStatus(ftHandle:Dword;RxBytes:Pointer) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_GetQueueStatus';
function FT_Read(ftHandle:Dword; FTInBuf : Pointer; BufferSize : LongInt; ResultPtr : Pointer ) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_Read';
function FT_Write(ftHandle:Dword; FTOutBuf : Pointer; BufferSize : LongInt; ResultPtr : Pointer ) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_Write';
function FT_GetModemStatus(ftHandle:Dword;ModemStatus:Pointer) : FT_Result ; stdcall ; External FT_DLL_Name name 'FT_GetModemStatus';

{$R *.dfm}

{
    Create program
}
procedure TMainForm.FormCreate(Sender: TObject);
var
   A: Longint;
   S: String;
   INI: TIniFile;
begin
ParamString:='';
MainState:=0;
REdit.Align:=alClient;
Grid.Align:=alClient;
Grid.DefaultRowHeight:=Grid.Canvas.TextHeight('|')+3;
REdit.Visible:=false;
USBDevice:='';
COMDevice:='';
//TimerTick:=0;
//PME:=true;
ISetList:=TStringList.Create;
INI:=TiniFile.Create(extractfilepath(paramstr(0))+'CoreExplorer.ini');
if INI<>nil then
   begin
   USBDevice:=Ini.ReadString('USB section','Device','');
   COMDevice:=Ini.ReadString('COM section','Device','');
   BinaryMode:=Ini.ReadBool('Transfer','RAW Data',False);
   RefreshInterval:=Ini.ReadInteger('Settings','Refresh interval',1);
   BS:=Ini.ReadInteger('Settings','Block size',256);
   Baud:=Ini.ReadInteger('Settings','Baud rate',0);

   CodeSel:=Ini.ReadInteger('Selectors','Kernel code',1);
   IOSel:=Ini.ReadInteger('Selectors','IO block',2);
   SysSel:=Ini.ReadInteger('Selectors','System registers',3);
   WholeRAMSel:=Ini.ReadInteger('Selectors','Whole RAM',4);
   StackSel:=Ini.ReadInteger('Selectors','Kernel stack',5);
   PSOSel:=Ini.ReadInteger('Selectors','System PSO',8);
   IntSel:=Ini.ReadInteger('Selectors','Interrupt table',9);
   ProcessSel:=Ini.ReadInteger('Selectors','Process table',10);
   DescriptorSel:=Ini.ReadInteger('Selectors','Descriptor table',11);
   ServiceSel:=Ini.ReadInteger('Selectors','Service selector',12);
   BreakpointSel:=Ini.ReadInteger('Selectors','Breakpoint log',14);
   ErrorSel:=Ini.ReadInteger('Selectors','Error log',15);
   FlashCtrlSel:=Ini.ReadInteger('Selectors','Flash control registers',16);
   FlashDataSel:=Ini.ReadInteger('Selectors','Flash data array',17);
   FlashWBSel:=Ini.ReadInteger('Selectors','Flash write buffer',18);

   for A:=0 to 31 do
       begin
       S:=Ini.ReadString('Instruction sets','SET'+IntToStr(A),'');
       if Length(S)=0 then Break
                      else ISetList.Add(S);
       end;

   Left:=Ini.ReadInteger('Position','Left',Left);
   Top:=Ini.ReadInteger('Position','Top',Top);
   Width:=Ini.ReadInteger('Position','Width',Width);
   Height:=Ini.ReadInteger('Position','Height',Height);
   if Ini.ReadBool('Position','Maximized',false) then WindowState:=wsMaximized
                                                 else WindowState:=wsNormal;
   Ini.Free;
   end;
// instruction set buffers
for A:=0 to 31 do IRefList[A]:=TStringList.Create;
end;

{
            Main menu draw
}
procedure TMainForm.CmdBoxDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
   A,B: Longint;
   Node: TTreeNode;
   S,T: String;
begin
CmdBox.Canvas.Font.Style:=[];
S:=CmdBox.Items[Index];
GetWord(S,T);
Delete(S,1,1);
A:=StrToIntDef(T,0);
case A of
     0:  begin
         CmdBox.Canvas.Font.Style:=[fsBold];
         B:=CmdBox.Canvas.TextWidth(S);
         if B<Rect.Right then B:=(Rect.Right-B) shr 1
                         else B:=0;
         CmdBox.Canvas.TextRect(Rect,B,Rect.Top,S);
         EFlags[A]:=false;
         end;
     1..2: begin
           EFlags[A]:=true;
           CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
           end;
     3:  begin
         EFlags[A]:=true;
         if Length(USBDevice)=0 then CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Use USB device...')
                                else CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Use USB device '+USBDevice);
         end;
     4: begin
        EFlags[A]:=true;
        CmdBox.Canvas.Font.Color:=clMedGray;
        CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
        end;
     5: begin
        EFlags[A]:=true;
        if BinaryMode then CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Binary data transfer mode: YES')
                      else CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Binary data transfer mode: NO');
        end;
     6: begin
        EFlags[A]:=true;
        CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Refresh interval: '+IntToStr(RefreshInterval)+'s.');
        end;
     7: begin
        EFlags[A]:=true;
        if AutoRefresh then CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Autorefresh: YES')
                       else CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Autorefresh: NO');
        end;
     8: begin
        EFlags[A]:=true;
        CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Data block size: '+IntToStr(BS)+' bytes');
        end;
     // load object from file
     9:  begin
         if (MainState<3)or(Tree.Selected=nil) then CmdBox.Canvas.Font.Color:=clMedGray
            else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                           else CmdBox.Canvas.Font.Color:=clBlack;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
         end;
     // save object to file and save object to the flash
     10,12:  begin
             if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
                else if (Tree.Selected.ImageIndex=102)or(Tree.Selected.ImageIndex=101)or(Tree.Selected.ImageIndex=100) then
                     begin
                     if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                               else CmdBox.Canvas.Font.Color:=clBlack;
                     end
                else if (Tree.Selected.ImageIndex<>2)or(not Grid.Visible) then CmdBox.Canvas.Font.Color:=clMedGray
                     else begin
                     if Grid.Cells[1,Grid.Selection.Top]<>'Object' then CmdBox.Canvas.Font.Color:=clMedGray
                        else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                       else CmdBox.Canvas.Font.Color:=clBlack;
                     end;
             EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
             CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
             end;
     // save memory block
     11: begin
         if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
            else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                           else CmdBox.Canvas.Font.Color:=clBlack;
         EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         end;
     // View object and view as PSO
     13,14:  begin
             CmdBox.Canvas.Font.Color:=clMedGray;
             if Tree.Selected<>nil then
                if (Grid.Visible)and(Tree.Selected.ImageIndex=2) then
                   if (Grid.Selection.Top>0) then
                      if Grid.Cells[1,Grid.Selection.Top]='Object' then
                         if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                   else CmdBox.Canvas.Font.Color:=clBlack;
             EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
             CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
             end;
     // delete object
     15: begin
         if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
            else if Tree.Selected.ImageIndex=102 then
                 begin
                 if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                           else CmdBox.Canvas.Font.Color:=clBlack;
                 end
            else if (Tree.Selected.ImageIndex<>2)or(not Grid.Visible) then CmdBox.Canvas.Font.Color:=clMedGray
                 else begin
                 // check object type
                 B:=HexToInt(Grid.Cells[0,Grid.Selection.Top]);
                 if (B=CodeSel)or(B=IOSel)or(B=SysSel)or(B=WholeRAMSel)or(B=StackSel)or(B=PSOSel)or(B=IntSel)or(B=ProcessSel)or(B=DescriptorSel)or
                    (B=ServiceSel)or(B=BreakpointSel)or(B=ErrorSel)or(B=FlashCtrlSel)or(B=FlashDataSel)or(B=FlashWBSel) then CmdBox.Canvas.Font.Color:=clMedGray
                    else if Grid.Cells[1,Grid.Selection.Top]<>'Object' then CmdBox.Canvas.Font.Color:=clMedGray
                         else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                        else CmdBox.Canvas.Font.Color:=clBlack;
                 end;
         EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         end;
     // run process, debug process
     16,20: begin
            if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
               else if Tree.Selected.ImageIndex<100 then CmdBox.Canvas.Font.Color:=clMedGray
                    else begin
                    Node:=Tree.Selected;
                    while Node.ImageIndex<>100 do Node:=Node.Parent;
                    if Pos('active',Node.Text)<>0 then CmdBox.Canvas.Font.Color:=clMedGray
                       else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                      else CmdBox.Canvas.Font.Color:=clBlack;
                    end;
            EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
            CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
            end;
     // create suspended
     17: begin
         if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
            else if (Tree.Selected.ImageIndex<>100)or(Tree.Selected.StateIndex<>0) then CmdBox.Canvas.Font.Color:=clMedGray
                 else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                else CmdBox.Canvas.Font.Color:=clBlack;
         EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         end;
     // stop process
     18: begin
         if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
            else if Tree.Selected.ImageIndex<100 then CmdBox.Canvas.Font.Color:=clMedGray
                 else begin
                 Node:=Tree.Selected;
                 while Node.ImageIndex<>100 do Node:=Node.Parent;
                 if Pos('active',Node.Text)=0 then CmdBox.Canvas.Font.Color:=clMedGray
                    else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                   else CmdBox.Canvas.Font.Color:=clBlack;
                 end;
         EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         end;
     // kill process
     19: begin
         if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
            else if Tree.Selected.ImageIndex<100 then CmdBox.Canvas.Font.Color:=clMedGray
                 else begin
                 Node:=Tree.Selected;
                 while Node.ImageIndex<>100 do Node:=Node.Parent;
                 if Pos('[',Node.Text)=0 then CmdBox.Canvas.Font.Color:=clMedGray
                    else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                   else CmdBox.Canvas.Font.Color:=clBlack;
                 end;
         EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         end;
     // pass parameter to the process
     21: begin
         if Tree.Selected=nil then CmdBox.Canvas.Font.Color:=clMedGray
            else if Tree.Selected.ImageIndex<100 then CmdBox.Canvas.Font.Color:=clMedGray
                 else if (Tree.Selected.ImageIndex=100)and(Tree.Selected.StateIndex=0) then CmdBox.Canvas.Font.Color:=clMedGray
                      else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                     else CmdBox.Canvas.Font.Color:=clBlack;
         EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         end;
     // erase flash and autorun list
     22,25: begin
            if (MainState<3)or(Tree.Selected=nil) then CmdBox.Canvas.Font.Color:=clMedGray
                           else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                          else CmdBox.Canvas.Font.Color:=clBlack;
            EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
            CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
            end;
     // load file, delete file
     23,24: begin
            if not FilesBox.Visible then CmdBox.Canvas.Font.Color:=clMedGray
               else if FilesBox.ItemIndex=-1 then CmdBox.Canvas.Font.Color:=clMedGray
                    else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                   else CmdBox.Canvas.Font.Color:=clBlack;
            EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
            CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
            end;
     // performance monitor, send command, refresh
     26..28: begin
             if MainState<3 then CmdBox.Canvas.Font.Color:=clMedGray
                            else if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                                           else CmdBox.Canvas.Font.Color:=clBlack;
             EFlags[A]:=CmdBox.Canvas.Font.Color<>clMedGray;
             CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
             end;
     // exit
     29: begin
         if CmdBox.Selected[Index] then CmdBox.Canvas.Font.Color:=clBtnFace
                                   else CmdBox.Canvas.Font.Color:=clBlack;
         EFlags[A]:=true;
         CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,S);
         end;
     // COM port
     30: begin
         EFlags[A]:=true;
         if Length(COMDevice)=0 then CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Use COM-port...')
                                else CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'Use COM-port '+COMDevice);
         end;
     // BaudRate
     31: begin
         EFlags[A]:=true;
         if Baud=0 then CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'UART baud: 921600')
                   else CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,'UART baud: 150000');
         end;
     else CmdBox.Canvas.TextRect(Rect,Rect.Left,Rect.Top,CmdBox.Items[Index]);
     end;
end;

{
    Main Timer
}
procedure TMainForm.MainTimerTimer(Sender: TObject);
var
   A,B,C,D: Longword;
   S,T: String;
   FT_Device_String_Buffer: array [0..50] of Char;
   Buff: array [0..255] of Byte;
   CNode, MNode, PNode: TTreeNode;
begin
case MainState of
     // port closed
     0: begin
        if Tree.Items.Count<>0 then Tree.Items.Clear;
        MainStatus.SimpleText:='No connections';
        MainStatus.Refresh;
        CP:='';
        for A:=0 to 255 do CoreBuff[A]:=0;
        if USBDevice<>'' then
           begin
           StrPCopy(FT_Device_String_Buffer,USBDevice);
           if FT_OpenEx(@FT_Device_String_Buffer,FT_OPEN_BY_SERIAL_NUMBER,@FT_Handle)=FT_OK
              then begin
              if Baud=0 then FT_SetBaudRate(FT_Handle,FT_BAUD_921600)
                        else FT_SetBaudRate(FT_Handle,FT_BAUD_1500000);
              FT_SetDataCharacteristics(FT_Handle,FT_DATA_BITS_8,FT_STOP_BITS_1,FT_PARITY_NONE);
              FT_SetTimeouts(FT_Handle,200,600);
              MainEdit.Lines.Add('Device '+USBDevice+' opened');
              MainState:=1;
              end;
           end;
        if COMDevice<>'' then
           begin
           Com.Comm1.DeviceName:=COMDevice;
           try
           MainState:=1;
           Com.Comm1.Open;
           except
           MainState:=0;
           end;
           if MainState=1 then MainEdit.Lines.Add('Device '+COMDevice+' opened');
           end;
        end;
     // port opened, but no connect to board
     1: begin
        MainStatus.SimpleText:='Port opened';
        A:=0; B:=0;
        if USBDevice<>'' then
           begin
           FT_GetQueueStatus(FT_Handle,@A);
           if A>0 then FT_Read(FT_Handle,@FT_In_Buffer,A,@B);
           if B<>0 then MainState:=2
              else begin
              // send ping to the board
              S:=' '+Chr(13);
              StrPCopy(FT_Out_Buffer,S);
              FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
              end;
           end;
        if COMDevice<>'' then
           begin
           try
           B:=Com.Comm1.InQueCount;
           B:=Com.Comm1.Read(FT_Out_Buffer,B);
           if B<>0 then MainState:=2
              else begin
              S:=' '+Chr(13);
              StrPCopy(FT_Out_Buffer,S);
              Com.Comm1.Write(FT_Out_Buffer,Length(S));
              end;
           except
           MainState:=0;
           MainStatus.SimpleText:='No connections';
           end
           end;
        end;
     // reading CPU list
     2: begin
        // get the number of master CPU first
        if ReadObject(SysSel,8,1,@Buff,'') then
           begin
           MasterCPU:=Buff[0];                                     // master CPU Number
           D:=0;
           CoreBuff[D]:=Buff[0];
           Inc(D);
           CNode:=Tree.Items.Add(nil,'Core '+IntToHex(MasterCPU,2));
           CNode.ImageIndex:=0; CNode.SelectedIndex:=0; CNode.StateIndex:=MasterCPU;
           MNode:=Tree.Items.AddChild(CNode,'System registers');
           MNode.ImageIndex:=1;
           MNode:=Tree.Items.AddChild(CNode,'Descriptos table');
           MNode.ImageIndex:=2;
           MNode:=Tree.Items.AddChild(CNode,'Interrupt table');
           MNode.ImageIndex:=3;
           MNode:=Tree.Items.AddChild(CNode,'System errors');
           MNode.ImageIndex:=4;
           MNode:=Tree.Items.AddChild(CNode,'Files');
           MNode.ImageIndex:=6;
           MNode:=Tree.Items.AddChild(CNode,'Processes');
           MNode.ImageIndex:=5;
           PNode:=Tree.Items.AddChild(MNode,'<empty>');
           PNode.ImageIndex:=-1;
           // reading rest of processor list
           S:='CL '+Chr(13);
           StrPCopy(FT_Out_Buffer,S);
           if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                            else begin
                            Com.Comm1.Write(FT_Out_Buffer,Length(S));
                            Sleep(256);
                            end;
           if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,23,@A)
                            else A:=Com.Comm1.Read(FT_In_Buffer,23);
           if A=23 then
              begin
              FT_In_Buffer[A]:=Chr(0);
              S:=StrPas(FT_In_Buffer);
              Delete(S,1,5);
              S:=Copy(S,1,16);
              A:=HexToInt(S);
              if A=0 then begin
                          if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,1,@A)
                                           else Com.Comm1.Read(FT_In_Buffer,1);
                          end
                 else begin
                 FT_Read(FT_Handle,@FT_In_Buffer,A,@B);
                 if A=B then
                    begin
                    FT_In_Buffer[B-1]:=Chr(0);
                    S:=StrPas(FT_In_Buffer);
                    while Length(S)<>0 do
                          begin
                          T:=Copy(S,1,2);
                          Delete(S,1,4);
                          C:=HexToInt(T);
                          if C<>MasterCPU then
                             begin
                             CNode:=Tree.Items.Add(nil,'Core '+IntToHex(C,2));
                             CoreBuff[D]:=C;
                             Inc(D);
                             CNode.ImageIndex:=0; CNode.SelectedIndex:=0; CNode.StateIndex:=C;
                             MNode:=Tree.Items.AddChild(CNode,'System registers');
                             MNode.ImageIndex:=1;
                             MNode:=Tree.Items.AddChild(CNode,'Descriptos table');
                             MNode.ImageIndex:=2;
                             MNode:=Tree.Items.AddChild(CNode,'Interrupt table');
                             MNode.ImageIndex:=3;
                             MNode:=Tree.Items.AddChild(CNode,'System errors');
                             MNode.ImageIndex:=4;
                             MNode:=Tree.Items.AddChild(CNode,'Files');
                             MNode.ImageIndex:=6;
                             MNode:=Tree.Items.AddChild(CNode,'Processes');
                             MNode.ImageIndex:=5;
                             PNode:=Tree.Items.AddChild(MNode,'<empty>');
                             PNode.ImageIndex:=-1;
                             end;
                          end;
                    end;
                 end;
              end;
           MainState:=3;
           MainStatus.SimpleText:='CoreExplorer connected to the processor system';
           end;
        end;
     // main state
     3: begin
        // check port state
        if USBDevice<>'' then
           begin
           if FT_GetModemStatus(FT_Handle,@A)<>FT_OK
              then begin
                   FT_Handle:=0;
                   Tree.Items.Clear;
                   REdit.Visible:=false;
                   Grid.Visible:=false;
                   FilesBox.Clear;
                   FilesBox.Visible:=false;
                   if PMonForm.Visible then PMonForm.Close;
                   MainState:=0;
                   end
              else CheckReceiver;
           end;
        if COMDevice<>'' then
           if Com.Comm1.Handle<=0
              then begin
                   Tree.Items.Clear;
                   REdit.Visible:=false;
                   Grid.Visible:=false;
                   FilesBox.Clear;
                   FilesBox.Visible:=false;
                   if PMonForm.Visible then PMonForm.Close;
                   MainState:=0;
                   MainStatus.SimpleText:='No connections';
                   end
              else CheckReceiver;
        end;
     end;
CmdBox.Repaint;
end;

{
     Selection of the menu item
}
procedure TMainForm.CmdBoxDblClick(Sender: TObject);
var
   SAddr,Total,A,B,C,D,Handle,Obj,Len,DCount: Longint;
   cA,cB: int64;
   Buff: PP;
   BBuff: array [0..32767] of Byte;
   TID: Word;
   AR: Byte;
   S,T,Ln: String;
   EFlag: Boolean;
begin
S:=CmdBox.Items[CmdBox.ItemIndex];
GetWord(S,T);
A:=StrToIntDef(T,0);
if EFlags[A] then
   case A of
     // predefined selectors
     1: begin
        SelForm.SelGrid.Cells[1,1]:=IntToHex(CodeSel,6);
        SelForm.SelGrid.Cells[1,2]:=IntToHex(IOSel,6);
        SelForm.SelGrid.Cells[1,3]:=IntToHex(SysSel,6);
        SelForm.SelGrid.Cells[1,4]:=IntToHex(WholeRAMSel,6);
        SelForm.SelGrid.Cells[1,5]:=IntToHex(StackSel,6);
        SelForm.SelGrid.Cells[1,6]:=IntToHex(PSOSel,6);
        SelForm.SelGrid.Cells[1,7]:=IntToHex(IntSel,6);
        SelForm.SelGrid.Cells[1,8]:=IntToHex(ProcessSel,6);
        SelForm.SelGrid.Cells[1,9]:=IntToHex(DescriptorSel,6);
        SelForm.SelGrid.Cells[1,10]:=IntToHex(ServiceSel,6);
        SelForm.SelGrid.Cells[1,11]:=IntToHex(BreakpointSel,6);
        SelForm.SelGrid.Cells[1,12]:=IntToHex(ErrorSel,6);
        SelForm.SelGrid.Cells[1,13]:=IntToHex(FlashCtrlSel,6);
        SelForm.SelGrid.Cells[1,14]:=IntToHex(FlashDataSel,6);
        SelForm.SelGrid.Cells[1,15]:=IntToHex(FlashWBSel,6);
        if SelForm.ShowModal=mrOK then
           begin
           CodeSel:=HexToInt(SelForm.SelGrid.Cells[1,1]);
           IOSel:=HexToInt(SelForm.SelGrid.Cells[1,2]);
           SysSel:=HexToInt(SelForm.SelGrid.Cells[1,3]);
           WholeRAMSel:=HexToInt(SelForm.SelGrid.Cells[1,4]);
           StackSel:=HexToInt(SelForm.SelGrid.Cells[1,5]);
           PSOSel:=HexToInt(SelForm.SelGrid.Cells[1,6]);
           IntSel:=HexToInt(SelForm.SelGrid.Cells[1,7]);
           ProcessSel:=HexToInt(SelForm.SelGrid.Cells[1,8]);
           DescriptorSel:=HexToInt(SelForm.SelGrid.Cells[1,9]);
           ServiceSel:=HexToInt(SelForm.SelGrid.Cells[1,10]);
           BreakpointSel:=HexToInt(SelForm.SelGrid.Cells[1,11]);
           ErrorSel:=HexToInt(SelForm.SelGrid.Cells[1,12]);
           FlashCtrlSel:=HexToInt(SelForm.SelGrid.Cells[1,13]);
           FlashDataSel:=HexToInt(SelForm.SelGrid.Cells[1,14]);
           FlashWBSel:=HexToInt(SelForm.SelGrid.Cells[1,15]);
           end;
        end;
     // Instruction sets configuration
     2:  begin
         ISetDlg.IList.Items.Clear;
         if ISetList.Count<>0 then
            for A:=0 to ISetList.Count-1 do ISetDlg.IList.Items.Add(ISetList.Strings[A]);
         if ISetDlg.ShowModal=mrOK then
            begin
            ISetList.Clear;
            if ISetDlg.IList.Count<>0 then
               for A:=0 to ISetDlg.IList.Count-1 do ISetList.Add(ISetDlg.IList.Items.Strings[A]);
            end;
         end;
     // select USB device
     3: begin
        MainTimer.Enabled:=false;
        if FT_Handle<>0 then FT_Close(FT_Handle);
        if Com.Comm1.Handle>0 then Com.Comm1.Close;
        UartForm.Tag:=0;
        if UartForm.ShowModal=mrOK then
           begin
           USBDevice:=UartForm.USBBox.Text;
           COMDevice:='';
           end;
        MainState:=0;
        CmdBox.Repaint;
        MainTimer.Enabled:=true;
        end;
     // change transfer mode
     5: begin
        BinaryMode:=not BinaryMode;
        CmdBox.Repaint;
        end;
     // change refresh interval
     6: begin
        S:=IntToStr(RefreshInterval);
        if InputQuery('Refresh interval','New value in sec.',S) then
           begin
           A:=StrToIntDef(S,1);
           if (A>0)and(A<61) then RefreshInterval:=A;
           RefTimer.Interval:=A*1000;
           CmdBox.Repaint;
           end;
        end;
     // autorefresh ON/OFF
     7: begin
        AutoRefresh:=not AutoRefresh;
        RefTimer.Enabled:=AutoRefresh;
        CmdBox.Repaint;
        end;
     // change data block size
     8: begin
        S:=IntToStr(BS);
        if InputQuery('Transmission block size','Size in bytes :',S) then
           begin
           BS:=StrToIntDef(S,256);
           if BS<0 then BS:=256;
           if BS>32768 then BS:=2048;
           CmdBox.Repaint;
           end;
        end;
     // Load object from file
     9: if OpnDlg.Execute then
           if ObjDlg.ShowModal=mrOK then
              begin
              PME:=false;
              Handle:=FileOpen(OpnDlg.FileName,fmOpenRead);
              if Handle>0 then
                 begin
                 MainTimer.Enabled:=false;
                 EFlag:=false;
                 Obj:=0;
                 Len:=FileSeek(Handle,0,2);
                 FileSeek(Handle,0,0);
                 GetMem(Buff,Len+16);
                 FileRead(Handle,Buff^,Len);
                 AR:=2 or (ObjDlg.DPLBox.ItemIndex shl 2);
                 if ObjDlg.REBox.Checked then AR:=AR or $10;
                 if ObjDlg.WEBox.Checked then AR:=AR or $20;
                 if ObjDlg.NEBox.Checked then AR:=AR or $40;
                 TID:=HexToInt(ObjDlg.TaskEdit.Text);
                 S:='CO '+IntToStr(Len)+' '+IntToHex(AR,2)+' '+IntToHex(TID,4)+' '+Chr(13);
                 if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                                  else Ln:='';
                 S:=CP+Ln+S;
                 CheckReceiver;
                 StrPCopy(FT_Out_Buffer,S);
                 if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@C)
                                  else Com.Comm1.Write(FT_Out_Buffer,Length(S));
                 D:=Length(S)+1+19+3-Length(CP)-Length(Ln);
                 if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,D,@C)
                    else begin
                    Sleep(D);
                    C:=Com.Comm1.Read(FT_In_Buffer,D);
                    end;
                 FT_In_Buffer[C]:=Chr(0);
                 if C<>D then EFlag:=true
                    else begin
                    S:=StrPas(FT_In_Buffer);
                    Delete(S,1,Pos(Chr(10),S)+3);
                    S:=Copy(S,1,16);
                    Obj:=HexToInt(S);
                    A:=0;                              // data offset
                    ProgForm.Caption:='Loading object from file: '+OpnDlg.FileName;
                    ProgForm.Show;
                    ProgForm.ProgBar.Min:=0;
                    ProgForm.ProgBar.Max:=Len;
                    ProgForm.ProgBar.Position:=0;
                    ProgForm.BytesStatic.Caption:='0';
                    Application.ProcessMessages;
                    while A<>Len do
                          begin
                          CheckReceiver;
                          if (Len-A)>=BS then B:=BS
                                         else B:=Len-A;
                          EFlag:=not WriteObject(Obj,A,B,@Buff[A],CP);
                          A:=A+B;
                          if EFlag then Break;
                          ProgForm.ProgBar.Position:=A;
                          cA:=A;
                          cB:=Len;
                          ProgForm.BytesStatic.Caption:=IntToStr(Round(100*cA/cB))+'% '+IntToStr(A)+' of '+IntToStr(Len);
                          Application.ProcessMessages;
                          end;
                    ProgForm.Close;
                    end;
                 FreeMem(Buff);
                 FileClose(Handle);
                 if Eflag then MainEdit.Lines.Add('Handhacking error occurs, transfered bytes: '+IntToStr(A)+' Error code: '+IntToStr(FTECode))
                    else begin
                    MainEdit.Lines.Add(IntToStr(Len)+' bytes loaded into object '+IntToHex(Obj,6));
                    // refresh grid and tree
                    RefreshDT;
                    RefreshTree;
                    end;
                 MainTimer.Enabled:=true;
                 end;
              PME:=true;
              end;
     // save object to the file
     10: Saveobjecttofile1Click(Sender);
     // save memory block to file
     11: if SaveDlg.Execute then
            if BlockDlg.ShowModal=mrOK then
               if StrToIntDef(BlockDlg.LengthEdit.Text,-1)>0 then
                  begin
                  PME:=false;
                  MainTimer.Enabled:=false;
                  Handle:=FileCreate(SaveDlg.FileName);
                  if Handle>0 then
                     begin
                     EFlag:=false;
                     SAddr:=HexToInt(BlockDlg.AddressEdit.Text);
                     Len:=StrToInt(BlockDlg.LengthEdit.Text);
                     Total:=0;
                     ProgForm.Caption:='Saving memory block to file: '+SaveDlg.FileName;
                     ProgForm.Show;
                     ProgForm.ProgBar.Min:=0;
                     ProgForm.ProgBar.Max:=Len;
                     ProgForm.ProgBar.Position:=Total;
                     Application.ProcessMessages;
                     while Len<>0 do
                           begin
                           if Len>=BS then DCount:=BS
                                      else DCount:=Len;
                           S:='RR '+IntToHex(SAddr,12)+' '+IntToStr(DCount)+Chr(13);
                           if Length(CP)=0 then Ln:=''
                                           else Ln:=IntToHex(Length(S),4);
                           S:=CP+Ln+S;
                           CheckReceiver;
                           StrPCopy(FT_Out_Buffer,S);
                           if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                                            else Com.Comm1.Write(FT_Out_Buffer,Length(S));
                           B:=Length(S)+3+(((DCount-1) shr 4)+1)*2+DCount*3+3-Length(CP)-Length(Ln);
                           if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
                              else begin
                              Sleep(B);
                              A:=Com.Comm1.Read(FT_In_Buffer,B);
                              end;
                           FT_In_Buffer[A]:=Chr(0);
                           if A<>B then EFlag:=true
                              else begin
                              AsciiToBuff(@FT_In_Buffer,@BBuff,DCount);
                              FileWrite(Handle,BBuff,DCount);
                              Total:=Total+DCount;
                              SAddr:=SAddr+DCount;
                              end;
                           ProgForm.ProgBar.Position:=Total;
                           Application.ProcessMessages;
                           Len:=Len-DCount;
                           if EFlag then Break;
                           end;
                     FileClose(Handle);
                     if EFlag then MainEdit.Lines.Add('Handhacking error occurs')
                              else MainEdit.Lines.Add(IntToStr(Total)+' bytes saved to the file '+SaveDlg.FileName);
                     MainEdit.Lines.Add('>');
                     ProgForm.Close;
                     end;
                  MainTimer.Enabled:=true;
                  CheckReceiver;
                  PME:=true;
                  end;
     // save object to flash
     12: SaveobjecttoFLASH1Click(Sender);
     // View Object
     13: begin
         Grid.Tag:=HexToInt(Grid.Cells[0,Grid.Selection.Top]);
         ObjStart:=0;
         ObjLength:=0;
         Grid.RowCount:=1;
         Grid.ColCount:=1;
         Grid.Refresh;
         end;
     // Delete object
     15: Deleteobject1Click(Sender);
     // run process
     16: Runprocess1Click(Sender);
     // create suspended
     17: Createsuspended1Click(Sender);
     // stop process
     18: Stopprocess1Click(Sender);
     // kill process
     19: Killprocess1Click(Sender);
     // debug process
     20: Debugprocess1Click(Sender);
     // pass parameter to the process
     21: Passparameter1Click(Sender);
     // erase entire flash
     22: begin
         S:='';
         if InputQuery('Entire flash erase','Security code :',S) then
            begin
            PME:=false;
            S:='EA '+S+Chr(13);
            if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                             else Ln:='';
            S:=CP+Ln+S;
            CheckReceiver;
            StrPCopy(FT_Out_Buffer,S);
            FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
            Sleep(500);
            if FilesBox.Visible then RefreshFiles;
            PME:=true;
            end;
         end;
     // load file to the memory
     23: Loadtomemory1Click(Sender);
     // delete file
     24: Delete1Click(Sender);
     // autorun list editing
     25: AutoForm.ShowModal;
     // show performance monitor
     26: begin
         PME:=true;
         PMonForm.Show;
         end;
     // send command
     27: if InputQuery('Send command','Command:',S) then
            begin
            S:=S+#13;
            CheckReceiver;
            StrPCopy(FT_Out_Buffer,S);
            if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                             else Com.Comm1.Write(FT_Out_Buffer,Length(S));
            end;
     //exit
     29: Close;
     // Select COM-port
     30: begin
         MainTimer.Enabled:=false;
         if FT_Handle<>0 then FT_Close(FT_Handle);
         if Com.Comm1.Handle>0 then Com.Comm1.Close;
         UartForm.Tag:=1;
         if UartForm.ShowModal=mrOK then
            begin
            COMDevice:=UartForm.USBBox.Text;
            USBDevice:='';
            end;
         MainState:=0;
         CmdBox.Repaint;
         MainTimer.Enabled:=true;
         end;
     // change baud rate
     31: begin
         MainTimer.Enabled:=false;
         if FT_Handle<>0 then FT_Close(FT_Handle);
         Baud:=Baud xor 1;
         REdit.Visible:=false;
         Grid.Visible:=false;
         MainState:=0;
         CmdBox.Repaint;
         MainTimer.Enabled:=true;
         end
     end;
end;

{
         Program termination
}
procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
   INI: TIniFile;
   A: Longint;
begin
MainTimer.Enabled:=false;
if FT_Handle<>0 then FT_Close(FT_Handle);
if Com.Comm1.Handle>0 then Com.Comm1.Close;
Ini:=TiniFile.Create(extractfilepath(paramstr(0))+'CoreExplorer.ini');
if Ini<>nil then
   begin
   Ini.WriteString('USB section','Device',USBDevice);
   Ini.WriteString('COM section','Device',COMDevice);
   Ini.WriteBool('Transfer','RAW Data',BinaryMode);
   Ini.WriteInteger('Settings','Refresh interval',RefreshInterval);
   Ini.WriteInteger('Settings','Block size',BS);
   Ini.WriteInteger('Settings','Baud rate',Baud);

   Ini.WriteInteger('Selectors','Kernel code',CodeSel);
   Ini.WriteInteger('Selectors','IO block',IOSel);
   Ini.WriteInteger('Selectors','System registers',SysSel);
   Ini.WriteInteger('Selectors','Whole RAM',WholeRAMSel);
   Ini.WriteInteger('Selectors','Kernel stack',StackSel);
   Ini.WriteInteger('Selectors','System PSO',PSOSel);
   Ini.WriteInteger('Selectors','Interrupt table',IntSel);
   Ini.WriteInteger('Selectors','Process table',ProcessSel);
   Ini.WriteInteger('Selectors','Descriptor table',DescriptorSel);
   Ini.WriteInteger('Selectors','Service selector',ServiceSel);
   Ini.WriteInteger('Selectors','Breakpoint log',BreakpointSel);
   Ini.WriteInteger('Selectors','Error log',ErrorSel);
   Ini.WriteInteger('Selectors','Flash control registers',FlashCtrlSel);
   Ini.WriteInteger('Selectors','Flash data array',FlashDataSel);
   Ini.WriteInteger('Selectors','Flash write buffer',FlashWBSel);

   for A:=0 to 31 do
       if A<ISetList.Count then Ini.WriteString('Instruction sets','SET'+IntToStr(A),ISetList.Strings[A])
                           else Ini.WriteString('Instruction sets','SET'+IntToStr(A),'');

   Ini.WriteInteger('Position','Left',Left);
   Ini.WriteInteger('Position','Top',Top);
   Ini.WriteInteger('Position','Width',Width);
   Ini.WriteInteger('Position','Height',Height);
   Ini.WriteBool('Position','Maximized',(WindowState=wsMaximized));

   Ini.Free;
   end;
ISetList.Free;
// instruction set buffers
for A:=0 to 31 do IRefList[A].Free;
end;

procedure TMainForm.Splitter1Moved(Sender: TObject);
begin
CmdBox.Repaint;
end;


// Processor tree click
procedure TMainForm.TreeClick(Sender: TObject);
var
	 Ax,Bx,Cx: Int64;
   A,B,C,D,E,F,G: Longint;
   Buff: array [0..255] of byte;
   S,T,Len,Ps: String;
   EBuff: array [0..63] of Int64;
   PLBuff, DMABuff: PP;

begin
if Tree.Items.Count<>0 then
begin
SetCC;
Screen.Cursor:=crHourGlass;
case Tree.Selected.ImageIndex of
     // if click on the core CPU number
     0: begin
        PME:=false;
        CoreNode:=Tree.Selected;
        Grid.Visible:=false;
        // read status;
        S:='GS '+Chr(13);
        if Length(CP)<>0 then Len:=IntToHex(Length(S),4)
                         else Len:='';
        S:=CP+Len+S;
        CheckReceiver;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,512,@A)
           else begin
           Sleep(600);
           B:=Com.Comm1.InQueCount;
           A:=Com.Comm1.Read(FT_In_Buffer,B);
           end;
        FT_In_Buffer[A]:=Chr(0);
        S:=StrPas(FT_In_Buffer);
        Delete(S,1,5);
        REdit.Clear;
        REdit.Paragraph.Alignment:=taLeftJustify;
        REdit.SelAttributes.Size:=9;
        REdit.SelAttributes.Style:=[];
        REdit.Lines.Add(Copy(S,1,Length(S)-1));
        REdit.Visible:=true;
        PME:=true;
        end;
     // system registers
     1: begin
        PME:=false;
        REdit.Clear;
        REdit.Visible:=true;
        Grid.Visible:=false;
        CheckReceiver;
        if ReadObject(SysSel,0,56,@Buff[0],CP) then
           if ReadObject(SysSel,64,4,@Buff[64],CP) then
              if ReadObject(SysSel,$60,32,@Buff[$60],CP) then
                 begin
                 //re-read system registers
                 //DTR
				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('DTR, offset 00h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
				         Bx:=(Buff[4]*4294967296 + Buff[3]*16777216 + Buff[2]*65536 + Buff[1]*256 + Buff[0])*32;    // table base
				         Ax:=Buff[7]*65536 + Buff[6]*256 + Buff[5];                                                 // table length
                 REdit.Lines.Add('DT Base: '+IntToHex(Bx,10)+#9+#9+'DT Limit: '+IntToStr(Ax)+#13+#10);
				         // MPCR
				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('MPCR, offset 08h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 REdit.Lines.Add('CPU Number: '+IntToHex(Buff[8],2));
                 if (Buff[8+3] and 1)<>0 then REdit.Lines.Add('Stream engine: Running')
                                         else REdit.Lines.Add('Stream engine: Stopped');
                 if (Buff[8+3] and 2)<>0 then REdit.Lines.Add('Frame Processing Unit: Running')
                                         else REdit.Lines.Add('Frame Processing Unit: Stopped');
                 if (Buff[8+3] and 4)<>0 then REdit.Lines.Add('Context controller: Ready')
                                         else REdit.Lines.Add('Context controller: Busy/Stopped');
                 if (Buff[8+3] and $40)<>0 then REdit.Lines.Add('Memory allocation: Disabled')
                                           else REdit.Lines.Add('Memory allocation: Enabled');
                 if (Buff[8+3] and $80)<>0 then REdit.Lines.Add('Context controller: Enabled')
                                           else REdit.Lines.Add('Context controller: Disabled');
                 REdit.Lines.Add('North direction lanes: '+IntToStr(Buff[8+4] and 7)+#9+'North direction lane width: '+IntToStr(8 shl ((Buff[8+4] shr 3) and 3)));
                 S:='North direction errors: ';
                 if (Buff[8+4] and $20)<>0 then S:=S+'Detected'
                                           else S:=S+'none';
                 S:=S+'   North link established: ';
                 if (Buff[8+4] and $40)<>0 then S:=S+'Yes'
                                           else S:=S+'No';
                 S:=S+'   North direction: ';
                 if (Buff[8+4] and $80)<>0 then S:=S+'Enabled'
                                           else S:=S+'Disabled';
                 REdit.Lines.Add(S);

                 REdit.Lines.Add('East direction lanes: '+IntToStr(Buff[8+5] and 7)+#9+'North direction lane width: '+IntToStr(8 shl ((Buff[8+5] shr 3) and 3)));
                 S:='East direction errors: ';
                 if (Buff[8+5] and $20)<>0 then S:=S+'Detected'
                                           else S:=S+'none';
                 S:=S+'   East link established: ';
                 if (Buff[8+5] and $40)<>0 then S:=S+'Yes'
                                           else S:=S+'No';
                 S:=S+'   East direction: ';
                 if (Buff[8+5] and $80)<>0 then S:=S+'Enabled'
                                           else S:=S+'Disabled';
                 REdit.Lines.Add(S);

                 REdit.Lines.Add('South direction lanes: '+IntToStr(Buff[8+6] and 7)+#9+'South direction lane width: '+IntToStr(8 shl ((Buff[8+6] shr 3) and 3)));
                 S:='South direction errors: ';
                 if (Buff[8+6] and $20)<>0 then S:=S+'Detected'
                                           else S:=S+'none';
                 S:=S+'   East link established: ';
                 if (Buff[8+6] and $40)<>0 then S:=S+'Yes'
                                           else S:=S+'No';
                 S:=S+'   East direction: ';
                 if (Buff[8+6] and $80)<>0 then S:=S+'Enabled'
                                           else S:=S+'Disabled';
                 REdit.Lines.Add(S);

                 REdit.Lines.Add('West direction lanes: '+IntToStr(Buff[8+7] and 7)+#9+'West direction lane width: '+IntToStr(8 shl ((Buff[8+7] shr 3) and 3)));
                 S:='West direction errors: ';
                 if (Buff[8+7] and $20)<>0 then S:=S+'Detected'
                                           else S:=S+'none';
                 S:=S+'   West link established: ';
                 if (Buff[8+7] and $40)<>0 then S:=S+'Yes'
                                           else S:=S+'No';
                 S:=S+'   West direction: ';
                 if (Buff[8+7] and $80)<>0 then S:=S+'Enabled'
                                           else S:=S+'Disabled';
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('CSR, offset 10h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='Current state: ';
                 case (Buff[16+3] and 7) of
                      0: S:=S+'Main code processing';
                      1: S:=S+'Sleep state';
                      2: S:=S+'Exception processing';
                      3: S:=S+'Interrupt processing';
                      4: S:=S+'System message processing';
                      5: S:=S+'Regular message processing';
                      6: S:=S+'Undefined';
                      7: S:=S+'Undefined';
                      end;
                 REdit.Lines.Add(S);
                 if (Buff[16+2] and $80)<>0 then S:='Message processing: Enabled'
                                            else S:='Message processing: Disabled';
                 if (Buff[16+2] and $40)<>0 then S:=S+'   Process switching: Enabled'
                                            else S:=S+'   Process switching: Disabled';
                 if (Buff[16+2] and $20)<>0 then S:=S+'   Interrupts: Enabled'
                                            else S:=S+'   Interrupts: Disabled';
                 if (Buff[16+2] and $10)<>0 then S:=S+'   System errors processing: Enabled'
                                            else S:=S+'   System errors processing: Disabled';
                 REdit.Lines.Add(S);
                 S:='CPL: '+IntToStr((Buff[16+2] shr 2) and 3);
                 S:=S+'   Task ID: '+IntToHex(Buff[16+1]*256 + Buff[16],4);
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('CPSR, offset 14h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 REdit.Lines.Add('Current PSO Selector: '+IntToHex(Buff[20+2]*65536 + Buff[20+1]*256 + Buff[20+0],6)+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('PLR, offset 18h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='Process table selector: '+IntToHex(Buff[24+2]*65536 + Buff[24+1]*256 + Buff[24+0],6);
                 S:=S+'   Table pointer: '+IntToStr(Buff[24+5]*256 + Buff[24+4]);
                 S:=S+'   Table length: '+IntToStr(Buff[24+7]*256 + Buff[24+6]);
                 if (Buff[24+3] and $80)<>0 then S:=S+'   Process switching: Enabled'
                                            else S:=S+'   Process switching: Disabled';
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('TFMR, offset 20h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 Ax:=(Buff[32+4]*4294967296 + Buff[32+3]*16777216 + Buff[32+2]*65536 + Buff[32+1]*256 + Buff[32+0])*32;
                 REdit.Lines.Add('Total free memory: '+IntToStr(Ax)+' bytes.'+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('CFMR, offset 28h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 Ax:=(Buff[40+4]*4294967296 + Buff[40+3]*16777216 + Buff[40+2]*65536 + Buff[40+1]*256 + Buff[40+0])*32;
                 REdit.Lines.Add('Cached free memory: '+IntToStr(Ax)+' bytes.'+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('INTCR, offset 30h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='Interrupt table selector: '+IntToHex(Buff[48+2]*65536 + Buff[48+1]*256 + Buff[48+0],6)+'   Interrupt table length: '+IntToStr(Buff[48+5]*256 + Buff[48+4])+'   Interrupt service: ';
                 if (Buff[48+3] and $80)<>0 then S:=S+'Enabled'
                                            else S:=S+'Disabled';
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('PTR, offset 40h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='Timer base value: '+IntToStr(Buff[64+1]*256 + Buff[64+0])+'   Timer current value: '+IntToStr(Buff[64+3]*256 + Buff[64+2]);
                 REdit.Lines.Add(S+#13+#10);

                 // output status of the DMA registers
                 DMABuff:=nil;
                 ReadDMA(DMABuff, CP);
                 if (DMABuff[0]<>0)
                    then begin
                    A:=0;
                    while DMABuff[A]<>0 do A:=A+56;
                    A:=A div 56;
				            REdit.Paragraph.Alignment:=taCenter;
				            REdit.SelAttributes.Size:=9;
				            REdit.SelAttributes.Style:=[fsBold];
                    REdit.Lines.Add('DMACTRL, offset 48h');
				            REdit.Paragraph.Alignment:=taLeftJustify;
				            REdit.SelAttributes.Size:=9;
				            REdit.SelAttributes.Style:=[];
                    for B:=0 to A-1 do
                        begin
                        S:='TXcntr'+IntToStr(B)+': '+IntToStr((DMABuff[B*56+24+7] shl 24)or(DMABuff[B*56+24+6] shl 16)or(DMABuff[B*56+24+5] shl 8)or(DMABuff[B*56+24+4]));
                        S:=S+', RXcntr'+IntToStr(B)+': '+IntToStr((DMABuff[B*56+7] shl 24)or(DMABuff[B*56+6] shl 16)or(DMABuff[B*56+5] shl 8)or(DMABuff[B*56+4]));
                        S:=S+', TXtimer'+IntToStr(B)+': '+IntToStr((DMABuff[B*56+3] shl 8)or(DMABuff[B*56+2]));
                        case (DMABuff[B*56+1] and $C0) shr 6 of
                             0: S:=S+', TXsize'+IntToStr(B)+': Byte';
                             1: S:=S+', TXsize'+IntToStr(B)+': Word';
                             2: S:=S+', TXsize'+IntToStr(B)+': DWord';
                             3: S:=S+', TXsize'+IntToStr(B)+': QWord';
                             end;
                        case (DMABuff[B*56+1] and $30) shr 4 of
                             0: S:=S+', RXsize'+IntToStr(B)+': Byte';
                             1: S:=S+', RXsize'+IntToStr(B)+': Word';
                             2: S:=S+', RXsize'+IntToStr(B)+': DWord';
                             3: S:=S+', RXsize'+IntToStr(B)+': QWord';
                             end;
                        if (DMABuff[B*56+1] and $08)<>0 then S:=S+', TXcycle'+IntToStr(B)+': ON'
                                                        else S:=S+', TXcycle'+IntToStr(B)+': OFF';
                        if (DMABuff[B*56+1] and $04)<>0 then S:=S+', RXcycle'+IntToStr(B)+': ON'
                                                        else S:=S+', RXcycle'+IntToStr(B)+': OFF';
                        S:=S+', TXCLKs'+IntToStr(B)+': '+IntToStr((DMABuff[B*56+24+8+7] shl 24)or(DMABuff[B*56+24+8+6] shl 16)or(DMABuff[B*56+24+8+5] shl 8)or(DMABuff[B*56+24+8+4]));
                        S:=S+', ErrorCode'+IntToStr(B)+': '+IntToHex((DMABuff[B*56+24+8+3] shl 8)or(DMABuff[B*56+24+8+2]),4);
                        REdit.Lines.Add(S);
                        end;
				            REdit.Paragraph.Alignment:=taCenter;
				            REdit.SelAttributes.Size:=9;
				            REdit.SelAttributes.Style:=[fsBold];
                    REdit.Lines.Add('DMARXPTR, offset 50h');
				            REdit.Paragraph.Alignment:=taLeftJustify;
				            REdit.SelAttributes.Size:=9;
				            REdit.SelAttributes.Style:=[];
                    for B:=0 to A-1 do
                        begin
                        S:='RXListPointer'+IntToStr(B)+': '+IntToHex((DMABuff[B*56+24+16+7] shl 24)or(DMABuff[B*56+24+16+6] shl 16)or(DMABuff[B*56+24+16+5] shl 8)or(DMABuff[B*56+24+16+4]),8);
                        S:=S+':'+IntToHex((DMABuff[B*56+24+16+3] shl 24)or(DMABuff[B*56+24+16+2] shl 16)or(DMABuff[B*56+24+16+1] shl 8)or(DMABuff[B*56+24+16+0]),8);
                        S:=S+Chr(9)+'RXCurrentPointer'+IntToStr(B)+': '+IntToHex((DMABuff[B*56+8+7] shl 24)or(DMABuff[B*56+8+6] shl 16)or(DMABuff[B*56+8+5] shl 8)or(DMABuff[B*56+8+4]),8);
                        S:=S+':'+IntToHex((DMABuff[B*56+8+3] shl 24)or(DMABuff[B*56+8+2] shl 16)or(DMABuff[B*56+8+1] shl 8)or(DMABuff[B*56+8+0]),8);
                        REdit.Lines.Add(S);
                        end;
				            REdit.Paragraph.Alignment:=taCenter;
				            REdit.SelAttributes.Size:=9;
				            REdit.SelAttributes.Style:=[fsBold];
                    REdit.Lines.Add('DMATXPTR, offset 58h');
				            REdit.Paragraph.Alignment:=taLeftJustify;
				            REdit.SelAttributes.Size:=9;
				            REdit.SelAttributes.Style:=[];
                    for B:=0 to A-1 do
                        begin
                        S:='TXListPointer'+IntToStr(B)+': '+IntToHex((DMABuff[B*56+24+24+7] shl 24)or(DMABuff[B*56+24+24+6] shl 16)or(DMABuff[B*56+24+24+5] shl 8)or(DMABuff[B*56+24+24+4]),8);
                        S:=S+':'+IntToHex((DMABuff[B*56+24+24+3] shl 24)or(DMABuff[B*56+24+24+2] shl 16)or(DMABuff[B*56+24+24+1] shl 8)or(DMABuff[B*56+24+24+0]),8);
                        S:=S+Chr(9)+'TXCurrentPointer'+IntToStr(B)+': '+IntToHex((DMABuff[B*56+16+7] shl 24)or(DMABuff[B*56+16+6] shl 16)or(DMABuff[B*56+16+5] shl 8)or(DMABuff[B*56+16+4]),8);
                        S:=S+':'+IntToHex((DMABuff[B*56+16+3] shl 24)or(DMABuff[B*56+16+2] shl 16)or(DMABuff[B*56+16+1] shl 8)or(DMABuff[B*56+16+0]),8);
                        REdit.Lines.Add(S);
                        end;
                    end;
                 FreeMem(DMABuff);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('AVCNTR, offset 60h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='Instructions, average counter: '+IntToStr(Buff[96+2]*65536+Buff[96+1]*256+Buff[96]);
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('MINCNTR, offset 68h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='Instructions, minimum counter: '+IntToStr(Buff[96+10]*65536+Buff[96+9]*256+Buff[96+8]);
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('MAXCNTR, offset 6Ch');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='Instructions, maximum counter: '+IntToStr(Buff[96+14]*65536+Buff[96+13]*256+Buff[96+12]);
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('PMCSR & PMPSR, offset 70h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='PM Code selector: '+IntToHex(Buff[96+18]*65536+Buff[96+17]*256+Buff[96+16],6)+'   PM Process selector: '+IntToHex(Buff[96+22]*65536+Buff[96+21]*256+Buff[96+20],6);
                 REdit.Lines.Add(S+#13+#10);

				         REdit.Paragraph.Alignment:=taCenter;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[fsBold];
                 REdit.Lines.Add('PMCR, offset 78h');
				         REdit.Paragraph.Alignment:=taLeftJustify;
				         REdit.SelAttributes.Size:=9;
				         REdit.SelAttributes.Style:=[];
                 S:='PM measure interval: '+FloatToStrF(((Buff[96+26]*65536+Buff[96+25]*256+Buff[96+24]) and $1FFFF)/100,ffGeneral,5,5)+'탎';
                 S:=S+'   PM monitoring state: ';
                 case ((Buff[96+27] shr 28) and 7) of
                      0: S:=S+'Main code processing';
                      1: S:=S+'Sleep state';
                      2: S:=S+'Exception processing';
                      3: S:=S+'Interrupt processing';
                      4: S:=S+'System message processing';
                      5: S:=S+'Regular message processing';
                      6: S:=S+'Undefined';
                      7: S:=S+'Undefined';
                      end;
                 S:=S+'   PM process switching: ';
                 if (Buff[96+27] and $80)=0 then S:=S+'excluded'
                                            else S:=S+'included';
                 REdit.Lines.Add(S+#13+#10);
                 end;
        PME:=true;
        end;
     // descriptor table
     2: begin
        PME:=false;
        REdit.Visible:=false;
        Grid.Tag:=0;
        Grid.Options:=Grid.Options + [goRowSelect];
        Grid.Visible:=true;
        Grid.ColCount:=14;
        Grid.FixedCols:=0;
        Grid.Cells[0,0]:='Selector';
        Grid.Cells[1,0]:='Type';
        Grid.Cells[2,0]:='DPL';
        Grid.Cells[3,0]:='Attributes';
        Grid.Cells[4,0]:='Task ID';
        Grid.Cells[5,0]:='Owner';
        Grid.Cells[6,0]:='Base';
        Grid.Cells[7,0]:='Lower limit';
        Grid.Cells[8,0]:='Upper limit';
        Grid.Cells[9,0]:='Lower link';
        Grid.Cells[10,0]:='Upper link';
        Grid.Cells[11,0]:='Pointer mask';
        Grid.Cells[12,0]:='Watchdog';
        Grid.Cells[13,0]:='Data width';
        // reading DTR
        S:='RR 1FFFFFFFFF80 8'+Chr(13);
        if Length(CP)<>0 then Len:=IntToHex(Length(S),4)
                         else Len:='';
        S:=CP+Len+S;
        CheckReceiver;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,50,@A)
           else begin
           Sleep(50+Length(S));
           A:=Com.Comm1.Read(FT_In_Buffer,50);
           end;
        FT_In_Buffer[A]:=Chr(0);
        if A=50 then
           begin
           AsciiToBuff(@FT_In_Buffer,@Buff,8);
           Bx:=(Buff[4]*4294967296 + Buff[3]*16777216 + Buff[2]*65536 + Buff[1]*256 + Buff[0]) * 32; // DT base and start address for read
           C:=(Buff[7] shl 16) or (Buff[6] shl 8) or Buff[5];       // count of entries
           Grid.RowCount:=C+1;
           Grid.FixedRows:=1;
           E:=0;
           while C<>0 do
                 begin
                 if C>=8 then D:=8               // readed descriptors
                         else D:=C;
                 S:='RR '+IntToHex(Bx,12)+' '+IntToStr(D*32)+Chr(13);
                 if Length(CP)<>0 then Len:=IntToHex(Length(S),4)
                                  else Len:='';
                 S:=CP+Len+S;
                 CheckReceiver;
                 StrPCopy(FT_Out_Buffer,S);
                 if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                                  else Com.Comm1.Write(FT_Out_Buffer,Length(S));
                 if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,Length(S)+6+D*2*2+D*2*16*3-Length(CP)-Length(Len),@A)
                    else begin
                    Sleep((Length(S)+6+D*2*2+D*2*16*3) div 3);
                    A:=Com.Comm1.Read(FT_In_Buffer,Length(S)+6+D*2*2+D*2*16*3-Length(CP)-Length(Len));
                    end;
                 FT_In_Buffer[A]:=Chr(0);
                 AsciiToBuff(@FT_In_Buffer,@Buff,D*32);
                 Buff[255]:=0;
                 C:=C-D;
                 Bx:=Bx+D*32;
                 while D<>0 do
                       begin
                       Grid.Cells[0,E+1]:=IntToHex(E,6);                      // selector
                       case (Buff[7] and 3) of
                            // free entry
                            0: if E=0 then begin
                                           Grid.Cells[1,E+1]:='Null descriptor';
                                           Grid.Cells[2,E+1]:='';
                                           Grid.Cells[3,E+1]:='';
                                           Grid.Cells[4,E+1]:='';
                                           Grid.Cells[5,E+1]:='';
                                           Grid.Cells[6,E+1]:='';
                                           Grid.Cells[7,E+1]:='';
                                           Grid.Cells[8,E+1]:='';
                                           Grid.Cells[9,E+1]:='';
                                           Grid.Cells[10,E+1]:='';
                                           Grid.Cells[11,E+1]:='';
                                           Grid.Cells[12,E+1]:='';
                                           Grid.Cells[13,E+1]:='';
                                           end
                                      else begin
                                      Grid.Cells[1,E+1]:='Free entry';
                                      for A:=2 to Grid.ColCount-1 do Grid.Cells[A,E+1]:='';
                                      end;
                            // free segment
                            1: begin
                               Grid.Cells[1,E+1]:='Free segment';
                               Grid.Cells[2,E+1]:='';
                               Grid.Cells[3,E+1]:='';
                               Grid.Cells[4,E+1]:='';
                               Grid.Cells[5,E+1]:='';
                               Ax:=(Buff[4]*4294967296 + Buff[3]*16777216 + Buff[2]*65536 + Buff[1]*256 + Buff[0]) * 32;
                               Grid.Cells[6,E+1]:=IntToHex(Ax,12);
                               Grid.Cells[7,E+1]:='';
                               Ax:=(Buff[255]*4294967296 + Buff[23]*16777216 + Buff[22]*65536 + Buff[21]*256 + Buff[20]) * 32;
                               Grid.Cells[8,E+1]:=IntToHex(Ax,10);
                               Grid.Cells[9,E+1]:='';
                               Grid.Cells[10,E+1]:='';
                               Grid.Cells[11,E+1]:='';
                               Grid.Cells[12,E+1]:='';
                               Grid.Cells[13,E+1]:='';
                               end;
                            // object descriptor
                            2: begin
                               Grid.Cells[1,E+1]:='Object';
                               Grid.Cells[2,E+1]:=IntToStr((Buff[7] shr 2) and 3);
                               S:='';
                               if (Buff[7] and $10)<>0 then S:='RE';
                               if (Buff[7] and $20)<>0 then S:=S+',WE';
                               if (Buff[7] and $40)<>0 then S:=S+',NE';
                               Grid.Cells[3,E+1]:=S;
                               Grid.Cells[4,E+1]:=IntToHex((Buff[6] shl 8) or Buff[5],4);
                               Grid.Cells[5,E+1]:=IntToHex(Buff[27]*16777216 + Buff[26]*65536 + Buff[25]*256 + Buff[24],6);
                               Ax:=(Buff[4]*4294967296 + Buff[3]*16777216 + Buff[2]*65536 + Buff[1]*256 + Buff[0]) * 32;
                               Grid.Cells[6,E+1]:=IntToHex(Ax,12);
                               Grid.Cells[7,E+1]:=IntToHex((Buff[19]*16777216 + Buff[18]*65536 + Buff[17]*256 + Buff[16]) * 32,12);
                               Grid.Cells[8,E+1]:=IntToHex((Buff[23]*16777216 + Buff[22]*65536 + Buff[21]*256 + Buff[20]) * 32,12);
                               Grid.Cells[9,E+1]:=IntToHex(Buff[11]*16777216 + Buff[10]*65536 + Buff[9]*256 + Buff[8],8);
                               Grid.Cells[10,E+1]:=IntToHex(Buff[15]*16777216 + Buff[14]*65536 + Buff[13]*256 + Buff[12],8);
                               Grid.Cells[11,E+1]:='';
                               Grid.Cells[12,E+1]:='';
                               Grid.Cells[13,E+1]:='';
                               end;
                            // stream
                            3: begin
                               Grid.Cells[1,E+1]:='Stream';
                               Grid.Cells[2,E+1]:=IntToStr((Buff[7] shr 2) and 3);
                               if (Buff[7] and $40)<>0 then S:='NE'
                                                       else S:='';
                               Grid.Cells[3,E+1]:=S;
                               Grid.Cells[4,E+1]:=IntToHex((Buff[6] shl 8) or Buff[5],4);
                               Grid.Cells[5,E+1]:=IntToHex(Buff[27]*16777216 + Buff[26]*65536 + Buff[25]*256 + Buff[24],6);
                               Ax:=(Buff[4]*4294967296 + Buff[3]*16777216 + Buff[2]*65536 + Buff[1]*256 + Buff[0]) * 32;
                               Grid.Cells[6,E+1]:=IntToHex(Ax,12);
                               Grid.Cells[7,E+1]:='';
                               Grid.Cells[8,E+1]:='';
                               Grid.Cells[9,E+1]:='';
                               Grid.Cells[10,E+1]:='';
                               Grid.Cells[11,E+1]:=IntToHex(Buff[10]*65536 + Buff[9]*256 + Buff[8],6);
                               Grid.Cells[12,E+1]:=IntToStr(Buff[12]);
                               Grid.Cells[13,E+1]:=IntToStr(8 shl (Buff[15] shr 6));
                               end;
                            end;
                       Move(Buff[32],Buff[0],256-32);
                       Dec(D);
                       Inc(E);
                       end;
                 end;
           Grid.FixedRows:=1;
           Grid.Refresh;
           for A:=0 to Grid.ColCount-1 do
               begin
               C:=0;
               for D:=0 to Grid.RowCount-1 do
                   if C<Grid.Canvas.TextWidth(Grid.Cells[A,D]) then C:=Grid.Canvas.TextWidth(Grid.Cells[A,D]);
               Grid.ColWidths[A]:=C+10;
               end;
           Grid.Refresh;
           end;
        PME:=true;
        end;
     // Interrupt table
     3: begin
        PME:=false;
        REdit.Visible:=false;
        Grid.Visible:=false;
        Grid.Tag:=0;
        Grid.Options:=Grid.Options + [goRowSelect];
        S:='RR 1FFFFFFFFFB0 8'+Chr(13);
        if Length(CP)<>0 then Len:=IntToHex(Length(S),4)
                         else Len:='';
        S:=CP+Len+S;
        CheckReceiver;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,50,@A)
           else begin
           Sleep(Length(S)+50);
           A:=Com.Comm1.Read(FT_In_Buffer,50);
           end;
        FT_In_Buffer[A]:=Chr(0);
        if A=50 then
           begin
           AsciiToBuff(@FT_In_Buffer,@Buff,8);
           B:=Buff[2]*65536 + Buff[1]*256 + Buff[0];                                               // table selector
           C:=Buff[5]*256 + Buff[4];                                                               // table length
           Grid.RowCount:=C+1;
           Grid.ColCount:=11;
           Grid.Cells[0,0]:='Interrupt';
           Grid.Cells[1,0]:='Process selector';
           Grid.Cells[2,0]:='Procedure index';
           Grid.Cells[3,0]:='Code object';
           Grid.Cells[4,0]:='Entry offset';
           Grid.Cells[5,0]:='Entry PL';
           Grid.Cells[6,0]:='Entry type';
           Grid.Cells[7,0]:='Hardware interrupts';
           Grid.Cells[8,0]:='Process switching';
           Grid.Cells[9,0]:='Message processing';
           Grid.Cells[10,0]:='CPL and Task ID from';
           Grid.FixedCols:=0;
           Grid.Visible:=true;
           E:=0;
           G:=0;
           while C<>0 do
                 begin
                 if C>=32 then D:=32
                          else D:=C;
                 CheckReceiver;
                 ReadObject(B,E,D*8,@Buff,CP);
                 C:=C-D;
                 E:=E+D*8;
                 F:=0;
                 while D<>0 do
                       begin
                       Grid.Cells[0,G+1]:=IntToStr(G);
                       Ax:=Buff[F+2]*65536 + Buff[F+1]*256+Buff[F];       //PSO selector
                       Grid.Cells[1,G+1]:=IntToHex(Ax,6);
                       Bx:=Buff[F+6]*65536 + Buff[F+5]*256+Buff[F+4];     //Entry number
                       Grid.Cells[2,G+1]:=IntToStr(Bx);
                       if Ax<>0 then
                          begin
                          CheckReceiver;
                          ReadObject(Ax,12,4,@A,CP);                         //read the export table offset
                          Bx:=A+(Bx shl 3);                                  //offset to the export table record
                          ReadObject(Ax,Bx,8,@Cx,CP);                        //read export table record
                          Bx:=(Cx shr 32) and $FFFFFF;
                          Grid.Cells[3,G+1]:=IntToHex(Bx,6);                 //code selector
                          Grid.Cells[4,G+1]:=IntToHex(Cx and $FFFFFFFF,8);   //code offset
                          Grid.Cells[5,G+1]:=IntToStr((Cx shr 56) and 3);    //PL
                          case (Cx shr 58) and 3 of
                               0: Grid.Cells[6,G+1]:='Interrupt';
                               1: Grid.Cells[6,G+1]:='Procedure';
                               2: Grid.Cells[6,G+1]:='System message';
                               3: Grid.Cells[6,G+1]:='Regular message';
                               end;
                          if (Cx and $1000000000000000)<>0 then Grid.Cells[7,G+1]:='Enabled'
                                                           else Grid.Cells[7,G+1]:='Disabled';
                          if (Cx and $2000000000000000)<>0 then Grid.Cells[8,G+1]:='Enabled'
                                                           else Grid.Cells[8,G+1]:='Disabled';
                          if (Cx and $4000000000000000)<>0 then Grid.Cells[9,G+1]:='Enabled'
                                                           else Grid.Cells[9,G+1]:='Disabled';
                          if (Cx and $8000000000000000)<>0 then Grid.Cells[10,G+1]:='requester'
                                                           else Grid.Cells[10,G+1]:='code object';
                          end
                          else begin
                               Grid.Cells[3,G+1]:='';
                               Grid.Cells[4,G+1]:='';
                               Grid.Cells[5,G+1]:='';
                               Grid.Cells[6,G+1]:='';
                               Grid.Cells[7,G+1]:='';
                               Grid.Cells[8,G+1]:='';
                               Grid.Cells[9,G+1]:='';
                               Grid.Cells[10,G+1]:='';
                          end;
                       Dec(D);
                       F:=F+8;
                       Inc(G);
                       end;
                 end;
           Grid.FixedRows:=1;
           Grid.Refresh;
           for A:=0 to Grid.ColCount-1 do
               begin
               C:=0;
               for D:=0 to Grid.RowCount-1 do
                   if C<Grid.Canvas.TextWidth(Grid.Cells[A,D]) then C:=Grid.Canvas.TextWidth(Grid.Cells[A,D]);
               Grid.ColWidths[A]:=C+10;
               end;
           Grid.Refresh;
           end;
        PME:=true;
        end;
     // system errors
     4: begin
        PME:=false;
        REdit.Visible:=false;
        Grid.Visible:=false;
        Grid.Tag:=0;
        Grid.Options:=Grid.Options + [goRowSelect];
        CheckReceiver;
        if ReadObject(ErrorSel,0,256,@EBuff[0],CP) then
           if ReadObject(ErrorSel,256,256,@EBuff[32],CP) then
              begin
              Grid.ColCount:=4;
              Grid.Cells[0,0]:='Description';
              Grid.Cells[1,0]:='Code';
              Grid.Cells[2,0]:='Process';
              Grid.Cells[3,0]:='Selector';
              Grid.RowCount:=1;
              A:=0;
              B:=0;
              if EBuff[0]<>0
                 then begin
                      while (EBuff[B and $3F]<>0)and(B<64) do Inc(B);
                            if B<64 then
                               begin
                               A:=B;
                               while (EBuff[A and $3F]=0)and(A<64) do Inc(A);
                               end;
                      end
                 else begin
                      while (EBuff[A]=0)and(A<64) do Inc(A);
                      if A=64 then A:=0
                         else begin
                         B:=A;
                         while (EBuff[B]<>0)and(B<64) do Inc(B);
                         end;
                      end;
              if (A or B)<>0 then
                 begin
                 C:=Grid.RowCount-1;
                 if A<B then Grid.RowCount:=Grid.RowCount+B-A
                        else Grid.RowCount:=Grid.RowCount+64+B-A;
                 D:=Grid.RowCount-1;
                 while C<>0 do
                       begin
                       Grid.Cells[0,D]:=Grid.Cells[0,C];
                       Grid.Cells[1,D]:=Grid.Cells[1,C];
                       Grid.Cells[2,D]:=Grid.Cells[2,C];
                       Grid.Cells[3,D]:=Grid.Cells[3,C];
                       Dec(D);
                       Dec(C);
                       end;
                 C:=A;
                 if A<B then D:=B-A
                        else D:=64+B-A;
                 while C<>B do
                       begin
                       C:=C and $3F;
                       case ((EBuff[C] shr 56) and 7) of
                            1: begin
                               if ((EBuff[C] shr 59)=$1F) then S:='Denied access to the another CPU,'
                                  else if ((EBuff[C] shr 59)=0) then S:='Invalid selector,'
                                       else begin
                                            if ((EBuff[C] shr 59) and 1)<>0 then S:='Object limit,';
                                            if ((EBuff[C] shr 60) and 1)<>0 then S:=S+'Read/Write,';
                                            if ((EBuff[C] shr 61) and 1)<>0 then S:=S+'PL violation,';
                                            if ((EBuff[C] shr 62) and 1)<>0 then S:=S+'Task ID,';
                                            if ((EBuff[C] shr 63) and 1)<>0 then S:=S+'Invalid descriptor,';
                                            end;
                               end;
                            2: begin
                               case ((EBuff[C] shr 59) and $1F) of
                                    0: S:='Message index out of range of import table,';
                                    1: S:='Invalid destination PSO selector,';
                                    2: S:='Index out of range of export table,';
                                    3: S:='Access denied by provilege level,';
                                    4: S:='Access denied by message type,';
                                    5: S:='Message queue overflow,';
                                    6: S:='Invalid interrupt index,';
                                    7: S:='Invalid PSO selector,';
                                    8: S:='Context stack overflow,';
                                    else S:='Unknown error,';
                                    end;
                               end;
                            3: begin
                               case ((EBuff[C] shr 59) and $1F) of
                                    1: S:='Context stack underflow,';
                                    2: S:='Invalid return selector,';
                                    else S:='Unknown error,';
                                    end;
                               end;
                            else S:='Unknown error,';
                            end;
                       Grid.Cells[0,D]:=Copy(S,1,Length(S)-1);
                       Grid.Cells[1,D]:=IntToHex(EBuff[C] shr 56,2);
                       Grid.Cells[2,D]:=IntToHex((EBuff[C] shr 32)and $0FFFFFF,6);
                       Grid.Cells[3,D]:=IntToHex(EBuff[C] and $0FFFFFFFF,8);
                       Inc(C);
                       Dec(D);
                       end;
                 FillChar(EBuff[0],512,0);
                 if A<B
                 then begin
                      while A<>B do
                            begin
                            if B-A>=32 then C:=32
                                       else C:=B-A;
                            WriteObject(15,A*8,C*8,@EBuff,CP);
                            A:=A+C;
                            end;
                      end
                 else begin
                      while A<>64 do
                            begin
                            if 64-A>=32 then C:=32
                                        else C:=64-A;
                            WriteObject(15,A*8,C*8,@EBuff,CP);
                            A:=A+C;
                            end;
                      A:=0;
                      while A<>B do
                            begin
                            if B-A>=32 then C:=32
                                       else C:=B-A;
                            WriteObject(15,A*8,C*8,@EBuff,CP);
                            A:=A+C;
                            end;
                      end;
                 end;
              if Grid.RowCount>1 then Grid.FixedRows:=1;
              Grid.Visible:=true;
              Grid.Refresh;
              for A:=0 to Grid.ColCount-1 do
                  begin
                  C:=0;
                  for D:=0 to Grid.RowCount-1 do
                      if C<Grid.Canvas.TextWidth(Grid.Cells[A,D]) then C:=Grid.Canvas.TextWidth(Grid.Cells[A,D]);
                  Grid.ColWidths[A]:=C+10;
                  end;
              Grid.Refresh;
              end;
        PME:=true;
        end;
     // processes
     5: begin
        PME:=false;
        Grid.Visible:=false;
        REdit.Visible:=true;
        REdit.Clear;
        REdit.Paragraph.Alignment:=taLeftJustify;
        REdit.SelAttributes.Size:=9;
        REdit.SelAttributes.Style:=[];
        PLBuff:=nil;
        // reading process list
        A:=0;
        CheckReceiver;
        if ReadObject(SysSel,$1E,2,@A,CP) then
           begin
           GetMem(PLBuff,A*4);
           FillChar(PLBuff[0],A*4,0);
           if not ReadObject(ProcessSel,0,A*4,PLBuff,CP) then A:=0;
           end;
        C:=A;
        // fill the PTree
        S:='PL '+Chr(13);
        if Length(CP)<>0 then Len:=IntToHex(Length(S),4)
                         else Len:='';
        S:=CP+Len+S;
        CheckReceiver;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                         else Com.Comm1.Write(FT_Out_Buffer,Length(S));
        B:=21;
        if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
           else begin
           Sleep(21+Length(S));
           A:=Com.Comm1.Read(FT_In_Buffer,B);
           end;
        if B=A then
           begin
           FT_In_Buffer[A]:=#0;
           S:=StrPas(FT_In_Buffer);
           Delete(S,1,5);
           B:=HexToInt(S);
           while B<>0 do
                 begin
                 if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
                                  else A:=Com.Comm1.Read(FT_In_Buffer,B);
                 if B<>A then B:=0
                    else begin
                    FT_In_Buffer[A]:=#0;
                    S:=StrPas(FT_In_Buffer);
                    GetWord(S,Ps);                            // Ps - name of process
                    GetWord(S,T);
                    RemoveFirstSpaces(S);
                    D:=HexToInt(Copy(S,1,16));      // selector PSO
                    if D<>0 then
                       begin
                       T:='[suspended]';
                       if (PLBuff<>nil)and(C<>0) then
                          for A:=0 to C-1 do
                              begin
                              Move(PLBuff[A*4],B,4);
                              if B=D then T:='[active]';
                              end;
                       REdit.Lines.Add(Ps+' '+T);
                       end;
                    B:=16;
                    if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
                                     else A:=Com.Comm1.Read(FT_In_Buffer,B);
                    if B<>A then B:=0
                       else begin
                       FT_In_Buffer[A]:=#0;
                       S:=StrPas(FT_In_Buffer);
                       B:=HexToInt(S);
                       end;
                    end;
                 end;
           if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,3,@A)
                            else A:=Com.Comm1.Read(FT_In_Buffer,3);
           end;
        Application.ProcessMessages;
        if PLBuff<>nil then FreeMem(PLBuff);
        PME:=true;
        end;
     // Files
     6: begin
        end;
     end;
FormResize(Sender);
Tree.Repaint;
Screen.Cursor:=crDefault;
end;
end;

{
    Resize form
}
procedure TMainForm.FormResize(Sender: TObject);
begin
if Grid.Visible then
   begin
   Grid.Ctl3D:=true;
   if Grid.RowCount>1 then Grid.FixedRows:=1;
   Grid.Refresh;
   end;
end;

{
             Check process tree expansion
}
procedure TMainForm.TreeExpanding(Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean);
var
   A,B,C,D,E: Longint;
   FNode,SNode: TTreeNode;
   S, T, Len: String;
   Fl: Boolean;
   PLBuff, DTBuff: PP;
begin
SetCC;
if Node.ImageIndex=5 then
   begin
   PME:=false;
   PLBuff:=nil;
   DTBuff:=nil;
   CheckReceiver;
   // reading descriptor table
   D:=ReadWholeObject(DescriptorSel,CP,DTBuff);
   // reading process list
   A:=0;
   if ReadObject(SysSel,$1E,2,@A,CP) then
      begin
      GetMem(PLBuff,A*4);
      FillChar(PLBuff[0],A*4,0);
      if not ReadObject(ProcessSel,0,A*4,PLBuff,CP) then A:=0;
      end;
   C:=A;
   // fill the PTree
   S:='PL '+Chr(13);
   if Length(CP)<>0 then Len:=IntToHex(Length(S),4)
                    else Len:='';
   S:=CP+Len+S;
   CheckReceiver;
   StrPCopy(FT_Out_Buffer,S);
   if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                    else Com.Comm1.Write(FT_Out_Buffer,Length(S));
   B:=21;
   if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
      else begin
      Sleep(Length(S)+B);
      A:=Com.Comm1.Read(FT_In_Buffer,B);
      end;
   Fl:=true;
   while Fl do
         begin
         Fl:=false;
         for E:=0 to Tree.Items.Count-1 do
             if Tree.Items[E].Parent=Node then
                begin
                Tree.Items[E].Delete;
                Fl:=true;
                Break;
                end;
         end;
   if B=A then
      begin
      FT_In_Buffer[A]:=#0;
      S:=StrPas(FT_In_Buffer);
      Delete(S,1,5);
      B:=HexToInt(S);
      while B<>0 do
            begin
            if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
                             else A:=Com.Comm1.Read(FT_In_Buffer,B);
            if B<>A then B:=0
               else begin
               FT_In_Buffer[A]:=#0;
               S:=StrPas(FT_In_Buffer);
               GetWord(S,T);
               FNode:=Tree.Items.AddChild(Node,T);
               FNode.ImageIndex:=100;
               GetWord(S,T);
               FNode.SelectedIndex:=HexToInt(T);              // selector of process object
               RemoveFirstSpaces(S);
               FNode.StateIndex:=HexToInt(Copy(S,1,16));      // selector PSO
               if FNode.StateIndex<>0 then
                  begin
                  T:='[suspended]';
                  if (PLBuff<>nil)and(C<>0) then
                     for A:=0 to C-1 do
                         begin
                         Move(PLBuff[A*4],B,4);
                         if B=FNode.StateIndex then T:='[active]';
                         end;
                  FNode.Text:=FNode.Text+' '+T;
                  // add objects to tree
                  SNode:=Tree.Items.AddChild(FNode,'PSO '+IntToHex(FNode.StateIndex,6));
                  SNode.ImageIndex:=101;
                  SNode.SelectedIndex:=FNode.StateIndex;
                  SNode:=Tree.Items.AddChild(FNode,'Export table');
                  SNode.ImageIndex:=103;
                  SNode:=Tree.Items.AddChild(FNode,'Import table');
                  SNode.ImageIndex:=104;
                  if (D shr 5)<>0 then
                     for A:=0 to (D shr 5)-1 do
                         begin
                         Move(DTBuff[(A shl 5)+24],B,4);
                         if B=FNode.StateIndex then
                            begin
                            SNode:=Tree.Items.AddChild(FNode,'Object '+IntToHex(A,6));
                            SNode.ImageIndex:=102;
                            SNode.StateIndex:=B;
                            SNode.SelectedIndex:=A;    // display mode
                            end;
                         end;
                  end;
               B:=16;
               if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
                                else A:=Com.Comm1.Read(FT_In_Buffer,B);
               if B<>A then B:=0
                  else begin
                  FT_In_Buffer[A]:=#0;
                  S:=StrPas(FT_In_Buffer);
                  B:=HexToInt(S);
                  end;
               end;
            end;
      if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,3,@A)
                       else A:=Com.Comm1.Read(FT_In_Buffer,3);
      end;
   if not Node.HasChildren then
      begin
      FNode:=Tree.Items.AddChild(Node,'<empty>');
      FNode.ImageIndex:=-1;
      end;
   Application.ProcessMessages;
   FormResize(Sender);
   if PLBuff<>nil then FreeMem(PLBuff);
   if DTBuff<>nil then FreeMem(DTBuff);
   PME:=true;
   end;
end;

{
              Checking receiver
}
procedure TMainForm.CheckReceiver;
var
   A: LongInt;
   Read_Result: Integer;
   S: String;
begin
PME:=false;
A:=0;
Read_Result:=0;
if USBDevice<>''
   then begin
        FT_GetQueueStatus(FT_Handle,@A);
        if A>0 then FT_Read(FT_Handle,@FT_In_Buffer,A,@Read_Result);
        end
   else if Com.Comm1.Handle>0
           then begin
           A:=Com.Comm1.InQueCount;
           if A>0 then Read_Result:=Com.Comm1.Read(FT_In_Buffer,A)
              else if A=-1 then
                      begin
                      Read_Result:=0;
                      Com.Comm1.Close;
                      Tree.Items.Clear;
                      REdit.Visible:=false;
                      Grid.Visible:=false;
                      FilesBox.Clear;
                      FilesBox.Visible:=false;
                      if PMonForm.Visible then PMonForm.Close;
                      MainState:=0;
                      MainStatus.SimpleText:='No connections';
                      end;
           end;
if Read_Result<>0 then
   begin
   FT_In_Buffer[Read_Result]:=Chr(0);
   S:=StrPas(FT_In_Buffer);
   if Pos(#$BB,S)<>0 then ReadBkpt
      else if Length(S)<>0 then
              if S[1]<>Chr(8) then MainEdit.Text:=MainEdit.Text+S
                 else if MainEdit.Text[Length(MainEdit.Text)]<>Chr(10) then MainEdit.Text:=Copy(MainEdit.Text,1,Length(MainEdit.Text)-1);
   MainEdit.SelStart:=Length(MainEdit.Text);
   end;
PME:=true;
end;

// clear status
procedure TMainForm.Clear1Click(Sender: TObject);
begin
MainEdit.Clear;
end;

{
    Process tree
}
procedure TMainForm.TreeChange(Sender: TObject; Node: TTreeNode);
var
   Ax,Bx,Cx,Dx,Ex: Int64;
   A,B,C,D,E,F,Cl: Longint;
   S: String;
   Buff: array [0..63] of Byte;
   PBuff: PP;

begin
SetCC;
Screen.Cursor:=crHourGlass;
case Node.ImageIndex of
     // name of the process
     100: begin
          PME:=false;
          Grid.Visible:=false;
          REdit.Visible:=true;
          REdit.Clear;
          CheckReceiver;
          if ReadObject(Node.SelectedIndex,$4C,52,@Buff[0],CP) then
             begin
             // Root node of process
             REdit.Paragraph.Alignment:=taCenter;
             REdit.SelAttributes.Size:=10;
             REdit.SelAttributes.Style:=[fsBold];
             S:='Process: '+Copy(Node.Text,1,Pos(' ',Node.Text)-1);
             REdit.Lines.Add(S);
             REdit.Paragraph.Alignment:=taLeftJustify;
             REdit.SelAttributes.Size:=9;
             REdit.SelAttributes.Style:=[];
             REdit.Lines.Add('');
             Move(Buff[0],A,4);
             REdit.Lines.Add('Starting CPL:'+#9+#9+IntToStr((A shr 18)and 3));
             REdit.Lines.Add('Task ID:'+#9+#9+IntToHex(A and $FFFF,4));
             if (A and $100000)<>0 then REdit.Lines.Add('Errors processing:'+#9+'Enabled')
                                   else REdit.Lines.Add('Errors processing:'+#9+'Disabled');
             if (A and $200000)<>0 then REdit.Lines.Add('Hardware interrupts:'+#9+'Enabled')
                                   else REdit.Lines.Add('Hardware interrupts:'+#9+'Disabled');
             if (A and $400000)<>0 then REdit.Lines.Add('Process switching:'+#9+'Enabled')
                                   else REdit.Lines.Add('Process switching:'+#9+'Disabled');
             if (A and $800000)<>0 then REdit.Lines.Add('Messages processing:'+#9+'Enabled')
                                   else REdit.Lines.Add('Messages processing:'+#9+'Disabled');
             // starting code offset
             Ax:=0;
             Move(Buff[4],Ax,4);
             REdit.Lines.Add('Starting offset:'+#9+#9+IntToHex(Ax,10));
             Ax:=0;
             Move(Buff[8],Ax,4);
             REdit.Lines.Add('Max. avail. memory:'+#9+IntToStr(Ax shr 5)+' Kb');
             Move(Buff[12],Ax,4);
             REdit.Lines.Add('Max. avail. objects:'+#9+IntToStr(Ax));
             Ax:=0;
             Move(Buff[16],Ax,4);
             REdit.Lines.Add('System stack size:'+#9+IntToStr(Ax)+' Bytes');
             Move(Buff[20],Ax,4);
             REdit.Lines.Add('Activation timer:'+#9+FloatToStrF(Ax*0.2,ffFixed,10,1)+' 탎');
             Ax:=0;
             Move(Buff[24],Ax,2);
             REdit.Lines.Add('System queue length:'+#9+IntToStr(Ax));
             Move(Buff[26],Ax,2);
             REdit.Lines.Add('Regular queue length:'+#9+IntToStr(Ax));

             REdit.Paragraph.Alignment:=taCenter;
             REdit.SelAttributes.Style:=[fsBold];
             REdit.Lines.Add('Program stacks sizes');
             REdit.Paragraph.Alignment:=taLeftJustify;
             REdit.SelAttributes.Style:=[];
             Move(Buff[28],Ax,2);
             REdit.Lines.Add('Stack for CPL=0:'+#9+IntToStr(Ax shr 5)+' Kb');
             Move(Buff[30],Ax,2);
             REdit.Lines.Add('Stack for CPL=1:'+#9+IntToStr(Ax shr 5)+' Kb');
             Move(Buff[32],Ax,2);
             REdit.Lines.Add('Stack for CPL=2:'+#9+IntToStr(Ax shr 5)+' Kb');
             Move(Buff[34],Ax,2);
             REdit.Lines.Add('Stack for CPL=3:'+#9+IntToStr(Ax shr 5)+' Kb');

             REdit.Paragraph.Alignment:=taCenter;
             REdit.SelAttributes.Style:=[fsBold];
             REdit.Lines.Add('Message tables');
             REdit.Paragraph.Alignment:=taLeftJustify;
             REdit.SelAttributes.Style:=[];
             Move(Buff[36],Ax,2);
             REdit.Lines.Add('Export table records:'+#9+IntToStr(Ax));
             Move(Buff[38],Ax,2);
             REdit.Lines.Add('Import table records:'+#9+IntToStr(Ax));
             end;
          PME:=true;
          end;
     // PSO display
     101: begin
          PME:=false;
          Grid.Visible:=false;
          REdit.Visible:=true;
          REdit.Clear;
          CheckReceiver;
          if ReadWholeObject(Node.SelectedIndex,CP,PBuff)>0 then
             begin
             REdit.Paragraph.Alignment:=taCenter;
             REdit.SelAttributes.Style:=[fsBold];
             REdit.SelAttributes.Size:=10;
             REdit.Lines.Add('PSO Header information');
             REdit.Paragraph.Alignment:=taLeftJustify;
             REdit.SelAttributes.Size:=9;
             // timer value
             Ax:=0;
             Move(PBuff[0],Ax,2);
             REdit.Lines.Add('Activation timer:'+#9+FloatToStrF(Ax*0.2,ffFixed,10,1)+' 탎');
             // remained free memory
             A:=4;
             Move(PBuff[A],Ax,4);
             REdit.Lines.Add('Remained available memory:'+#9+IntToStr(Ax shr 5)+' Kb');
             // remained free objects
             A:=8;
             Move(PBuff[A],Ax,4);
             REdit.Lines.Add('Remained available objects:'+#9+IntToStr(Ax));
             // export table
             A:=12;
             Ax:=0;
             Bx:=0;
             Move(PBuff[A],Ax,4);
             A:=16;
             Move(PBuff[A],Bx,4);
             REdit.Lines.Add('Exported procedures table offset: '+IntToHex(Ax,8)+'h, count: '+IntToStr(Bx));
             // import table
             A:=20;
             Ax:=0;
             Bx:=0;
             Move(PBuff[A],Ax,4);
             A:=24;
             Move(PBuff[A],Bx,4);
             REdit.Lines.Add('Imported procedures table offset: '+IntToHex(Ax,8)+'h, count: '+IntToStr(Bx));
             // System messages queue
             A:=28; Move(PBuff[A],Ax,4);
             A:=32; B:=0; C:=0; D:=0;
             Move(PBuff[A],B,2); Move(PBuff[A+4],C,2); Move(PBuff[A+6],D,2);
             REdit.Lines.Add('System messages queue offset: '+IntToHex(Ax,8)+'h, length: '+IntToStr(B)+', RPTR: '+IntToStr(C)+', WPTR: '+IntToStr(D));
             // regular messages queue
             A:=40; Move(PBuff[A],Ax,4);
             A:=44; B:=0; C:=0; D:=0;
             Move(PBuff[A],B,2); Move(PBuff[A+4],C,2); Move(PBuff[A+6],D,2);
             REdit.Lines.Add('Regular messages queue offset: '+IntToHex(Ax,8)+'h, length: '+IntToStr(B)+', RPTR: '+IntToStr(C)+', WPTR: '+IntToStr(D));
             // context stack parameters
             A:=52; Ax:=0; Bx:=0; Move(PBuff[A],Ax,4);
             S:='Context stack offset: '+IntToHex(Ax,8)+'h';
             Move(PBuff[A+4],B,4); S:=S+' length: '+IntToStr(B);
             Move(PBuff[A+8],Bx,4); S:=S+' pointer: '+IntToHex(Bx,8)+'h';
             REdit.Lines.Add(S);
             // processing stack frames
             Cx:=0; A:=0;
             while Cx<=Bx do
                   begin
                   REdit.Paragraph.Alignment:=taCenter;
                   REdit.SelAttributes.Style:=[fsBold];
                   REdit.SelAttributes.Size:=10;
                   Move(PBuff[Cx+Ax+8],B,4);
                   if (B and $F8000000)=0 then REdit.Lines.Add('Context frame '+IntToStr(A)+' X16 mode')
                                          else REdit.Lines.Add('Context frame '+IntToStr(A)+' X32 mode');
                   F:=B and $F8000000;                                                            // store type of context
                   REdit.Paragraph.Alignment:=taLeftJustify;
                   REdit.SelAttributes.Size:=9;
                   Move(PBuff[Ax+Cx],Cl,4); Move(PBuff[Ax+Cx+4],D,4);
                   REdit.Lines.Add('Context length: '+IntToStr(Cl)+#9+#9+#9+'Message parameter: '+IntToHex(D,8)+'h');
                   Dx:=0; Move(PBuff[Ax+Cx+16],Dx,5);
                   REdit.Lines.Add('CSR: '+IntToHex(B,8)+'h'+#9+#9+#9+'IP: '+IntToHex(Dx,10)+'h');
                   S:='';
                   for C:=0 to 3 do
                       begin
                       Dx:=0; Move(PBuff[8+Ax+Cx+16+C*16],Dx,5); Move(PBuff[8+Ax+Cx+24+C*16],B,4);
                       if Length(S)<>0 then S:=S+#9;
                       S:=S+'SP CPL'+IntToStr(C)+': '+IntToHex(B,8)+'['+IntToHex(Dx,10)+']';
                       end;
                   REdit.Lines.Add(S);
                   REdit.Paragraph.Alignment:=taLeftJustify;
                   REdit.SelAttributes.Style:=[fsBold];
                   REdit.SelAttributes.Size:=9;
                   REdit.Lines.Add('Nn'+#9+'GPR'+#9+#9+#9+#9+#9+#9+'AFR'+#9+#9+'ADR');
                   REdit.Paragraph.Alignment:=taLeftJustify;
                   REdit.SelAttributes.Size:=9;
                   REdit.SelAttributes.Style:=[];
                   if F=0
                      then for C:=0 to 15 do
                               begin
                               Move(PBuff[8+Ax+Cx+208+C*8],Dx,8);
                               S:='';
                               if C<10 then S:='0';
                               S:=S+IntToStr(C)+':'+#9+IntToHex(Dx,16);
                               Move(PBuff[8+Ax+Cx+80+C*8],Dx,8);
                               S:=S+IntToHex(Dx,16)+'h'+#9;
                               Move(PBuff[8+Ax+Cx+336+C*8],B,4);
                               S:=S+IntToHex(B,8)+'h'+#9;
                               Dx:=0;
                               Move(PBuff[8+Ax+Cx+464+C*8],Dx,5);
                               S:=S+IntToHex(Dx,10)+'h';
                               REdit.Lines.Add(S);
                               end
                      else for C:=0 to 31 do
                               begin
                               Move(PBuff[8+Ax+Cx+336+C*8],Dx,8);
                               S:='';
                               if C<10 then S:='0';
                               S:=S+IntToStr(C)+':'+#9+IntToHex(Dx,16);
                               Move(PBuff[8+Ax+Cx+80+C*8],Dx,8);
                               S:=S+IntToHex(Dx,16)+'h'+#9;
                               Move(PBuff[8+Ax+Cx+592+C*8],B,4);
                               S:=S+IntToHex(B,8)+'h';
                               if C<16 then
                                  begin
                                  Dx:=0;
                                  Move(PBuff[8+Ax+Cx+848+C*8],Dx,5);
                                  S:=S+#9+IntToHex(Dx,10)+'h';
                                  end;
                               REdit.Lines.Add(S);
                               end;
                   if F=0 then begin
                               Cl:=Cl-592;
                               Dx:=592;
                               end
                          else begin
                               Cl:=Cl-976;
                               Dx:=976;
                               end;
                   if Cl<>0 then
                      begin
                      REdit.Paragraph.Alignment:=taLeftJustify;
                      REdit.SelAttributes.Style:=[fsBold];
                      REdit.SelAttributes.Size:=9;
                      REdit.Lines.Add(#9+'Application-specific context:');
                      REdit.Paragraph.Alignment:=taLeftJustify;
                      REdit.SelAttributes.Size:=9;
                      REdit.SelAttributes.Style:=[];
                      S:='';
                      while Cl<>0 do
                            begin
                            if Length(S)>71 then
                               begin
                               REdit.Lines.Add(S);
                               S:='';
                               end;
                            Move(PBuff[8+Ax+Cx+Dx],Ex,8);
                            S:=S+IntToHex(Ex,16)+'h ';
                            Inc(Dx,8);
                            Dec(Cl,8);
                            end;
                      REdit.Lines.Add(S);
                      end;
                   Move(PBuff[Cx+Ax],B,4);
                   Cx:=Cx+16+B;
                   Inc(A);
                   end;
             end;
          PME:=true;
          end;
     // if object
     102: begin
          REdit.Visible:=false;
          Grid.Visible:=false;
          Grid.RowCount:=1;
          Grid.ColCount:=1;
          ObjStart:=0; ObjLength:=0;
          Grid.Tag:=Node.SelectedIndex;
          Grid.Visible:=true;
          FormResize(Sender);
          end;
     // if export table
     103: begin
          PME:=false;
          Grid.Visible:=false;
          REdit.Visible:=true;
          REdit.Clear;
          REdit.Paragraph.Alignment:=taCenter;
          REdit.SelAttributes.Size:=10;
          REdit.SelAttributes.Style:=[fsBold];
          S:='Exported procedures';
          REdit.Lines.Add(S);
          REdit.Paragraph.Alignment:=taLeftJustify;
          REdit.SelAttributes.Size:=9;
          REdit.SelAttributes.Style:=[];
          REdit.Lines.Add('');
          A:=0;
          B:=0;
          CheckReceiver;
          if ReadObject(Node.Parent.SelectedIndex,$70,2,@A,CP) then
             if A=0 then REdit.Lines.Add('Process has no exported procedures')
                else if ReadPartialObject(Node.Parent.SelectedIndex,$80,A*64,PBuff,CP) then
                    begin
                    while A<>0 do
                          begin
                          if PBuff[B]=0 then REdit.Lines.Add('Empty entry')
                          else begin
                          case (PBuff[B+59] shr 2) and 3 of
                               0: S:='Interrupt handler: ';
                               1: S:='Procedure: ';
                               2: S:='System message: ';
                               3: S:='Regular message: ';
                               end;
                          C:=0;
                          while PBuff[B+C]<>0 do
                                begin
                                S:=S+Chr(PBuff[B+C]); Inc(C);
                                end;
                          REdit.Lines.Add(S);
                          REdit.Lines.Add(#9+'Entry PL: '+IntToStr(PBuff[B+59] and 3));
                          if (PBuff[B+59] and $10)<>0 then REdit.Lines.Add(#9+'Hardware interrupts: Enabled')
                                                   else REdit.Lines.Add(#9+'Hardware interrupts: Disabled');
                          if (PBuff[B+59] and $20)<>0 then REdit.Lines.Add(#9+'Process switching: Enabled')
                                                   else REdit.Lines.Add(#9+'Process switching: Disabled');
                          if (PBuff[B+59] and $40)<>0 then REdit.Lines.Add(#9+'Message processing: Enabled')
                                                   else REdit.Lines.Add(#9+'Message processing: Disabled');
                          if (PBuff[B+59] and $80)<>0 then REdit.Lines.Add(#9+'PL and TaskID passed from caller')
                                                   else REdit.Lines.Add(#9+'PL and TaskID extracted from code object');
                          // reading procedure object
                          E:=PBuff[B+58];
                          CheckReceiver;
                          if ReadObject(Node.Parent.SelectedIndex,$70,4,@Buff[0],CP) then
                             begin
                             C:=0; D:=0; Move(Buff[0],C,2); Move(Buff[2],D,2);
                             C:=(C shl 6)+(D shl 7)+128;
                             while E<>0 do
                                   if not ReadObject(Node.Parent.SelectedIndex,C+$40,4,@Buff[0],CP) then E:=0
                                      else begin
                                      D:=0;
                                      Move(Buff[0],D,4);
                                      C:=C+(D shl 5);
                                      Dec(E);
                                      end;
                             CheckReceiver;
                             if ReadObject(Node.Parent.SelectedIndex,C,64,@Buff[0],CP) then
                                begin
                                S:='';
                                C:=0;
                                while Buff[C]<>0 do
                                      begin
                                      S:=S+Chr(Buff[C]); Inc(C);
                                      end;
                                REdit.Lines.Add(#9+'Object name: '+S);
                                C:=0;
                                Move(Buff[60],C,4);
                                REdit.Lines.Add(#9+'Procedure selector: '+IntToHex(C,8)+'h');
                                end;
                             end;

                          Move(PBuff[B+60],C,4);
                          REdit.Lines.Add(#9+'Procedure offset: '+IntToHex(C,8)+'h');
                          REdit.Lines.Add('');
                          end;
                          B:=B+64;
                          Dec(A);
                          end;
                    FreeMem(PBuff);
                    end;
          PME:=true;
          end;
     // imported procedures
     104: begin
          PME:=false;
          Grid.Visible:=false;
          REdit.Visible:=true;
          REdit.Clear;
          REdit.Paragraph.Alignment:=taCenter;
          REdit.SelAttributes.Size:=10;
          REdit.SelAttributes.Style:=[fsBold];
          S:='Imported procedures';
          REdit.Lines.Add(S);
          REdit.Paragraph.Alignment:=taLeftJustify;
          REdit.SelAttributes.Size:=9;
          REdit.SelAttributes.Style:=[];
          REdit.Lines.Add('');
          A:=0; B:=0; C:=0;
          CheckReceiver;
          if ReadObject(Node.Parent.SelectedIndex,$70,2,@A,CP) then
             if ReadObject(Node.Parent.SelectedIndex,$72,2,@B,CP) then
                if B=0 then REdit.Lines.Add('Process has no import procedures')
                   else if ReadPartialObject(Node.Parent.SelectedIndex,$80+A*64,B*128,PBuff,CP) then
                    begin
                    while B<>0 do
                          begin
                          if PBuff[C]=0 then REdit.Lines.Add('Empty entry')
                             else begin
                             S:='Process: ';
                             D:=0;
                             while PBuff[C+D]<>0 do
                                   begin
                                   S:=S+Chr(PBuff[C+D]);
                                   Inc(D);
                                   end;
                             S:=S+#9+#9+#9+'Entry: ';
                             D:=64;
                             while PBuff[C+D]<>0 do
                                   begin
                                   S:=S+Chr(PBuff[C+D]);
                                   Inc(D);
                                   end;
                             REdit.Lines.Add(S);
                             end;
                          C:=C+128;
                          Dec(B);
                          end;
                    FreeMem(PBuff);
                    end;
          PME:=true;
          end;
     end;
Screen.Cursor:=crDefault;
end;

{
    Draw table
}
procedure TMainForm.GridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   A,B,C,D,E: Longint;
   Ax: Int64;
   Asp: Single;
   Adp: Double;
   Buff: PP;
begin
if Grid.Visible and (Grid.Tag<>0) then
   begin
   PME:=false;
   if (Grid.ColCount=1)and(Grid.RowCount=1) then
      begin
      // if it's a first data table drawing
      A:=Grid.Canvas.TextWidth('__')+6;
      if Word1.Checked then A:=Grid.Canvas.TextWidth('____')+6;
      if DWord1.Checked then A:=Grid.Canvas.TextWidth('________')+6;
      if QWord1.Checked then A:=Grid.Canvas.TextWidth('________________')+6;
      if OWord1.Checked then A:=Grid.Canvas.TextWidth('________________________________')+6;
      if Integer321.Checked then A:=Grid.Canvas.TextWidth('__________')+6;
      if Integer641.Checked then A:=Grid.Canvas.TextWidth('______________________')+6;
      if Float321.Checked then A:=Grid.Canvas.TextWidth('_____________')+6;
      if Float641.Checked then A:=Grid.Canvas.TextWidth('__________________________')+6;
      B:=Trunc((Grid.Width-Grid.Canvas.TextWidth('________')+6)/A);
      if B=0 then B:=1;
      C:=1;
      while B>1 do
            begin
            B:=B shr 1;
            Inc(C);
            end;
      B:=1 shl (C-1);
      Grid.ColCount:=B+1;
      Grid.DefaultColWidth:=A;
      Grid.ColWidths[0]:=Grid.Canvas.TextWidth('________')+6;
      A:=(Trunc(Grid.Height/Grid.DefaultRowHeight)-1)*B;                                      // calculate maximum block size in data elements
      if ObjLength<>0 then C:=ObjLength
         else begin
         CheckReceiver;
         C:=GetObjectLength(CP,Grid.Tag);
         ObjLength:=C;
         end;
      C:=C-ObjStart;
      if Word1.Checked then C:=C shr 1;
      if DWord1.Checked then C:=C shr 2;
      if QWord1.Checked then C:=C shr 3;
      if OWord1.Checked then C:=C shr 4;
      if Integer321.Checked then C:=C shr 2;
      if Integer641.Checked then C:=C shr 3;
      if Float321.Checked then C:=C shr 2;
      if Float641.Checked then C:=C shr 3;
      if C<A then A:=Trunc((C-1)/B)+1
             else A:=Trunc((A-1)/B)+1;
      Grid.RowCount:=A+1;
      Grid.FixedCols:=1;
      Grid.FixedRows:=1;
      Grid.Options:=Grid.Options-[goRowSelect];
      D:=1;
      if Word1.Checked then D:=2;
      if DWord1.Checked then D:=4;
      if QWord1.Checked then D:=8;
      if OWord1.Checked then D:=16;
      if Integer321.Checked then D:=4;
      if Integer641.Checked then D:=8;
      if Float321.Checked then D:=4;
      if Float641.Checked then D:=8;
      for C:=0 to B-1 do Grid.Cells[1+C,0]:=IntToHex(C*D,2);
      A:=ObjStart;
      Grid.Cells[0,0]:=IntToHex(Grid.Tag,6);
      for C:=0 to Grid.RowCount-2 do
          begin
          Grid.Cells[0,C+1]:=IntToHex(A,8);
          A:=A+D*B;
          end;
      if A>ObjLength then A:=ObjLength-ObjStart
                     else A:=A-ObjStart;
      CheckReceiver;
      if ReadPartialObject(Grid.Tag,ObjStart,A,Buff,CP) then
         begin
         E:=ObjStart;
         A:=0;
         for B:=0 to Grid.RowCount-2 do
             begin
             for C:=0 to Grid.ColCount-2 do
                 if E=ObjLength then Grid.Cells[C+1,B+1]:=''
                 else begin
                 if Byte1.Checked then Grid.Cells[C+1,B+1]:=IntToHex(Buff[A],2);
                 if Word1.Checked then Grid.Cells[C+1,B+1]:=IntToHex((Buff[A+1] shl 8)or(Buff[A]),4);
                 if DWord1.Checked then Grid.Cells[C+1,B+1]:=IntToHex((Buff[A+3] shl 24)or(Buff[A+2] shl 16)or(Buff[A+1] shl 8)or(Buff[A]),8);
                 if QWord1.Checked then Grid.Cells[C+1,B+1]:=IntToHex((Buff[A+7] shl 24)or(Buff[A+6] shl 16)or(Buff[A+5] shl 8)or(Buff[A+4]),8)+IntToHex((Buff[A+3] shl 24)or(Buff[A+2] shl 16)or(Buff[A+1] shl 8)or(Buff[A]),8);
                 if OWord1.Checked then Grid.Cells[C+1,B+1]:= IntToHex((Buff[A+15] shl 24)or(Buff[A+14] shl 16)or(Buff[A+13] shl 8)or(Buff[A+12]),8)+
                                                              IntToHex((Buff[A+11] shl 24)or(Buff[A+10] shl 16)or(Buff[A+9] shl 8)or(Buff[A+8]),8)+
                                                              IntToHex((Buff[A+7] shl 24)or(Buff[A+6] shl 16)or(Buff[A+5] shl 8)or(Buff[A+4]),8)+
                                                              IntToHex((Buff[A+3] shl 24)or(Buff[A+2] shl 16)or(Buff[A+1] shl 8)or(Buff[A]),8);
                 if Integer321.Checked then Grid.Cells[C+1,B+1]:=IntToStr((Buff[A+3] shl 24)or(Buff[A+2] shl 16)or(Buff[A+1] shl 8)or(Buff[A]));
                 if Integer641.Checked then
                    begin
                    Move(Buff[A],Ax,8);
                    Grid.Cells[C+1,B+1]:=IntToStr(Ax);
                    end;
                 if Float321.Checked then
                    begin
                    Move(Buff[A],Asp,4);
                    Grid.Cells[C+1,B+1]:=FloatToStrF(Asp,ffGeneral,8,8);
                    end;
                 if Float641.Checked then
                    begin
                    Move(Buff[A],Adp,8);
                    Grid.Cells[C+1,B+1]:=FloatToStrF(Adp,ffGeneral,15,15);
                    end;
                 A:=A+D;
                 E:=E+D;
                 end;
             if E=ObjLength then Break;
             end;
         FreeMem(Buff);
         end;
      end;
   PME:=true;
   end;
end;

// Grid menu popup
procedure TMainForm.GridMenuPopup(Sender: TObject);
var
   A: Longint;
begin
Viewobject1.Enabled:=false;
ViewasPSO1.Enabled:=Viewobject1.Enabled;
Deleteobject1.Enabled:=Viewobject1.Enabled;
if Tree.Selected<>nil then
   if Grid.Cells[0,0]='Selector' then
        begin
        Viewobject1.Enabled:=Grid.Cells[1,Grid.Selection.Top]='Object';
        ViewasPSO1.Enabled:=Viewobject1.Enabled;
        // check object type
        A:=HexToInt(Grid.Cells[0,Grid.Selection.Top]);
        if (A=CodeSel)or(A=IOSel)or(A=SysSel)or(A=WholeRAMSel)or(A=StackSel)or(A=PSOSel)or(A=IntSel)or(A=ProcessSel)or(A=DescriptorSel)or
           (A=ServiceSel)or(A=BreakpointSel)or(A=ErrorSel)or(A=FlashCtrlSel)or(A=FlashDataSel)or(A=FlashWBSel) then Deleteobject1.Enabled:=false
           else Deleteobject1.Enabled:=Viewobject1.Enabled;
        end;
Radix1.Enabled:=Grid.Tag<>0;
end;

// change data display mode
procedure TMainForm.Byte1Click(Sender: TObject);
begin
if not(Byte1.Checked or Word1.Checked or DWord1.Checked or QWord1.Checked or OWord1.Checked or Integer321.Checked or Integer641.Checked or Float321.Checked or Float641.Checked) then Byte1.Checked:=true;
Grid.RowCount:=1;
Grid.ColCount:=1;
end;

{
    Down scroll
}
procedure TMainForm.GridMouseWheelDown(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
var
   A,B,C,D,E: Longint;
   Ax: Int64;
   Asp: Single;
   Adp: Double;
   Buff: PP;
begin
if (Grid.Selection.Top=(Grid.RowCount-1))and(Grid.Tag<>0) then
   begin
   PME:=false;
   Buff:=nil;
   A:=HexToInt(Grid.Cells[0,Grid.RowCount-1]);
   if Byte1.Checked then A:=A+Grid.ColCount-1;
   if Word1.Checked then A:=A+((Grid.ColCount-1)shl 1);
   if DWord1.Checked then A:=A+((Grid.ColCount-1)shl 2);
   if QWord1.Checked then A:=A+((Grid.ColCount-1)shl 3);
   if OWord1.Checked then A:=A+((Grid.ColCount-1)shl 4);
   if Integer321.Checked then A:=A+((Grid.ColCount-1)shl 2);
   if Integer641.Checked then A:=A+((Grid.ColCount-1)shl 3);
   if Float321.Checked then A:=A+((Grid.ColCount-1)shl 2);
   if Float641.Checked then A:=A+((Grid.ColCount-1)shl 3);
   D:=1;
   if Word1.Checked then D:=2;
   if DWord1.Checked then D:=4;
   if QWord1.Checked then D:=8;
   if OWord1.Checked then D:=16;
   if Integer321.Checked then D:=4;
   if Integer641.Checked then D:=8;
   if Float321.Checked then D:=4;
   if Float641.Checked then D:=8;
   if A<ObjLength then
      begin
      for B:=0 to Grid.RowCount-2 do
          for C:=0 to Grid.ColCount-1 do Grid.Cells[c,B+1]:=Grid.Cells[c,B+2];
      Grid.Cells[0,Grid.RowCount-1]:=IntToHex(A,8);
      for C:=1 to Grid.ColCount-1 do Grid.Cells[C,Grid.RowCount-1]:='';
	    ObjStart:=HexToInt(Grid.Cells[0,1]);
      C:=Grid.ColCount-1;
      if Word1.Checked then C:=(Grid.ColCount-1)shl 1;
      if DWord1.Checked then C:=(Grid.ColCount-1)shl 2;
      if QWord1.Checked then C:=(Grid.ColCount-1)shl 3;
      if OWord1.Checked then C:=(Grid.ColCount-1)shl 4;
      if Integer321.Checked then C:=(Grid.ColCount-1)shl 2;
      if Integer641.Checked then C:=(Grid.ColCount-1)shl 3;
      if Float321.Checked then C:=(Grid.ColCount-1)shl 2;
      if Float641.Checked then C:=(Grid.ColCount-1)shl 3;
      if A+C>ObjLength then C:=ObjLength-A;
      E:=0;
      CheckReceiver;
      if ReadPartialObject(Grid.Tag,A,C,Buff,CP) then
         for B:=1 to Grid.ColCount-1 do
             if A=ObjLength then Break
                else begin
                if Byte1.Checked then Grid.Cells[B,Grid.RowCount-1]:=IntToHex(Buff[E],2);
                if Word1.Checked then Grid.Cells[B,Grid.RowCount-1]:=IntToHex((Buff[E+1] shl 8)or(Buff[E]),4);
                if DWord1.Checked then Grid.Cells[B,Grid.RowCount-1]:=IntToHex((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]),8);
                if QWord1.Checked then Grid.Cells[B,Grid.RowCount-1]:=IntToHex((Buff[E+7] shl 24)or(Buff[E+6] shl 16)or(Buff[E+5] shl 8)or(Buff[E+4]),8)+IntToHex((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]),8);
                if OWord1.Checked then Grid.Cells[B,Grid.RowCount-1]:= IntToHex((Buff[E+15] shl 24)or(Buff[E+14] shl 16)or(Buff[E+13] shl 8)or(Buff[E+12]),8)+
                                                              IntToHex((Buff[E+11] shl 24)or(Buff[E+10] shl 16)or(Buff[E+9] shl 8)or(Buff[E+8]),8)+
                                                              IntToHex((Buff[E+7] shl 24)or(Buff[E+6] shl 16)or(Buff[E+5] shl 8)or(Buff[E+4]),8)+
                                                              IntToHex((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]),8);
                 if Integer321.Checked then Grid.Cells[B,Grid.RowCount-1]:=IntToStr((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]));
                 if Integer641.Checked then
                    begin
                    Move(Buff[E],Ax,8);
                    Grid.Cells[B,Grid.RowCount-1]:=IntToStr(Ax);
                    end;
                 if Float321.Checked then
                    begin
                    Move(Buff[E],Asp,4);
                    Grid.Cells[B,Grid.RowCount-1]:=FloatToStrF(Asp,ffGeneral,8,8);
                    end;
                 if Float641.Checked then
                    begin
                    Move(Buff[E],Adp,8);
                    Grid.Cells[B,Grid.RowCount-1]:=FloatToStrF(Adp,ffGeneral,15,15);
                    end;
                A:=A+D;
                E:=E+D;
                end;
      if Buff<>nil then FreeMem(Buff);
      end;
   PME:=true;
   end;
end;

{
    Scroll data up
}
procedure TMainForm.GridMouseWheelUp(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
var
   Ax: Int64;
   A,B,C,D,E: Longint;
   Asp: Single;
   Adp: Double;
   Buff: PP;
begin
if Grid.Selection.Top=1 then
begin
C:=Grid.ColCount-1;
if Word1.Checked then C:=(Grid.ColCount-1)shl 1;
if DWord1.Checked then C:=(Grid.ColCount-1)shl 2;
if QWord1.Checked then C:=(Grid.ColCount-1)shl 3;
if OWord1.Checked then C:=(Grid.ColCount-1)shl 4;
if Integer321.Checked then C:=(Grid.ColCount-1)shl 2;
if Integer641.Checked then C:=(Grid.ColCount-1)shl 3;
if Float321.Checked then C:=(Grid.ColCount-1)shl 2;
if Float641.Checked then C:=(Grid.ColCount-1)shl 3;
A:=HexToInt(Grid.Cells[0,1]);
if (ObjStart<>0)and(A-C>=0) then
   begin
   PME:=false;
   A:=A-C;
   B:=Grid.RowCount-1;
   while B<>1 do
         begin
         for D:=0 to Grid.ColCount-1 do Grid.Cells[D,B]:=Grid.Cells[D,B-1];
         Dec(B);
         end;
   Grid.Cells[0,1]:=IntToHex(A,8);
   ObjStart:=A;
   CheckReceiver;
   if ReadPartialObject(Grid.Tag,A,C,Buff,CP) then
      begin
      D:=1;
      if Word1.Checked then D:=2;
      if DWord1.Checked then D:=4;
      if QWord1.Checked then D:=8;
      if OWord1.Checked then D:=16;
      if Integer321.Checked then D:=4;
      if Integer641.Checked then D:=8;
      if Float321.Checked then D:=4;
      if Float641.Checked then D:=8;
      E:=0;
      for B:=1 to Grid.ColCount-1 do
          begin
          if Byte1.Checked then Grid.Cells[B,1]:=IntToHex(Buff[E],2);
          if Word1.Checked then Grid.Cells[B,1]:=IntToHex((Buff[E+1] shl 8)or(Buff[E]),4);
          if DWord1.Checked then Grid.Cells[B,1]:=IntToHex((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]),8);
          if QWord1.Checked then Grid.Cells[B,1]:=IntToHex((Buff[E+7] shl 24)or(Buff[E+6] shl 16)or(Buff[E+5] shl 8)or(Buff[E+4]),8)+IntToHex((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]),8);
          if OWord1.Checked then Grid.Cells[B,1]:= IntToHex((Buff[E+15] shl 24)or(Buff[E+14] shl 16)or(Buff[E+13] shl 8)or(Buff[E+12]),8)+
                                                              IntToHex((Buff[E+11] shl 24)or(Buff[E+10] shl 16)or(Buff[E+9] shl 8)or(Buff[E+8]),8)+
                                                              IntToHex((Buff[E+7] shl 24)or(Buff[E+6] shl 16)or(Buff[E+5] shl 8)or(Buff[E+4]),8)+
                                                              IntToHex((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]),8);
          if Integer321.Checked then Grid.Cells[B,1]:=IntToStr((Buff[E+3] shl 24)or(Buff[E+2] shl 16)or(Buff[E+1] shl 8)or(Buff[E]));
          if Integer641.Checked then
             begin
             Move(Buff[E],Ax,8);
             Grid.Cells[B,1]:=IntToStr(Ax);
             end;
          if Float321.Checked then
             begin
             Move(Buff[E],Asp,4);
             Grid.Cells[B,1]:=FloatToStrF(Asp,ffGeneral,8,8);
             end;
          if Float641.Checked then
             begin
             Move(Buff[E],Adp,8);
             Grid.Cells[B,1]:=FloatToStrF(Adp,ffGeneral,15,15);
             end;
          E:=E+D;
          end;
      end;
   PME:=true;
   end;
end;
end;

{
    Check the keyboard in the view data object mode
}
procedure TMainForm.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
   A,D: Longint;
   FFlag: Boolean;
begin
FFlag:=false;
if Grid.Tag<>0 then
   begin
   D:=1;
   if Word1.Checked then D:=2;
   if DWord1.Checked then D:=4;
   if QWord1.Checked then D:=8;
   if OWord1.Checked then D:=16;
   if Integer321.Checked then D:=4;
   if Integer641.Checked then D:=8;
   if Float321.Checked then D:=4;
   if Float641.Checked then D:=8;
   // page down check
   if Key=VK_NEXT	then
      if (HexToInt(Grid.Cells[0,Grid.RowCount-1])+(Grid.ColCount-1)*D)<=ObjLength then
         begin
         ObjStart:=HexToInt(Grid.Cells[0,Grid.RowCount-1]);
         Grid.RowCount:=1;
         Grid.ColCount:=1;
         Grid.Refresh;
         end;
   // arrow down
   if Key=VK_DOWN then GridMouseWheelDown(Sender,[],Point(0,0),FFlag);
   // arror up
   if Key=VK_UP then GridMouseWheelUp(Sender,[],Point(0,0),FFlag);
   // page up check
   if (Key=VK_PRIOR)and(ObjStart<>0) then
      begin
      A:=(Grid.RowCount-2)*(Grid.ColCount-1)*D;                                   // number of bytes
      if A<ObjStart then ObjStart:=ObjStart-A
                    else ObjStart:=0;
      Grid.RowCount:=1;
      Grid.ColCount:=1;
      Grid.Refresh;
      end;
   // Home hey check
   if (Key=VK_HOME)and(ObjStart<>0)and(Shift=[ssCtrl]) then
      begin
      ObjStart:=0;
      Grid.RowCount:=1;
      Grid.ColCount:=1;
      Grid.Refresh;
      end;
   // end key check
   if (Key=VK_END)and(Shift=[ssCtrl]) then
      begin
      A:=(Grid.RowCount-2)*(Grid.ColCount-1)*D;                                   // number of bytes
      if A<ObjLength then
         begin
         ObjStart:=ObjLength-A;
         Grid.RowCount:=1;
         Grid.ColCount:=1;
         Grid.Refresh;
         end;
      end;
   end;
end;

// check state
procedure TMainForm.GridSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
if Tree.Selected<>nil then
   if Tree.Selected.ImageIndex=2 then CmdBox.Refresh;
end;

{
      Double click - view object
}
procedure TMainForm.GridDblClick(Sender: TObject);
begin
if Tree.Selected<>nil then
   if Tree.Selected.ImageIndex=2 then
      if (Grid.Tag=0)and(Grid.Cells[1,Grid.Selection.Top]='Object') then
         begin
         Grid.Tag:=HexToInt(Grid.Cells[0,Grid.Selection.Top]);
         ObjStart:=0;
         ObjLength:=0;
         Grid.RowCount:=1;
         Grid.ColCount:=1;
         Grid.Refresh;
         end;
end;

{
         View object as PSO
}
procedure TMainForm.ViewasPSO1Click(Sender: TObject);
var
   Ax,Bx,Cx,Dx,Ex: Int64;
   A,B,C,D,F,Cl: Longint;
   PBuff: PP;
   S: String;
begin
PME:=false;
A:=HexToInt(Grid.Cells[0,Grid.Selection.Top]);
Grid.Visible:=false;
REdit.Visible:=true;
REdit.Clear;
REdit.Tag:=A;
CheckReceiver;
if ReadWholeObject(A,CP,PBuff)>0 then
   begin
   REdit.Paragraph.Alignment:=taCenter;
   REdit.SelAttributes.Style:=[fsBold];
   REdit.SelAttributes.Size:=10;
   REdit.Lines.Add('PSO Header information');
   REdit.Paragraph.Alignment:=taLeftJustify;
   REdit.SelAttributes.Size:=9;
   // timer value
   Ax:=0;
   Move(PBuff[0],Ax,2);
   REdit.Lines.Add('Activation timer:'+#9+FloatToStrF(Ax*0.2,ffFixed,10,1)+' 탎');
   // remained free memory
   A:=4;
   Move(PBuff[A],Ax,4);
   REdit.Lines.Add('Remained available memory:'+#9+IntToStr(Ax shr 5)+' Kb');
   // remained free objects
   A:=8;
   Move(PBuff[A],Ax,4);
   REdit.Lines.Add('Remained available objects:'+#9+IntToStr(Ax));
   // export table
   A:=12;
   Ax:=0;
   Bx:=0;
   Move(PBuff[A],Ax,4);
   A:=16;
   Move(PBuff[A],Bx,4);
   REdit.Lines.Add('Exported procedures table offset: '+IntToHex(Ax,8)+'h, count: '+IntToStr(Bx));
   // import table
   A:=20;
   Ax:=0;
   Bx:=0;
   Move(PBuff[A],Ax,4);
   A:=24;
   Move(PBuff[A],Bx,4);
   REdit.Lines.Add('Imported procedures table offset: '+IntToHex(Ax,8)+'h, count: '+IntToStr(Bx));
   // System messages queue
   A:=28; Move(PBuff[A],Ax,4);
   A:=32; B:=0; C:=0; D:=0;
   Move(PBuff[A],B,2); Move(PBuff[A+4],C,2); Move(PBuff[A+6],D,2);
   REdit.Lines.Add('System messages queue offset: '+IntToHex(Ax,8)+'h, length: '+IntToStr(B)+', RPTR: '+IntToStr(C)+', WPTR: '+IntToStr(D));
   // regular messages queue
   A:=40; Move(PBuff[A],Ax,4);
   A:=44; B:=0; C:=0; D:=0;
   Move(PBuff[A],B,2); Move(PBuff[A+4],C,2); Move(PBuff[A+6],D,2);
   REdit.Lines.Add('Regular messages queue offset: '+IntToHex(Ax,8)+'h, length: '+IntToStr(B)+', RPTR: '+IntToStr(C)+', WPTR: '+IntToStr(D));
   // context stack parameters
   A:=52; Ax:=0; Bx:=0; Move(PBuff[A],Ax,4);
   S:='Context stack offset: '+IntToHex(Ax,8)+'h';
   Move(PBuff[A+4],B,4); S:=S+' length: '+IntToStr(B);
   Move(PBuff[A+8],Bx,4); S:=S+' pointer: '+IntToHex(Bx,8)+'h';
   REdit.Lines.Add(S);
   // processing stack frames
   Cx:=0; A:=0;
   while Cx<=Bx do
         begin
         REdit.Paragraph.Alignment:=taCenter;
         REdit.SelAttributes.Style:=[fsBold];
         REdit.SelAttributes.Size:=10;
         Move(PBuff[Cx+Ax+8],B,4);
         if (B and $F8000000)=0 then REdit.Lines.Add('Context frame '+IntToStr(A)+' X16 mode')
                                else REdit.Lines.Add('Context frame '+IntToStr(A)+' X32 mode');
         F:=B and $F8000000;                                                            // store type of context
         REdit.Paragraph.Alignment:=taLeftJustify;
         REdit.SelAttributes.Size:=9;
         Move(PBuff[Ax+Cx],Cl,4); Move(PBuff[Ax+Cx+4],D,4);
         REdit.Lines.Add('Context length: '+IntToStr(Cl)+#9+#9+#9+'Message parameter: '+IntToHex(D,8)+'h');
         Dx:=0; Move(PBuff[Ax+Cx+16],Dx,5);
         REdit.Lines.Add('CSR: '+IntToHex(B,8)+'h'+#9+#9+#9+'IP: '+IntToHex(Dx,10)+'h');
         S:='';
         for C:=0 to 3 do
             begin
             Dx:=0; Move(PBuff[8+Ax+Cx+16+C*16],Dx,5); Move(PBuff[8+Ax+Cx+24+C*16],B,4);
             if Length(S)<>0 then S:=S+#9;
             S:=S+'SP CPL'+IntToStr(C)+': '+IntToHex(B,8)+'['+IntToHex(Dx,10)+']';
             end;
         REdit.Lines.Add(S);
         REdit.Paragraph.Alignment:=taLeftJustify;
         REdit.SelAttributes.Style:=[fsBold];
         REdit.SelAttributes.Size:=9;
         REdit.Lines.Add('Nn'+#9+'GPR'+#9+#9+#9+#9+#9+#9+'AFR'+#9+#9+'ADR');
         REdit.Paragraph.Alignment:=taLeftJustify;
         REdit.SelAttributes.Size:=9;
         REdit.SelAttributes.Style:=[];
         if F=0
            then for C:=0 to 15 do
                 begin
                 Move(PBuff[8+Ax+Cx+208+C*8],Dx,8);
                 S:='';
                 if C<10 then S:='0';
                 S:=S+IntToStr(C)+':'+#9+IntToHex(Dx,16);
                 Move(PBuff[8+Ax+Cx+80+C*8],Dx,8);
                 S:=S+IntToHex(Dx,16)+'h'+#9;
                 Move(PBuff[8+Ax+Cx+336+C*8],B,4);
                 S:=S+IntToHex(B,8)+'h'+#9;
                 Dx:=0;
                 Move(PBuff[8+Ax+Cx+464+C*8],Dx,5);
                 S:=S+IntToHex(Dx,10)+'h';
                 REdit.Lines.Add(S);
                 end
            else for C:=0 to 31 do
                 begin
                 Move(PBuff[8+Ax+Cx+336+C*8],Dx,8);
                 S:='';
                 if C<10 then S:='0';
                 S:=S+IntToStr(C)+':'+#9+IntToHex(Dx,16);
                 Move(PBuff[8+Ax+Cx+80+C*8],Dx,8);
                 S:=S+IntToHex(Dx,16)+'h'+#9;
                 Move(PBuff[8+Ax+Cx+592+C*8],B,4);
                 S:=S+IntToHex(B,8)+'h';
                 if C<16 then
                    begin
                    Dx:=0;
                    Move(PBuff[8+Ax+Cx+848+C*8],Dx,5);
                    S:=S+#9+IntToHex(Dx,10)+'h';
                    end;
                 REdit.Lines.Add(S);
                 end;
         if F=0 then begin
                     Cl:=Cl-592;
                     Dx:=592;
                     end
                else begin
                     Cl:=Cl-976;
                     Dx:=976;
                     end;
         if Cl<>0 then
            begin
            REdit.Paragraph.Alignment:=taLeftJustify;
            REdit.SelAttributes.Style:=[fsBold];
            REdit.SelAttributes.Size:=9;
            REdit.Lines.Add(#9+'Application-specific context:');
            REdit.Paragraph.Alignment:=taLeftJustify;
            REdit.SelAttributes.Size:=9;
            REdit.SelAttributes.Style:=[];
            S:='';
            while Cl<>0 do
                  begin
                  if Length(S)>71 then
                     begin
                     REdit.Lines.Add(S);
                     S:='';
                     end;
                  Move(PBuff[8+Ax+Cx+Dx],Ex,8);
                  S:=S+IntToHex(Ex,16)+'h ';
                  Inc(Dx,8);
                  Dec(Cl,8);
                  end;
            REdit.Lines.Add(S);
            end;
         Move(PBuff[Cx+Ax],B,4);
         Cx:=Cx+16+B;
         Inc(A);
         end;
   end;
PME:=true;
end;

{
    Delete object
}
procedure TMainForm.Deleteobject1Click(Sender: TObject);
var
   A,B,Obj: Longint;
   S, Ln: String;
begin
PME:=false;
if (Grid.Visible)and(Grid.Cells[0,0]='Selector') then Obj:=HexToInt(Grid.Cells[0,Grid.Selection.Top])
                                                 else Obj:=Tree.Selected.SelectedIndex;
if MessageDlg('Do you want to delete object: '+IntToHex(Obj,6),mtConfirmation,[mbYes,mbNo],0)=mrYes then
   begin
   S:='DO '+IntToHex(Obj,6)+Chr(13);
   if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                    else Ln:='';
   S:=CP+Ln+S;
   CheckReceiver;
   StrPCopy(FT_Out_Buffer,S);
   if USBDevice<>'' then FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A)
                    else Com.Comm1.Write(FT_Out_Buffer,Length(S));
   B:=Length(S)+6;
   if USBDevice<>'' then FT_Read(FT_Handle,@FT_In_Buffer,B,@A)
      else begin
      Sleep(B+Length(S));
      A:=Com.Comm1.Read(FT_In_Buffer,B);
      end;
   if A=B then
      begin
      MainEdit.Lines.Add('Object '+IntToHex(Obj,6)+' deleted.');
      if FT_In_Buffer[B-1]=#$BB then ReadBkpt;
      end;
   RefreshDT;
   RefreshTree;
   end;
PME:=true;
end;

{
       Check state of the files box
}
procedure TMainForm.TreeCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; var DefaultDraw: Boolean);
var
   Nd: TTreeNode;
   S: String;
begin
if Node.ImageIndex<>6 then Tree.Canvas.Font.Style:=[]
   else if FilesBox.Visible then Tree.Canvas.Font.Style:=[fsBold]
        else Tree.Canvas.Font.Style:=[];
Nd:=Node;
while Nd.Parent<>nil do Nd:=Nd.Parent;
if (Length(CP)=0)and(Nd.StateIndex=MasterCPU) then Tree.Canvas.Font.Color:=clBlack
   else if Length(CP)=0 then Tree.Canvas.Font.Color:=clGray
           else if CP='@'+IntToHex(Nd.StateIndex,2) then Tree.Canvas.Font.Color:=clBlack
                   else Tree.Canvas.Font.Color:=clGray;
end;

{
    ON/OFF files box
}
procedure TMainForm.TreeDblClick(Sender: TObject);
begin
SetCC;
if Tree.Selected<>nil then
   if Tree.Selected.ImageIndex=6 then
      if FilesBox.Visible then
         begin
         FileSplitter.Visible:=false;
         FilesBox.Visible:=false;
         Tree.Refresh;
         end
      else begin
      FilesBox.Visible:=true;
      FileSplitter.Visible:=true;
      RefreshFiles;
      Tree.Refresh;
      end;
end;

{
    Refresh descriptor table
}
procedure TMainForm.RefreshDT;
var
   A: Longint;
begin
if (Grid.Visible)and(Grid.Cells[0,0]='Selector') then
   for A:=0 to Tree.Items.Count-1 do
       if Tree.Items[A].HasAsParent(CoreNode) then
          if Tree.Items[A].ImageIndex=2 then
             begin
             Tree.Items[A].Selected:=true;
             TreeClick(nil);
             end;
end;

{
    Refresh process tree
}
procedure TMainForm.RefreshTree;
var
   A: Longint;
begin
for A:=0 to Tree.Items.Count-1 do
    if Tree.Items[A].HasAsParent(CoreNode) then
       if (Tree.Items[A].Expanded)and(Tree.Items[A].ImageIndex=5) then
          begin
          Tree.Items[A].Collapse(true);
          Tree.Items[A].Selected:=true;
          Tree.Items[A].Expand(true);
          Break;
          end;
end;

{
 Refresh files list
}
procedure TMainForm.RefreshFiles;
var
   A,B: Longint;
   S,Ln: String;
begin
PME:=false;
// read the files catalog
FilesBox.Items.Clear;
S:='GC '+Chr(13);
if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                 else Ln:='';
S:=CP+Ln+S;
CheckReceiver;
StrPCopy(FT_Out_Buffer,S);
FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
FT_Read(FT_Handle,@FT_In_Buffer,23,@A);
if A=23 then
   begin
   FT_In_Buffer[A]:=Chr(0);
   S:=StrPas(FT_In_Buffer);
   Delete(S,1,5);
   S:=Copy(S,1,16);
   B:=HexToInt(S);
   if B=0 then FT_Read(FT_Handle,@FT_In_Buffer,1,@A)
      else begin
      FT_Read(FT_Handle,@FT_In_Buffer,B+1,@A);
      if B+1=A then
         begin
         FT_In_Buffer[A-1]:=Chr(0);
         S:=StrPas(FT_In_Buffer);
         FilesBox.Items.Text:=S;
         end;
      end;
   end;
PME:=true;
end;

{
    Set the core number and prefix
}
procedure TMainForm.SetCC;
var
   Node: TTreeNode;
begin
if Tree.Selected<>nil then
   begin
   Node:=Tree.Selected;
   while Node.Parent<>nil do Node:=Node.Parent;
   if Node.StateIndex<>MasterCPU then CP:='@'+IntToHex(Node.StateIndex,2)
                                 else CP:='';
   end;
end;

// files menu popup
procedure TMainForm.FilesMenuPopup(Sender: TObject);
begin
if FilesBox.ItemIndex>=0
   then begin
        Loadtomemory1.Enabled:=true;
        Delete1.Enabled:=true;
        end
   else begin
        Loadtomemory1.Enabled:=false;
        Delete1.Enabled:=false;
        end;
end;

{
    Delete file
}
procedure TMainForm.Delete1Click(Sender: TObject);
var
   A,B: Longint;
   S,Ln: String;
begin
PME:=false;
if MessageDlg('Do You want to delete file: '+FilesBox.Items.Strings[FilesBox.ItemIndex],mtConfirmation,[mbYes,mbNo],0)=mrYes then
   begin
   S:='DF '+FilesBox.Items.Strings[FilesBox.ItemIndex]+Chr(13);
   if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                    else Ln:='';
   S:=CP+Ln+S;
   CheckReceiver;
   StrPCopy(FT_Out_Buffer,S);
   FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
   FT_Read(FT_Handle,@FT_In_Buffer,Length(S)-1-Length(CP)-Length(Ln),@A);
   B:=100;
   FT_In_Buffer[0]:=#0;
   while (B<>0)and(FT_In_Buffer[0]<>#$9B)and(FT_In_Buffer[0]<>#$BB) do
         begin
         FT_Read(FT_Handle,@FT_In_Buffer,1,@A);
         Dec(B);
         end;
   if FT_In_Buffer[0]=#$BB then ReadBkpt;
   RefreshFiles;
   end;
PME:=true;
end;

{
       Load file to memory
}
procedure TMainForm.Loadtomemory1Click(Sender: TObject);
var
   A: Longint;
   S,Ln: String;
begin
if Application.MessageBox('Load object to the memory ?','Confirmation',MB_YESNO)=IDYES then
   begin
   PME:=false;
   S:='RF '+FilesBox.Items.Strings[FilesBox.ItemIndex]+Chr(13);
   if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                    else Ln:='';
   S:=CP+Ln+S;
   CheckReceiver;
   StrPCopy(FT_Out_Buffer,S);
   FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
   FT_Read(FT_Handle,@FT_In_Buffer,Length(S)-1-Length(CP)-Length(Ln),@A);
   Sleep(500);
   CheckReceiver;
   // check state
   RefreshDT;
   RefreshTree;
   if A>0 then
      if FT_In_Buffer[A-1]=#$BB then ReadBkpt;
   PME:=true;
   end;
end;

{
       Tree menu popup
}
procedure TMainForm.TreeMenuPopup(Sender: TObject);
begin
Refresh1.Enabled:=MainState=3;
if Tree.Selected=nil
   then begin
        Saveobjecttofile1.Enabled:=false;
        SaveobjecttoFLASH1.Enabled:=false;
        Viewobject2.Enabled:=false;
        ViewasPSO2.Enabled:=false;
        Deleteobject2.Enabled:=false;
        Runprocess1.Enabled:=false;
        Createsuspended1.Enabled:=false;
        Stopprocess1.Enabled:=false;
        Killprocess1.Enabled:=false;
        Debugprocess1.Enabled:=false;
        Passparameter1.Enabled:=false;
        end
   else begin
        Saveobjecttofile1.Enabled:=(Tree.Selected.ImageIndex=100)or(Tree.Selected.ImageIndex=101)or(Tree.Selected.ImageIndex=102);
        SaveobjecttoFLASH1.Enabled:=(Tree.Selected.ImageIndex=100)or(Tree.Selected.ImageIndex=102);
        Viewobject2.Enabled:=(Tree.Selected.ImageIndex=100);
        ViewasPSO2.Enabled:=(Tree.Selected.ImageIndex=102);
        Deleteobject2.Enabled:=(Tree.Selected.ImageIndex=102);
        Runprocess1.Enabled:=(Tree.Selected.ImageIndex=100)and(Pos('active',Tree.Selected.Text)=0);
        Createsuspended1.Enabled:=(Tree.Selected.ImageIndex=100)and(Pos('[',Tree.Selected.Text)=0);
        Stopprocess1.Enabled:=(Tree.Selected.ImageIndex=100)and(Pos('active',Tree.Selected.Text)<>0);
        Killprocess1.Enabled:=(Tree.Selected.ImageIndex=100)and(Pos('[',Tree.Selected.Text)<>0);
        Debugprocess1.Enabled:=Runprocess1.Enabled;
        Passparameter1.Enabled:=(Tree.Selected.ImageIndex=100)and(Pos('[',Tree.Selected.Text)<>0);
        end;
end;

// save object to file
procedure TMainForm.Saveobjecttofile1Click(Sender: TObject);
var
   DTBase,SOffset,EOffset: Int64;
   DCount,A,SSel,CSel,Handle,Total: Longint;
   S,Ln: String;
   EFlag: Boolean;
   BBuff: array [0..32767] of Byte;
begin
if SaveDlg.Execute then
   begin
   PME:=false;
   if Grid.Visible and (Grid.Cells[0,0]='Selector') then CSel:=HexToInt(Grid.Cells[0,Grid.Selection.Top])
                                                    else CSel:=Tree.Selected.SelectedIndex;
   Handle:=FileCreate(SaveDlg.FileName);
   Total:=0;
   if Handle>0 then
      begin
      MainTimer.Enabled:=false;
      //1. Read DT Base
      S:='RR 1FFFFFFFFF80 8'+Chr(13);
      if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                       else Ln:='';
      S:=CP+Ln+S;
      CheckReceiver;
      StrPCopy(FT_Out_Buffer,S);
      if USBDevice<>''
         then begin
              FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
              FT_Read(FT_Handle,@FT_In_Buffer,50,@A);
              end
         else begin
              Com.Comm1.Write(FT_Out_Buffer,Length(S));
              Sleep(Length(S)+50);
              A:=Com.Comm1.Read(FT_In_Buffer,50);
              end;
      FT_In_Buffer[A]:=Chr(0);
      EFlag:=false;
      SSel:=0;
      if A<>50 then EFlag:=true
         else begin
         AsciiToBuff(@FT_In_Buffer,@BBuff,8);
         DTBase:=(BBuff[4]*4294967296 + BBuff[3]*16777216 + BBuff[2]*65536 + BBuff[1]*256 + BBuff[0]) * 32;
         //reading lower link selector
         while CSel<>0 do
               begin
               SSel:=CSel;
               S:='RR '+IntToHex(DTBase+CSel*32+8,12)+' 4'+Chr(13);
               if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                                else Ln:='';
               S:=CP+Ln+S;
               CheckReceiver;
               StrPCopy(FT_Out_Buffer,S);
               if USBDevice<>''
                  then begin
                       FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                       FT_Read(FT_Handle,@FT_In_Buffer,38,@A);
                       end
                  else begin
                       Com.Comm1.Write(FT_Out_Buffer,Length(S));
                       Sleep(Length(S)+38);
                       A:=Com.Comm1.Read(FT_In_Buffer,38);
                       end;
               FT_In_Buffer[A]:=Chr(0);
               if A<>38 then EFlag:=True
                  else begin
                  AsciiToBuff(@FT_In_Buffer,@BBuff,4);
                  CSel:=BBuff[2]*65536 + BBuff[1]*256 + BBuff[0];
                  end;
               if EFlag then Break;
               end;
         // SSel - start selector.
         ProgForm.Caption:='Saving object to the file: '+SaveDlg.FileName;
         ProgForm.Show;
         if not EFlag then
            while SSel<>0 do
                  begin
                  // reading segment limits
                  S:='RR '+IntToHex(DTBase+SSel*32+12,12)+' 12'+Chr(13);
                  if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                                   else Ln:='';
                  S:=CP+Ln+S;
                  CheckReceiver;
                  StrPCopy(FT_Out_Buffer,S);
                  if USBDevice<>''
                     then begin
                          FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                          FT_Read(FT_Handle,@FT_In_Buffer,63,@A);
                          end
                     else begin
                          Com.Comm1.Write(FT_Out_Buffer,Length(S));
                          Sleep(Length(S)+63);
                          A:=Com.Comm1.Read(FT_In_Buffer,63);
                          end;
                  FT_In_Buffer[A]:=Chr(0);
                  if A<>63 then EFlag:=true
                     else begin
                     // if limits present
                     AsciiToBuff(@FT_In_Buffer,@BBuff,12);
                     CSel:=BBuff[2]*65536 + BBuff[1]*256 + BBuff[0];       //Upper link selector
                     SOffset:=(BBuff[7]*16777216 + BBuff[6]*65536 + BBuff[5]*256 + BBuff[4])*32;
                     EOffset:=(BBuff[11]*16777216 + BBuff[10]*65536 + BBuff[9]*256 + BBuff[8])*32;
                     ProgForm.ProgBar.Min:=SOffset;
                     ProgForm.ProgBar.Max:=EOffset;
                     ProgForm.ProgBar.Position:=SOffset;
                     ProgForm.BytesStatic.Caption:='0';
                     Application.ProcessMessages;
                     while SOffset<>EOffset do
                           begin
                           // reading data until end of segment reached
                           if (EOffset-SOffset)>=BS then DCount:=BS
                                                    else DCount:=EOffset-SOffset;
                           EFlag:=not ReadObject(SSel,SOffset,DCount,@BBuff,CP);
                           if not EFlag then
                              begin
                              FileWrite(Handle,BBuff,DCount);
                              Total:=Total+DCount;
                              end;
                           SOffset:=SOffset+DCount;
                           ProgForm.ProgBar.Position:=SOffset;
                           ProgForm.BytesStatic.Caption:=IntToStr(Round(100*SOffset/EOffset))+'% '+IntToStr(SOffset)+' of '+IntToStr(EOffset);
                           Application.ProcessMessages;
                           if EFlag then Break;
                           end;
                     end;
                  if EFlag then Break;
                  SSel:=CSel;
                  end;
         ProgForm.Close;
         end;
      FileClose(Handle);
      if EFlag then MainEdit.Lines.Add('Handhacking error occurs')
               else MainEdit.Lines.Add(IntToStr(Total)+' bytes was saved in file '+SaveDlg.FileName);
      MainEdit.Lines.Add('>');
      MainTimer.Enabled:=true;
      end;
   PME:=true;
   end;
end;
// save object to flash
procedure TMainForm.SaveobjecttoFLASH1Click(Sender: TObject);
var
   A: Longint;
   S,T,Ln: String;
begin
S:='';
if Tree.Selected.ImageIndex<100 then T:=Grid.Cells[0,Grid.Selection.Top]
   else begin
        S:=Tree.Selected.Text;                                          // object name
        if Pos('[',S)<>0 then S:=Copy(S,1,Pos('[',S)-2);
        T:=IntToHex(Tree.Selected.SelectedIndex,6);
        end;
if InputQuery('Save object to the flash','Filename :',S) then
   begin
   PME:=false;
   S:='WF '+T+' '+S+Chr(13);
   if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                    else Ln:='';
   S:=CP+Ln+S;
   CheckReceiver;
   StrPCopy(FT_Out_Buffer,S);
   FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
   Sleep(500);
   FT_Read(FT_Handle,@FT_In_Buffer,Length(S)-1-Length(CP)-Length(Ln),@A);
   if A>0 then
       if FT_In_Buffer[A-1]=#$BB then ReadBkpt;
   if FilesBox.Visible then RefreshFiles;
   PME:=true;
   end;
end;
// refresh tree
procedure TMainForm.Refresh1Click(Sender: TObject);
begin
RefreshTree;
end;
// view object
procedure TMainForm.Viewobject2Click(Sender: TObject);
begin
REdit.Visible:=false;
Grid.Tag:=Tree.Selected.SelectedIndex;
ObjStart:=0;
ObjLength:=0;
Grid.RowCount:=1;
Grid.ColCount:=1;
Grid.Visible:=true;
Grid.Refresh;
end;
// vew object as pso
procedure TMainForm.ViewasPSO2Click(Sender: TObject);
begin
Grid.Cells[0,Grid.Selection.Top]:=IntToHex(Tree.Selected.SelectedIndex,6);
ViewasPSO1Click(Sender);
end;
// delete object
procedure TMainForm.Deleteobject2Click(Sender: TObject);
begin
Deleteobject1Click(Sender);
end;
// run process
procedure TMainForm.Runprocess1Click(Sender: TObject);
var
   A: Longint;
   Node: TTreeNode;
   S,Ln: String;
begin
PME:=false;
Node:=Tree.Selected;
while Node.ImageIndex<>100 do Node:=Node.Parent;
S:='0';
if Pos('suspended',Node.Text)<>0
   then begin
        S:='RP '+IntToHex(Node.SelectedIndex,6)+Chr(13);
        if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                         else Ln:='';
        S:=CP+Ln+S;
        CheckReceiver;
        StrPCopy(FT_Out_Buffer,S);
        if USBDevice<>''
           then begin
                FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
                end
           else begin
                Com.Comm1.Write(FT_Out_Buffer,Length(S));
                Sleep(Length(S)+16);
                A:=Com.Comm1.Read(FT_In_Buffer,16);
                end;
        if A=16 then
            if FT_In_Buffer[15]=#$BB then ReadBkpt;
        end
   else if InputQuery('Run process','Run parameter:',S) then
           begin
           A:=HexToInt(S);
           S:='CP '+IntToHex(Node.SelectedIndex,6)+' '+IntToHex(A,8)+Chr(13);
           if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                            else Ln:='';
           S:=CP+Ln+S;
           CheckReceiver;
           StrPCopy(FT_Out_Buffer,S);
           if USBDevice<>''
              then begin
                   FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                   FT_Read(FT_Handle,@FT_In_Buffer,25,@A);
                   end
              else begin
                   Com.Comm1.Write(FT_Out_Buffer,Length(S));
                   Sleep(Length(S)+25);
                   A:=Com.Comm1.Read(FT_In_Buffer,25);
                   end;
           if A=25 then
              begin
              S:='RP '+IntToHex(Node.SelectedIndex,6)+Chr(13);
              if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                               else Ln:='';
              S:=CP+Ln+S;
              StrPCopy(FT_Out_Buffer,S);
              if USBDevice<>''
                 then begin
                      FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                      FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
                      end
                 else begin
                      Com.Comm1.Write(FT_Out_Buffer,Length(S));
                      Sleep(Length(S)+16);
                      A:=Com.Comm1.Read(FT_In_Buffer,16);
                      end;
              if A=16 then
                  if FT_In_Buffer[15]=#$BB then ReadBkpt;
              end;
           end;
RefreshDT;
RefreshTree;
PME:=true;
end;
// create suspende
procedure TMainForm.Createsuspended1Click(Sender: TObject);
var
   A,B: Longint;
   Node: TTreeNode;
   S,Ln: String;
begin
PME:=false;
Node:=Tree.Selected;
S:='0';
if InputQuery('Create suspended process','Run parameter:',S) then
   begin
   A:=HexToInt(S);
   B:=Node.SelectedIndex;                                         //process object selector
   S:='CP '+IntToHex(B,6)+' '+IntToHex(A,8)+Chr(13);
   if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                    else Ln:='';
   S:=CP+Ln+S;
   CheckReceiver;
   StrPCopy(FT_Out_Buffer,S);
   if USBDevice<>''
      then begin
           FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
           FT_Read(FT_Handle,@FT_In_Buffer,25,@A);
           end
      else begin
           Com.Comm1.Write(FT_Out_Buffer,Length(S));
           Sleep(Length(S)+25);
           A:=Com.Comm1.Read(FT_In_Buffer,25);
           end;
   RefreshDT;
   RefreshTree;
   end;
PME:=true;
end;

// stop process
procedure TMainForm.Stopprocess1Click(Sender: TObject);
var
   A: Longint;
   Node: TTreeNode;
   S,Ln: String;
begin
PME:=false;
Node:=Tree.Selected;
while Node.ImageIndex<>100 do Node:=Node.Parent;
if Application.MessageBox('Confirmation','Do You wanna to stop the process ?',MB_YESNO)=IDYES then
   begin
   S:='SP '+IntToHex(Node.SelectedIndex,6)+Chr(13);
   if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                    else Ln:='';
   S:=CP+Ln+S;
   CheckReceiver;
   StrPCopy(FT_Out_Buffer,S);
   if USBDevice<>''
      then begin
           FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
           FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
           end
      else begin
           Com.Comm1.Write(FT_Out_Buffer,Length(S));
           Sleep(Length(S)+16);
           A:=Com.Comm1.Read(FT_In_Buffer,16);
           end;
   if A=16 then
       if FT_In_Buffer[15]=#$BB then ReadBkpt;
   RefreshDT;
   RefreshTree;
   end;
PME:=true;
end;

// kill process
procedure TMainForm.Killprocess1Click(Sender: TObject);
var
   A: Longint;
   Node: TTreeNode;
   S,Ln: String;
begin
PME:=false;
Node:=Tree.Selected;
while Node.ImageIndex<>100 do Node:=Node.Parent;
if Application.MessageBox('Confirmation','Do You wanna to kill the process ?',MB_YESNO)=IDYES then
   begin
   if Pos('suspended',Node.Text)<>0
      then begin
           S:='KP '+IntToHex(Node.SelectedIndex,6)+Chr(13);
           if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                            else Ln:='';
           S:=CP+Ln+S;
           CheckReceiver;
           StrPCopy(FT_Out_Buffer,S);
           if USBDevice<>''
              then begin
                   FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                   FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
                   end
              else begin
                   Com.Comm1.Write(FT_Out_Buffer,Length(S));
                   Sleep(Length(S)+16);
                   A:=Com.Comm1.Read(FT_In_Buffer,16);
                   end;
           if A=16 then
               if FT_In_Buffer[15]=#$BB then ReadBkpt;
           end
      else begin
           S:='SP '+IntToHex(Node.SelectedIndex,6)+Chr(13);
           if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                            else Ln:='';
           S:=CP+Ln+S;
           CheckReceiver;
           StrPCopy(FT_Out_Buffer,S);
           if USBDevice<>''
              then begin
                   FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                   FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
                   end
              else begin
                   Com.Comm1.Write(FT_Out_Buffer,Length(S));
                   Sleep(Length(S)+16);
                   A:=Com.Comm1.Read(FT_In_Buffer,16);
                   end;
           if A=16 then
              begin
              S:='KP '+IntToHex(Node.SelectedIndex,6)+Chr(13);
              if Length(CP)<>0 then Ln:=IntToHex(Length(S),4)
                               else Ln:='';
              S:=CP+Ln+S;
              CheckReceiver;
              StrPCopy(FT_Out_Buffer,S);
              if USBDevice<>''
                 then begin
                      FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@A);
                      FT_Read(FT_Handle,@FT_In_Buffer,16,@A);
                      end
                 else begin
                      Com.Comm1.Write(FT_Out_Buffer,Length(S));
                      Sleep(Length(S)+16);
                      A:=Com.Comm1.Read(FT_In_Buffer,16);
                      end;
              if A=16 then
                  if FT_In_Buffer[15]=#$BB then ReadBkpt;
              end;
           end;
   RefreshDT;
   RefreshTree;
   end;
PME:=true;
end;

// pass parameter
procedure TMainForm.Passparameter1Click(Sender: TObject);
var
   A,B,C,D: Longint;
   Node: TTreeNode;
begin
PME:=false;
if InputQuery('Run process with parameter','Enter 32-bit parameter in HEX:',ParamString) then
   begin
   Node:=Tree.Selected;
   while Node.ImageIndex<>100 do Node:=Node.Parent;
   A:=HexToInt(ParamString);
   B:=Node.SelectedIndex;
   CheckReceiver;
   if B<>PSOSel then
      if ReadObject(B,$48,4,@B,CP) then
         if B<>0 then
            begin
            // read pointer to the context from PSO
            ReadObject(B,$34,4,@C,CP);
            ReadObject(B,$3C,4,@D,CP);
            C:=C+D+4;                           // pointer to parameter
            WriteBlocked(B,C,4,@A,CP);
            end;
   RefreshDT;
   RefreshTree;
   end;
PME:=true;
end;

{
    Run the debuger
}
procedure TMainForm.Debugprocess1Click(Sender: TObject);
var
   A,B,P: Longint;
   S: String;
   Node: TTreeNode;
begin
PME:=false;
if InputQuery('Run process with parameter','Enter 32-bit parameter in HEX:',S) then P:=HexToInt(S)
                                                                               else P:=0;
Node:=Tree.Selected;
while Node.ImageIndex<>100 do Node:=Node.Parent;
if Node.StateIndex=0
   then begin
        A:=Node.SelectedIndex;                                                 // process object selector
        if P=0 then S:='CP '+IntToHex(A and $FFFF,6)+Chr(13)
               else S:='CP '+IntToHex(A and $FFFF,6)+' '+IntToHex(P,8)+Chr(13);
        if Length(CP)<>0 then S:=CP+IntToHex(Length(S),4)+S;
        CheckReceiver;
        StrPCopy(FT_Out_Buffer,S);
        FT_Write(FT_Handle,@FT_Out_Buffer,Length(S),@B);
        if P=0 then P:=16
               else P:=25;
        FT_Read(FT_Handle,@FT_In_Buffer,P,@B);
        if B=P then
           begin
           RefreshTree;
           Application.ProcessMessages;
           if Length(CP)=0 then DebugForm.Tag:=Node.SelectedIndex
                           else DebugForm.Tag:=(HexToInt(Copy(CP,2,2)) shl 24) or Node.SelectedIndex;
           DebugForm.Show;
           if FT_In_Buffer[P-1]=#$BB then ReadBkpt;
           end;
        end
   else begin
        if Pos('suspended',Node.Text)<>0 then
           begin
           if Length(CP)=0 then DebugForm.Tag:=Node.SelectedIndex
                           else DebugForm.Tag:=(HexToInt(Copy(CP,2,2)) shl 24) or Node.SelectedIndex;
           DebugForm.Show;
           end;
        end;
end;

end.
