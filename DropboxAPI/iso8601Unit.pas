unit iso8601Unit;

interface

type
  TIso8601 = class(TObject)
  public
    class function DateTimeFromIso8601(const Value: string): TDateTime; static;
    class function UtcDateTimeToIso8601(const Value: TDateTime): string; static;
    class function DateTimeToIso8601(const Value: TDateTime): string; static;
    class function UtcNow: TDateTime; static;
    class function ToUtc(const Value: TDateTime): TDateTime; static;
    class function FromUtc(const Value: TDateTime): TDateTime; static;
  end;

implementation

uses
  IdGlobalProtocols, {IdGlobal for Index}   SysUtils,
  XSBuiltIns;

class function TIso8601.DateTimeFromIso8601(const Value: string): TDateTime;
begin
  with TXSDateTime.Create() do
  try
    XSToNative(value); // convert from WideString
    Result := AsDateTime; // convert to TDateTime  finally
  finally
    Free();
  end;
end;

class function TIso8601.UtcDateTimeToIso8601(const Value: TDateTime): string;
begin
  with TXSDateTime.Create() do
  try
    AsUTCDateTime := Value;
    Result := NativeToXS; // convert to WideString
  finally
    Free();
  end;
end;

class function TIso8601.DateTimeToIso8601(const Value: TDateTime): string;
begin
  with TXSDateTime.Create() do
  try
    AsDateTime := Value; // convert from TDateTime
    Result := NativeToXS; // convert to WideString
  finally
    Free();
  end;
end;

class function TIso8601.UtcNow: TDateTime;
begin
  Result := ToUtc(Now);
end;

class function TIso8601.ToUtc(const Value: TDateTime): TDateTime;
var
  Bias: TDateTime;
begin
  Bias := TimeZoneBias;
  Result := Value + TimeZoneBias;
end;

class function TIso8601.FromUtc(const Value: TDateTime): TDateTime;
var
  Bias: TDateTime;
begin
  Bias := TimeZoneBias;
  Result := Value - TimeZoneBias;
end;

end.
