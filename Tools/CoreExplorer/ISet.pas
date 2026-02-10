unit ISet;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons;

type
  TISetDlg = class(TForm)
    IList: TListBox;
    ISetCancel: TBitBtn;
    ISetOK: TBitBtn;
    ISetDown: TButton;
    ISetUp: TButton;
    ISetDelete: TButton;
    ISetAdd: TButton;
    ISetOpen: TOpenDialog;
    procedure FormShow(Sender: TObject);
    procedure ISetAddClick(Sender: TObject);
    procedure IListClick(Sender: TObject);
    procedure ISetDeleteClick(Sender: TObject);
    procedure ISetUpClick(Sender: TObject);
    procedure ISetDownClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ISetDlg: TISetDlg;

implementation

{$R *.dfm}

// form show.
procedure TISetDlg.FormShow(Sender: TObject);
begin
ISetAdd.Enabled:=IList.Count<32;
if (IList.ItemIndex=-1)and(IList.Count<>0) then ILIst.Selected[0]:=true;
ISetDelete.Enabled:=(IList.ItemIndex>=0);
ISetUp.Enabled:=(IList.ItemIndex>0);
ISetDown.Enabled:=(IList.ItemIndex<(IList.Count-1));
end;

// add new set
procedure TISetDlg.ISetAddClick(Sender: TObject);
begin
if ISetOpen.Execute then IList.Items.Add(ISetOpen.FileName);
FormShow(Sender);
end;

procedure TISetDlg.IListClick(Sender: TObject);
begin
FormShow(Sender);
end;

// delete record
procedure TISetDlg.ISetDeleteClick(Sender: TObject);
begin
IList.DeleteSelected;
FormShow(Sender);
end;

// move item up
procedure TISetDlg.ISetUpClick(Sender: TObject);
var
   A: Longint;
   S: String;
begin
A:=IList.ItemIndex;
S:=IList.Items.Strings[A];
IList.DeleteSelected;
IList.Items.Insert(A-1,S);
IList.ItemIndex:=A-1;
FormShow(Sender);
end;

// move item down
procedure TISetDlg.ISetDownClick(Sender: TObject);
var
   A: Longint;
   S: String;
begin
A:=IList.ItemIndex;
S:=IList.Items.Strings[A];
IList.DeleteSelected;
IList.Items.Insert(A+1,S);
IList.ItemIndex:=A+1;
FormShow(Sender);

end;

end.
