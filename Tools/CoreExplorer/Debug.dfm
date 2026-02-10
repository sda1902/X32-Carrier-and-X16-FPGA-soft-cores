object DebugForm: TDebugForm
  Left = 457
  Top = 229
  Width = 1305
  Height = 675
  BorderStyle = bsSizeToolWin
  Caption = 'Debugger'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -10
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnActivate = FormActivate
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object DebugTab: TTabControl
    Left = 0
    Top = 0
    Width = 1289
    Height = 636
    Align = alClient
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Verdana'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
    OnChange = DebugTabChange
    object Splitter1: TSplitter
      Left = 672
      Top = 6
      Width = 4
      Height = 626
      Align = alRight
      Color = clBtnFace
      ParentColor = False
    end
    object CodeGrid: TStringGrid
      Left = 4
      Top = 6
      Width = 668
      Height = 626
      Align = alClient
      BorderStyle = bsNone
      Color = clBtnFace
      ColCount = 3
      FixedCols = 0
      GridLineWidth = 0
      Options = [goFixedVertLine, goFixedHorzLine, goRowSelect]
      PopupMenu = CodePopMenu
      TabOrder = 0
      OnDrawCell = CodeGridDrawCell
      OnSelectCell = CodeGridSelectCell
    end
    object Panel1: TPanel
      Left = 676
      Top = 6
      Width = 609
      Height = 626
      Align = alRight
      TabOrder = 1
      object Splitter2: TSplitter
        Left = 1
        Top = 430
        Width = 607
        Height = 4
        Cursor = crVSplit
        Align = alBottom
        Color = clBtnFace
        ParentColor = False
      end
      object GPRGrid: TStringGrid
        Left = 1
        Top = 1
        Width = 607
        Height = 429
        Align = alClient
        BorderStyle = bsNone
        Color = clBtnFace
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -9
        Font.Name = 'Verdana'
        Font.Style = []
        GridLineWidth = 0
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goColSizing, goColMoving, goRowSelect]
        ParentFont = False
        ScrollBars = ssVertical
        TabOrder = 0
        OnDrawCell = GPRGridDrawCell
      end
      object CSRGrid: TStringGrid
        Left = 1
        Top = 583
        Width = 607
        Height = 42
        Align = alBottom
        BorderStyle = bsNone
        Color = clBtnFace
        ColCount = 7
        FixedCols = 0
        RowCount = 2
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -9
        Font.Name = 'Verdana'
        Font.Style = []
        GridLineWidth = 0
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing]
        ParentFont = False
        ScrollBars = ssNone
        TabOrder = 1
        OnDrawCell = CSRGridDrawCell
      end
      object ADRGrid: TStringGrid
        Left = 1
        Top = 434
        Width = 607
        Height = 149
        Align = alBottom
        BorderStyle = bsNone
        Color = clBtnFace
        ColCount = 3
        RowCount = 9
        Font.Charset = RUSSIAN_CHARSET
        Font.Color = clWindowText
        Font.Height = -9
        Font.Name = 'Verdana'
        Font.Style = []
        GridLineWidth = 0
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goColSizing, goRowSelect]
        ParentFont = False
        TabOrder = 2
        OnDrawCell = ADRGridDrawCell
      end
    end
  end
  object CodePopMenu: TPopupMenu
    Left = 368
    Top = 304
    object RunItem: TMenuItem
      Caption = 'Run process'
      ShortCut = 120
      OnClick = RunItemClick
    end
    object StepItem: TMenuItem
      Caption = 'Step'
      ShortCut = 118
      OnClick = StepItemClick
    end
    object RTCItem: TMenuItem
      Caption = 'Run to cursor'
      ShortCut = 115
      OnClick = RTCItemClick
    end
    object BKPTItem: TMenuItem
      Caption = 'Toggle breakpoint'
      ShortCut = 116
      OnClick = BKPTItemClick
    end
    object CloseItem: TMenuItem
      Caption = 'Close session'
      ShortCut = 16497
      OnClick = CloseItemClick
    end
  end
end
