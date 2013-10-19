unit settings;

interface

uses
  iniFiles, System.SysUtils, Vcl.Dialogs;

type

  TSettings = class
    procedure load();
    procedure save();
    function getLangStr(): string;
  private
    langStr: string;
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

procedure TSettings.load();
var
  ini: TMemIniFile;
  res: string;
begin
  ini := TMemIniFile.Create(settingfilename, TEncoding.UTF8);
  try
      langStr := ini.ReadString('Options', 'LANG', '');
  finally
    ini.Free;
  end;
end;

procedure TSettings.save();
begin
  //
end;

initialization

finalization

if Assigned(_Singleton) then
  _Singleton.Free;

end.
