unit Sel;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, Grids, IniFiles;

type
  TSelForm = class(TForm)
    SelGrid: TStringGrid;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure SelGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SelForm: TSelForm;

implementation

{$R *.dfm}

// prepare grid
procedure TSelForm.FormCreate(Sender: TObject);
begin
SelGrid.Cells[0,0]:='Object'; SelGrid.Cells[1,0]:='Selector';
SelGrid.Cells[0,1]:='Kernel code';
SelGrid.Cells[0,2]:='IO space';
SelGrid.Cells[0,3]:='System registers';
SelGrid.Cells[0,4]:='Whole RAM';
SelGrid.Cells[0,5]:='Kernel stack';
SelGrid.Cells[0,6]:='Kernel PSO';
SelGrid.Cells[0,7]:='Interrupt table';
SelGrid.Cells[0,8]:='Process table';
SelGrid.Cells[0,9]:='Descriptor table';
SelGrid.Cells[0,10]:='Service selector';
SelGrid.Cells[0,11]:='Breakpoint list';
SelGrid.Cells[0,12]:='Error list';
SelGrid.Cells[0,13]:='Flash control';
SelGrid.Cells[0,14]:='Flash data array';
SelGrid.Cells[0,15]:='Flash write buffer';
end;

// realign table
procedure TSelForm.FormResize(Sender: TObject);
begin
SelGrid.Refresh;
SelGrid.DefaultRowHeight:=SelGrid.Canvas.TextHeight('RW!')+4;
SelGrid.ColWidths[0]:=SelGrid.Canvas.TextWidth('Descriptor table')+20;
SelGrid.ColWidths[1]:=SelGrid.Canvas.TextWidth('Selector')+30;

SelGrid.Refresh;
end;

// draw cells
procedure TSelForm.SelGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
   X,Y: Longint;
begin
if (Sender as TStringGrid).Cells[ACol,ARow]<>'' then
   begin
   Y:=(Rect.Bottom-Rect.Top-(Sender as TSTringGrid).Canvas.TextHeight('W')) div 2;
   X:=(Rect.Right-Rect.Left-(Sender as TSTringGrid).Canvas.TextWidth((Sender as TSTringGrid).Cells[ACol,ARow])) div 2;
   (Sender as TSTringGrid).Canvas.TextRect(Rect,X+Rect.Left,Y+Rect.Top,(Sender as TSTringGrid).Cells[ACol,ARow]);
   end;
end;

end.
