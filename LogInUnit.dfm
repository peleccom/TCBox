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
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 244
    Height = 194
    ActivePage = TabSheet1
    Align = alClient
    MultiLine = True
    Style = tsFlatButtons
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'TabSheet1'
      TabVisible = False
      OnShow = TabSheet1Show
      DesignSize = (
        236
        184)
      object EnterPageLabel: TLabel
        Left = 0
        Top = 0
        Width = 236
        Height = 13
        Align = alTop
        Alignment = taCenter
        Caption = 'Total Commander Dropbox plugin'
        WordWrap = True
        ExplicitWidth = 159
      end
      object Enter: TButton
        Left = 24
        Top = 38
        Width = 185
        Height = 28
        Anchors = []
        Caption = #1042#1093#1086#1076
        TabOrder = 0
        OnClick = EnterClick
      end
      object SignOut: TButton
        Left = 24
        Top = 82
        Width = 185
        Height = 28
        Anchors = []
        Caption = #1057#1084#1077#1085#1080#1090#1100' '#1087#1086#1083#1100#1079#1086#1074#1072#1090#1077#1083#1103
        TabOrder = 1
        OnClick = SignOutClick
      end
      object SignIn: TButton
        Left = 24
        Top = 124
        Width = 185
        Height = 29
        Anchors = []
        Caption = #1040#1074#1090#1086#1088#1080#1079#1086#1074#1072#1090#1100#1089#1103
        TabOrder = 2
        OnClick = SignInClick
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'TabSheet2'
      ImageIndex = 1
      TabVisible = False
      DesignSize = (
        236
        184)
      object AcceptPageLabel: TLabel
        Left = 0
        Top = 0
        Width = 236
        Height = 26
        Align = alTop
        Alignment = taCenter
        Caption = 
          #1055#1086#1076#1090#1074#1077#1088#1076#1080#1090#1077' '#1076#1086#1089#1090#1091#1087' '#1087#1088#1080#1083#1086#1078#1077#1085#1080#1102' '#1074' '#1073#1088#1072#1091#1079#1077#1088#1077' '#1080' '#1079#1072#1090#1077#1084' '#1085#1072#1078#1084#1080#1090#1077' '#39#1055#1088#1080#1085#1103#1090 +
          #1100#39
        WordWrap = True
        ExplicitWidth = 235
      end
      object AcceptButton: TButton
        Left = 3
        Top = 72
        Width = 102
        Height = 28
        Anchors = []
        Caption = #1055#1088#1080#1085#1103#1090#1100
        TabOrder = 0
        OnClick = AcceptButtonClick
      end
      object CancelButton: TButton
        Left = 131
        Top = 72
        Width = 102
        Height = 28
        Anchors = []
        Caption = #1054#1090#1082#1083#1086#1085#1080#1090#1100
        TabOrder = 1
        OnClick = CancelButtonClick
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'TabSheet3'
      ImageIndex = 2
      TabVisible = False
      object ConnectResultLabel: TLabel
        Left = 0
        Top = 0
        Width = 236
        Height = 13
        Align = alTop
        Alignment = taCenter
        Caption = #1057#1086#1077#1076#1080#1085#1077#1085#1080#1077' '#1091#1089#1090#1072#1085#1086#1074#1083#1077#1085#1086
        ExplicitWidth = 130
      end
      object BitBtn1: TBitBtn
        Left = 0
        Top = 159
        Width = 236
        Height = 25
        Align = alBottom
        Kind = bkOK
        NumGlyphs = 2
        TabOrder = 0
        OnClick = BitBtn1Click
      end
    end
  end
end
