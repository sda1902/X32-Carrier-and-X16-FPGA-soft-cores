program CoreExplorer;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  Variables in 'Variables.pas',
  ISet in 'ISet.pas' {ISetDlg},
  Sel in 'Sel.pas' {SelForm},
  Uart in 'Uart.pas' {UartForm},
  Obj in 'Obj.pas' {ObjDlg},
  ProgressForm in 'ProgressForm.pas' {ProgForm},
  Auto in 'Auto.pas' {AutoForm},
  Block in 'Block.pas' {BlockDlg},
  PMon in 'PMon.pas' {PMonForm},
  Debug in 'Debug.pas' {DebugForm},
  Comm in 'Comm.pas' {Com};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Core Explorer';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TISetDlg, ISetDlg);
  Application.CreateForm(TSelForm, SelForm);
  Application.CreateForm(TUartForm, UartForm);
  Application.CreateForm(TObjDlg, ObjDlg);
  Application.CreateForm(TProgForm, ProgForm);
  Application.CreateForm(TAutoForm, AutoForm);
  Application.CreateForm(TBlockDlg, BlockDlg);
  Application.CreateForm(TPMonForm, PMonForm);
  Application.CreateForm(TDebugForm, DebugForm);
  Application.CreateForm(TCom, Com);
  Application.Run;
end.
