object BlockDlg: TBlockDlg
  Left = 344
  Top = 120
  BorderStyle = bsToolWindow
  Caption = 'Block parameters'
  ClientHeight = 181
  ClientWidth = 399
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
    Width = 124
    Height = 20
    Caption = 'Start address:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
  end
  object Label2: TLabel
    Left = 32
    Top = 80
    Width = 121
    Height = 20
    Caption = 'Block length :'
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
  end
  object AddressEdit: TEdit
    Left = 160
    Top = 32
    Width = 193
    Height = 24
    TabOrder = 0
    Text = '0'
  end
  object LengthEdit: TEdit
    Left = 160
    Top = 80
    Width = 193
    Height = 24
    TabOrder = 1
    Text = '0'
  end
  object OKBtn: TBitBtn
    Left = 144
    Top = 128
    Width = 97
    Height = 25
    TabOrder = 2
    Kind = bkOK
  end
  object CancelBtn: TBitBtn
    Left = 256
    Top = 128
    Width = 97
    Height = 25
    TabOrder = 3
    Kind = bkCancel
  end
end
