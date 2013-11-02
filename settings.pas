unit settings;

interface

uses
  iniFiles, System.SysUtils, Vcl.Dialogs;

type

  TSettings = class
    procedure load();
    procedure save();
    function getLangStr(): string;
    procedure setLangStr(lang: string);
    function getLogLevel():String;
  private
    langStr: string;
    logLevel:string;
  end;

function GetSettings(): TSettings;

var
  settingfilename: string;

implementation

var

  _Singleton: TSettings = nil;

function GetSettings(): TSettings;
begin
  if not Assigned(_Singleton) then
    _Singleton := TSettings.Create;
  Result := _Singleton
end;

{ TSettings }

function TSettings.getLangStr: string;
begin
  Result := langStr;
end;

function TSettings.getLogLevel: String;
begin
 Result := logLevel;
end;

procedure TSettings.load();
var
  ini: TMemIniFile;
  res: string;
begin
  ini := TMemIniFile.Create(settingfilename, TEncoding.UTF8);
  try
    langStr := ini.ReadString('Options', 'LANG', '');
    logLevel := ini.ReadString('Options','LogLevel','ALL');
  finally
    ini.Free;
  end;
end;

procedure TSettings.save();
var
  ini: TMemIniFile;
begin
  ini := TMemIniFile.Create(settingfilename, TEncoding.UTF8);
  try
    ini.WriteString('Options', 'LANG', langStr);
    ini.UpdateFile();
  finally
    ini.Free;
  end;
end;

procedure TSettings.setLangStr(lang: string);
begin
  langStr :=  lang;
  save();
end;

initialization

finalization

if Assigned(_Singleton) then
  _Singleton.Free;

end.
