object ProgForm: TProgForm
  Left = 552
  Top = 334
  BorderStyle = bsToolWindow
  Caption = 'Progress'
  ClientHeight = 74
  ClientWidth = 588
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
  object ProgBar: TProgressBar
    Left = 7
    Top = 24
    Width = 574
    Height = 26
    Smooth = True
    TabOrder = 0
  end
  object BytesStatic: TStaticText
    Left = 0
    Top = 56
    Width = 585
    Height = 20
    Alignment = taCenter
    AutoSize = False
    TabOrder = 1
  end
end
