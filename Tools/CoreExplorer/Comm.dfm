object Com: TCom
  Left = 374
  Top = 190
  Width = 171
  Height = 230
  Caption = 'Com'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 120
  TextHeight = 16
  object Comm1: TComm
    DeviceName = 'Com2'
    MonitorEvents = [evBreak, evCTS, evDSR, evError, evRing, evRlsd, evRxChar, evRxFlag, evTxEmpty]
    BaudRate = cbr115200
    Options = []
    Left = 80
    Top = 80
  end
end
