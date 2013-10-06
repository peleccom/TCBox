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
    FConsumer: TOAuthConsumer;
    FToken: TOAuthToken;
    FRequestToken: TOAuthToken;
    FSignatureMethod: TOAuthSignatureMethod;
    FLocale: string;
    FRestClient: TRestClient;
    FRoot: string;
    procedure OauthSignRequest(var params: TStringList;
      consumer: TOAuthConsumer; token: TOAuthToken);
  public
    property Root: string read FRoot;
    constructor Create(consumer_key, consumer_secret: string;
      access_type: TAccessType; locale: string = '');
    destructor Destroy(); override;
    function isLinked(): boolean;
    procedure unlink();
    procedure setToken(access_token, access_token_secret: string);
    function getAccessToken: TOAuthToken;
    procedure setRequestToken(request_token, request_token_secret: string);
    function buildPath(target: string; params: TStringList = nil): string;
    function buildUrl(host: string; target: string;
      params: TStringList = nil): string;
    function buildAuthorizeUrl(request_token: TOAuthToken;
      oauth_callback: string): string;
    function obtainRequestToken(): TOAuthToken;
    function obtainAccessToken(request_token: TOAuthToken = nil): TOAuthToken;
    function getAccessString(URL: string;
      request_token: TOAuthToken = nil): string;
    function request(URL: string; var requestparams: TStringList;
      var requestheaders: TStringList; params: TStringList = nil;
      method: string = 'GET'): string;
    procedure buildAccessHeaders(method, resourse_url: string;
      params: TStringList; request_token: TOAuthToken;
      var headers_out, params_out: TStringList);
    function SaveAccessToken(filename: string): boolean; overload;
    function SaveAccessToken(s: TStream): boolean; overload;
    function LoadAccessToken(filename: string): boolean; overload;
    function LoadAccessToken(s: TStream): boolean; overload;
  end;

implementation

{ TDropboxSession }

procedure TDropboxSession.buildAccessHeaders(method, resourse_url: string;
  params: TStringList; request_token: TOAuthToken;
  var headers_out, params_out: TStringList);
var
  oauth_params: TStringList;
  token: TOAuthToken;
  I: integer;
  key: string;
begin
  params_out := TStringList.Create;
  oauth_params := TStringList.Create;
  headers_out := TStringList.Create;
  if params <> nil then
    params_out.Assign(params);
  oauth_params.Values['oauth_consumer_key'] := FConsumer.key;
  oauth_params.Values['oauth_timestamp'] := TOAuthRequest.GenerateTimestamp();
  oauth_params.Values['oauth_nonce'] := TOAuthRequest.GenerateNonce();
  oauth_params.Values['oauth_version'] := OAUTH_VERSION;
  if request_token <> nil then
    token := request_token
  else
    token := FToken;
  if token <> nil then
    oauth_params.Values['oauth_token'] := token.key;
  OauthSignRequest(oauth_params, FConsumer, token);
  for I := 0 to oauth_params.Count - 1 do
  begin
    key := oauth_params.Names[I];
    params_out.Values[key] := oauth_params.Values[key];
  end;
  oauth_params.Free;
end;

function TDropboxSession.buildAuthorizeUrl(request_token: TOAuthToken;
  oauth_callback: string): string;
var
  params: TStringList;
begin
  params := TStringList.Create;
  params.Add('oauth_token=' + request_token.key);
  if oauth_callback <> '' then
    params.Add('oauth_callback=' + oauth_callback);
  Result := buildUrl(WEB_HOST, '/oauth/authorize', params);
  FreeAndNil(params);
end;

function TDropboxSession.buildPath(target: string; params: TStringList): string;
  function _IntToHex(Value: integer; Digits: integer): String;
  begin
    Result := SysUtils.IntToHex(Value, Digits);
  end;
  function UrlEncode(const s: String): String;
  var
    I: integer;
    Ch: Char;
    raw: TArray<System.Byte>;
  begin
    Result := '';
    for I := 1 to Length(s) do
    begin
      Ch := s[I];
      if ((Ch >= '0') and (Ch <= '9')) or ((Ch >= 'a') and (Ch <= 'z')) or
        ((Ch >= 'A') and (Ch <= 'Z')) or (Ch = '.') or (Ch = '-') or (Ch = '_')
        or (Ch = '~') or (Ch = '/') then
        Result := Result + Ch
      else
      begin
        if ord(Ch) < 255 then
          Result := Result + '%' + _IntToHex(ord(Ch), 2)
        else
        begin
          raw := TEncoding.UTF8.GetBytes(Ch);
          Result := Result + '%' + _IntToHex(raw[0], 2) + '%' +
            _IntToHex(raw[1], 2)
        end;
      end;

    end;
  end;

var
  target_path: string;
  mparams: TStringList;
begin
  target_path := UrlEncode(target);
  mparams := TStringList.Create;
  mparams.Delimiter := '&';
  if params <> nil then
    mparams.AddStrings(params);
  if FLocale <> '' then
    mparams.Add('locale=' + FLocale);
  if mparams.Count <> 0 then
    Result := Format('/%d%s?%s', [API_VERSION, target_path,
      TIdURI.ParamsEncode(mparams.DelimitedText)])
  else
    Result := Format('/%d%s', [API_VERSION, target_path]);
  FreeAndNil(mparams);
end;

function TDropboxSession.buildUrl(host, target: string;
  params: TStringList): string;
begin
  Result := Format('https://%s%s', [host, buildPath(target, params)]);
end;

constructor TDropboxSession.Create(consumer_key, consumer_secret: string;
  access_type: TAccessType; locale: string);
begin
  FConsumer := TOAuthConsumer.Create(consumer_key, consumer_secret);
  FToken := nil;
  FRequestToken := nil;
  FSignatureMethod := TOAuthSignatureMethod_HMAC_SHA1.Create;
  FLocale := locale;
  if access_type = TAccessType.dropbox then
    FRoot := 'dropbox'
  else
    FRoot := 'sandbox';

  FRestClient := TRestClient.Create;
end;

destructor TDropboxSession.Destroy;
begin
  if FConsumer <> nil then
    FreeAndNil(FConsumer);
  if FSignatureMethod <> nil then
    FreeAndNil(FSignatureMethod);
  if FToken <> nil then
    FreeAndNil(FToken);
  if FRequestToken <> nil then
    FreeAndNil(FRequestToken);
  if FRestClient <> nil then
    FreeAndNil(FRestClient);
  inherited Destroy();
end;

function TDropboxSession.getAccessString(URL: string;
  request_token: TOAuthToken = nil): string;
var
  ARequest: TOAuthRequest;
  token: TOAuthToken;
begin
  if request_token <> nil then
    token := request_token
  else
    token := FToken;
  ARequest := TOAuthRequest.FromConsumerAndToken(FConsumer, token, URL);
  ARequest.SignRequest(FSignatureMethod, FConsumer, token);
  Result := ARequest.ToUrl;
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

function TDropboxSession.LoadAccessToken(s: TStream): boolean;
var
  sl: TStringList;
  t: TOAuthToken;
begin
  sl := TStringList.Create;
  t := TOAuthToken.Create('', '');
  Result := False;
  try
    try
      sl.LoadFromStream(s);
      t.FromString(sl.Text);
      setToken(t.key, t.Secret);
      Result := True;
    finally
      t.Free;
      sl.Free;
    end;
  except
  end;
end;

function TDropboxSession.LoadAccessToken(filename: string): boolean;
var
  keyFileStream: TFileStream;
begin
  Result := True;
  try
    keyFileStream := TFileStream.Create(filename, fmOpenRead);
    try
      Result := LoadAccessToken(keyFileStream);
    finally
      keyFileStream.Free;
    end;
  except
    Result := False;
  end;
end;

procedure TDropboxSession.OauthSignRequest(var params: TStringList;
  consumer: TOAuthConsumer; token: TOAuthToken);
var
  sig: string;
begin
  params.Values['oauth_signature_method'] := 'PLAINTEXT';

  if token <> nil then
    sig := Format('%s&%s', [consumer.Secret, token.Secret])
  else
    sig := Format('%s&', [consumer.Secret]);
  params.Values['oauth_signature'] := sig;
end;

function TDropboxSession.obtainAccessToken(request_token: TOAuthToken = nil)
  : TOAuthToken;
var
  URL, s: string;
  ARequest: TOAuthRequest;
begin
  if request_token = nil then
    request_token := FRequestToken;
  Assert(request_token <> nil,
    'No request_token available on the session. Please pass one.');
  URL := buildUrl(API_HOST, '/oauth/access_token');
  ARequest := TOAuthRequest.FromConsumerAndToken(FConsumer, request_token, URL);
  ARequest.SignRequest(FSignatureMethod, FConsumer, request_token);
  URL := ARequest.ToUrl;
  s := FRestClient.GET(URL);
  if FToken = nil then
    FToken := TOAuthToken.Create('', '');
  FToken.FromString(s);
  Result := FToken;
  ARequest.Free;
end;

function TDropboxSession.obtainRequestToken(): TOAuthToken;
var
  URL: string;
  s: string;
  ARequest: TOAuthRequest;
begin
  if FToken <> nil then
    FreeAndNil(FToken);
  URL := buildUrl(API_HOST, '/oauth/request_token');
  ARequest := TOAuthRequest.FromConsumerAndToken(FConsumer, nil, URL);
  ARequest.SignRequest(FSignatureMethod, FConsumer, nil);
  URL := ARequest.ToUrl;
  s := FRestClient.GET(URL);
  if FRequestToken <> nil then
    FreeAndNil(FRequestToken);
  FRequestToken := TOAuthToken.Create('', '');
  FRequestToken.FromString(s);
  ARequest.Free;
  Result := FRequestToken;
end;

/// make request url, parameters to post and headers to request
function TDropboxSession.request(URL: string;
  var requestparams, requestheaders: TStringList; params: TStringList;
  method: string): string;
var
  ARequest: TOAuthRequest;
begin
  ARequest := TOAuthRequest.FromConsumerAndToken(FConsumer, FToken, URL,
    params, method);
  ARequest.SignRequest(FSignatureMethod, FConsumer, FToken);
  if (method = 'GET') or (method = 'PUT') then
  begin
    Result := ARequest.ToUrl;
  end
  else
  begin
    Result := ARequest.GetNormalizedHTTPUrl;
    ARequest.ToPost(requestparams);
  end;
  ARequest.ToHeader(requestheaders);
  ARequest.Free;
end;

function TDropboxSession.SaveAccessToken(s: TStream): boolean;
var
  t: TOAuthToken;
  sl: TStringList;
begin
  Result := False;
  try
    t := getAccessToken();
    sl := TStringList.Create;
    sl.Text := t.AsString;
    try
      sl.SaveToStream(s);
      Result := True;
    finally
      sl.Free;
    end;
  except

  end;

end;

function TDropboxSession.SaveAccessToken(filename: string): boolean;
var
  keyFileStream: TFileStream;
begin
  Result := True;
  try
    keyFileStream := TFileStream.Create(filename, fmCreate);
    try
      Result := SaveAccessToken(keyFileStream);
    finally
      keyFileStream.Free;
    end;
  except
    Result := False;
  end;
end;

procedure TDropboxSession.setRequestToken(request_token,
  request_token_secret: string);
begin
  if FToken <> nil then
    FreeAndNil(FToken);
  FToken := TOAuthToken.Create(request_token, request_token_secret);
end;

procedure TDropboxSession.setToken(access_token, access_token_secret: string);
begin
  if FToken <> nil then
    FreeAndNil(FToken);
  FToken := TOAuthToken.Create(access_token, access_token_secret);
end;

procedure TDropboxSession.unlink;
begin
  if FToken <> nil then
    FreeAndNil(FToken);
end;

end.
