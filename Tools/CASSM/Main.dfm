object MainForm: TMainForm
  Left = 797
  Top = 189
  Width = 859
  Height = 460
  Caption = 'CAssm'
  Color = clBtnFace
  Constraints.MinHeight = 200
  Constraints.MinWidth = 700
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  PixelsPerInch = 120
  TextHeight = 16
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 851
    Height = 57
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 16
      Width = 59
      Height = 16
      Caption = 'Source :'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Verdana'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object SourceBtn: TButton
      Left = 504
      Top = 16
      Width = 33
      Height = 22
      Caption = '...'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Verdana'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      OnClick = SourceBtnClick
    end
    object RunBtn: TButton
      Left = 536
      Top = 16
      Width = 73
      Height = 22
      Caption = 'Run'
      Enabled = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Verdana'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 1
      OnClick = RunBtnClick
    end
    object StopBtn: TButton
      Left = 608
      Top = 16
      Width = 75
      Height = 22
      Caption = 'Stop'
      Enabled = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Verdana'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 2
    end
    object SourceEdit: TComboBox
      Left = 80
      Top = 16
      Width = 425
      Height = 24
      BevelInner = bvNone
      BevelOuter = bvNone
      Ctl3D = True
      DropDownCount = 32
      ItemHeight = 16
      ParentCtl3D = False
      TabOrder = 3
      OnChange = SourceEditChange
    end
  end
  object MsgBox: TListBox
    Left = 0
    Top = 57
    Width = 851
    Height = 352
    Align = alClient
    Ctl3D = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Verdana'
    Font.Style = []
    ItemHeight = 16
    ParentCtl3D = False
    ParentFont = False
    TabOrder = 1
  end
  object MainStatus: TStatusBar
    Left = 0
    Top = 409
    Width = 851
    Height = 19
    Panels = <
      item
        Width = 100
      end
      item
        Width = 100
      end
      item
        Width = 100
      end>
  end
  object MainTimer: TTimer
    Enabled = False
    OnTimer = MainTimerTimer
    Left = 560
    Top = 88
  end
  object OpenDlg: TOpenDialog
    Left = 512
    Top = 88
  end
end
