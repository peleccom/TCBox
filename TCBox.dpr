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
  LogInUnit in 'LogInUnit.pas' {LogInForm} ,
  mycrypt in 'mycrypt.pas',
  Log4D in 'Log4D.pas',
  PluginConsts in 'PluginConsts.pas',
  settings in 'settings.pas',
  gnugettext in 'gnugettext.pas',
  SettingUnit in 'SettingUnit.pas' {SettingsForm} ,
  UserLogin in 'UserLogin.pas',
  DropboxClient in 'DropboxAPI\DropboxClient.pas',
  DropboxRest in 'DropboxAPI\DropboxRest.pas',
  DropboxSession in 'DropboxAPI\DropboxSession.pas',
  iso8601Unit in 'DropboxAPI\iso8601Unit.pas',
  OAuth in 'DropboxAPI\OAuth.pas';

// httpGet in 'httpGet.pas';

{$E wfx}
{$R *.RES}

type
  PJsonArrayEnumerator = ^TJSONArrayEnumerator;

  TFindNextRecord = Record
    PList: ^TList<tWIN32FINDDATAW>;
    index: Integer;
  End;

  TSimpleDownloadEventHandler = class(TDownloadEventHandler)
    FMax: Int64;
    Fsource, FDestination: string;
    isAborted: boolean;
    constructor Create(source, destination: string);
    procedure onBegin(ASender: TObject; AWorkMode: TWorkMode;
      Max: Int64); override;
    procedure onWork(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64); override;
  end;

  TChunkedUploadEventHandler = class(TSimpleDownloadEventHandler)
    constructor Create(source, destination: string; size: Int64);
    procedure onWork(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64); override;
    procedure setCurrentPosition(position: Int64);
  private
    FPosition: Int64;
    FSize: Int64;
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

function ShowLoginForm: boolean;
var
  modal: TModalResult;
begin
  if TUserLogin.loadKey(AccessKeyFullFileName, DropboxSession) then
  begin
    Result := True;
    Exit;
  end;
  logger.Info('Key file not loaded');
  LogInForm := TLogInForm.Create(nil, DropboxSession, DropboxClient,
    AccessKeyFullFileName);
  modal := LogInForm.ShowModal;
  if modal = mrOk then
    Result := True
  else
    Result := False;
  LogInForm.Free;
end;

function showSettingsForm(): boolean;
var
  form: TSettingsForm;
begin
  form := TSettingsForm.Create(nil, DropboxSession, AccessKeyFullFileName);
  form.ShowModal();
  form.Free;
end;

// Send progress value to TC
function SendProgress(sourceName: String; targetName: String;
  percentDone: Integer): boolean;
var
  isAbort: Integer;
begin
  // some checks
  isAbort := ProgressProc(PluginNumber, PChar(sourceName), PChar(targetName),
    percentDone);
  if (isAbort = 1) then
    Result := True
  else
    Result := False;

end;

function PutBigFile(f: TFileStream; localFilename: String;
  dropboxFilename: String; overwrite: boolean = False): Integer;
var
  chunkedUploader: TChunkedUploader;
  size: Int64;
  json: TJSONObject;
  percentUpload: byte;
begin
  SendProgress(localFilename, dropboxFilename, 0);
  size := f.size;
  chunkedUploader := DropboxClient.getChunkedUpload(f, f.size);
  try
    while chunkedUploader.Offset < size do
    begin
      logger.Debug('Upload chunk with offset '+IntTostr(chunkedUploader.Offset));

      if size <> 0 then
        percentUpload := Round((chunkedUploader.Offset * 100) / size)
      else
        percentUpload := 0;
      if SendProgress(localFilename, dropboxFilename, percentUpload) then

      // user abort
      begin
        Result := FS_FILE_USERABORT;
        Exit;
      end;
      try
        chunkedUploader.uploadChunked(PLUGIN_CHUNK_SIZE);
      except
        begin
          logger.Error('UploadChunked exception');
          raise;
        end;
      end;
    end;
    json := chunkedUploader.finish(dropboxFilename, overwrite);
    if json <> nil then
      json.Free;
    Result := FS_FILE_OK;
    SendProgress(localFilename, dropboxFilename, 100);
  finally
    chunkedUploader.Free;
  end;
end;

function PutSmallFile(f: TFileStream; localFilename: String;
  dropboxFilename: String; overwrite: boolean): Integer;
var
  handler: TSimpleDownloadEventHandler;
begin
  SendProgress(localFilename, dropboxFilename, 0);
  handler := TSimpleDownloadEventHandler.Create(localFilename, dropboxFilename);
  try
    DropboxClient.putFile(dropboxFilename, f, overwrite, '', handler);
    if handler.isAborted then
    begin
      // close filestream and delete file
      Result := FS_FILE_USERABORT;
      Exit;
    end
    else
    begin
      Result := FS_FILE_OK;
      Exit;
    end;

  finally
    handler.Free;
  end;
  SendProgress(localFilename, dropboxFilename, 100);
end;

function FsInitW(PluginNr: Integer; pProgressProcW: tProgressProcW;
  pLogProcW: tLogProcW; pRequestProcW: tRequestProcW): Integer; stdcall;

var
  token: TOAuthToken;
begin
  ProgressProc := pProgressProcW;
  LogProc := pLogProcW;
  RequestProc := pRequestProcW;
  PluginNumber := PluginNr;
  logger.Info('Initialization');
  DropboxSession := TDropboxSession.Create(APP_KEY, APP_SECRET,
    TAccessType.dropbox);
  DropboxClient := TDropboxClient.Create(DropboxSession);
  LoginClosed := not ShowLoginForm();
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
    if not ShowLoginForm() then
    begin
      DropboxSession.unlink();
      Result := INVALID_HANDLE_VALUE;
      Exit;
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
    for i := 0 to JsonArray.size - 1 do
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
      Exit();
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
  handler: TSimpleDownloadEventHandler;
  remotefilename: string;
begin
  remotefilename := normalizeDropboxPath(RemoteName);
  if ((CopyFlags = 0) or (CopyFlags = FS_COPYFLAGS_MOVE)) and
    FileExists(LocalName) then
  begin
    Result := FS_FILE_EXISTS;
    Exit;
  end;
  filemode := fmCreate;
  if (CopyFlags and FS_COPYFLAGS_RESUME) <> 0 then
  // Resume not supported
  begin
    Result := FS_FILE_NOTSUPPORTED;
    Exit;
  end;
  fs := nil;
  handler := nil;
  try
    try
      if FileExists(LocalName) and ((CopyFlags and FS_COPYFLAGS_OVERWRITE) = 0)
      then
      begin
        Result := FS_FILE_NOTSUPPORTED;
        Exit;
      end;
      fs := TFileStream.Create(LocalName, filemode);
      handler := TSimpleDownloadEventHandler.Create(remotefilename, LocalName);
      DropboxClient.getFile(remotefilename, fs, '', handler);
      if handler.isAborted then
      begin
        // close filestream and delete file
        FreeAndNil(fs);
        DeleteFile(LocalName);
        Result := FS_FILE_USERABORT;
        Exit;
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
              Exit;
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
  filesize: Int64;
  overwrite: boolean;
begin
  remotefilename := normalizeDropboxPath(RemoteName);
  overwrite := False;

  if (((CopyFlags and FS_COPYFLAGS_RESUME) = 0) and
    ((CopyFlags and FS_COPYFLAGS_OVERWRITE) = 0) and
    DropboxClient.exists(remotefilename)) then
  begin
    Result := FS_FILE_EXISTS;
    Exit;
  end;
  if (CopyFlags and FS_COPYFLAGS_RESUME) <> 0 then
  begin
    Result := FS_FILE_NOTSUPPORTED;
    Exit;
  end;
  if (CopyFlags and FS_COPYFLAGS_OVERWRITE) <> 0 then
    overwrite := True;

  fs := nil;
  try
    try
      fs := TFileStream.Create(LocalName, fmOpenRead);
      filesize := fs.size;

      if filesize > PLUGIN_BIGFILE_SIZE then { change }
      begin
        logger.Debug('Uploading bigFile');
        // use uploadbigfile (chunked upload)
        Result := PutBigFile(fs, LocalName, remotefilename, overwrite);
        if Result <> FS_FILE_OK then
          Exit;
      end
      else
      begin
        logger.Debug('Uploading smallFile');
        Result := PutSmallFile(fs, LocalName, remotefilename, overwrite);
        if Result <> FS_FILE_OK then
          Exit;
      end;
      if (CopyFlags and FS_COPYFLAGS_MOVE) <> 0 then
        DeleteFile(LocalName);
    finally
      if fs <> nil then
        fs.Free;
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

function FsRenMovFileW(OldName, NewName: pwidechar; Move, overwrite: bool;
  RemoteInfo: pRemoteInfo): Integer; stdcall;
var
  oldFileName, newFileName: string;
  newFileExists: boolean;
  json: TJSONObject;
begin
  oldFileName := normalizeDropboxPath(OldName);
  newFileName := normalizeDropboxPath(NewName);
  newFileExists := DropboxClient.exists(newFileName);
  if (not overwrite and newFileExists) = True then
  begin
    Result := FS_FILE_EXISTS;
    Exit;
  end;
  if (overwrite and newFileExists) = True then
    try
      try
        SendProgress(OldName, NewName, 0);
        DropboxClient.delete(newFileName);
      except
        Result := FS_FILE_NOTSUPPORTED;
        Exit;
      end;
    finally
      SendProgress(OldName, NewName, 100);
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
      Exit;
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
    // ShowDllFormModal;
    showSettingsForm();
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

{ TSimpleDownloadEventHandler }

constructor TSimpleDownloadEventHandler.Create(source, destination: string);
begin
  Fsource := source;
  FDestination := destination;
  isAborted := False;
end;

procedure TSimpleDownloadEventHandler.onBegin(ASender: TObject;
  AWorkMode: TWorkMode; Max: Int64);
begin
  FMax := Max;
end;

procedure TSimpleDownloadEventHandler.onWork(ASender: TObject;
  AWorkMode: TWorkMode; AWorkCount: Int64);
var
  percent: Integer;
  isAborted: boolean;
begin
  if FMax = 0 then
    percent := 0
  else
    percent := Round((AWorkCount * 100) / FMax);
  isAborted := SendProgress(Fsource, FDestination, percent);
  if isAborted then
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

{ TChunkedUploadEventHandler }

constructor TChunkedUploadEventHandler.Create(source, destination: string;
  size: Int64);
begin
  Inherited Create(source, destination);
  FSize := size;
end;

procedure TChunkedUploadEventHandler.onWork(ASender: TObject;
  AWorkMode: TWorkMode; AWorkCount: Int64);
var
  percent: Integer;
  isAborted: boolean;
  totalWorkCount: Int64;
begin
  totalWorkCount := AWorkCount + FPosition;
  if (Fsize = 0) then
    percent := 0
  else
    percent := Round((totalWorkCount * 100) / Fsize);
  //logger.Debug('total work ' + IntTostr(totalWorkCount));
  //logger.Debug('progress ' + IntTostr(percent));
  isAborted := SendProgress(Fsource, FDestination, percent);
  if isAborted then
  begin
    DropboxClient.Abort();
    self.isAborted := True;
  end;
end;

procedure TChunkedUploadEventHandler.setCurrentPosition(position: Int64);
begin
  FPosition := position;
  logger.Debug('position ------ ' +InttoStr(position));
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

  // settings configuration
  settingfilename := PluginPath + PLUGIN_SETTINGS_FILENAME;
  GetSettings().load();

  UseLanguage(GetSettings().getLangStr());
  DefaultInstance.BindtextdomainToFile('languagecodes',
    PluginPath + PLUGIN_LANGUAGE_CODES_PATH);

  // free LocalEncoding
end.
