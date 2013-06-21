library TCBox;




uses
  Windows,
  FSPLUGIN,
  classes,
  sysutils,
  wininet,
  registry,
  ShellApi,
  OAuth,
  IdHTTP,
  IdAntiFreezeBase,
  IdComponent,
  IdTCPConnection,
  IdTCPClient,
  IdSSLOpenSSL,

  // acess keys
  AccessConfig
  ;

//httpGet in 'httpGet.pas';

{$E wfx}
{$R icon.res}
{$R *.RES}
const
  VERSION_TEXT = '1.0';
  PLUGIN_TITLE = 'Total Commander Dropbox plugin';
  HELLO_TITLE  = 'TCBox '+VERSION_TEXT;


  REQUES_TOKEN_HANDLER = 10;


var
  ProgressProc : tProgressProc;
  LogProc      : tLogProc;
  RequestProc  : tRequestProc;
  PluginNumber: integer;

  // oauth

  Key : String;
  Secret : String;
  Consumer : TOAuthConsumer;
  ARequest : TOAuthRequest ;
  HMAC :TOAuthSignatureMethod;
  HTTPStream : TStringStream;
  Response : String;
  Token : TOAuthToken;
  oauth_token :String;
  oauth_token_secret :String;
  IdHTTP1 : TIdHTTP;
  request_token_flag : Boolean;
{FileGet}
{fIleGEt}
function FsInit (PluginNr : integer; pProgressProc : tProgressProc; pLogProc : tLogProc;
                pRequestProc : tRequestProc) : integer; stdcall;

begin
    ProgressProc := pProgressProc;
    LogProc      :=pLogProc;
    RequestProc  :=pRequestProc;
    PluginNumber := PluginNr;

    Result := 0;
end;

procedure Request();
var
  URL: string;
  endpos: integer;
  antifreeze : TIdAntiFreezeBase;
  LHandler: TIdSSLIOHandlerSocketOpenSSL;
  Strs : TMemoryStream;
  s:String ;
begin
  URL := 'https://api.dropbox.com/1/oauth/request_token';
// Create all objects
  Consumer := TOAuthConsumer.Create(APP_KEY, APP_Secret);
  HMAC := TOAuthSignatureMethod_HMAC_SHA1.Create;

  ARequest := TOAuthRequest.Create(URL);

  ARequest := ARequest.FromConsumerAndToken(Consumer, nil, URL);
  ARequest.Sign_Request(HMAC, Consumer, nil);
  HTTPStream := TStringStream.Create('');
  LHandler := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  URL := URL + '?' + ARequest.GetString;
  idHTTP1 := TIdHTTP.Create(nil);

IdHTTP1.IOHandler:=LHandler;
try
Response := idHTTP1.Get(URL);
  except
    on E : Exception do
    begin
      s := E.ClassName+' поднята ошибка, с сообщением : '+E.Message;
      MessageBox(0,PChar(s),'',0);
    end;
  end;
 { ShellExecute(0,
               PChar('open'),
               PChar(URL),    // <--- здесь указать урл
               Nil,
               Nil,
               SW_SHOW);   }


endpos := AnsiPos('&oauth_token=', Response);
oauth_token_secret := Copy(Response, 20, endpos-20);
Response := Copy(Response, endpos, Length(Response));

oauth_token := Copy(Response, 14, Length(Response));
Token := TOAuthToken.Create(oauth_token, oauth_token_secret);

end;


procedure Auth();
var
Callback_URL, URL :string;
begin
URL := 'https://www.dropbox.com/1/oauth/authorize';
Callback_URL := 'bsuirsched.appspot.com' ;
URL := URL + '?' + 'oauth_token=' + oauth_token + '&' + 'oauth_token_secret=' + oauth_token_secret +
'&oauth_callback=' + TOAuthUtil.urlEncodeRFC3986(Callback_URL);
         MessageBox(0,PChar(URL),'',0);
  ShellExecute(0,
               PChar('open'),
               PChar(URL),    // <--- здесь указать урл
               Nil,
               Nil,
               SW_SHOW);
end;

procedure Accept();
var
endpos: integer;
URL: string;
begin
URL := 'https://api.dropbox.com/1/oauth/access_token';
Consumer := nil;
Consumer := TOAuthConsumer.Create(Key, Secret,
'http://www.chuckbeasley.com');
ARequest.HTTPURL := URL;
ARequest := ARequest.FromConsumerAndToken(Consumer, Token, URL);
ARequest.Sign_Request(HMAC, Consumer, Token);
URL := URL + '?' + ARequest.GetString;
Response := idHTTP1.Get(URL);
endpos := AnsiPos('&oauth_token_secret=', Response);
oauth_token :='';
oauth_token := Copy(Response, 13, endpos-13);
Response := Copy(Response, endpos, Length(Response));

oauth_token_secret := Copy(Response, 21, Length(Response));
Token := TOAuthToken.Create(oauth_token, oauth_token_secret);
end;
{ ------------------------------------------------------------------ }

function FsFindFirst (Path : PChar; var FindData : tWIN32FINDDATA) : thandle; stdcall;
var
s: AnsiString;
begin
  request_token_flag := True;
  Request();
  Auth();

  if request_token_flag then
  begin
    result := REQUES_TOKEN_HANDLER;
    s:='Accept token' ;
    StrPCopy(FindData.cFileName,s);
  end;
end;

{ ------------------------------------------------------------------ }

function FsFindNext (Hdl : thandle; var FindData : tWIN32FINDDATA) : bool; stdcall;

begin
if Hdl=REQUES_TOKEN_HANDLER then
  FindData.cFileName := 'hello';
 // function FsFindNext
  MessageBox(0,'Dir','Find next',0);
 result := False;
end;

{ ------------------------------------------------------------------ }

function FsFindClose (Hdl : thandle) : integer; stdcall;

begin
result := 0;

end;

{ ------------------------------------------------------------------ }
function Copy(RemoteName, LocalName : PChar; CopyFlags : integer ;
                    RemoteInfo : pRemoteInfo):integer;

begin


end;
{ ------------------------------------------------------------------ }

function FsGetFile (RemoteName, LocalName : PChar; CopyFlags : integer ;
                    RemoteInfo : pRemoteInfo) : integer; stdcall;


begin
    result :=0 ;
end;
{ ------------------------------------------------------------------ }


exports

  FsFindClose,
  FsFindFirst,
  FsFindNext,
  FsGetFile,
  FsInit;

{ ------------------------------------------------------------------ }

end.