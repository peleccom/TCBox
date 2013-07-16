library TCBox;




uses
  Windows,
  Vcl.Dialogs,
  Vcl.Controls,
  FSPLUGIN,
  classes,
  sysutils,
  wininet,
  registry,
  ShellApi,
  Generics.Collections,
  AccessConfig,
  Data.DBXJSON,
  idComponent,
  DropboxClient in '..\DropboxAPI\DropboxClient.pas',
  DropboxRest in '..\DropboxAPI\DropboxRest.pas',
  DropboxSession in '..\DropboxAPI\DropboxSession.pas',
  OAuth in '..\DropboxAPI\OAuth.pas';

//httpGet in 'httpGet.pas';

{$E wfx}
{$R icon.res}
{$R *.RES}


const
  VERSION_TEXT = '1.0beta';
  PLUGIN_TITLE = 'Total Commander Dropbox plugin';
  HELLO_TITLE  = 'TCBox '+VERSION_TEXT;
  ACCESS_KEY_FILENAME = 'c:\tmp\key.txt';


  REQUES_TOKEN_HANDLER = 10;

type
PJsonArrayEnumerator = ^ TJSONArrayEnumerator;

TFindNextRecord = Record
  PList : ^TList<tWIN32FINDDATAW>;
  index : Integer;
End;
  TDownloadEventHandler = class
  FMax: Int64;
  Fsource, FDestination:string;
  isAborted:boolean;
  constructor Create(source, destination:string);
    procedure onBegin (ASender: TObject; AWorkMode: TWorkMode; Max: Int64);
    procedure onWork (ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
  end;
var
  ProgressProc : tProgressProcW;
  LogProc      : tLogProcW;
  RequestProc  : tRequestProcW;
  PluginNumber: integer;


//
//Dropbox
  dropboxSession : TDropboxSession;
  dropboxClient : TDropboxClient;
{FileGet}
{fIleGEt}

procedure AddLog(LogString: string; LogFileName: string);
var
  F: TFileStream;
  PStr: PChar;
  LengthLogString: integer;
  outpututf8: RawByteString;
  isAppendMode: boolean;
  preamble:TBytes;
begin
  LengthLogString := Length(LogString) + 2;
  LogString := LogString + #13#10;
PStr := StrAlloc(LengthLogString + 1);
  StrPCopy(PStr, LogString);
  isAppendMode := false;
  if FileExists(LogFileName) then
  begin
    F := TFileStream.Create(LogFileName, fmOpenWrite);
    isAppendMode := True;
  end
  else
  F := TFileStream.Create(LogFileName, fmCreate);

  if not isAppendMode then
  begin
    preamble := TEncoding.UTF8.GetPreamble;
    F.WriteBuffer( PAnsiChar(preamble)^, Length(preamble));
  end
  else
  begin
    F.Seek(F.Size, 0); { go to the end, append }
  end;
  try
    outpututf8 := Utf8Encode(LogString); // this converts UnicodeString to WideString, sadly.
    F.WriteBuffer( PAnsiChar(outpututf8)^, Length(outpututf8) );
  finally
    F.Free;
  end;
end;

procedure Log(mess: String);
const
LOG_FILENAME = 'c:\tmp\TCBOX.log';
begin
 AddLog(mess, LOG_FILENAME);
end;



function DateTimeToFileTime(FileTime: TDateTime): TFileTime;
var
 LocalFileTime, Ft: TFileTime;
 SystemTime: TSystemTime;
begin
 Result.dwLowDateTime  := 0;
 Result.dwHighDateTime := 0;
 DateTimeToSystemTime(FileTime, SystemTime);
 SystemTimeToFileTime(SystemTime, LocalFileTime);
 LocalFileTimeToFileTime(LocalFileTime, Ft);
 Result := Ft;
end;

procedure LoadFindDatawFromJSON(jsonobject: TJSONObject; var FindData : tWIN32FINDDATAW);
var
filename : string;
jsonvalue : TJSONValue;
modified : TDateTime;
begin
try
    Fillchar(FindData, sizeof(FindData), 0);
    filename := GetSimpleFileName (jsonobject.Get('path').JsonValue.Value);
    jsonValue := jsonobject.Get('is_dir').JsonValue;
    if jsonValue is TJSONTrue then FindData.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
    FindData.nFileSizeLow:=(jsonobject.Get('bytes').JsonValue as TJSONNumber).AsInt64;
    StrPLCopy(FindData.cFileName, filename, High(FindData.cFileName));
    modified := StrToDateTime('15-02-2011');
    FindData.ftLastWriteTime := DateTimeToFileTime(modified);
except
  On E:Exception do
  begin
    LogProc(pluginNumber, msgtype_details,' LoadFindDatawFromJSON ');
  end;
end;

end;






function confirm():Boolean;
begin
if RequestProc(PluginNumber,RT_MsgYesNo,'Confirm Authentification','Continue with auth?',nil,0)
then
  begin
        result :=  True;
  end
else
result := False; //go out
end;


function FsInitW(PluginNr:integer;pProgressProcW:tProgressProcW;pLogProcW:tLogProcW;
                pRequestProcW:tRequestProcW):integer; stdcall;

var
token : TOAuthToken;
url : string;
begin
    ProgressProc := pProgressProcW;
    LogProc      :=pLogProcW;
    RequestProc  :=pRequestProcW;
    PluginNumber := PluginNr;
    Result := 1;
    dropboxSession := TDropboxSession.Create(APP_KEY,APP_SECRET,TAccessType.dropbox);
    dropboxClient := TDropboxClient.Create(dropboxSession);
    if not DropboxSession.LoadAccessToken(ACCESS_KEY_FILENAME) then
    begin
      try
      try
        token := dropboxSession.obtainRequestToken();
        url := dropboxSession.buildAuthorizeUrl(token,'');
        ShellExecute(0,
               PChar('open'),
               PChar(url),
               Nil,
               Nil,
               SW_SHOW);
        if Confirm() then
        begin
          dropboxSession.obtainAccessToken();
        end;
        dropboxSession.SaveAccessToken(ACCESS_KEY_FILENAME);
        Result := 0;

      finally

      end;
    except
    on E1:ErrorResponse do
      Log('Error response ' + E1.Message);
    on E2: RESTSocketError do
      Log('Rest socket Error '+ E2.Message);
      end;
    end;
end;

procedure Request();

begin

end;

{ ------------------------------------------------------------------ }

function FsFindFirstW(path :pwidechar;var FindData:tWIN32FINDDATAW):thandle; stdcall;
var
json : TJSONObject;
i : integer;
spath : String;
JsonArray : TJSONArray;
FindDatatmp : TWin32FindDataW;
PFindNextRec : ^TFindNextRecord;
begin

Result := INVALID_HANDLE_VALUE;
try
  spath :=  path;
  New(PFindNextRec);
  New(PFindNextRec.PList);
  (PFindNextRec.PList)^ := TList<tWIN32FINDDATAW>.Create;
  spath := StringReplace(spath,'\','/',[rfReplaceAll]);
  json := dropboxClient.metaData(spath, True);
  JsonArray:=json.Get('contents').JsonValue as TJSONArray;

  for I := 0 to JsonArray.Size-1 do
  begin
      LoadFindDatawFromJSON(JsonArray.Get(I) as TJSONObject, FindDatatmp);
      PFindNextRec.PList.Add(FindDatatmp);
  end;
  json.Free;

  if PFindNextRec.PList.Count > 0 then
    begin
        FindData := PFindNextRec.PList.Items[0];
        PFindNextRec.index := 1;
        Result := THandle(PFindNextRec);
        exit();
    end
  else
    begin
        Result := INVALID_HANDLE_VALUE;
        SetLastError(ERROR_NO_MORE_FILES);
    end;
  except
    on E1:ErrorResponse do
      Log('Exception in FindFirst '+E1.ClassName+' '+E1.Message);
    on E2: RESTSocketError do
      Log('Exception in FindFirst '+E2.ClassName+' '+E2.Message);
    on E3:Exception do
      Log('Exception in FindFirst '+E3.ClassName+' '+E3.Message);
  end;

    // Clean a pointers if error occurred in FindFirst
  PFindNextRec.PList.Free;
  Dispose(PFindNextRec.PList);
  Dispose(PFindNextRec);
  //
end;

{ ------------------------------------------------------------------ }

function FsFindNextW(Hdl:thandle;var FindDataW:tWIN32FINDDATAW):bool; stdcall;
var
PFindNextRecord : ^TFindNextRecord;

begin
  Result := False;
  PFindNextRecord := Pointer(Hdl);
  if PFindNextRecord.index < pfindNextRecord.PList.Count then
  begin
        FindDataW := PFindNextRecord.PList.Items[pfindNextRecord.index];
        Inc(pfindNextRecord.index);
        Result := True;
  end
end;

{ ------------------------------------------------------------------ }

function FsFindClose (Hdl : thandle) : integer; stdcall;
var
PFindNextRecord : ^TFindNextRecord;
begin
  Result := 0;
  PfindNextRecord := Pointer(Hdl);
  PFindNextRecord.PList.Free;
  Dispose(PFindNextRecord.PList);
  Dispose(PFindNextRecord);
end;

{ ------------------------------------------------------------------ }

function FsGetFile (RemoteName, LocalName : PChar; CopyFlags : integer ;
                    RemoteInfo : pRemoteInfo) : integer; stdcall;


begin
  Result := FS_FILE_NOTFOUND;
end;
{ ------------------------------------------------------------------ }
function FsInit(PluginNr:integer;pProgressProc:tProgressProc;pLogProc:tLogProc;
                pRequestProc:tRequestProc):integer; stdcall;
begin
 Result := 1;
end;
function FsFindNext(Hdl:thandle;var FindData:tWIN32FINDDATA):bool; stdcall;
begin
   Result := False;
end;
function FsFindFirst(path :pchar;var FindData:tWIN32FINDDATA):thandle; stdcall;
begin
  Result := INVALID_HANDLE_VALUE;
end;

function FsGetFileW(RemoteName,LocalName:pwidechar;CopyFlags:integer;
  RemoteInfo:pRemoteInfo):integer; stdcall;
var
fs : TFileStream;
filemode : Word;
handler : TDownloadEventHandler;
remotefilename:string;
begin
  ShowMessage(IntToStr(CopyFlags));
   remotefilename := StringReplace(RemoteName,'\','/',[rfReplaceAll]);
    if ((CopyFlags = 0) or (CopyFlags = FS_COPYFLAGS_MOVE) ) and FileExists(LocalName) then
    //To Do: Add resume support in this if code
      begin
        Result := FS_FILE_EXISTS;
        exit;
      end;
    filemode := fmCreate;
    if (CopyFlags and FS_COPYFLAGS_OVERWRITE) <> 0 then filemode := fmCreate;
    if (CopyFlags and FS_COPYFLAGS_RESUME) <> 0 then filemode := fmOpenWrite;
    try
    try
      fs := TFileStream.Create(LocalName,filemode);
      handler := TDownloadEventHandler.Create(remotefilename, LocalName);
      dropboxClient.getFile(remotefilename,fs,'',handler.onBegin, handler.onWork);
      if handler.isAborted then
      begin
        // close filestream and delete file
        fs.Free;
        Result := FS_FILE_USERABORT	;
      end
      else
          Result :=FS_FILE_OK	 ;
      
    finally
      if fs <> nil then fs.Free;
      if handler <> nil  then handler.free;

    end;
    except
    on E1:ErrorResponse do
    begin
    Log('Exception in GetFile '+E1.ClassName+' '+E1.Message);
    if E1.Code = 404 then
      // Remote file not found
      Result := FS_FILE_NOTFOUND
    else
      // another dropbox errors
      Result := FS_FILE_READERROR;
    end;
    on E2: RESTSocketError do
    begin
        Log('Exception in GetFile '+E2.ClassName+' '+E2.Message);
        Result := FS_FILE_READERROR;
    end;
    on E3:Exception do
    begin
         Log('Exception in GetFile '+E3.ClassName+' '+E3.Message);
         Result := FS_FILE_WRITEERROR;
    end;
    end;
  end;

exports

  FsFindClose,
  FsFindFirstW,
  FsFindFirst,
  FsFindNextW,
  FsFindNext,
  FsGetFile,
  FsInitW,
  FsgetFile,
  FsGetFileW,
  FsInit;

{ ------------------------------------------------------------------ }
var SaveExit:tfarproc;

procedure LibExit;
begin
  ExitProc := SaveExit;
   MessageBox(0,PChar('exit'),'',0);
end;

{$E wfx}

{ TDownloadEventHandler }

constructor TDownloadEventHandler.Create(source, destination:string);
begin
Fsource := source;
FDestination := destination;
isAborted:=false;
end;

procedure TDownloadEventHandler.onBegin(ASender: TObject; AWorkMode: TWorkMode;
  Max: Int64);
begin
  FMax:= Max;
end;

procedure TDownloadEventHandler.onWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
  var
  percent:integer;
  isaborted: integer;
begin
try
    percent := Round((AWorkCount *100) / FMax);
except
on EZeroDivide do
  percent:= 0;
end;
   isAborted := ProgressProc(PluginNumber,PChar(Fsource), PChar(FDestination),percent );
   if isaborted = 1 then
   begin
    dropboxClient.Abort();
    self.isaborted:=true;
   end;
end;

begin
  SaveExit := ExitProc;	{ Kette der Exit-Prozeduren speichern }
  ExitProc := @LibExit;	{ Exit-Prozedur LibExit installieren }

end.