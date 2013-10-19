unit UserLogin;
// load and save user key
interface

uses System.Classes, System.SysUtils, PluginConsts, DropboxSession, Log4D,
  mycrypt, AccessConfig, IdCoderMIME;

type
  TUserLogin = class
  public
    class function saveKey(accessKeyFilename: string;
      session: TDropboxSession): boolean;
    class function loadKey(accessKeyFilename: string;
      session: TDropboxSession): boolean;
  private
    class function encrypt(Data: string): string;
    class function decrypt(Data: string): string;
  end;

implementation

{ TUserLogin }

class function TUserLogin.decrypt(Data: string): string;
var
  buf: string;
begin
  try
    buf := TIdDecoderMIME.DecodeString(Data);
    Result := decryptstring(buf, KEYFILE_PASS);
  except
    Result := '';
  end;
end;

class function TUserLogin.encrypt(Data: string): string;
var
  buf: string;
begin
  try
    buf := Cryptstring(Data, KEYFILE_PASS);
    Result := TIdEncoderMIME.EncodeString(buf);
  except
    Result := '';
  end;
end;

class function TUserLogin.loadKey(accessKeyFilename: string;
  session: TDropboxSession): boolean;
var
  keyFileStream: TFileStream;
  stringStream: TStringStream;
  bufString: string;
begin
  Result := True;
  try
    keyFileStream := TFileStream.Create(accessKeyFilename, fmOpenRead);
    stringStream := TStringStream.Create();
    try
      stringStream.LoadFromStream(keyFileStream);
      bufString := stringStream.DataString;
      bufString := decrypt(bufString);
      // check signature
      if (pos(ACESS_KEY_SIGNATURE_STRING, bufString) <> 1) then
      begin
        TLogLogger.GetLogger('Default').Debug('Key file signature incorrect');
        Result := False;
        exit;
      end;
      // delete signature
      bufString := Copy(bufString, Length(ACESS_KEY_SIGNATURE_STRING) + 1,
        Length(bufString) - Length(ACESS_KEY_SIGNATURE_STRING));
      stringStream.Clear;
      stringStream.WriteString(bufString);
      stringStream.Seek(0, soFromBeginning);
      session.LoadAccessToken(stringStream);
    finally
      keyFileStream.Free;
      stringStream.Free;
    end;
  except
    Result := False;
  end;
end;

class function TUserLogin.saveKey(accessKeyFilename: string;
  session: TDropboxSession): boolean;
var
  keyFileStream: TFileStream;
  stringStream: TStringStream;
  bufString: string;
begin
  Result := True;
  try
    keyFileStream := TFileStream.Create(accessKeyFilename, fmCreate);
    stringStream := TStringStream.Create();

    try
      session.SaveAccessToken(stringStream);
      bufString := stringStream.DataString;
      bufString := encrypt(ACESS_KEY_SIGNATURE_STRING + bufString);
      stringStream.Clear;
      stringStream.WriteString(bufString);
      stringStream.SaveToStream(keyFileStream);
    finally
      keyFileStream.Free;
      stringStream.Free;
    end;
  except
    Result := False;
  end;
end;

end.
