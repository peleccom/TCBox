unit mycrypt;

interface

function CryptString(Str, Key: String): String;
function DeCryptString(Str, Key: String): String;

implementation

function CryptString(Str, Key: String): String;
var
  i, q: Integer;
begin
  for i := 1 to Length(Str) do
  begin
    q := (Ord(Str[i]) + (Ord(Key[(Pred(i) mod Length(Key)) + 1]) - Ord('0')));
    if q >= 256 then
      Dec(q, 256);
    Str[i] := Chr(q);
    Result := Str;
  end;
end;

function DeCryptString(Str, Key: String): String;
var
  i, q: Integer;
begin
  for i := 1 to Length(Str) do
  begin
    q := (Ord(Str[i]) - (Ord(Key[(Pred(i) mod Length(Key)) + 1]) - Ord('0')));
    if q < 0 then
      Inc(q, 256);
    Str[i] := Chr(q);
    Result := Str;
  end;
end;

end.
