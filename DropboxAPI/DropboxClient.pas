unit DropboxClient;

interface

uses Windows {debug} , DropboxSession, SysUtils, System.Classes, DropboxRest,
  Data.DBXJSON, idComponent, Oauth, IdCustomHTTPServer, RegularExpressions,
  iso8601Unit, Vcl.Dialogs;

type
  TChunkedUploader = class;

  TDropboxClient = class
  private
    FSession: TDropboxSession;
    FRestClient: TRestClient;
  public
    constructor Create(session: TDropboxSession);
    constructor Destroy();
    // make reuest url , postparams and headers. Return in out params. Client must free they then finish
    function request(target: string; var requestparams: TStringList;
      var requestheaders: TStringList; params: TStringList = nil;
      method: string = 'GET'; contentserver: boolean = false): string; overload;
    function request(target: string; params: TStringList = nil;
      method: string = 'GET'; contentserver: boolean = false): string; overload;
    function accountInfo(): TJsonObject;
    function metaData(path: string; list: boolean; file_limit: integer = 10000;
      hash: boolean = false; revision: string = '';
      include_deleted: boolean = false): TJsonObject;
    // Return True if path refers to an existing path
    function exists(path: string): boolean;
    // Copies a file or folder to a new location
    function copy(fromPath: string; toPath: string): TJsonObject;
    // Moves a file or folder to a new location
    function move(fromPath: string; toPath: string): TJsonObject;
    // Return True if path is existsting file
    function isFile(path: string): boolean;
    // Return True if path is existsting directory
    function isDir(path: string): boolean;
    // Creates and returns a Dropbox link to files or folders users can use to view a preview of the file in a web browser.
    function share(path: string): TJsonObject;
    procedure getFile(fromPath: string; stream: TStream; rev: string = '';
      workbegin: TWorkEvent = nil; work: TWorkEvent = nil);
    function createFolder(path: string): boolean;
    // Delete file or folder. raise exception if fails
    procedure delete(path: string);
    function putFile(fullPath: string; filestream: TStream;
      overwrite: boolean = false; parentRev: string = '';
      workbegin: TWorkEvent = nil; work: TWorkEvent = nil): string;
    // abort download operation
    procedure Abort();
    function getChunkedUpload(stream: TStream; size: Int64): TChunkedUploader;
    function uploadChunk(stream: TStream; length: Int64; var uploadId: String;
      offset: integer = 0): Int64;
    //
    function parseDate(dateStr: string): TDateTime;
  end;

  TChunkedUploader = class
  private
    FClient: TDropboxClient;
    FOffset: Int64;
    FUploadId: String;
    FLastBlock: TStream;
    FFileStream: TStream;
    FFileSize: Int64;
  public
    constructor Create(client: TDropboxClient; stream: TStream; size: Int64);
    // change integer
    procedure uploadChunked(chunksize: Int64 = 4 * 1024 * 1024);
    function finish(path: String; overwrite: boolean = false;
      parentRev: String = ''): TJsonObject;
    property Offset: Int64 read FOffset;
  end;

function format_path(path: string): string;
function Strip(s: String; ch: Char): String;
function GetSimpleFileName(s: string): string;

implementation

function Strip(s: String; ch: Char): String;
var
  i, index: integer;
begin
  index := 1;
  for i := 1 to length(s) do
    if s[i] <> ch then
    begin
      index := i;
      break;
    end;
  s := copy(s, index, length(s) - index + 1);
  index := length(s);
  for i := length(s) downto 1 do
    if s[i] <> ch then
    begin
      index := i;
      break;
    end;
  s := copy(s, 1, index);
  Result := s;
end;

function format_path(path: string): string;
begin
  if path = '' then
  begin
    Result := path;
    exit;
  end;
  path := StringReplace(path, '//', '/', [rfReplaceAll]);
  if path = '/' then
    Result := ''
  else
    Result := '/' + Strip(path, '/');
end;

function GetSimpleFileName(s: string): string;
var
  i, index: integer;
begin
  index := 0;
  for i := length(s) downto 1 do
    if s[i] = '/' then
    begin
      index := i;
      break;
    end;
  Result := copy(s, index + 1, length(s) - index);
end;
{ DropboxClient }

procedure TDropboxClient.Abort;
begin
  FRestClient.Abort();
end;

function TDropboxClient.accountInfo(): TJsonObject;
var
  url: string;
begin
  url := request('/account/info', nil, 'GET');
  Result := FRestClient.GET_JSON(url);
end;

function TDropboxClient.copy(fromPath, toPath: string): TJsonObject;
var
  params, requestparams, requestheaders: TStringList;
  url: string;
begin
  try
    params := TStringList.Create;
    requestparams := TStringList.Create;
    requestheaders := TStringList.Create;
    params.Values['root'] := FSession.Root;
    params.Values['from_path'] := fromPath;
    params.Values['to_path'] := toPath;
    url := request('/fileops/copy', requestparams, requestheaders,
      params, 'POST');
    Result := FRestClient.POST_JSON(url, requestparams);
  finally
    params.Free;
    requestparams.Free;
    requestheaders.Free;
  end;
end;

constructor TDropboxClient.Create(session: TDropboxSession);
begin
  FSession := session;
  FRestClient := TRestClient.Create;
end;

function TDropboxClient.createFolder(path: string): boolean;
var
  url: string;
  params: TStringList;
  json: TJsonObject;
  requestparams, requestheaders: TStringList;
begin
  Result := false;
  json := nil;
  try
    try
      params := TStringList.Create;
      requestparams := TStringList.Create;
      requestheaders := TStringList.Create;
      params.Values['root'] := FSession.Root;
      params.Values['path'] := format_path(path);
      url := request('/fileops/create_folder', requestparams, requestheaders,
        params, 'POST');
      json := FRestClient.POST_JSON(url, requestparams);
      json.Free;
      Result := true;
    finally
      params.Free;
      requestparams.Free;
      requestheaders.Free;

    end;
  except
    on E: Exception do
      Result := false;
  end;

end;

constructor TDropboxClient.Destroy;
begin
  FreeAndNil(FSession);
  FreeAndNil(FRestClient);
end;

procedure TDropboxClient.delete(path: string);
var
  params: TStringList;
  requestparams, requestheaders: TStringList;
  url: string;
  json: TJsonObject;
begin
  params := TStringList.Create;
  requestparams := TStringList.Create;
  requestheaders := TStringList.Create;
  params.Values['root'] := FSession.Root;
  params.Values['path'] := format_path(path);
  try
    url := request('/fileops/delete', requestparams, requestheaders,
      params, 'POST');
    json := FRestClient.POST_JSON(url, requestparams);
    json.Free;
  finally
    params.Free;
    requestparams.Free;
    requestheaders.Free;
  end;
end;

function TDropboxClient.exists(path: string): boolean;
var
  json: TJsonObject;
begin
  Result := false;
  try
    json := metaData(path, false);
    if not((json.Get('is_deleted') <> nil) and
      (json.Get('is_deleted').JsonValue is TJSONTrue)) then
      Result := true;
    json.Free;
  except
    on E: ErrorResponse do
    begin
      if E.Code = 404 then
        // File with name not found
        Result := false
      else
        raise;
    end;
  end;
end;

function TDropboxClient.getChunkedUpload(stream: TStream; size: Int64)
  : TChunkedUploader;
begin
  Result := TChunkedUploader.Create(Self, stream, size);
end;

procedure TDropboxClient.getFile(fromPath: string; stream: TStream; rev: string;
  workbegin: TWorkEvent; work: TWorkEvent);
var
  path, url: string;
  params: TStringList;
begin
  path := Format('/files/%s%s', [FSession.Root, format_path(fromPath)]);
  params := TStringList.Create;
  if rev <> '' then
    params.Add('rev=' + rev);
  url := request(path, params, 'GET', true);
  FRestClient.Get(url, stream, nil, workbegin, work);
  params.Free;
end;

function TDropboxClient.isDir(path: string): boolean;
var
  json: TJsonObject;
  isDirJsonValue: TJSONValue;
begin
  Result := false;
  try
    json := nil;
    json := metaData(path, false);
    isDirJsonValue := json.Get('is_dir').JsonValue;
    if (isDirJsonValue is TJSONTrue) then
      Result := true;
  finally
    begin
      if json <> nil then
        json.Free;
    end;
  end;

end;

function TDropboxClient.isFile(path: string): boolean;
var
  json: TJsonObject;
  isDirJsonValue: TJSONValue;
begin
  Result := false;
  try
    json := nil;
    json := metaData(path, false);
    isDirJsonValue := json.Get('is_dir').JsonValue;
    if (isDirJsonValue is TJSONFalse) then
      Result := true;
  finally
    begin
      if json <> nil then
        json.Free;
    end;
  end;

end;

function booltostr(value: boolean): string;
begin
  if value then
    Result := 'true'
  else
    Result := 'false';
end;

function TDropboxClient.metaData(path: string; list: boolean;
  file_limit: integer = 10000; hash: boolean = false; revision: string = '';
  include_deleted: boolean = false): TJsonObject;
var
  params: TStringList;
  url: string;
begin
  path := Format('/metadata/%s%s', [FSession.Root, format_path(path)]);
  params := TStringList.Create;

  params.Add('file_limit=' + IntToStr(file_limit));
  params.Add('list=' + booltostr(list));
  params.Add('include_deleted=' + booltostr(include_deleted));
  // hash
  if revision <> '' then
    params.Add('rev=' + revision);
  url := request(path, params, 'GET');
  Result := FRestClient.GET_JSON(url);
  params.Free;
end;

function TDropboxClient.move(fromPath, toPath: string): TJsonObject;
var
  params, requestparams, requestheaders: TStringList;
  url: string;
begin
  params := TStringList.Create;
  try
    requestparams := TStringList.Create;
    requestheaders := TStringList.Create;
    params.Values['root'] := FSession.Root;
    params.Values['from_path'] := fromPath;
    params.Values['to_path'] := toPath;
    url := request('/fileops/move', requestparams, requestheaders,
      params, 'POST');
    Result := FRestClient.POST_JSON(url, requestparams);
  finally
    params.Free;
    requestparams.Free;
    requestheaders.Free;
  end;
end;

function TDropboxClient.parseDate(dateStr: string): TDateTime;
const
  _ShortMonthNames: array [1 .. 12] of string = ('Jan', 'Feb', 'Mar', 'Apr',
    'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  RegEx: TRegEx;
  M: TMatch;
  i, j: integer;
  isoval: string;
  month: byte;
begin
  RegEx := TRegEx.Create
    ('\w{3},\s(\d+)\s(\w{3})\s(\d{4})\s(\d+:\d+:\d+)\s\+(\d+)');
  if RegEx.IsMatch(dateStr) then
  begin
    M := RegEx.Match(dateStr); // получаем коллекцию совпадений
    if M.Groups.Count = 6 then
    begin
      // Правильная дата из 6 групп
      begin
        month := 1;
        for j := 1 to 12 do
        begin
          if M.Groups.Item[2].value = _ShortMonthNames[j] then
          begin
            month := j;
            break;
          end;
        end;

        isoval := M.Groups.Item[3].value + '-' + IntToStr(month) + '-' +
          M.Groups.Item[1].value + 'T' + M.Groups.Item[4].value + '+' +
          M.Groups.Item[5].value;
        Result := iso8601Unit.TIso8601.DateTimeFromIso8601(isoval);
        exit;
      end;
    end;
  end;
end;

function TDropboxClient.putFile(fullPath: string; filestream: TStream;
  overwrite: boolean; parentRev: string; workbegin: TWorkEvent;
  work: TWorkEvent): string;
var
  path, url: string;
  params: TStringList;
  mimeTable: TIdThreadSafeMimeTable;
  mimeType: String;
begin
  path := Format('/files_put/%s%s', [FSession.Root, format_path(fullPath)]);
  params := TStringList.Create;
  params.Values['overwrite'] := booltostr(overwrite);
  if parentRev = '' then
    params.Values['parent_rev'] := parentRev;
  url := request(path, params, 'PUT', true);
  mimeTable := TIdThreadSafeMimeTable.Create();
  mimeType := mimeTable.GetFileMIMEType(fullPath);
  mimeTable.Free;
  Result := FRestClient.PUT(url, filestream, nil, workbegin, work, mimeType);
  params.Free;
end;

function TDropboxClient.request(target: string; params: TStringList;
  method: string; contentserver: boolean): string;
var
  requestheaders, requestparams: TStringList;
begin
  requestheaders := nil;
  requestparams := nil;
  Result := request(target, requestparams, requestheaders, params, method,
    contentserver);
end;

function TDropboxClient.share(path: string): TJsonObject;
var
  url: string;
  params: TStringList;
  headers: TStringList;
begin
  params := TStringList.Create;
  headers := TStringList.Create;
  try
    path := Format('/shares/%s%s', [FSession.Root, format_path(path)]);
    url := request(path, params, headers, nil, 'POST');
    Result := FRestClient.POST_JSON(url, params)
  finally
    params.Free;
    headers.Free;
  end;
end;

function TDropboxClient.uploadChunk(stream: TStream; length: Int64;
  var uploadId: String; offset: integer): Int64;
var
  params: TStringList;
  url: String;
  json: TJsonObject;
begin
  params := TStringList.Create;
  if uploadId <> '' then
  begin
    params.Values['upload_id'] := uploadId;
    params.Values['offset'] := IntToStr(offset);
  end;
  url := request('/chunked_upload', params, 'PUT', true);
  params.Free;
  json := FRestClient.PUT_JSON(url, stream);
  try
    Result := (json.Get('offset').JsonValue as TJSONNumber).AsInt64;
    uploadId := json.Get('upload_id').JsonValue.value
  finally
    json.Free;
  end;
end;

function TDropboxClient.request(target: string;
  var requestparams, requestheaders: TStringList; params: TStringList;
  method: string; contentserver: boolean): string;
var
  host, base: string;
begin
  if contentserver then
    host := FSession.API_CONTENT_HOST
  else
    host := FSession.API_HOST;
  base := FSession.buildUrl(host, target);
  Result := FSession.request(base, requestparams, requestheaders,
    params, method);
end;

{ TChunkedUploader }

constructor TChunkedUploader.Create(client: TDropboxClient; stream: TStream;
  size: Int64);
begin
  FClient := client;
  FOffset := 0;
  FUploadId := '';
  FFileStream := stream;
  FLastBlock := nil;
  FFileSize := size;
end;

function TChunkedUploader.finish(path: String; overwrite: boolean;
  parentRev: String): TJsonObject;
var
  params, requestparams, requestheaders: TStringList;
  url: String;
begin
  path := Format('/commit_chunked_upload/%s%s',
    [FClient.FSession.Root, format_path(path)]);
  params := TStringList.Create;
  requestparams := TStringList.Create;
  requestheaders := TStringList.Create;
  params.Values['overwrite'] := booltostr(overwrite);
  params.Values['upload_id'] := FUploadId;
  if parentRev <> '' then
    params.Values['parent_rev'] := parentRev;
  url := FClient.request(path, requestparams,requestheaders,params ,'POST', true);
  try
    Result := FClient.FRestClient.POST_JSON(url,  requestparams);
  finally
    params.Free;
    requestparams.Free;
    requestheaders.Free;
  end;

end;

procedure TChunkedUploader.uploadChunked(chunksize: Int64);
var
  nextChunkSize: Int64;
  bufferStream: TMemoryStream;
  reply: TJsonObject;
  jsonOffset: TJSONPair;
  replyOffset: Int64;
begin
  bufferStream := TMemoryStream.Create;
  try
    while Self.FOffset < Self.FFileSize do
    begin
      if (chunksize < (Self.FFileSize - FOffset)) then
        nextChunkSize := chunksize
      else
        nextChunkSize := (Self.FFileSize - FOffset);
      if (FLastBlock = nil) then
      begin
        bufferStream.CopyFrom(FFileStream, nextChunkSize);
        FLastBlock := bufferStream;
      end;
      try
        FOffset := FClient.uploadChunk(bufferStream, nextChunkSize,
          FUploadId, FOffset);
        FLastBlock := nil;
      except
        on E: ErrorResponse do
        begin
          reply := E.Body;
          if reply <> nil then
          begin
            jsonOffset := reply.Get('offset');
            if jsonOffset <> nil then
            begin
              replyOffset := (jsonOffset.JsonValue as TJSONNumber).AsInt64;
              if replyOffset <> 0 then
              begin
                if replyOffset > FOffset then
                begin
                  FLastBlock := nil;
                  FOffset := replyOffset;
                end;
              end;

            end;
          end;
        end;

      end;
    end;

  finally
    bufferStream.Free;
  end;
end;

end.
