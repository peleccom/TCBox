unit LogInUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  DropboxSession, OAuth, ShellApi, Vcl.ComCtrls, Vcl.Buttons, Vcl.ExtCtrls,
  mycrypt, IdCoderMIME, AccessConfig;

const
  SignatureString = 'TCBox1_';

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
    constructor Create(AOwner: TComponent; session: TDropboxSession;
      accessKeyFilename: string);
    procedure SignOutClick(Sender: TObject);
    procedure SignInClick(Sender: TObject);
    procedure EnterClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure AcceptButtonClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure TabSheet1Show(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
  private
    { Private declarations }
    accessKeyFilename: string;

    function saveKey(): boolean;
    function loadKey(): boolean;
    function deleteKey(): boolean;

    // crypt fucntions
    function encrypt(data: string): string;
    function decrypt(data: string): string;
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
  deleteKey();
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

procedure TLogInForm.BitBtn1Click(Sender: TObject);
begin
  saveKey();
end;

procedure TLogInForm.CancelButtonClick(Sender: TObject);
begin
  PageControl1.ActivePageIndex := 0;
end;

constructor TLogInForm.Create(AOwner: TComponent; session: TDropboxSession;
  accessKeyFilename: string);
begin
  inherited Create(AOwner);
  self.session := session;
  self.accessKeyFilename := accessKeyFilename;
  loadKey();
end;

function TLogInForm.decrypt(data: string): string;
var
  buf: string;
begin
  buf := TIdDecoderMIME.DecodeString(data);
  Result := decryptstring(buf, KEYFILE_PASS);
end;

function TLogInForm.deleteKey: boolean;
begin
  //
  Result := DeleteFile(accessKeyFilename);
end;

function TLogInForm.encrypt(data: string): string;
var
  buf: string;
begin
  buf := Cryptstring(data, KEYFILE_PASS);
  Result := TIdEncoderMIME.EncodeString(buf);
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
      stringStream.LoadFromStream(keyFileStream);;
      bufString := stringStream.DataString;
      bufString := decrypt(bufString);
      // check signature
      if (pos(SignatureString, bufString) <> 1) then
      begin
        Result := False;
        exit;
      end;
      // delete signature
      bufString := Copy(bufString, Length(SignatureString) + 1,
        Length(bufString) - Length(SignatureString));
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
      bufString := encrypt(SignatureString + bufString);
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
