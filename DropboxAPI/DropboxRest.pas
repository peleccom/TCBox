unit DropboxRest;

interface

uses System.Classes, SysUtils, idHttp, IdSSLOpenSSL, Data.DBXJSON, IdHeaderList,
  IdStack, idComponent;

type
  {

    procedure TForm1.Button1Click(Sender: TObject);
    var
    s :TMemoryStream;
    sl : TStringStream;
    begin
    sl := TStringStream.Create('',TEncoding.UTF8);
    s := TMemoryStream.Create;
    IdHTTP1.HandleRedirects := True;
    IdHTTP1.Get('http://open.by', s);
    sl.LoadFromStream(s);
    ShowMessage(sl.DataString);
    end;

  }
  ErrorResponse = class(Exception)
  private
    FStatus: integer;
    FReason: string;
    FBody: TJSONObject;
    FErrorMsg: string;
    FUserErrorMsg: string;
    FHeaders: TIdHeaderList;
  public
    constructor Create(response: TIdHTTPResponse; errorMessage: string);
    destructor Desroy();
    property Code: integer read FStatus;
    property Reason: string read FReason;
    property Body: TJSONObject read FBody;
    property Headers: TIdHeaderList read FHeaders;
    property errorMessage: string read FErrorMsg;
    property UserErrorMessage: string read FUserErrorMsg;
  end;

  RESTSocketError = class(Exception)
    constructor Create(host: string; e: Exception);
  end;

  TRestClient = class
  private
    FIdHttp: TidHttp;
    FLHandler: TIdSSLIOHandlerSocketOpenSSL;
    // procedure GET(url: string; aContent: TStream; headers: TIdHeaderList); overload;
  public
    constructor Create;
    destructor Destroy; override;
    class function Request(method, url: string; post_params: TStringList;
      Body: string; Headers: TStringList): TMemoryStream;
    function GET_JSON(url: string; Headers: TIdHeaderList = nil): TJSONObject;
    procedure GET(url: string; aContent: TStream; Headers: TIdHeaderList = nil;
      beginproc: TWorkEvent = nil; progressproc: TWorkEvent = nil); overload;
    function GET(url: string; Headers: TIdHeaderList = nil): string; overload;
    function POST(url: string; rawpostParams: TStringList;
      Headers: TIdHeaderList = nil): string; overload;
    procedure POST(url: string; rawpostParams: TStringList; aContent: TStream;
      Headers: TIdHeaderList = nil; beginproc: TWorkEvent = nil;
      progressproc: TWorkEvent = nil); overload;
    function POST_JSON(url: string; rawpostParams: TStringList;
      Headers: TIdHeaderList = nil): TJSONObject;
    function PUT(url: string; Body: TStream; Headers: TIdHeaderList = nil;
      beginproc: TWorkEvent = nil; progressproc: TWorkEvent = nil;
      mimeType: String = ''): string; overload;
    function PUT_JSON(url: string; Body: TStream; Headers: TIdHeaderList = nil;
      beginproc: TWorkEvent = nil; progressproc: TWorkEvent = nil)
      : TJSONObject; overload;
    // function POST(url: string; params, headers: TStringList):TJsonObject;
    // function PUT(url, body: string; headers: TStringList): TJsonObject;
    // abort download
    procedure Abort();
  end;

implementation

{ TRESTClient }
function MemoryStreamToString(s: TStream): string;
var
  SL: TStringList;
  str: string;
begin
  s.Position := 0;
  SL := TStringList.Create;
  SL.LoadFromStream(s);
  str := SL.Text;
  SL.Free;
  s.Position := 0;
end;

procedure TRestClient.Abort;
begin
  FIdHttp.Disconnect;
end;

constructor TRestClient.Create;
begin
  FIdHttp := TidHttp.Create(nil);
  FIdHttp.HandleRedirects := True;
  FLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  FIdHttp.IOHandler := FLHandler;
  FIdHttp.Request.UserAgent := 'Dropbox API Client Delphi';

end;

destructor TRestClient.Destroy;
begin
  FreeAndNil(FLHandler);
  FreeAndNil(FIdHttp);
  inherited Destroy;
end;

procedure TRestClient.GET(url: string; aContent: TStream;
  Headers: TIdHeaderList; beginproc: TWorkEvent; progressproc: TWorkEvent);
begin
  //

  try
    try

      if Assigned(beginproc) then
        FIdHttp.OnWorkBegin := beginproc;
      if Assigned(progressproc) then
        FIdHttp.OnWork := progressproc;
      FIdHttp.Request.RawHeaders.Clear;
      if Headers <> nil then
        FIdHttp.Request.RawHeaders.AddStrings(Headers);
      FIdHttp.GET(url, aContent);
    finally
      FIdHttp.OnWork := nil;
      FIdHttp.OnWorkBegin := nil;
    end;
  except
    on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, E1.errorMessage);
    end;
    on E2: EidSocketError do
    begin
      raise RESTSocketError.Create(FIdHttp.Request.host, E2);
    end;

  end;

end;

function TRestClient.GET_JSON(url: string; Headers: TIdHeaderList = nil)
  : TJSONObject;
var
  s: string;
begin
  try
    s := GET(url, Headers);
    Result := TJSONObject.ParseJSONValue(s) as TJSONObject;
  except
    on E3: TJSONException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, s);
    end;
  end;
end;

function TRestClient.GET(url: string; Headers: TIdHeaderList = nil): string;
begin
  try
    FIdHttp.Request.RawHeaders.Clear;
    if Headers <> nil then
      FIdHttp.Request.RawHeaders.AddStrings(Headers);

    Result := FIdHttp.GET(url);
  except
    on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, E1.errorMessage);
    end;
    on E2: EidSocketError do
    begin
      raise RESTSocketError.Create(FIdHttp.Request.host, E2);
    end;
  end;
end;

function TRestClient.POST(url: string; rawpostParams: TStringList;
  Headers: TIdHeaderList): string;
begin
  try
    FIdHttp.Request.RawHeaders.Clear;
    if Headers <> nil then
      FIdHttp.Request.RawHeaders.AddStrings(Headers);
    FIdHttp.HTTPOptions := [];
    Result := FIdHttp.POST(url, rawpostParams);
  except
    on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, E1.errorMessage);
    end;
    on E2: EidSocketError do
    begin
      raise RESTSocketError.Create(FIdHttp.Request.host, E2);
    end;
  end;
end;

procedure TRestClient.POST(url: string; rawpostParams: TStringList;
  aContent: TStream; Headers: TIdHeaderList;
  beginproc, progressproc: TWorkEvent);
begin
  //

  try
    try

      if Assigned(beginproc) then
        FIdHttp.OnWorkBegin := beginproc;
      if Assigned(progressproc) then
        FIdHttp.OnWork := progressproc;
      FIdHttp.Request.RawHeaders.Clear;
      if Headers <> nil then
        FIdHttp.Request.RawHeaders.AddStrings(Headers);
      FIdHttp.HTTPOptions := [];
      FIdHttp.POST(url, rawpostParams, aContent);
    finally
      FIdHttp.OnWork := nil;
      FIdHttp.OnWorkBegin := nil;
    end;
  except
    on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, E1.errorMessage);
    end;
    on E2: EidSocketError do
    begin
      raise RESTSocketError.Create(FIdHttp.Request.host, E2);
    end;

  end;
end;

function TRestClient.POST_JSON(url: string; rawpostParams: TStringList;
  Headers: TIdHeaderList): TJSONObject;
var
  s: string;
begin
  try
    s := POST(url, rawpostParams, Headers);
    Result := TJSONObject.ParseJSONValue(s) as TJSONObject;
  except
    on E3: TJSONException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, s);
    end;
  end;
end;

{ function TRESTClient.POST(url: string; params,
  headers: TStringList): TJsonObject;
  var
  s:string;
  begin
  s := FIdHttp.Post(url, params);
  Result :=TJSONObject.ParseJSONValue(s) as TJSONObject;
  end;

  function TRESTClient.PUT(url, body: string;
  headers: TStringList): TJsonObject;
  begin
  // json :=TJSONObject.ParseJSONValue(Result) as TJSONObject;
  end;
}
class function TRestClient.Request(method, url: string;
  post_params: TStringList; Body: string; Headers: TStringList): TMemoryStream;
begin
  if post_params <> nil then
  begin
    if Body <> '' then
      raise Exception.Create
        ('body parameter cannot be used with post_params parameter');
    Body := '';
  end;

end;

function TRestClient.PUT(url: string; Body: TStream; Headers: TIdHeaderList;
  beginproc, progressproc: TWorkEvent; mimeType: String): string;
begin
  //

  try
    try

      if Assigned(beginproc) then
        FIdHttp.OnWorkBegin := beginproc;
      if Assigned(progressproc) then
        FIdHttp.OnWork := progressproc;
      FIdHttp.Request.RawHeaders.Clear;
      if Headers <> nil then
        FIdHttp.Request.RawHeaders.AddStrings(Headers);
      FIdHttp.HTTPOptions := [];
      if mimeType <> '' then
        FIdHttp.Request.ContentType := mimeType;
      Result := FIdHttp.PUT(url, Body);
    finally
      FIdHttp.OnWork := nil;
      FIdHttp.OnWorkBegin := nil;
      FIdHttp.Request.ContentType := '';
    end;
  except
    on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, E1.errorMessage);
    end;
    on E2: EidSocketError do
    begin
      raise RESTSocketError.Create(FIdHttp.Request.host, E2);
    end;

  end;
end;

function TRestClient.PUT_JSON(url: string; Body: TStream;
  Headers: TIdHeaderList; beginproc, progressproc: TWorkEvent): TJSONObject;
var
  s: string;
begin
  try
    s := PUT(url, Body, Headers, beginproc, progressproc);
    Result := TJSONObject.ParseJSONValue(s) as TJSONObject;
  except
    on E3: TJSONException do
    begin
      raise ErrorResponse.Create(FIdHttp.response, s);
    end;
  end;
end;

{ ErrorResponse }

constructor ErrorResponse.Create(response: TIdHTTPResponse;
  errorMessage: string);
var
  json: TJSONObject;
  msg: string;
begin
  inherited Create('');
  FStatus := response.ResponseCode;
  FReason := response.ResponseText;
  FBody := nil;
  FHeaders := response.RawHeaders;
  json := nil;
  json := TJSONObject.ParseJSONValue(errorMessage) as TJSONObject;
  if json = nil then
    raise Exception.Create('Non json response');
  FBody := json;
  try
  FErrorMsg := (json.GET('error').JsonValue as TJSONString).Value;
  FUserErrorMsg := (json.GET('user_error').JsonValue as TJSONString).Value;
  except
   // field 'user_error' may be empty
  end;
  if (FUserErrorMsg <> '') and (FUserErrorMsg <> FErrorMsg) then
    msg := Format('%s (%s)', [FUserErrorMsg, FErrorMsg])
  else if FErrorMsg <> '' then
    msg := FErrorMsg
  else if FBody = nil then
    msg := FReason
  else
    msg := Format('Error parsing response body or headers: ' +
      'Body - %s Headers - %s', [FBody, FHeaders.DelimitedText]);

  Message := Format('[%d] %s', [FStatus, msg]);

end;

destructor ErrorResponse.Desroy;
begin
  inherited;
  if FBody <> nil then
    FBody.Free;
end;

{ RESTSocketError }

constructor RESTSocketError.Create(host: string; e: Exception);
begin
  inherited Create(Format('Error connecting to"%s\": %s', [host, e.Message]));
end;

end.
