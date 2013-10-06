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
  OAuth in '..\DropboxAPI\OAuth.pas',
  iso8601Unit in '..\DropboxAPI\iso8601Unit.pas',
  LogInUnit in 'LogInUnit.pas' {LogInForm} ,
  mycrypt in 'mycrypt.pas';

// httpGet in 'httpGet.pas';

{$E wfx}
{$R icon.res}
{$R *.RES}

const
  VERSION_TEXT = '1.0beta';
  PLUGIN_TITLE = 'Total Commander Dropbox plugin';
  HELLO_TITLE = 'TCBox ' + VERSION_TEXT;
  ACCESS_KEY_FILENAME = 'key.txt';
  LOG_FILENAME = 'TCBOX.log';
  MAX_LOG_SIZE = 20 * 1024;

  REQUES_TOKEN_HANDLER = 10;

type
  PJsonArrayEnumerator = ^TJSONArrayEnumerator;

  TFindNextRecord = Record
    PList: ^TList<tWIN32FINDDATAW>;
    index: Integer;
  End;

  TDownloadEventHandler = class
    FMax: Int64;
    Fsource, FDestination: string;
    isAborted: boolean;
    constructor Create(source, destination: string);
    procedure onBegin(ASender: TObject; AWorkMode: TWorkMode; Max: Int64);
    procedure onWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
  end;

var
  ProgressProc: tProgressProcW;
  LogProc: tLogProcW;
  RequestProc: tRequestProcW;
  PluginNumber: Integer;

  PluginPath: string;
  LogFullFilename: string;
  AccessKeyFullFileName: string;
  LocalEncoding: TEncoding;

  // SSL libs
  libeay32Handle, ssleay32Handle: THandle;
  //
  // Dropbox
  DropboxSession: TDropboxSession;
  DropboxClient: TDropboxClient;

procedure AddLog(LogString: string; LogFileName: string);
var
  F: TFileStream;
  PStr: PChar;
  LengthLogString: Integer;
  outpututf8: RawByteString;
  isAppendMode: boolean;
  preamble: TBytes;
begin
  LengthLogString := Length(LogString) + 2;
  LogString := LogString + #13#10;
  PStr := StrAlloc(LengthLogString + 1);
  StrPCopy(PStr, LogString);
  isAppendMode := False;
  if FileExists(LogFileName) then
  begin
    F := TFileStream.Create(LogFileName, fmOpenWrite);
    if F.Size < MAX_LOG_SIZE then
      isAppendMode := True
    else
      F.Free;
  end;
  if not isAppendMode then
  begin
    F := TFileStream.Create(LogFileName, fmCreate);
    preamble := TEncoding.UTF8.GetPreamble;
    F.WriteBuffer(PAnsiChar(preamble)^, Length(preamble));
  end
  else
  begin
    F.Seek(F.Size, 0); { go to the end, append }
  end;
  try
    outpututf8 := Utf8Encode(FormatDateTime('[dd-mm-yy hh:mm:ss] ', Now) +
      LogString); // this converts UnicodeString to WideString, sadly.
    F.WriteBuffer(PAnsiChar(outpututf8)^, Length(outpututf8));
  finally
    F.Free;
  end;
end;

procedure Log(mess: String);
begin
  AddLog(mess, LogFullFilename);
end;

function GetPluginFileName(): string;
var
  buffer: array [0 .. MAX_PATH] of Char;
begin
  GetModuleFileName(HInstance, buffer, MAX_PATH);
  Result := buffer;
end;

function DateTimeToFileTime(FileTime: TDateTime): TFileTime;
var
  LocalFileTime, Ft: TFileTime;
  SystemTime: TSystemTime;
begin
  Result.dwLowDateTime := 0;
  Result.dwHighDateTime := 0;
  DateTimeToSystemTime(FileTime, SystemTime);
  SystemTimeToFileTime(SystemTime, LocalFileTime);
  LocalFileTimeToFileTime(LocalFileTime, Ft);
  Result := Ft;
end;

procedure LoadFindDatawFromJSON(jsonobject: TJSONObject;
  var FindData: tWIN32FINDDATAW);
var
  filename: string;
  jsonvalue: TJSONValue;
  modified: TDateTime;
begin
  try
    Fillchar(FindData, sizeof(FindData), 0);
    filename := GetSimpleFileName(jsonobject.Get('path').jsonvalue.Value);
    jsonvalue := jsonobject.Get('is_dir').jsonvalue;
    if jsonvalue is TJSONTrue then
      FindData.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
    FindData.nFileSizeLow :=
      (jsonobject.Get('bytes').jsonvalue as TJSONNumber).AsInt64;
    StrPLCopy(FindData.cFileName, filename, High(FindData.cFileName));
    modified := DropboxClient.parseDate(jsonobject.Get('modified')
      .jsonvalue.Value);
    FindData.ftLastWriteTime := DateTimeToFileTime(modified);
  except
    On E: Exception do
    begin
      LogProc(PluginNumber, msgtype_details, ' LoadFindDatawFromJSON ');
    end;
  end;

end;

// convert backshashes to forwardslashes
function normalizeDropboxPath(path: string): string;
begin
  Result := StringReplace(path, '\', '/', [rfReplaceAll]);
end;

function confirm(): boolean;
begin
  if RequestProc(PluginNumber, RT_MsgYesNo, 'Authentification request',
    'Confirm Authentification in your browser and press YES', nil, 0) then
  begin
    Result := True;
  end
  else
    Result := False; // go out
end;

function ShowDllFormModal: boolean;
var
  modal: TModalResult;
begin
  LogInForm := TLogInForm.Create(nil, DropboxSession, AccessKeyFullFileName);
  LogInForm.Icon.LoadFromResourceName(HInstance, '1');
  modal := LogInForm.ShowModal;
  if modal = mrOk then
    Result := True
  else
    Result := False;
  LogInForm.Free;
end;

function FsInitW(PluginNr: Integer; pProgressProcW: tProgressProcW;
  pLogProcW: tLogProcW; pRequestProcW: tRequestProcW): Integer; stdcall;

var
  token: TOAuthToken;
  url: string;
begin
  ProgressProc := pProgressProcW;
  LogProc := pLogProcW;
  RequestProc := pRequestProcW;
  PluginNumber := PluginNr;
  Result := 1;
  DropboxSession := TDropboxSession.Create(APP_KEY, APP_SECRET,
    TAccessType.dropbox);
  DropboxClient := TDropboxClient.Create(DropboxSession);
  ShowDllFormModal();
end;

procedure Request();

begin

end;

{ ------------------------------------------------------------------ }

function FsFindFirstW(path: pwidechar; var FindData: tWIN32FINDDATAW)
  : THandle; stdcall;
var
  json: TJSONObject;
  i: Integer;
  spath: String;
  JsonArray: TJSONArray;
  FindDatatmp: tWIN32FINDDATAW;
  PFindNextRec: ^TFindNextRecord;
begin
  if not DropboxSession.isLinked() then
  begin
    if not ShowDllFormModal() then
    begin
      Result := INVALID_HANDLE_VALUE;
      exit;
    end;

  end;
  Result := INVALID_HANDLE_VALUE;
  New(PFindNextRec);
  New(PFindNextRec.PList);
  try
    spath := path;
    (PFindNextRec.PList)^ := TList<tWIN32FINDDATAW>.Create;
    spath := normalizeDropboxPath(spath);
    json := DropboxClient.metaData(spath, True);
    JsonArray := json.Get('contents').jsonvalue as TJSONArray;
    for i := 0 to JsonArray.Size - 1 do
    begin
      LoadFindDatawFromJSON(JsonArray.Get(i) as TJSONObject, FindDatatmp);
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
    on E1: ErrorResponse do
      Log('Exception in FindFirst ' + E1.ClassName + ' ' + E1.Message);
    on E2: RESTSocketError do
      Log('Exception in FindFirst ' + E2.ClassName + ' ' + E2.Message);
    on E3: Exception do
      Log('Exception in FindFirst ' + E3.ClassName + ' ' + E3.Message);
  end;

  // Clean a pointers if error occurred in FindFirst
  PFindNextRec.PList.Free;
  Dispose(PFindNextRec.PList);
  Dispose(PFindNextRec);
  //
end;

{ ------------------------------------------------------------------ }

function FsFindNextW(Hdl: THandle; var FindDataW: tWIN32FINDDATAW)
  : bool; stdcall;
var
  PFindNextRecord: ^TFindNextRecord;

begin
  Result := False;
  try
    PFindNextRecord := Pointer(Hdl);
    if PFindNextRecord.index < PFindNextRecord.PList.Count then
    begin
      FindDataW := PFindNextRecord.PList.Items[PFindNextRecord.index];
      Inc(PFindNextRecord.index);
      Result := True;
    end
  except
    on E: Exception do
      Log('Exception in FindNext ' + E.ClassName + ' ' + E.Message);
  end;
end;

{ ------------------------------------------------------------------ }

function FsFindClose(Hdl: THandle): Integer; stdcall;
var
  PFindNextRecord: ^TFindNextRecord;
begin
  Result := 0;
  PFindNextRecord := Pointer(Hdl);
  PFindNextRecord.PList.Free;
  Dispose(PFindNextRecord.PList);
  Dispose(PFindNextRecord);
end;

{ ------------------------------------------------------------------ }

function FsGetFile(RemoteName, LocalName: PChar; CopyFlags: Integer;
  RemoteInfo: pRemoteInfo): Integer; stdcall;

begin
  Result := FS_FILE_NOTFOUND;
end;

{ ------------------------------------------------------------------ }
function FsInit(PluginNr: Integer; pProgressProc: tProgressProc;
  pLogProc: tLogProc; pRequestProc: tRequestProc): Integer; stdcall;
begin
  Result := 1;
end;

function FsFindNext(Hdl: THandle; var FindData: tWIN32FINDDATA): bool; stdcall;
begin
  Result := False;
end;

function FsFindFirst(path: PChar; var FindData: tWIN32FINDDATA)
  : THandle; stdcall;
begin
  Result := INVALID_HANDLE_VALUE;
end;

function FsGetFileW(RemoteName, LocalName: pwidechar; CopyFlags: Integer;
  RemoteInfo: pRemoteInfo): Integer; stdcall;
var
  fs: TFileStream;
  filemode: Word;
  handler: TDownloadEventHandler;
  remotefilename: string;
begin
  remotefilename := normalizeDropboxPath(RemoteName);
  if ((CopyFlags = 0) or (CopyFlags = FS_COPYFLAGS_MOVE)) and
    FileExists(LocalName) then
  begin
    Result := FS_FILE_EXISTS;
    exit;
  end;
  filemode := fmCreate;
  if (CopyFlags and FS_COPYFLAGS_RESUME) <> 0 then
  // Resume not supported
  begin
    Result := FS_FILE_NOTSUPPORTED;
    exit;
  end;
  fs := nil;
  handler := nil;
  try
    try
      if FileExists(LocalName) and ((CopyFlags and FS_COPYFLAGS_OVERWRITE) = 0)
      then
      begin
        Result := FS_FILE_NOTSUPPORTED;
        exit;
      end;
      fs := TFileStream.Create(LocalName, filemode);
      handler := TDownloadEventHandler.Create(remotefilename, LocalName);
      DropboxClient.getFile(remotefilename, fs, '', handler.onBegin,
        handler.onWork);
      if handler.isAborted then
      begin
        // close filestream and delete file
        FreeAndNil(fs);
        DeleteFile(LocalName);
        Result := FS_FILE_USERABORT;
        exit;
      end
      else
      begin
        Result := FS_FILE_OK;
        if (CopyFlags and FS_COPYFLAGS_MOVE) <> 0 then
          // Remove file
          try
            DropboxClient.delete(remotefilename);
          except
            on E: Exception do
            begin
              Log('Exception in GetFile(delete remote file) ' + E.ClassName +
                ' ' + E.Message);
              Result := FS_FILE_NOTSUPPORTED;
              exit;
            end;
          end;

      end;
    finally
      if fs <> nil then
        fs.Free;
      if handler <> nil then
        handler.Free;

    end;
  except
    on E1: ErrorResponse do
    begin
      Log('Exception in GetFile ' + E1.ClassName + ' ' + E1.Message);
      if E1.Code = 404 then
        // Remote file not found
        Result := FS_FILE_NOTFOUND
      else
        // another dropbox errors
        Result := FS_FILE_READERROR;
    end;
    on E2: RESTSocketError do
    begin
      Log('Exception in GetFile ' + E2.ClassName + ' ' + E2.Message);
      Result := FS_FILE_READERROR;
    end;
    on E3: Exception do
    begin
      Log('Exception in GetFile ' + E3.ClassName + ' ' + E3.Message);
      Result := FS_FILE_WRITEERROR;
    end;
  end;
end;

function FsMkDirW(RemoteDir: pwidechar): bool; stdcall;
var
  Dir: string;
begin
  try
    Dir := normalizeDropboxPath(RemoteDir);
    Result := DropboxClient.createFolder(Dir);
  except
    on E: Exception do
    begin
      Log('Exception in FsMkDirW ' + E.ClassName + ' ' + E.Message);
      Result := False;
    end;
  end;
end;

function FsRemoveDirW(RemoteName: pwidechar): bool; stdcall;
var
  Dir: string;
begin
  Result := False;
  try
    Dir := normalizeDropboxPath(RemoteName);
    DropboxClient.delete(Dir);
    Result := True;
  except
    on E: Exception do
    begin
      Log('Exception in FsRemoveDirW ' + E.ClassName + ' ' + E.Message);
    end;
  end;

end;

function FsDeleteFileW(RemoteName: pwidechar): bool; stdcall;
var
  Name: string;
begin
  Result := False;
  try
    Name := normalizeDropboxPath(RemoteName);
    DropboxClient.delete(Name);
    Result := True;
  except
    on E3: Exception do
    begin
      Log('Exception in FsDeleteFileW ' + E3.ClassName + ' ' + E3.Message);
    end;
  end;
end;

function FsPutFileW(LocalName, RemoteName: pwidechar; CopyFlags: Integer)
  : Integer; stdcall;
var
  remotefilename: string;
  fs: TFileStream;
  handler: TDownloadEventHandler;
begin
  remotefilename := normalizeDropboxPath(RemoteName);
  if (((CopyFlags and FS_COPYFLAGS_RESUME) = 0) and
    ((CopyFlags and FS_COPYFLAGS_OVERWRITE) = 0) and
    DropboxClient.exists(remotefilename)) then
  begin
    Result := FS_FILE_EXISTS;
    exit;
  end;
  if (CopyFlags and FS_COPYFLAGS_RESUME) <> 0 then
  begin
    Result := FS_FILE_NOTSUPPORTED;
    exit;
  end;
  if (CopyFlags and FS_COPYFLAGS_OVERWRITE) <> 0 then
    // delete file
    try
      DropboxClient.delete(remotefilename)
    except
      on E: Exception do
      begin
        Log('Exception in PUTFile(delete remote file) ' + E.ClassName + ' ' +
          E.Message);
        Result := FS_FILE_NOTSUPPORTED;
        exit;
      end;
    end;
  fs := nil;
  handler := nil;
  try
    try
      fs := TFileStream.Create(LocalName, fmOpenRead);
      handler := TDownloadEventHandler.Create(LocalName, remotefilename);
      DropboxClient.putFile(remotefilename, fs, False, '', handler.onBegin,
        handler.onWork);
      if handler.isAborted then
      begin
        // close filestream and delete file
        fs.Free;
        Result := FS_FILE_USERABORT;
        exit;
      end
      else
      begin
        FreeAndNil(fs);
        Result := FS_FILE_OK;
        if (CopyFlags and FS_COPYFLAGS_MOVE) <> 0 then
          DeleteFile(LocalName);
        exit;
      end;

    finally
      if fs <> nil then
        fs.Free;
      if handler <> nil then
        handler.Free;
    end;
  except
    on E1: ErrorResponse do
    begin
      Log('Exception in PUTFile ' + E1.ClassName + ' ' + E1.Message);
      // Dropbox errors
      Result := FS_FILE_WRITEERROR;
    end;
    on E2: RESTSocketError do
    begin
      Log('Exception in PutFile ' + E2.ClassName + ' ' + E2.Message);
      Result := FS_FILE_WRITEERROR;
    end;
    on E3: EFOpenError do
    begin
      Log('Exception in PutFile ' + E3.ClassName + ' ' + E3.Message);
      Result := FS_FILE_NOTFOUND;
    end;
    on E4: EReadError do
    begin
      Log('Exception in PutFile ' + E4.ClassName + ' ' + E4.Message);
      Result := FS_FILE_READERROR;
    end;
    on E5: Exception do
    begin
      Log('Exception in PutFile ' + E5.ClassName + ' ' + E5.Message);
      Result := FS_FILE_READERROR;
    end;
  end;
end;

function FsRenMovFileW(OldName, NewName: pwidechar; Move, OverWrite: bool;
  RemoteInfo: pRemoteInfo): Integer; stdcall;
var
  oldFileName, newFileName: string;
  newFileExists: boolean;
  json: TJSONObject;
begin
  oldFileName := normalizeDropboxPath(OldName);
  newFileName := normalizeDropboxPath(NewName);
  newFileExists := DropboxClient.exists(newFileName);
  if not OverWrite and newFileExists then
  begin
    Result := FS_FILE_EXISTS;
    exit;
  end;
  if OverWrite and newFileExists then
    try
      DropboxClient.delete(newFileName);
    except
      Result := FS_FILE_NOTSUPPORTED;
      exit;
    end;
  try
    if Move then
    begin
      // move object
      json := DropboxClient.Move(oldFileName, newFileName);
      json.Free;
    end
    else
    begin
      // copy objects
      json := DropboxClient.copy(oldFileName, newFileName);
      json.Free;
    end;
    Result := FS_FILE_OK;
  except
    on E: Exception do
    begin
      Log('Exception in FsRenMovFileW ' + E.ClassName + ' ' + E.Message);
      Result := FS_FILE_WRITEERROR;
      exit;
    end;
  end;
end;

procedure FsGetDefRootName(DefRootName: PAnsiChar; maxlen: Integer); stdcall;
const
  rootName: String = 'Dropbox';
begin
  StrPLCopy(DefRootName, rootName, maxlen);
end;

function FsExecuteFileW(MainWin: THandle; RemoteName, Verb: pwidechar)
  : Integer; stdcall;
begin
  if (RemoteName = '\') and (Verb = 'properties') then
  begin
    ShowDllFormModal;
  end;
  Result := FS_EXEC_OK;
end;

exports

  FsFindClose,
  FsFindFirstW,
  FsFindFirst,
  FsFindNextW,
  FsFindNext,
  FsGetFile,
  FsInitW,
  FsGetFile,
  FsGetFileW,
  FsMkDirW,
  FsRemoveDirW,
  FsRenMovFileW,
  FsDeleteFileW,
  FsPutFileW,
  FsGetDefRootName,
  FsExecuteFileW,
  FsInit;

{ ------------------------------------------------------------------ }

{ TDownloadEventHandler }

constructor TDownloadEventHandler.Create(source, destination: string);
begin
  Fsource := source;
  FDestination := destination;
  isAborted := False;
end;

procedure TDownloadEventHandler.onBegin(ASender: TObject; AWorkMode: TWorkMode;
  Max: Int64);
begin
  FMax := Max;
end;

procedure TDownloadEventHandler.onWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
var
  percent: Integer;
  isAborted: Integer;
begin
  if FMax = 0 then
    percent := 0
  else
    percent := Round((AWorkCount * 100) / FMax);
  isAborted := ProgressProc(PluginNumber, PChar(Fsource),
    PChar(FDestination), percent);
  if isAborted = 1 then
  begin
    DropboxClient.Abort();
    self.isAborted := True;
  end;
end;

procedure MyDLLProc(Reason: Integer);
begin
  if Reason = DLL_PROCESS_DETACH then
  begin
    LocalEncoding.Free;
    if ssleay32Handle <> 0 then
      FreeLibrary(ssleay32Handle);
    if libeay32Handle <> 0 then
      FreeLibrary(libeay32Handle);
    if DropboxClient <> nil then
      DropboxClient.Free; // automatically free seesion object
  end;

end;

begin
  PluginPath := ExtractFilePath(GetPluginFileName());
  LogFullFilename := PluginPath + LOG_FILENAME;
  AccessKeyFullFileName := PluginPath + ACCESS_KEY_FILENAME;
  LocalEncoding := TEncoding.GetEncoding(GetACP());
  DLLProc := @MyDLLProc;

  // Hack to load ssl libs from custom path
  libeay32Handle := LoadLibrary(pwidechar(PluginPath + '\libeay32.dll'));
  ssleay32Handle := LoadLibrary(pwidechar(PluginPath + '\ssleay32.dll'));

  // free LocalEncoding
end.
