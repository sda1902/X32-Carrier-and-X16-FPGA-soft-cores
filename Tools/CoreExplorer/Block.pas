unit Block;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons;

type
  TBlockDlg = class(TForm)
    Label1: TLabel;
    AddressEdit: TEdit;
    Label2: TLabel;
    LengthEdit: TEdit;
    OKBtn: TBitBtn;
    CancelBtn: TBitBtn;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  BlockDlg: TBlockDlg;

implementation

{$R *.dfm}

end.
