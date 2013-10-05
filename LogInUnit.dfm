object LogInForm: TLogInForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'TCBox Login'
  ClientHeight = 194
  ClientWidth = 244
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object AuthLabel: TLabel
    Left = 24
    Top = 8
    Width = 43
    Height = 13
    Caption = 'Auth..ed'
  end
  object SignOut: TButton
    Left = 104
    Top = 96
    Width = 75
    Height = 25
    Caption = 'SignOut'
    TabOrder = 0
    OnClick = SignOutClick
  end
  object SignIn: TButton
    Left = 8
    Top = 96
    Width = 75
    Height = 25
    Caption = 'SignIn'
    TabOrder = 1
    OnClick = SignInClick
  end
  object Enter: TButton
    Left = 8
    Top = 64
    Width = 75
    Height = 26
    Caption = 'Enter'
    TabOrder = 2
    OnClick = EnterClick
  end
end
