object ObjDlg: TObjDlg
  Left = 501
  Top = 193
  BorderStyle = bsToolWindow
  Caption = 'Object properties'
  ClientHeight = 295
  ClientWidth = 286
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 120
  TextHeight = 16
  object Label1: TLabel
    Left = 32
    Top = 32
    Width = 108
    Height = 20
    Caption = 'Object DPL :'
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
  end
  object Label2: TLabel
    Left = 32
    Top = 184
    Width = 87
    Height = 20
    Caption = 'TASK ID :'
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
  end
  object DPLBox: TComboBox
    Left = 152
    Top = 32
    Width = 89
    Height = 28
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ItemHeight = 20
    ItemIndex = 3
    ParentFont = False
    TabOrder = 0
    Text = '3'
    Items.Strings = (
      '0'
      '1'
      '2'
      '3')
  end
  object REBox: TCheckBox
    Left = 32
    Top = 80
    Width = 209
    Height = 17
    Alignment = taLeftJustify
    Caption = 'Readable :'
    Checked = True
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
    State = cbChecked
    TabOrder = 1
  end
  object WEBox: TCheckBox
    Left = 32
    Top = 112
    Width = 209
    Height = 17
    Alignment = taLeftJustify
    Caption = 'Writable :'
    Checked = True
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
    State = cbChecked
    TabOrder = 2
  end
  object NEBox: TCheckBox
    Left = 32
    Top = 144
    Width = 209
    Height = 17
    Alignment = taLeftJustify
    Caption = 'Network access :'
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
    TabOrder = 3
  end
  object OKBtn: TBitBtn
    Left = 56
    Top = 240
    Width = 89
    Height = 25
    TabOrder = 4
    Kind = bkOK
  end
  object CancelBtn: TBitBtn
    Left = 160
    Top = 240
    Width = 91
    Height = 25
    TabOrder = 5
    Kind = bkCancel
  end
  object TaskEdit: TEdit
    Left = 128
    Top = 184
    Width = 113
    Height = 28
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
    TabOrder = 6
    Text = '0'
  end
end
