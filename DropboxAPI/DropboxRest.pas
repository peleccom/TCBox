unit DropboxRest;

interface
uses System.Classes, SysUtils, idHttp, IdSSLOpenSSL, Data.DBXJSON, IdHeaderList,IdStack,idComponent;
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
ErrorResponse =class(Exception)
private
  FStatus: integer;
  FReason: string;
  FBody: string;
  FErrorMsg:string;
  FUserErrorMsg:string;
  FHeaders: TIdHeaderList;
public
constructor Create(response:TIdHTTPResponse; errorMessage: string);
destructor Desroy();
property Code:integer read FStatus;
property Reason :string read FReason;
property Body:  string read FBody;
property Headers: TIdHeaderList read FHeaders;
property ErrorMessage: string read FErrorMsg;
property UserErrorMessage:string read FUserErrorMsg;
end;

RESTSocketError = class (Exception)
    constructor Create(host:string; e:Exception);
end;


TRestClient = class
  private
    FIdHttp : TidHttp;
    FLHandler : TIdSSLIOHandlerSocketOpenSSL;
   // procedure GET(url: string; aContent: TStream; headers: TIdHeaderList); overload;
  public
  constructor Create;
  destructor Destroy;override;
  class function Request(method, url: string; post_params:TStringList;body: string; headers : TStringList): TMemoryStream;
  function GET_JSON(url: string; headers: TIdHeaderList=nil) : TJsonObject;
  procedure GET(url: string; aContent: TStream;headers: TIdHeaderList=nil; beginproc : TWorkEvent=nil;
              progressproc : TWorkEvent=nil); overload;
  function GET(url: string; headers: TIdHeaderList=nil) : string; overload;
  function POST(url: string;rawpostParams:TStringList; headers: TIdHeaderList=nil) : string; overload;
  procedure POST(url: string;rawpostParams:TStringList; aContent: TStream;headers: TIdHeaderList=nil; beginproc : TWorkEvent=nil;
              progressproc : TWorkEvent=nil); overload;
  function POST_JSON(url: string;rawpostParams:TStringList; headers: TIdHeaderList=nil) : TJsonObject;
 // function POST(url: string; params, headers: TStringList):TJsonObject;
 // function PUT(url, body: string; headers: TStringList): TJsonObject;
  // abort download
 procedure Abort();
end;

implementation

{ TRESTClient }
function MemoryStreamToString(s: TStream): string;
var
SL:TStringList;
str : string;
begin
s.Position := 0;
SL:=TStringList.Create;
SL.LoadFromStream(s);
str:=SL.Text;
SL.Free;
s.Position := 0;
end;
procedure TRestClient.Abort;
begin
  FIdHttp.Disconnect;
end;

constructor TRESTClient.Create;
begin
  FIdHttp := TIdHTTP.Create(nil);
  FIdHttp.HandleRedirects := True;
  FLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  FIdHttp.IOHandler := FLHandler;
  FIdHttp.Request.UserAgent := 'Dropbox API Client Delphi';

end;

destructor TRESTClient.Destroy;
begin
  FreeAndNil(FLHandler);
  FreeAndNil(FIdHttp);
  inherited Destroy;
end;

procedure TRestClient.GET(url: string; aContent: TStream; headers: TIdHeaderList;
  beginproc : TWorkEvent; progressproc : TWorkEvent);
begin
//

try
  try

    if Assigned(beginproc)
      then FIdHttp.OnWorkBegin := beginproc;
    if Assigned(progressproc)
      then FIdHttp.OnWork := progressproc;
    FIdHttp.Request.RawHeaders.Clear;
    if headers <> nil then
        FIdHttp.Request.RawHeaders.AddStrings(headers);
    FIdHttp.Get(url, aContent);
  finally
    FIdHttp.OnWork := nil;
    FIdHttp.OnWorkBegin := nil;
  end;
except
  on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.Response, E1.ErrorMessage);
    end;
  on E2: EidSocketError do
  begin
    raise RESTSocketError.Create(FIdHttp.Request.Host,E2);
  end;

end;

end;

function TRESTClient.GET_JSON(url: string;  headers: TIdHeaderList=nil): TJsonObject;
var
  s: string;
begin
try
  s := GET(url, headers);
  Result :=TJSONObject.ParseJSONValue(s) as TJSONObject;
except
  on E3: TJSONException do
  begin
    raise ErrorResponse.Create(FIdHttp.Response,s);
  end;
end;
end;

function TRESTClient.GET(url: string;  headers: TIdHeaderList=nil): string;
begin
try
  FIdHttp.Request.RawHeaders.Clear;
  if headers <> nil then
      FIdHttp.Request.RawHeaders.AddStrings(headers);

  Result:=   FIdHttp.Get(url);
except
  on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.Response, E1.ErrorMessage);
    end;
  on E2: EidSocketError do
  begin
    raise RESTSocketError.Create(FIdHttp.Request.Host,E2);
  end;
end;
end;



function TRestClient.POST(url: string; rawpostParams: TStringList;
  headers: TIdHeaderList): string;
begin
try
  FIdHttp.Request.RawHeaders.Clear;
  if headers <> nil then
      FIdHttp.Request.RawHeaders.AddStrings(headers);
  FIdHttp.HTTPOptions := [];
  Result:=   FIdHttp.Post(url,rawpostParams);
except
  on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.Response, E1.ErrorMessage);
    end;
  on E2: EidSocketError do
  begin
    raise RESTSocketError.Create(FIdHttp.Request.Host,E2);
  end;
end;
end;

procedure TRestClient.POST(url: string; rawpostParams: TStringList;
  aContent: TStream; headers: TIdHeaderList; beginproc,
  progressproc: TWorkEvent);
begin
//

try
  try

    if Assigned(beginproc)
      then FIdHttp.OnWorkBegin := beginproc;
    if Assigned(progressproc)
      then FIdHttp.OnWork := progressproc;
    FIdHttp.Request.RawHeaders.Clear;
    if headers <> nil then
        FIdHttp.Request.RawHeaders.AddStrings(headers);
    FIdHttp.HTTPOptions := [];
    FIdHttp.Post(url,rawpostParams, aContent);
  finally
    FIdHttp.OnWork := nil;
    FIdHttp.OnWorkBegin := nil;
  end;
except
  on E1: EIdHTTPProtocolException do
    begin
      raise ErrorResponse.Create(FIdHttp.Response, E1.ErrorMessage);
    end;
  on E2: EidSocketError do
  begin
    raise RESTSocketError.Create(FIdHttp.Request.Host,E2);
  end;

end;
end;

function TRestClient.POST_JSON(url: string; rawpostParams: TStringList;
  headers: TIdHeaderList): TJsonObject;
var
  s: string;
begin
try
  s := POST(url,rawpostParams, headers);
  Result :=TJSONObject.ParseJSONValue(s) as TJSONObject;
except
  on E3: TJSONException do
  begin
    raise ErrorResponse.Create(FIdHttp.Response,s);
  end;
end;
end;

{function TRESTClient.POST(url: string; params,
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
class function TRESTClient.Request(method, url: string;
  post_params: TStringList; body: string; headers: TStringList): TMemoryStream;
begin
  if post_params <> nil then
  begin
    if body <> '' then
      raise Exception.Create('body parameter cannot be used with post_params parameter');
  body := '';
   end;

end;

{ ErrorResponse }

constructor ErrorResponse.Create(response: TIdHTTPResponse;errorMessage: string);
var
  json : TJSONObject;
  msg : string;
begin
inherited Create('');
FStatus := response.ResponseCode;
FReason := response.ResponseText;
FBody := errorMessage;
FHeaders := response.RawHeaders;
json := nil;
try
try
 json := TJsonObject.ParseJSONValue(FBody) as TJSONObject;
 if json=nil then raise Exception.Create('Non json response');
 FErrorMsg := (json.Get('error').JsonValue as TJSONString).Value;
 FUserErrorMsg := (json.Get('user_error').JsonValue as TJSONString).Value;
finally
  if json <> nil then json.Free;
  end;
  except
  end;

  if ( FUserErrorMsg <> '') and (FUserErrorMsg <> FErrorMsg)
       then
           msg := Format('%s (%s)', [FUserErrorMsg, FErrorMsg])
       else
          if FErrorMsg <> ''
              then
                  msg := FErrorMsg
              else
                  if FBody = ''
                      then
                          msg := FReason
                  else
                      msg := Format('Error parsing response body or headers: ' +
                  'Body - %s Headers - %s', [FBody, FHeaders.DelimitedText]);

Message := Format('[%d] %s' ,[FStatus,msg]);

end;

destructor ErrorResponse.Desroy;
begin
inherited;
end;

{ RESTSocketError }

constructor RESTSocketError.Create(host: string; e: Exception);
begin
inherited Create(Format('Error connecting to"%s\": %s' , [host, e.Message]));
end;

end.
