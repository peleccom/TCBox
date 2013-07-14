unit DropboxSession;

interface
uses System.Classes, SysUtils, OAuth, IdURI, DropboxRest, Data.DBXJSON;

  type
  TAccessType = (dropbox, app_folder);
  TDropboxSession = class

    const
    API_VERSION = 1;
    API_HOST = 'api.dropbox.com';
    WEB_HOST = 'www.dropbox.com';
    API_CONTENT_HOST = 'api-content.dropbox.com';
    private
    FConsumer : TOAuthConsumer;
    FToken: TOAuthToken;
    FRequestToken: TOAuthToken;
    FSignatureMethod : TOAuthSignatureMethod;
    FLocale : string;
    FRestClient: TRestClient;
    FRoot:string;
    public
    property Root: string read FRoot;
    constructor Create(consumer_key, consumer_secret: string; access_type: TAccessType; locale:string='');
    destructor Destroy();
    function isLinked():boolean;
    procedure unlink();
    procedure setToken(access_token, access_token_secret: string);
    function getAccessToken: TOAuthToken;
    procedure setRequestToken(request_token, request_token_secret: string);
    function buildPath(target:string; params:TStringList=nil):string;
    function buildUrl(host: string; target: string; params: TStringList=nil):string;
    function buildAuthorizeUrl(request_token: TOAuthToken; oauth_callback: string):string;
    function obtainRequestToken(): TOAuthToken;
    function obtainAccessToken(request_token: TOAuthToken = nil):TOAuthToken;
    function getAccessString(URL: string; request_token: TOAuthToken=nil):string;
    procedure buildAccessHeaders(method, resourse_url: string; params: TStringList; request_token: TOAuthToken;var headers_out,params_out :TStringList);
    function SaveAccessToken(filename : string) : Boolean;
    function LoadAccessToken(filename : string) : Boolean;
  end;

implementation




{ TDropboxSession }

procedure TDropboxSession.buildAccessHeaders(method, resourse_url: string;
  params: TStringList; request_token: TOAuthToken; var headers_out,
  params_out: TStringList);
var
  mparams: TStringList;
begin
  mparams := TStringList.Create;
  if params<>nil then
    mparams.AddStrings(params);
  mparams.Add( 'oauth_consumer_key='+FConsumer.Key);
  FreeAndNil(mparams);
end;

function TDropboxSession.buildAuthorizeUrl(request_token: TOAuthToken;
  oauth_callback: string): string;
var
params:TStringList;
begin
  params:= TStringList.Create;
  params.Add('oauth_token='+ request_token.key);
  if oauth_callback <> '' then
    params.Add('oauth_callback='+oauth_callback);
  Result := buildUrl(WEB_HOST,'/oauth/authorize', params );
  FreeAndNil(params);
end;

function TDropboxSession.buildPath(target: string; params: TStringList): string;
function _IntToHex(Value: Integer; Digits: Integer): String;
begin
    Result := SysUtils.IntToHex(Value, Digits);
end;
function UrlEncode(const S : String) : String;
var
    I : Integer;
    Ch : Char;
    raw : TArray<System.Byte>;
begin
    Result := '';
    for I := 1 to Length(S) do begin
        Ch := S[I];
        if ((Ch >= '0') and (Ch <= '9')) or
           ((Ch >= 'a') and (Ch <= 'z')) or
           ((Ch >= 'A') and (Ch <= 'Z')) or
           (Ch = '.') or (Ch = '-') or (Ch = '_') or (Ch = '~') or (Ch = '/') then
            Result := Result + Ch
        else
        begin
            if ord(Ch)<255 then
            Result := Result + '%' + _IntToHex(Ord(Ch), 2)
            else
            begin
            raw := TEncoding.UTF8.GetBytes(ch);
            Result := Result + '%' + _IntToHex(raw[0] , 2)+ '%' + _IntToHex(raw[1] , 2)
            end;
        end;

    end;
end;
var
  target_path: string;
  mparams : TStringList;
begin
  target_path :=  UrlEncode(target);
  mparams :=  TStringList.Create;
  mparams.Delimiter:='&';
  if params <> nil then
    mparams.AddStrings(params);
  if FLocale <> '' then
    mparams.Add('locale=' + FLocale);
  if mparams.Count<>0 then
    Result := Format('/%d%s?%s',[API_VERSION, target_path, TIdURI.ParamsEncode(mparams.DelimitedText)])
  else
    Result := Format('/%d%s',[API_VERSION,target_path ]);
  FreeAndNil(mparams);
end;

function TDropboxSession.buildUrl(host, target: string;
  params: TStringList): string;
begin
  Result := Format('https://%s%s',[host, buildPath(target, params)]);
end;

constructor TDropboxSession.Create(consumer_key, consumer_secret: string;
  access_type: TAccessType; locale: string);
begin
  FConsumer := TOAuthConsumer.Create(consumer_key, consumer_secret);
  FToken := nil;
  FRequestToken := nil;
  FSignatureMethod := TOAuthSignatureMethod_HMAC_SHA1.Create;
  FLocale := locale;
  if access_type = TAccessType.dropbox then FRoot := 'dropbox'
                                        else FRoot := 'sandbox';

  FRestClient := TRestClient.Create;
end;

destructor TDropboxSession.Destroy;
begin
  if FConsumer<>nil then
    FreeAndNil(FConsumer);
  if FSignatureMethod<>nil then
    FreeAndNil(FSignatureMethod);
  if FToken<>nil then
    FreeAndNil(FToken);
  if FRequestToken<>nil then
    FreeAndNil(FRequestToken);
  if FRestClient<>nil then
    FreeAndNil(FRestClient);

end;

function TDropboxSession.getAccessString(URL: string; request_token: TOAuthToken=nil):string;
var
  ARequest : TOAuthRequest;
  token : TOAuthToken;
begin
  ARequest := TOAuthRequest.Create(URL);
  if request_token<>nil then token := request_token
                        else token := FToken;
  ARequest.HTTPURL := URL;
  ARequest.FromConsumerAndToken(FConsumer, token, URL);
  ARequest.Sign_Request(FSignatureMethod, FConsumer, token);
  Result := ARequest.GetString;
  FreeAndNil(ARequest);
end;

function TDropboxSession.getAccessToken: TOAuthToken;
begin
  Result := FToken;
end;

function TDropboxSession.isLinked: boolean;
begin
   if FToken <> nil then
    Result := True
    else
    Result := False;
end;

function TDropboxSession.LoadAccessToken(filename: string): Boolean;
var
sl : TStringList;
t : TOAuthToken;
begin
  sl := TStringList.Create;
  t := TOAuthToken.Create('','');
  Result := False;
  try
    try
      sl.LoadFromFile(filename);
      t.FromString(sl.Text);
      setToken(t.Key, t.Secret);
      Result := True;
    finally
      t.Free;
      sl.Free;
    end;
  except
  end;
end;

function TDropboxSession.obtainAccessToken(request_token: TOAuthToken = nil): TOAuthToken;
var
  url,s : string;
begin
  if request_token = nil then request_token := FRequestToken;
  Assert(request_token <> nil, 'No request_token available on the session. Please pass one.');
  url := buildUrl(API_HOST, '/oauth/access_token');
  url := url + '?' + getAccessString(url, request_token);
  s := FRestClient.GET(url);
  if FToken = nil then FToken := TOAuthToken.Create('','');
  FToken.FromString(s);
  Result := FToken;
end;

function TDropboxSession.obtainRequestToken(): TOAuthToken;
var
  url: string;
  s: string;
  ARequest : TOAuthRequest;
begin
  if FToken<>nil then
    FreeAndNil(FToken);
  url := buildUrl(API_HOST, '/oauth/request_token');
  ARequest := TOAuthRequest.Create(url);
  ARequest := ARequest.FromConsumerAndToken(FConsumer, nil, url);
  ARequest.Sign_Request(FSignatureMethod, FConsumer, nil);
  url := url + '?' + ARequest.GetString;
  s := FRestClient.GET(url);
  if FRequestToken<>nil then
    FreeAndNil(FRequestToken);
  FRequestToken := TOAuthToken.Create('','');
  FRequestToken.FromString(s);
  ARequest.Free;
  Result := FRequestToken;
end;

function TDropboxSession.SaveAccessToken(filename: string): Boolean;
var
t : TOAuthToken;
sl : TStringList;
begin
  Result := False;
  try
    t := getAccessToken();
    sl := TStringList.Create;
    sl.Text := t.AsString;
    try
      sl.SaveToFile(filename);
      Result := True;
    finally
      sl.Free;
    end;
  except

  end;
end;

procedure TDropboxSession.setRequestToken(request_token,
  request_token_secret: string);
begin
  if FToken<>nil then
    FreeAndNil(FToken);
  FToken := TOAuthToken.Create(request_token, request_token_secret);
end;

procedure TDropboxSession.setToken(access_token, access_token_secret: string);
begin
  if FToken<>nil then
    FreeAndNil(FToken);
  FToken := TOAuthToken.Create(access_token, access_token_secret);
end;

procedure TDropboxSession.unlink;
begin
  if FToken<>nil then
    FreeAndNil(FToken);
end;

end.
