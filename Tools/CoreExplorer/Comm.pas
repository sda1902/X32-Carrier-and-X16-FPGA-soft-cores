unit Comm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Async32;

type
  TCom = class(TForm)
    Comm1: TComm;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Com: TCom;

implementation

{$R *.dfm}

end.
