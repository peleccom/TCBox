object SettingsForm: TSettingsForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 119
  ClientWidth = 273
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 107
    Height = 13
    Caption = 'Language'
  end
  object LanguagesComboBox: TComboBox
    Left = 121
    Top = 5
    Width = 145
    Height = 21
    Style = csDropDownList
    TabOrder = 0
    OnChange = LanguagesComboBoxChange
  end
  object LogOutButton: TButton
    Left = 8
    Top = 49
    Width = 107
    Height = 25
    Caption = 'Log out'
    TabOrder = 1
    OnClick = LogOutButtonClick
  end
  object BitBtn1: TBitBtn
    Left = 0
    Top = 94
    Width = 273
    Height = 25
    Align = alBottom
    Kind = bkOK
    NumGlyphs = 2
    TabOrder = 2
    ExplicitLeft = -7
  end
  object XPManifest1: TXPManifest
    Left = 176
    Top = 144
  end
end
