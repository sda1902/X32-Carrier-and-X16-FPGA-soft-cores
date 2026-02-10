unit Obj;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons;

type
  TObjDlg = class(TForm)
    Label1: TLabel;
    DPLBox: TComboBox;
    REBox: TCheckBox;
    WEBox: TCheckBox;
    NEBox: TCheckBox;
    OKBtn: TBitBtn;
    CancelBtn: TBitBtn;
    Label2: TLabel;
    TaskEdit: TEdit;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ObjDlg: TObjDlg;

implementation

{$R *.dfm}

end.
