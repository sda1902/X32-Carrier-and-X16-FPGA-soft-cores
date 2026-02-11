program CAssm;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  CompMsg in 'CompMsg.pas',
  Structures in 'Structures.pas',
  Subprog in 'Subprog.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
