object AutoForm: TAutoForm
  Left = 673
  Top = 202
  Width = 588
  Height = 421
  BorderStyle = bsSizeToolWin
  Caption = 'Autorun'
  Color = clBtnFace
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -10
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 12
  object Panel1: TPanel
    Left = 0
    Top = 351
    Width = 572
    Height = 31
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object OkBtn: TBitBtn
      Left = 792
      Top = 6
      Width = 56
      Height = 19
      TabOrder = 0
      OnClick = OkBtnClick
      Kind = bkOK
    end
    object CancelBtn: TBitBtn
      Left = 858
      Top = 6
      Width = 56
      Height = 19
      TabOrder = 1
      Kind = bkCancel
    end
  end
  object AutoGrid: TStringGrid
    Left = 0
    Top = 0
    Width = 572
    Height = 351
    Align = alClient
    ColCount = 4
    Ctl3D = False
    DefaultColWidth = 150
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goEditing, goAlwaysShowEditor]
    ParentCtl3D = False
    TabOrder = 1
    OnDblClick = AutoGridDblClick
    OnDrawCell = AutoGridDrawCell
    OnKeyDown = AutoGridKeyDown
    OnSelectCell = AutoGridSelectCell
    OnSetEditText = AutoGridSetEditText
  end
end
