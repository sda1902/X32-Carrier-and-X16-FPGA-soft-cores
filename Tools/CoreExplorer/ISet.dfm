object ISetDlg: TISetDlg
  Left = 625
  Top = 143
  BorderStyle = bsToolWindow
  Caption = 'Instruction sets'
  ClientHeight = 487
  ClientWidth = 611
  Color = clBtnFace
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnShow = FormShow
  PixelsPerInch = 120
  TextHeight = 16
  object IList: TListBox
    Left = 0
    Top = 0
    Width = 611
    Height = 433
    Align = alTop
    BevelInner = bvNone
    BevelOuter = bvNone
    Color = clBtnFace
    Ctl3D = False
    ItemHeight = 16
    ParentCtl3D = False
    TabOrder = 0
    OnClick = IListClick
  end
  object ISetCancel: TBitBtn
    Left = 520
    Top = 448
    Width = 75
    Height = 25
    TabOrder = 1
    Kind = bkCancel
  end
  object ISetOK: TBitBtn
    Left = 432
    Top = 448
    Width = 75
    Height = 25
    TabOrder = 2
    Kind = bkOK
  end
  object ISetDown: TButton
    Left = 328
    Top = 448
    Width = 91
    Height = 25
    Caption = 'Move down'
    Enabled = False
    TabOrder = 3
    OnClick = ISetDownClick
  end
  object ISetUp: TButton
    Left = 224
    Top = 448
    Width = 91
    Height = 25
    Caption = 'Move up'
    Enabled = False
    TabOrder = 4
    OnClick = ISetUpClick
  end
  object ISetDelete: TButton
    Left = 120
    Top = 448
    Width = 91
    Height = 25
    Caption = 'Delete'
    Enabled = False
    TabOrder = 5
    OnClick = ISetDeleteClick
  end
  object ISetAdd: TButton
    Left = 16
    Top = 448
    Width = 91
    Height = 25
    Caption = 'Add...'
    TabOrder = 6
    OnClick = ISetAddClick
  end
  object ISetOpen: TOpenDialog
    Title = 'Instruction set selection'
    Left = 256
    Top = 288
  end
end
