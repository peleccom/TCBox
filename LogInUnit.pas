unit LogInUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  DropboxClient, DropboxSession, Vcl.Buttons, Vcl.ComCtrls, OAuth, ShellApi,
  Vcl.ExtCtrls,
  mycrypt, IdCoderMIME, AccessConfig, Log4D, Data.DBxjson, PluginConsts,
  DropboxRest;

const
  // * TIMEOUTS *

  // open a browser and wait msec
  BROWSER_OPEN_TIMEOUT = 5000;
  // checks access key every msec
  CHECK_ACCESS_TOKEN_INTERVAl = 5000;
  // maximum counts of checkAccessKey timer calls
  CHECK_ACCESS_TOKEN_MAX_COUNT = 60; // 5 min

  // * TABS_INDEXES *

  //

type
  TLogInForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    ConnectResultLabel: TLabel;
    BitBtn1: TBitBtn;
    AcceptButton: TButton;
    CancelButton: TButton;
    AcceptPageLabel: TLabel;
    EnterPageLabel: TLabel;
    Label1: TLabel;
    UserNameLabel: TLabel;
    Enter: TButton;
    SignOut: TButton;
    SignIn: TButton;
    checkAccessTokenTimer: TTimer;
    constructor Create(AOwner: TComponent; session: TDropboxSession;
      client: TDropboxClient; accessKeyFilename: string);
    procedure SignOutClick(Sender: TObject);
    procedure SignInClick(Sender: TObject);
    procedure EnterClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure AcceptButtonClick(Sender: TObject);
    procedure TabSheet1Show(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure checkAccessTokenTimerTimer(Sender: TObject);
  private
    { Private declarations }
    accessKeyFilename: string;
    logger: TLogLogger;
    checkAccessTokenTimerCount: integer;
    function saveKey(): boolean;
    function loadKey(): boolean;
    function deleteKey(): boolean;

    // crypt fucntions
    function encrypt(Data: string): string;
    function decrypt(Data: string): string;

    // helper client functions
    function getUserName(): string;
  public
    session: TDropboxSession;
    client: TDropboxClient;
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
    Sleep(BROWSER_OPEN_TIMEOUT);
    PageControl1.ActivePageIndex := 1;
    // start a timer
    checkAccessTokenTimer.Interval := CHECK_ACCESS_TOKEN_INTERVAl;
    checkAccessTokenTimerCount := 0;
    checkAccessTokenTimer.Enabled := True;
  except
    on E: Exception do
    begin
      ShowMessage('Error: ' + E.Message);
      logger.Error('Obtain request token ' + E.ClassName + ' ' + E.Message);
    end;
  end;
end;

procedure TLogInForm.SignOutClick(Sender: TObject);
begin
  if not deleteKey() then
    logger.Debug('Key file not deleted');
  session.unlink();
  TabSheet1Show(self);
end;

procedure TLogInForm.TabSheet1Show(Sender: TObject);
begin
  if session.isLinked() then
  begin
    // logged in
    UserNameLabel.Visible := True;
    SignOut.Visible := True;
    Enter.Visible := True;
    SignIn.Visible := False;

    try
      UserNameLabel.Caption := getUserName();
    except
      on E: Exception do
      begin
        UserNameLabel.Caption := '';
        logger.Debug('Cant get display name ' + E.ClassName + E.Message);
      end;
    end;
  end
  else
  begin
    UserNameLabel.Visible := False;
    SignOut.Visible := False;
    Enter.Visible := False;
    SignIn.Visible := True;
    UserNameLabel.Caption := '';
  end;
end;

procedure TLogInForm.AcceptButtonClick(Sender: TObject);
begin
  try
    session.obtainAccessToken();
    if session.isLinked() then
    begin
      logger.Info('Accept token: Linked to dropbox');
      PageControl1.ActivePageIndex := 2;
    end
    else
    begin
      PageControl1.ActivePageIndex := 0;
      logger.Debug('Accept token: Not linked to Dropbox');
    end;

  except
    on E: Exception do
    begin
      ShowMessage('Error: ' + E.Message);
      logger.Error('Accept token: error ' + E.ClassName + ' ' + E.Message);
    end;

  end;

  // ModalResult :=  mrOk;
end;

procedure TLogInForm.BitBtn1Click(Sender: TObject);
begin
  if not saveKey() then
    logger.Debug('Key file not saved');
end;

procedure TLogInForm.checkAccessTokenTimerTimer(Sender: TObject);
begin
  checkAccessTokenTimerCount:= checkAccessTokenTimerCount + 1;
  if checkAccessTokenTimerCount > CHECK_ACCESS_TOKEN_MAX_COUNT then
  begin
    checkAccessTokenTimer.Enabled := False;
    logger.Debug('CheckAccessTokenTimer error - maximum repeat count achieved');
    exit;
  end;

  try
    session.obtainAccessToken();
    if session.isLinked() then
    begin
      checkAccessTokenTimer.Enabled := False;
      PageControl1.ActivePageIndex := 2;
    end;
  except
    on E: ErrorResponse do
    begin
      if E.Code = 401 then
      begin
        // Not yet , wait until next OnTimer
        exit;
      end
      else
      begin
        logger.Debug('CheckAccessTokenTimer error: ' + E.ClassName + ' ' +
          E.Message);
        checkAccessTokenTimer.Enabled := False;
      end;
    end;
    on E1: Exception do
    begin
      logger.Debug('CheckAccessTokenTimer error: ' + E1.ClassName + ' ' +
        E1.Message);
      checkAccessTokenTimer.Enabled := False;
    end;
  end;

end;

constructor TLogInForm.Create(AOwner: TComponent; session: TDropboxSession;
  client: TDropboxClient; accessKeyFilename: string);
begin
  inherited Create(AOwner);
  logger := TLogLogger.GetLogger('Default');
  self.session := session;
  self.client := client;
  self.accessKeyFilename := accessKeyFilename;
  if not loadKey() then
    logger.Info('Key file not loaded');
end;

function TLogInForm.decrypt(Data: string): string;
var
  buf: string;
begin
  try
    buf := TIdDecoderMIME.DecodeString(Data);
    Result := decryptstring(buf, KEYFILE_PASS);
  except
    Result := '';
  end;
end;

function TLogInForm.deleteKey: boolean;
begin
  //
  Result := DeleteFile(accessKeyFilename);
end;

function TLogInForm.encrypt(Data: string): string;
var
  buf: string;
begin
  try
    buf := Cryptstring(Data, KEYFILE_PASS);
    Result := TIdEncoderMIME.EncodeString(buf);
  except
    Result := '';
  end;
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
  EnterPageLabel.Caption := PLUGIN_HELLO_TITLE;
end;

function TLogInForm.getUserName: string;
var
  json: TJSONObject;
begin
  json := client.accountInfo();
  try
    Result := json.Get('display_name').jsonvalue.Value;
  finally
    json.Free;
  end;
end;

function TLogInForm.loadKey: boolean;
var
  keyFileStream: TFileStream;
  stringStream: TStringStream;
  bufString: string;
begin
  Result := True;
  try
    keyFileStream := TFileStream.Create(accessKeyFilename, fmOpenRead);
    stringStream := TStringStream.Create();
    try
      stringStream.LoadFromStream(keyFileStream);
      bufString := stringStream.DataString;
      bufString := decrypt(bufString);
      // check signature
      if (pos(ACESS_KEY_SIGNATURE_STRING, bufString) <> 1) then
      begin
        logger.Debug('Key file signature incorrect');
        Result := False;
        exit;
      end;
      // delete signature
      bufString := Copy(bufString, Length(ACESS_KEY_SIGNATURE_STRING) + 1,
        Length(bufString) - Length(ACESS_KEY_SIGNATURE_STRING));
      stringStream.Clear;
      stringStream.WriteString(bufString);
      stringStream.Seek(0, soFromBeginning);
      session.LoadAccessToken(stringStream);
    finally
      keyFileStream.Free;
      stringStream.Free;
    end;
  except
    Result := False;
  end;
end;

function TLogInForm.saveKey: boolean;
var
  keyFileStream: TFileStream;
  stringStream: TStringStream;
  bufString: string;
begin
  Result := True;
  try
    keyFileStream := TFileStream.Create(accessKeyFilename, fmCreate);
    stringStream := TStringStream.Create();

    try
      session.SaveAccessToken(stringStream);
      bufString := stringStream.DataString;
      bufString := encrypt(ACESS_KEY_SIGNATURE_STRING + bufString);
      stringStream.Clear;
      stringStream.WriteString(bufString);
      stringStream.SaveToStream(keyFileStream);
    finally
      keyFileStream.Free;
      stringStream.Free;
    end;
  except
    Result := False;
  end;
end;

end.
