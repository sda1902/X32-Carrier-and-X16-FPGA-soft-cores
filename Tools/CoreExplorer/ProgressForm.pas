unit ProgressForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls;

type
  TProgForm = class(TForm)
    ProgBar: TProgressBar;
    BytesStatic: TStaticText;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ProgForm: TProgForm;

implementation

{$R *.dfm}

end.
