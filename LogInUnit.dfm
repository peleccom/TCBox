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
    Margins.Right = 5
    ActivePage = TabSheet1
    Align = alClient
    MultiLine = True
    Style = tsFlatButtons
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'TabSheet1'
      TabVisible = False
      OnShow = TabSheet1Show
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
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
      object Label1: TLabel
        Left = 0
        Top = 37
        Width = 236
        Height = 13
        Align = alTop
        Alignment = taRightJustify
        ExplicitLeft = 233
        ExplicitWidth = 3
      end
      object UserNameLabel: TLabel
        AlignWithMargins = True
        Left = 3
        Top = 16
        Width = 223
        Height = 18
        Margins.Right = 10
        Align = alTop
        Alignment = taRightJustify
        Color = clBtnFace
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGreen
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = [fsItalic]
        ParentColor = False
        ParentFont = False
        ExplicitLeft = 221
        ExplicitWidth = 5
      end
      object Enter: TButton
        Left = 25
        Top = 70
        Width = 185
        Height = 28
        Anchors = []
        Caption = 'Enter'
        TabOrder = 0
        OnClick = EnterClick
      end
      object SignOut: TButton
        Left = 25
        Top = 139
        Width = 185
        Height = 28
        Anchors = []
        Caption = 'Change user'
        TabOrder = 1
        OnClick = SignOutClick
      end
      object SignIn: TButton
        Left = 25
        Top = 104
        Width = 185
        Height = 29
        Anchors = []
        Caption = 'Log in'
        TabOrder = 2
        OnClick = SignInClick
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'TabSheet2'
      ImageIndex = 1
      TabVisible = False
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      DesignSize = (
        236
        184)
      object AcceptPageLabel: TLabel
        Left = 0
        Top = 0
        Width = 236
        Height = 13
        Align = alTop
        Alignment = taCenter
        WordWrap = True
        ExplicitWidth = 3
      end
      object SpinnerImage: TImage
        Left = 88
        Top = 56
        Width = 64
        Height = 64
        Center = True
        Stretch = True
        Transparent = True
      end
      object AcceptButton: TButton
        Left = 3
        Top = 139
        Width = 102
        Height = 28
        Anchors = []
        Caption = 'Accept'
        TabOrder = 0
        Visible = False
        OnClick = AcceptButtonClick
      end
      object CancelButton: TButton
        Left = 131
        Top = 139
        Width = 102
        Height = 28
        Anchors = []
        Caption = 'Back'
        TabOrder = 1
        OnClick = CancelButtonClick
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'TabSheet3'
      ImageIndex = 2
      TabVisible = False
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object ConnectResultLabel: TLabel
        Left = 0
        Top = 0
        Width = 109
        Height = 13
        Align = alTop
        Alignment = taCenter
        Caption = 'Connected to Dropbox'
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
  object checkAccessTokenTimer: TTimer
    Enabled = False
    OnTimer = checkAccessTokenTimerTimer
    Top = 168
  end
  object OpenBrowserTimer: TTimer
    Enabled = False
    OnTimer = OpenBrowserTimerTimer
    Top = 136
  end
end
