object SelForm: TSelForm
  Left = 640
  Top = 294
  BorderStyle = bsToolWindow
  Caption = 'Pre-defined selectors'
  ClientHeight = 379
  ClientWidth = 501
  Color = clBtnFace
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnResize = FormResize
  PixelsPerInch = 120
  TextHeight = 16
  object SelGrid: TStringGrid
    Left = 0
    Top = 0
    Width = 501
    Height = 329
    Align = alTop
    BorderStyle = bsNone
    Color = clBtnFace
    ColCount = 2
    Ctl3D = True
    RowCount = 16
    GridLineWidth = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goEditing, goAlwaysShowEditor]
    ParentCtl3D = False
    TabOrder = 0
    OnDrawCell = SelGridDrawCell
  end
  object BitBtn1: TBitBtn
    Left = 416
    Top = 344
    Width = 75
    Height = 25
    TabOrder = 1
    Kind = bkCancel
  end
  object BitBtn2: TBitBtn
    Left = 336
    Top = 344
    Width = 75
    Height = 25
    TabOrder = 2
    Kind = bkOK
  end
end
