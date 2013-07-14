unit DropboxClient;

interface
uses DropboxSession, SysUtils, System.Classes, DropboxRest, Data.DBXJSON, idComponent;
type
  TDropboxClient = class
  private
    FSession: TDropboxSession;
    FrestClient : TRestClient;
  public
  constructor Create(session: TDropboxSession);
  constructor Destroy();
  function request(target: string; params: TStringList=nil; method: string='GET';contentserver: boolean=false):string;
  function accountInfo():TJsonObject;
  function metaData(path: string; list: boolean;file_limit: integer = 10000; hash:boolean=False;revision:string='';include_deleted:boolean=False):TJsonObject;
  procedure getFile(fromPath:string; stream: TStream; rev:string='';workbegin : TWorkEvent=nil; work : TWorkEvent=nil);
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

constructor TDropboxClient.Destroy;
begin
   FreeAndNil(FSession);
   FreeAndNil(FrestClient);
end;

procedure TDropboxClient.getFile(fromPath:string; stream: TStream;rev: string; workbegin : TWorkEvent; work : TWorkEvent);
var
path,url:string;
params : TStringList;
json: TJSONObject;
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

function TDropboxClient.request(target: string; params: TStringList=nil; method: string='GET';contentserver: boolean=false):string;
var
  mparams: TStringList;
  host, base, url, url_clear: string;
  delim:char;
begin
   mparams := TStringList.Create;
   if params<>nil then mparams.AddStrings(params);
   mparams.Sort;
   if contentserver then host := TDropboxSession.API_CONTENT_HOST
                    else host := TDropboxSession.API_HOST;
   base := FSession.buildUrl(host, target);
   //
   if method = 'GET' then
   begin
           url_clear :=  FSession.buildUrl(host, target, nil);
           url := FSession.buildUrl(host, target, mparams);
           if mparams.Count>0 then delim := '&'
           else delim := '?';
           url := url + delim + FSession.getAccessString(url);
   end

   else
      url :='Some else';
  Result := url;

end;

end.
