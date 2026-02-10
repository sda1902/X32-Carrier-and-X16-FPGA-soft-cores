object UartForm: TUartForm
  Left = 690
  Top = 357
  BorderStyle = bsToolWindow
  Caption = 'USB Device'
  ClientHeight = 136
  ClientWidth = 235
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnActivate = FormActivate
  PixelsPerInch = 120
  TextHeight = 16
  object Label1: TLabel
    Left = 24
    Top = 24
    Width = 124
    Height = 18
    Caption = 'Available devices'
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -15
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
  end
  object CancelBtn: TBitBtn
    Left = 144
    Top = 96
    Width = 75
    Height = 25
    TabOrder = 0
    Kind = bkCancel
  end
  object OKBtn: TBitBtn
    Left = 56
    Top = 96
    Width = 75
    Height = 25
    TabOrder = 1
    Kind = bkOK
  end
  object USBBox: TComboBox
    Left = 24
    Top = 48
    Width = 193
    Height = 24
    ItemHeight = 16
    TabOrder = 2
    OnChange = USBBoxChange
  end
end
