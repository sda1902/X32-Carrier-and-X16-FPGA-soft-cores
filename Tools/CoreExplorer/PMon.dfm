object PMonForm: TPMonForm
  Left = 349
  Top = 217
  Width = 1238
  Height = 504
  BorderStyle = bsSizeToolWin
  Caption = 'Performance monitor'
  Color = clBtnFace
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 120
  TextHeight = 16
  object Splitter1: TSplitter
    Left = 320
    Top = 0
    Width = 5
    Height = 472
  end
  object PMonGrid: TStringGrid
    Left = 0
    Top = 0
    Width = 320
    Height = 472
    Align = alLeft
    ColCount = 2
    Ctl3D = False
    DefaultColWidth = 150
    RowCount = 11
    FixedRows = 0
    ParentCtl3D = False
    TabOrder = 0
    OnDblClick = PMonGridDblClick
    OnDrawCell = PMonGridDrawCell
    OnSelectCell = PMonGridSelectCell
    OnSetEditText = PMonGridSetEditText
  end
  object Comb: TComboBox
    Left = 416
    Top = 112
    Width = 145
    Height = 24
    ItemHeight = 16
    TabOrder = 1
    Text = 'Comb'
    Visible = False
    OnExit = CombExit
  end
  object Panel1: TPanel
    Left = 325
    Top = 0
    Width = 905
    Height = 472
    Align = alClient
    BevelOuter = bvNone
    Ctl3D = False
    ParentCtl3D = False
    TabOrder = 2
  end
  object PMonTimer: TTimer
    Enabled = False
    OnTimer = PMonTimerTimer
    Left = 168
    Top = 336
  end
  object ImgPopup: TPopupMenu
    Left = 240
    Top = 344
    object Savetofile1: TMenuItem
      Caption = 'Save to file'
      OnClick = Savetofile1Click
    end
  end
  object SavePicDlg: TSavePictureDialog
    Left = 168
    Top = 384
  end
end
