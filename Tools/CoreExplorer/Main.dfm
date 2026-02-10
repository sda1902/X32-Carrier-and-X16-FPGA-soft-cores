object MainForm: TMainForm
  Left = 406
  Top = 160
  Width = 1305
  Height = 675
  Caption = 'Core Explorer'
  Color = clBtnFace
  DockSite = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Verdana'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  PixelsPerInch = 120
  TextHeight = 16
  object Splitter1: TSplitter
    Left = 225
    Top = 0
    Width = 6
    Height = 530
    Color = clInactiveCaption
    ParentColor = False
    OnMoved = Splitter1Moved
  end
  object Splitter2: TSplitter
    Left = 0
    Top = 530
    Width = 1297
    Height = 4
    Cursor = crVSplit
    Align = alBottom
    Color = clInactiveCaption
    ParentColor = False
  end
  object Splitter3: TSplitter
    Left = 449
    Top = 0
    Width = 6
    Height = 530
    Color = clInactiveCaption
    ParentColor = False
    OnMoved = Splitter1Moved
  end
  object FileSplitter: TSplitter
    Left = 1170
    Top = 0
    Width = 4
    Height = 530
    Align = alRight
    Color = clInactiveCaption
    ParentColor = False
    Visible = False
  end
  object CmdBox: TListBox
    Left = 0
    Top = 0
    Width = 225
    Height = 530
    Style = lbOwnerDrawFixed
    Align = alLeft
    BorderStyle = bsNone
    Color = clMenu
    Ctl3D = False
    ExtendedSelect = False
    ItemHeight = 16
    Items.Strings = (
      '0 Settings'
      '1 Pre-defined selectors...'
      '2 Instruction sets...'
      '3 Use USB device...'
      '4 Use PCIe device...'
      '30 Use COM-port'
      '31 UART baud rate'
      '5 Binary data transfer mode'
      '6 Refresh interval'
      '7 Autorefresh'
      '8 Data block size'
      '0 Objects'
      '9 Load object from file'
      '10 Save object to file'
      '11 Save memory block to file'
      '12 Save object to the FLASH'
      '13 View object'
      '14 View as PSO'
      '15 Delete object'
      '0 Processes'
      '16 Run process'
      '17 Create suspended'
      '18 Stop process'
      '19 Kill process'
      '20 Debug process'
      '21 Pass parameter to the process'
      '0 Flash control'
      '22 Erase entire flash'
      '23 Load file to the memory'
      '24 Delete file'
      '25 Autorun list'
      '0 Other commands'
      '26 Performance monitor'
      '27 Send command'
      '28 Refresh'
      '29 Exit')
    ParentCtl3D = False
    TabOrder = 0
    OnDblClick = CmdBoxDblClick
    OnDrawItem = CmdBoxDrawItem
  end
  object MainEdit: TMemo
    Left = 0
    Top = 534
    Width = 1297
    Height = 90
    Align = alBottom
    BorderStyle = bsNone
    Color = clBtnFace
    Ctl3D = False
    ParentCtl3D = False
    PopupMenu = EditMenu
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 1
  end
  object Tree: TTreeView
    Left = 231
    Top = 0
    Width = 218
    Height = 530
    Align = alLeft
    BorderStyle = bsNone
    Color = clBtnFace
    Ctl3D = False
    Indent = 19
    ParentCtl3D = False
    PopupMenu = TreeMenu
    ReadOnly = True
    TabOrder = 2
    OnChange = TreeChange
    OnClick = TreeClick
    OnCustomDrawItem = TreeCustomDrawItem
    OnDblClick = TreeDblClick
    OnExpanding = TreeExpanding
  end
  object MainStatus: TStatusBar
    Left = 0
    Top = 624
    Width = 1297
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object REdit: TRichEdit
    Left = 512
    Top = 40
    Width = 185
    Height = 89
    BevelInner = bvNone
    BevelOuter = bvNone
    BorderStyle = bsNone
    Color = clBtnFace
    Ctl3D = False
    ParentCtl3D = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 4
    WordWrap = False
  end
  object Grid: TStringGrid
    Left = 760
    Top = 64
    Width = 320
    Height = 120
    BorderStyle = bsNone
    Color = clBtnFace
    Ctl3D = False
    GridLineWidth = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect]
    ParentCtl3D = False
    PopupMenu = GridMenu
    TabOrder = 5
    Visible = False
    OnDblClick = GridDblClick
    OnDrawCell = GridDrawCell
    OnKeyDown = GridKeyDown
    OnMouseWheelDown = GridMouseWheelDown
    OnMouseWheelUp = GridMouseWheelUp
    OnSelectCell = GridSelectCell
  end
  object FilesBox: TListBox
    Left = 1174
    Top = 0
    Width = 123
    Height = 530
    Align = alRight
    BorderStyle = bsNone
    Color = clBtnFace
    Ctl3D = False
    ItemHeight = 16
    ParentCtl3D = False
    PopupMenu = FilesMenu
    TabOrder = 6
    Visible = False
  end
  object MainTimer: TTimer
    Interval = 500
    OnTimer = MainTimerTimer
    Left = 712
    Top = 360
  end
  object RefTimer: TTimer
    Enabled = False
    Left = 800
    Top = 376
  end
  object EditMenu: TPopupMenu
    Left = 320
    Top = 568
    object Clear1: TMenuItem
      Caption = 'Clear'
      OnClick = Clear1Click
    end
  end
  object GridMenu: TPopupMenu
    OnPopup = GridMenuPopup
    Left = 856
    Top = 280
    object Viewobject1: TMenuItem
      Caption = 'View object'
      OnClick = GridDblClick
    end
    object ViewasPSO1: TMenuItem
      Caption = 'View as PSO'
      OnClick = ViewasPSO1Click
    end
    object Deleteobject1: TMenuItem
      Caption = 'Delete object'
      OnClick = Deleteobject1Click
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object Radix1: TMenuItem
      Caption = 'Radix'
      object Byte1: TMenuItem
        AutoCheck = True
        Caption = 'Byte'
        Checked = True
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object Word1: TMenuItem
        AutoCheck = True
        Caption = 'Word'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object DWord1: TMenuItem
        AutoCheck = True
        Caption = 'DWord'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object QWord1: TMenuItem
        AutoCheck = True
        Caption = 'QWord'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object OWord1: TMenuItem
        AutoCheck = True
        Caption = 'OWord'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object Integer321: TMenuItem
        AutoCheck = True
        Caption = 'Integer 32'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object Integer641: TMenuItem
        AutoCheck = True
        Caption = 'Integer 64'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object Float321: TMenuItem
        AutoCheck = True
        Caption = 'Float 32'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
      object Float641: TMenuItem
        AutoCheck = True
        Caption = 'Float 64'
        GroupIndex = 1
        RadioItem = True
        OnClick = Byte1Click
      end
    end
  end
  object OpnDlg: TOpenDialog
    Left = 592
    Top = 280
  end
  object SaveDlg: TSaveDialog
    Left = 592
    Top = 328
  end
  object FilesMenu: TPopupMenu
    OnPopup = FilesMenuPopup
    Left = 1216
    Top = 336
    object Loadtomemory1: TMenuItem
      Caption = 'Load to memory'
      OnClick = Loadtomemory1Click
    end
    object Delete1: TMenuItem
      Caption = 'Delete'
      OnClick = Delete1Click
    end
    object N4: TMenuItem
      Caption = '-'
    end
    object Refresh2: TMenuItem
      Caption = 'Refresh'
    end
  end
  object TreeMenu: TPopupMenu
    OnPopup = TreeMenuPopup
    Left = 256
    Top = 256
    object Saveobjecttofile1: TMenuItem
      Caption = 'Save object to file'
      OnClick = Saveobjecttofile1Click
    end
    object SaveobjecttoFLASH1: TMenuItem
      Caption = 'Save object to FLASH'
      OnClick = SaveobjecttoFLASH1Click
    end
    object Viewobject2: TMenuItem
      Caption = 'View object'
      OnClick = Viewobject2Click
    end
    object ViewasPSO2: TMenuItem
      Caption = 'View as PSO'
      OnClick = ViewasPSO2Click
    end
    object Deleteobject2: TMenuItem
      Caption = 'Delete object'
      OnClick = Deleteobject2Click
    end
    object N2: TMenuItem
      Caption = '-'
    end
    object Runprocess1: TMenuItem
      Caption = 'Run process'
      OnClick = Runprocess1Click
    end
    object Createsuspended1: TMenuItem
      Caption = 'Create suspended'
      OnClick = Createsuspended1Click
    end
    object Stopprocess1: TMenuItem
      Caption = 'Stop process'
      OnClick = Stopprocess1Click
    end
    object Killprocess1: TMenuItem
      Caption = 'Kill process'
      OnClick = Killprocess1Click
    end
    object Debugprocess1: TMenuItem
      Caption = 'Debug process'
      OnClick = Debugprocess1Click
    end
    object Passparameter1: TMenuItem
      Caption = 'Pass parameter'
      OnClick = Passparameter1Click
    end
    object N3: TMenuItem
      Caption = '-'
    end
    object Refresh1: TMenuItem
      Caption = 'Refresh'
      OnClick = Refresh1Click
    end
  end
end
