unit DropboxClient;

interface
uses Windows{debug}, DropboxSession, SysUtils, System.Classes, DropboxRest, Data.DBXJSON, idComponent,Oauth, IdCustomHTTPServer;
type
  TDropboxClient = class
  private
    FSession: TDropboxSession;
    FrestClient : TRestClient;
  public
  constructor Create(session: TDropboxSession);
  constructor Destroy();
  // make reuest url , postparams and headers. Return in out params. Client must free they then finish
  function request(target: string;var requestparams: TStringList;
           var requestheaders: TStringList; params: TStringList=nil;
           method: string='GET';contentserver: boolean=false):string;overload;
  function request(target: string;params: TStringList=nil;
           method: string='GET';contentserver: boolean=false):string;overload;
  function accountInfo():TJsonObject;
  function metaData(path: string; list: boolean;file_limit: integer = 10000; hash:boolean=False;revision:string='';include_deleted:boolean=False):TJsonObject;
  // Check file existance
  function fileExists(path: string): boolean;
  procedure getFile(fromPath:string; stream: TStream; rev:string='';workbegin : TWorkEvent=nil; work : TWorkEvent=nil);
  function createFolder(path: string):boolean;
  function fileDelete(path: string): boolean;
  function putFile(fullPath: string;filestream: Tstream;overwrite: boolean=False; parentRev: string=''; workbegin : TWorkEvent=nil; work : TWorkEvent=nil): string;
  // abort download operation
  procedure Abort();
end;
  function format_path(path : string):string;
  function Strip(s: String; ch: Char): String;
  function GetSimpleFileName(s: string):string;

implementation

function Strip(s: String; ch: Char): String;
var
  i, index :integer;
begin
  index := 1;
  for I := 1 to Length(s) do
    if  s[i] <> ch  then
    begin
     index := i;
     break;
    end;
  s := Copy(s, index, Length(s)-index+1);
  index := Length(s);
  for I := Length(s) downto 1 do
    if  s[i] <> ch  then
    begin
     index := i;
     break;
    end;
    s := Copy(s, 1, index);
  Result := s;
end;

function format_path(path : string):string;
begin
   if path = '' then
   begin
    Result := path;
    exit;
   end;
   path := StringReplace(path, '//', '/',[rfReplaceAll]);
   if path='/'
    then Result := ''
    else Result := '/' + Strip(path, '/');
end;

  function GetSimpleFileName(s: string):string;
  var
  i, index : integer;
  begin
    index := 0;
    for I := Length(s) downto 1 do
      if s[i] = '/' then
      begin
       index := i;
       break;
      end;
      Result := Copy(s, index+1, Length(s) - index);
  end;
{ DropboxClient }

procedure TDropboxClient.Abort;
begin
  FrestClient.Abort();
end;

function TDropboxClient.accountInfo(): TJsonObject;
var
  url : string;
begin
  url := request('/account/info',nil,'GET');
  Result := FrestClient.GET_JSON(url);
end;

constructor TDropboxClient.Create(session: TDropboxSession);
begin
  FSession := session;
  FrestClient := TRestClient.Create;
end;

function TDropboxClient.createFolder(path: string): boolean;
var
  url: string;
  params : TStringList;
  json : TJSONObject;
  requestparams, requestheaders: TStringList;
begin
Result := false;
json:=nil;
try
try
  params := TStringList.Create;
  requestparams := TStringList.Create;
  requestheaders := TStringList.Create;
  params.Values['root'] := FSession.Root;
  params.Values['path'] := format_path(path);
  url := request('/fileops/create_folder',requestparams,requestheaders,params,'POST');
  json := FrestClient.POST_JSON(url, requestparams);
  json.Free;
  Result:=true;
finally
    params.Free;
    requestparams.Free;
    requestheaders.Free;

end;
except
  on E: Exception do
  Result := False;
end;

end;

constructor TDropboxClient.Destroy;
begin
   FreeAndNil(FSession);
   FreeAndNil(FrestClient);
end;

function TDropboxClient.fileDelete(path: string): boolean;
var
params : TStringList;
requestparams, requestheaders: TStringList;
url : string;
json : TJSONObject;
begin
  params := TStringList.Create;
  requestparams := TStringList.Create;
  requestheaders := TStringList.Create;
  params.Values['root'] := FSession.Root;
  params.Values['path'] := format_path(path);
  Result := false;
  json := nil;
  try
     url := request('/fileops/delete',requestparams,requestheaders,params,'POST');
     json := FrestClient.POST_JSON(url, requestparams);
     json.Free;
     Result := True;
  finally
      params.Free;
      requestparams.Free;
      requestheaders.Free;
  end;



end;

function TDropboxClient.fileExists(path: string): boolean;
var
json : TJSONObject;
jsonValue: TJSONValue;
begin
Result := False;
try
  json := metaData(path, True);
  jsonValue := json.Get('is_dir').JsonValue;
  if jsonValue is TJSONFalse then
    Result := True;
  json.Free;
except on E: ErrorResponse do
begin
  if E.Code = 404 then
    // File with name not found
    Result := False
  else
    raise;
end;
end;

end;

procedure TDropboxClient.getFile(fromPath:string; stream: TStream;rev: string; workbegin : TWorkEvent; work : TWorkEvent);
var
path,url:string;
params : TStringList;
begin
  path := Format('/files/%s%s',[FSession.Root, format_path(fromPath)]);
  params := TStringList.Create;
  if rev<>'' then params.Add('rev='+rev);
  url := request(path, params, 'GET', True);
  FrestClient.GET(url, stream,nil, workbegin, work);
  params.Free;
end;

function booltostr(value : boolean):string;
begin
  if value then
    Result := 'True'
  else
    Result := 'False';
end;

function TDropboxClient.metaData(path: string; list: boolean;file_limit: integer = 10000;
 hash:boolean=False;revision:string='';include_deleted:boolean=False): TJsonObject;
var
  params : TStringList;
  url : string;
begin
  path := Format('/metadata/%s%s',[FSession.Root,  format_path(path)]);
  params := TStringList.Create;

  params.Add('file_limit='+ IntToStr(file_limit));
  params.Add('list='+ 'true' );
   params.Add('include_deleted='+booltostr(include_deleted));
  if not list then  params.Add('list=false');
  //hash
  if revision<>'' then params.Add('rev='+revision);
  url := request(path, params, 'GET' );
  Result := FrestClient.GET_JSON(url);
  params.Free;
end;


function TDropboxClient.putFile(fullPath: string; filestream: Tstream;
  overwrite: boolean; parentRev: string; workbegin : TWorkEvent; work : TWorkEvent): string;
var
  path, url: string;
  params: TStringList;
  mimeTable: TIdThreadSafeMimeTable;
  mimeType:String;
begin
  path := Format('/files_put/%s%s', [Fsession.Root, format_path(fullPath)]);
  params := TStringList.Create;
  params.Values['overwrite'] := BoolToStr(overwrite);
  if parentRev = '' then params.Values['parent_rev'] := parentRev;
  url := request(path, params, 'PUT', True);
  mimeTable := TIdThreadSafeMimeTable.Create();
  mimeType  := mimeTable.GetFileMIMEType(fullPath);
  mimeTable.Free;
  Result := FrestClient.PUT(url, filestream,nil, workbegin, work,mimeType);
  params.Free;
end;

function TDropboxClient.request(target: string; params: TStringList;
  method: string; contentserver: boolean): string;
var
requestheaders, requestparams :TStringList;
begin
requestheaders := nil;
requestparams := nil;
Result:= request(target,requestparams,requestheaders,params,method,contentserver);
end;

function TDropboxClient.request(target: string;var requestparams, requestheaders: TStringList;
      params: TStringList; method: string; contentserver: boolean):string;
var
host, base : string;
begin
  if contentserver then
    host := FSession.API_CONTENT_HOST
  else
    host := FSession.API_HOST;
  base := FSession.buildUrl(host, target);
  Result := FSession.request(base,requestparams,requestheaders,params,method);
end;

end.
