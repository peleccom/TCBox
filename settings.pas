unit settings;

interface
uses
  iniFiles, System.SysUtils;
type

TSettings = class
   procedure load(filename: string);
   procedure save(filename: string);
   function getLangStr(): string;
   private
    langStr: string;
end;

implementation

{ TSettings }

function TSettings.getLangStr: string;
begin
  Result := langStr;
end;

procedure TSettings.load(filename: string);
var
  ini: TMemIniFile;
  res: string;
begin
  ini := TMemIniFile.Create(filename, TEncoding.UTF8);
   try
     langStr := ini.ReadString('Options', 'LANG', '');
   finally
     ini.Free;
   end;
end;

procedure TSettings.save(filename: string);
begin

end;

end.
