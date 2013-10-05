unit LogInUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  DropboxSession, OAuth, ShellApi, Vcl.ComCtrls, Vcl.Buttons, Vcl.ExtCtrls;

type
  TLogInForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    ConnectResultLabel: TLabel;
    BitBtn1: TBitBtn;
    Enter: TButton;
    SignOut: TButton;
    SignIn: TButton;
    AcceptButton: TButton;
    CancelButton: TButton;
    AcceptPageLabel: TLabel;
    EnterPageLabel: TLabel;
    constructor Create(AOwner: TComponent; session: TDropboxSession);
    procedure SignOutClick(Sender: TObject);
    procedure SignInClick(Sender: TObject);
    procedure EnterClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure AcceptButtonClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure TabSheet1Show(Sender: TObject);
  private
    { Private declarations }
  public
    session: TDropboxSession;
    { Public declarations }
  end;

var
  LogInForm: TLogInForm;

implementation

{$R *.dfm}

procedure TLogInForm.SignInClick(Sender: TObject);
var
  token: TOAuthToken;
  url: string;
begin
  try
    token := session.obtainRequestToken();
    url := session.buildAuthorizeUrl(token, '');
    ShellExecute(0, PChar('open'), PChar(url), Nil, Nil, SW_SHOW);
    Sleep(3000);
    PageControl1.ActivePageIndex := 1;
  except
    on E: Exception do
      ShowMessage('Error: ' + E.Message);
  end;
end;

procedure TLogInForm.SignOutClick(Sender: TObject);
begin
  session.unlink();
  TabSheet1Show(self);
end;

procedure TLogInForm.TabSheet1Show(Sender: TObject);
begin
  if session.isLinked() then
  begin
    // logged in
    Enter.Visible := True;
    SignIn.Visible := False;
    SignOut.Visible := True;
  end
  else
  begin
    Enter.Visible := False;
    SignIn.Visible := True;
    SignOut.Visible := False;
  end;
end;

procedure TLogInForm.AcceptButtonClick(Sender: TObject);
begin
  try
    session.obtainAccessToken();
    PageControl1.ActivePageIndex := 0;
    if session.isLinked() then
    begin
      PageControl1.ActivePageIndex := 2;
    end
    else
      PageControl1.ActivePageIndex := 0;
  except
    on E: Exception do
      ShowMessage('Error: ' + E.Message);
  end;

  // ModalResult :=  mrOk;
end;

procedure TLogInForm.CancelButtonClick(Sender: TObject);
begin
  PageControl1.ActivePageIndex := 0;
end;

constructor TLogInForm.Create(AOwner: TComponent; session: TDropboxSession);
begin
  inherited Create(AOwner);
  self.session := session;
end;

procedure TLogInForm.EnterClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TLogInForm.FormCreate(Sender: TObject);
var
  page: Integer;
begin
  for page := 0 to PageControl1.PageCount - 1 do
  begin
    PageControl1.Pages[page].TabVisible := False;
  end;
  PageControl1.ActivePageIndex := 0;
end;

end.
