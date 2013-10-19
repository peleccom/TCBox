library TCBox;

{$R *.dres}

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
  mycrypt in 'mycrypt.pas',
  Log4D in 'Log4D.pas',
  PluginConsts in 'PluginConsts.pas',
  settings in 'settings.pas',
  gnugettext in 'gnugettext.pas';

// httpGet in 'httpGet.pas';

{$E wfx}
{$R *.RES}

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
  LoginClosed: boolean;

  // SSL libs
  libeay32Handle, ssleay32Handle: THandle;
  //
  // Dropbox
  DropboxSession: TDropboxSession;
  DropboxClient: TDropboxClient;

  logger: TLogLogger;
  logAppender: ILogAppender;
  logLayout: ILogLayout;

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

function ShowDllFormModal: boolean;
var
  modal: TModalResult;
begin
  LogInForm := TLogInForm.Create(nil, DropboxSession, DropboxClient,
    AccessKeyFullFileName);
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
  settings: TSettings;
begin
  settings := TSettings.Create();
  settings.load(PluginPath + PLUGIN_SETTINGS_FILENAME);
  settings.Free;
  ProgressProc := pProgressProcW;
  LogProc := pLogProcW;
  RequestProc := pRequestProcW;
  PluginNumber := PluginNr;
  logger.Info('Initialization');
  DropboxSession := TDropboxSession.Create(APP_KEY, APP_SECRET,
    TAccessType.dropbox);
  DropboxClient := TDropboxClient.Create(DropboxSession);
  LoginClosed := not ShowDllFormModal();
  if LoginClosed then
    DropboxSession.unlink();
  Result := 0;
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
  if (not DropboxSession.isLinked()) and (not LoginClosed) then
  begin
    if not ShowDllFormModal() then
    begin
      DropboxSession.unlink();
      Result := INVALID_HANDLE_VALUE;
      exit;
    end;
  end;
  LoginClosed := False;
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
    on E1: Exception do
      logger.Error('Exception in FindFirst ' + E1.ClassName + ' ' + E1.Message);
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
      logger.Error('Exception in FindNext ' + E.ClassName + ' ' + E.Message);
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
              logger.Error('Exception in GetFile(delete remote file) ' +
                E.ClassName + ' ' + E.Message);
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
      logger.Error('Exception in GetFile ' + E1.ClassName + ' ' + E1.Message);
      if E1.Code = 404 then
        // Remote file not found
        Result := FS_FILE_NOTFOUND
      else
        // another dropbox errors
        Result := FS_FILE_READERROR;
    end;
    on E2: RESTSocketError do
    begin
      logger.Error('Exception in GetFile ' + E2.ClassName + ' ' + E2.Message);
      Result := FS_FILE_READERROR;
    end;
    on E3: Exception do
    begin
      logger.Error('Exception in GetFile ' + E3.ClassName + ' ' + E3.Message);
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
      logger.Error('Exception in FsMkDirW ' + E.ClassName + ' ' + E.Message);
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
      logger.Error('Exception in FsRemoveDirW ' + E.ClassName + ' ' +
        E.Message);
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
      logger.Error('Exception in FsDeleteFileW ' + E3.ClassName + ' ' +
        E3.Message);
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
        logger.Error('Exception in PUTFile(delete remote file) ' + E.ClassName +
          ' ' + E.Message);
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
      logger.Error('Exception in PUTFile ' + E1.ClassName + ' ' + E1.Message);
      // Dropbox errors
      Result := FS_FILE_WRITEERROR;
    end;
    on E2: RESTSocketError do
    begin
      logger.Error('Exception in PutFile ' + E2.ClassName + ' ' + E2.Message);
      Result := FS_FILE_WRITEERROR;
    end;
    on E3: EFOpenError do
    begin
      logger.Error('Exception in PutFile ' + E3.ClassName + ' ' + E3.Message);
      Result := FS_FILE_NOTFOUND;
    end;
    on E4: EReadError do
    begin
      logger.Error('Exception in PutFile ' + E4.ClassName + ' ' + E4.Message);
      Result := FS_FILE_READERROR;
    end;
    on E5: Exception do
    begin
      logger.Error('Exception in PutFile ' + E5.ClassName + ' ' + E5.Message);
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
  if (not OverWrite and newFileExists) = True then
  begin
    Result := FS_FILE_EXISTS;
    exit;
  end;
  if (OverWrite and newFileExists) = True then
    try
      DropboxClient.delete(newFileName);
    except
      Result := FS_FILE_NOTSUPPORTED;
      exit;
    end;
  try
    if Move = True then
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
      logger.Error('Exception in FsRenMovFileW ' + E.ClassName + ' ' +
        E.Message);
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
  LogFullFilename := PluginPath + PLUGIN_LOG_FILENAME;
  AccessKeyFullFileName := PluginPath + PLUGIN_ACCESS_KEY_FILENAME;
  LocalEncoding := TEncoding.GetEncoding(GetACP());
  DLLProc := @MyDLLProc;

  // Hack to load ssl libs from custom path
  libeay32Handle := LoadLibrary(pwidechar(PluginPath + '\libeay32.dll'));
  ssleay32Handle := LoadLibrary(pwidechar(PluginPath + '\ssleay32.dll'));

  // Logging
  logLayout := TLogPatternLayout.Create('%r (%d) [%t] (%c) %p %x - %m%n');
  logAppender := TLogRollingFileAppender.Create('Default', LogFullFilename,
    logLayout);
  logLayout.Options[DateFormatOpt] := 'dd-mm-yy hh:mm:ss';
  TLogBasicConfigurator.Configure(logAppender);
  TLogLogger.GetRootLogger.Level := All;
  logger := TLogLogger.GetLogger('Default');

  // free LocalEncoding
end.
