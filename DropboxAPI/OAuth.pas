{
      Mozilla Public License.

      ``The contents of this file are subject to the Mozilla Public License
      Version 1.1 (the "License"); you may not use this file except in compliance
      with the License. You may obtain a copy of the License at

      http://www.mozilla.org/MPL/

      Software distributed under the License is distributed on an "AS IS"
      basis, WITHOUT WARRANTY OF

      ANY KIND, either express or implied. See the License for the specific language governing rights and

      limitations under the License.

      The Original Code is OAuth Core 1.0 - Delphi implementation.

      The Initial Developer of the Original Code is CB2 Enterprises, Inc.
      Portions created by

      CB2 Enterprises, Inc. are Copyright (C) 2008-2009.
      All Rights Reserved.

      Contributor(s): ______________________________________.

      Alternatively, the contents of this file may be used under the terms
      of the _____ license (the  [___] License), in which case the provisions
      of [______] License are applicable  instead of those above.
      If you wish to allow use of your version of this file only under the terms
      of the [____] License and not to allow others to use your version of this
      file under the MPL, indicate your decision by deleting  the provisions
      above and replace  them with the notice and other provisions required
      by the [___] License.  If you do not delete the provisions above,
      a recipient may use your version of this file under either the MPL or the
      [___] License."
}

unit OAuth;

interface

uses
  Classes, SysUtils, IdURI, Windows;
const
HTTP_METHOD = 'GET';
OAUTH_VERSION = '1.0';
type

  EOAuthException = class(Exception);

  TOAuthConsumer = class;
  TOAuthToken = class;
  TOAuthRequest = class;
  TOAuthSignatureMethod = class;
  TOAuthSignatureMethod_HMAC_SHA1 = class;
  TOAuthSignatureMethod_PLAINTEXT = class;

  TOAuthConsumer = class
  private
    FKey: string;
    FSecret: string;
    FCallback_URL: string;
    procedure SetKey(const Value: string);
    procedure SetSecret(const Value: string);
    procedure SetCallback_URL(const Value: string);
  public
    constructor Create(Key, Secret: string); overload;
    constructor Create(Key, Secret: string; Callback_URL: string); overload;
    property Key: string read FKey write SetKey;
    property Secret: string read FSecret write SetSecret;
    property Callback_URL: string read Fcallback_URL write SetCallback_URL;
  end;

  TOAuthToken = class
  private
    FKey: string;
    FSecret: string;
    FCallback: string;
    procedure SetKey(const Value: string);
    procedure SetSecret(const Value: string);
    procedure SetCallback(const Value: string);
  public
    constructor Create(Key, Secret: string);
    function AsString: string; virtual;
    procedure FromString(s: string);
    property Key: string read FKey write SetKey;
    property Secret: string read FSecret write SetSecret;
    property Callback: string read FCallback write SetCallback;
  end;

  TOAuthRequest = class
  private
    FParameters: TStringList;
    FHTTPMethod: string;
    FHTTPURL: string;
    FVersion: string;
  public
    constructor Create(URL: string=''; Parameters: TStringList=nil;Method: string=HTTP_METHOD);
    destructor Desroy();
    procedure SetParameter(parameter, value: string);
    function GetParameter(key : string): string;
    procedure GetNonoauthParameters(var Parameters: TStringList);
    procedure ToHeader(var headers : TStringList; realm:string='');
    procedure ToPost(var post: TStringList);
    function ToPostData(): string;
    function ToUrl(): string;
    function GetNormalizedParameters():string;
    function GetNormalizedHTTPMethod():string;
    function GetNormalizedHTTPUrl():string;
    procedure SignRequest(Signature_Method: TOAuthSignatureMethod; Consumer: TOAuthConsumer;
                          Token: TOAuthToken);
    function BuildSignature(Signature_Method: TOAuthSignatureMethod; Consumer: TOAuthConsumer;
                          Token: TOAuthToken): string;
    class function FromConsumerAndToken(Consumer: TOAuthConsumer; Token: TOAuthToken;
                                  HTTPURL: string=''; Parameters: TStringList=nil;HTTPMethod: string=HTTP_METHOD;Callback: string='';
                                  Verifier:string=''): TOAuthRequest;
    class function GenerateNonce(lenght: integer=8): string;
    class function GenerateTimestamp: string;
  end;

  TOAuthSignatureMethod = class
  public
    function check_signature(Request: TOAuthRequest; Consumer: TOAuthConsumer;
                             Token: TOAuthToken; Signature: string): boolean;
    function get_name(): string; virtual; abstract;
    function build_signature(Request: TOAuthRequest; Consumer: TOAuthConsumer;
                             Token: TOAuthToken): string; virtual; abstract;
    procedure build_signature_base_string(Request: TOAuthRequest; Consumer: TOAuthConsumer; Token: TOAuthToken; out key, raw : string); virtual; abstract;
  end;

  TOAuthSignatureMethod_HMAC_SHA1 = class(TOAuthSignatureMethod)
  public
    function get_name(): string; override;
    function build_signature(Request: TOAuthRequest; Consumer: TOAuthConsumer;
                             Token: TOAuthToken): string; override;
    procedure build_signature_base_string(Request: TOAuthRequest; Consumer: TOAuthConsumer; Token: TOAuthToken; out key, raw : string); override;
  end;

  TOAuthSignatureMethod_PLAINTEXT = class(TOAuthSignatureMethod)
  public
    function get_name(): string; override;
    function build_signature(Request: TOAuthRequest; Consumer: TOAuthConsumer;
                             Token: TOAuthToken): string; override;
    procedure build_signature_base_string(Request: TOAuthRequest; Consumer: TOAuthConsumer; Token: TOAuthToken; out key, raw : string); override;
  end;

  TOAuthUtil = class
  public
    class function urlEncodeRFC3986(URL: string):string;
    class function urlDecodeRFC3986(URL: string):string;
  end;

const
  UnixStartDate : TDateTime = 25569;

implementation
uses
  IdGlobal, IdHash, IdHashMessageDigest, IdHMACSHA1, IdCoderMIME;

function DateTimeToUnix(ConvDate: TDateTime): Longint;
var
  x: double;
  lTimeZone: TTimeZoneInformation;
begin
  GetTimeZoneInformation(lTimeZone);
  ConvDate := ConvDate + (lTimeZone.Bias / 1440);
  x := (ConvDate - UnixStartDate) * 86400;
  Result := Trunc(x);
end;

function _IntToHex(Value: Integer; Digits: Integer): String;
begin
    Result := SysUtils.IntToHex(Value, Digits);
end;

function XDigit(Ch : Char) : Integer;
begin
    if (Ch >= '0') and (Ch <= '9') then
        Result := Ord(Ch) - Ord('0')
    else
        Result := (Ord(Ch) and 15) + 9;
end;


function IsXDigit(Ch : Char) : Boolean;
begin
    Result := ((Ch >= '0') and (Ch <= '9')) or
              ((Ch >= 'a') and (Ch <= 'f')) or
              ((Ch >= 'A') and (Ch <= 'F'));
end;

function htoin(Value : PChar; Len : Integer) : Integer;
var
    I : Integer;
begin
    Result := 0;
    I      := 0;
    while (I < Len) and (Value[I] = ' ') do
        I := I + 1;
    while (I < len) and (IsXDigit(Value[I])) do begin
        Result := Result * 16 + XDigit(Value[I]);
        I := I + 1;
    end;
end;


function htoi2(Value : PChar) : Integer;
begin
    Result := htoin(Value, 2);
end;


function UrlEncode(s: string; safe: string='/'): string;
function _IntToHex(Value: Integer; Digits: Integer): String;
begin
    Result := SysUtils.IntToHex(Value, Digits);
end;
var
    I, J, K : Integer;
    Ch : Char;
    raw : TArray<System.Byte>;
    added_flag : boolean;

begin
    Result := '';
    for I := 1 to Length(S) do
    begin
        added_flag := False;
        Ch := S[I];

        if  ((Ch >= '0') and (Ch <= '9')) or
            ((Ch >= 'a') and (Ch <= 'z')) or
            ((Ch >= 'A') and (Ch <= 'Z')) or
            (Ch = '.') or (Ch = '-') or (Ch = '_') then
        begin
            Result := Result + Ch;
            added_flag := True;
        end
        else
            for J := 1 to Length(safe) do
                if Ch = safe[J] then
                begin
                  Result := Result + Ch;
                  added_flag := True;
                  break;
                end;

        if not added_flag then
        begin
            raw := TEncoding.UTF8.GetBytes(ch);
            for K := 0 to Length(raw)-1 do
            begin
                Result := Result + '%' + _IntToHex(raw[K] , 2);
            end;
        end;
    end;
end;


function Escape(s:string):string;
begin
  Result := UrlEncode(s, '~');
end;


function UrlDecode(const Url : String) : String;
var
    I, J, K, L : Integer;
begin
    Result := Url;
    L      := Length(Result);
    I      := 1;
    K      := 1;
    while TRUE do begin
        J := I;
        while (J <= Length(Result)) and (Result[J] <> '%') do begin
            if J <> K then
                Result[K] := Result[J];
            Inc(J);
            Inc(K);
        end;
        if J > Length(Result) then
            break;                   { End of string }
        if J > (Length(Result) - 2) then begin
            while J <= Length(Result) do begin
                Result[K] := Result[J];
                Inc(J);
                Inc(K);
            end;
            break;
        end;
        Result[K] := Char(htoi2(@Result[J + 1]));
        Inc(K);
        I := J + 3;
        Dec(L, 2);
    end;
    SetLength(Result, L);
end;

{ TOAuthConsumer }
constructor TOAuthConsumer.Create(Key, Secret: string);
begin
  FKey := Key;
  FSecret := Secret;
  FCallBack_URL  := '';
end;

constructor TOAuthConsumer.Create(Key, Secret, Callback_URL: string);
begin
  FKey := Key;
  FSecret := Secret;
  FCallBack_URL  := Callback_URL;
end;

procedure TOAuthConsumer.SetCallback_URL(const Value: string);
begin
  FCallback_URL := Value;
end;

procedure TOAuthConsumer.SetKey(const Value: string);
begin
  FKey := Value;
end;

procedure TOAuthConsumer.SetSecret(const Value: string);
begin
  FSecret := Value;
end;

{ TOAuthToken }
function TOAuthToken.AsString: string;
begin
  result := 'oauth_token=' + Self.Key + '&oauth_token_secret=' + Self.Secret;
end;

constructor TOAuthToken.Create(Key, Secret: string);
begin
  FKey := Key;
  FSecret := Secret;
  FCallback := '';
end;

procedure TOAuthToken.FromString(s: string);
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  sl.Delimiter := '&';
  sl.DelimitedText := s;
  SetKey(sl.Values['oauth_token']);
  SetSecret(sl.Values['oauth_token_secret']);
  FreeAndNil(sl);
end;

procedure TOAuthToken.SetCallback(const Value: string);
begin
  FCallback := Value;
end;

procedure TOAuthToken.SetKey(const Value: string);
begin
  FKey := Value;
end;

procedure TOAuthToken.SetSecret(const Value: string);
begin
  FSecret := Value;
end;

{ TOAuthRequest }
function TOAuthRequest.BuildSignature(Signature_Method: TOAuthSignatureMethod;
  Consumer: TOAuthConsumer; Token: TOAuthToken): string;
begin
  Result := Signature_Method.build_signature(Self, Consumer, Token);
end;


constructor TOAuthRequest.Create(URL: string; Parameters: TStringList;Method:string);
begin
  FHTTPURL := URL;
  FHTTPMethod := Method;
  FParameters := TStringList.Create;
  if Parameters<>nil then FParameters.Assign(Parameters);
  FVersion := OAUTH_VERSION;
end;

destructor TOAuthRequest.Desroy;
begin
  FParameters.Free;
end;

class function TOAuthRequest.FromConsumerAndToken(Consumer: TOAuthConsumer;
  Token: TOAuthToken; HTTPURL: string; Parameters: TStringList; HTTPMethod,
  Callback, Verifier: string): TOAuthRequest;
var
  mParameters : TStringList;
  defaults : TStringList;
begin
  mparameters := TStringList.Create;
  defaults := TStringList.Create;
  if Parameters <> nil then mParameters.Assign(Parameters);
  defaults.Values['oauth_consumer_key'] := Consumer.Key;
  defaults.Values['oauth_timestamp'] := GenerateTimestamp();
  defaults.Values['oauth_nonce'] := GenerateNonce();
  defaults.Values['oauth_version'] := OAUTH_VERSION;
  defaults.AddStrings(mParameters);
  mParameters.Assign(defaults);
  if Token <> nil then
  begin
    mParameters.Values['oauth_token'] := Token.Key;
    if Token.Callback<>'' then mParameters.Values['oauth_callback'] := Token.Callback;
    if verifier <> '' then mParameters.Values['oauth_verifier'] := verifier;
  end
  else
    if Callback <> '' then mParameters.Values['oauth_callback'] := Callback;

  Result := TOAuthRequest.Create(HTTPURL, mParameters,HTTPMethod);
  defaults.Free;
  mparameters.Free;
end;

class function TOAuthRequest.GenerateNonce(lenght: integer): string;
var
i:integer;
 begin
  randomize;
for I := 0 to lenght - 1 do
  Result:= Result + IntToStr(Random(10));
end;

class function TOAuthRequest.GenerateTimeStamp: string;
begin
  Result := IntToStr(DateTimeToUnix(Now));
end;

procedure TOAuthRequest.GetNonOauthParameters(var Parameters: TStringList);
var
  i: integer;
  key : string;
begin
  parameters.clear;
  for I := 0 to FParameters.Count-1 do
    begin
      key := FParameters.Names[i];
      if Pos('oauth_',key)<1 then parameters.Values[key] := FParameters.Values[key];
    end;
end;

function TOAuthRequest.GetNormalizedHTTPMethod: string;
begin
   Result := UpperCase(FHTTPMethod);
end;

function TOAuthRequest.GetNormalizedHTTPUrl: string;
var
uri : TIdURI;
port_part, path_part : string;
begin
   uri := TIdURI.Create(FHTTPURL);
   if uri.Port<>'' then
   begin
    if (uri.Protocol = 'http') and (uri.Port='80') then uri.Port :='';
    if (uri.Protocol = 'https') and (uri.Port='443') then uri.Port :='';
   end;
   if uri.Port <> '' then port_part := ':' + uri.Port;
   if uri.Document = ''
   then
    path_part := Copy(uri.Path, 0, Length(uri.Path)-1)
   else
    path_part := uri.Path + uri.Document;
   Result := Format('%s://%s%s%s', [uri.Protocol, uri.Host,port_part, path_part]);
   uri.Free;
end;

function TOAuthRequest.GetNormalizedParameters: string;
var
parameters, key_values_list : TStringList;
x,i: integer;
key : string;
begin
  parameters := TStringList.Create;
  key_values_list := TStringList.Create;
  parameters.Assign(FParameters);
  x := parameters.IndexOfName('oauth_signature');
  if x <> -1 then
    parameters.Delete(x);
  for I := 0 to parameters.Count-1 do
  begin
    key := parameters.Names[I];
    key_values_list.Values[Escape(key)] := Escape(parameters.ValueFromIndex[I])
  end;
   // Attention here..
  key_values_list.Sort();

  key_values_list.Delimiter := '&';
  Result := key_values_list.DelimitedText;
  parameters.Free;
  key_values_list.Free;
end;

function TOAuthRequest.GetParameter(key: string): string;
begin
   Result := FParameters.Values[key];
end;



procedure TOAuthRequest.SetParameter(parameter, value: string);
begin
  FParameters.Values[parameter] := value;
end;

procedure TOAuthRequest.SignRequest(Signature_Method: TOAuthSignatureMethod;
  Consumer: TOAuthConsumer; Token: TOAuthToken);
begin
  //Set the signature parameter to the result of build_signature.
  //Set the signature method.
  setParameter('oauth_signature_method', signature_method.get_name());
  //Set the signature.
  setParameter('oauth_signature', BuildSignature(signature_method, consumer, token))
end;

procedure TOAuthRequest.ToHeader(var headers: TStringList; realm: string);
var
auth_header, key : string;
i : integer;
begin
if headers = nil then exit;
headers.Clear;
auth_header := Format('OAuth realm="%s"', [realm]);
for I := 0 to FParameters.Count-1 do
  begin
    key := FParameters.Names[i];
    if Copy(key, 0, 6) = 'oauth_'
      then auth_header := auth_header + Format(', %s="%s"', [key, Escape(FParameters.Values[key])]);
  end;
  headers.Values['Authorization'] := auth_header;
end;

procedure TOAuthRequest.ToPost(var post: TStringList);
var i: Integer;
begin
  if post = nil then exit;
  post.Clear;
  post.Delimiter := '&';
  for I := 0 to FParameters.Count-1 do
  begin
    post.Add(Format('%s=%s', [Escape(FParameters.Names[I]), Escape(FParameters.ValueFromIndex[I])]));
  end;
end;

function TOAuthRequest.ToPostData: string;
var
dataStringList : TStringList;
begin
 dataStringList := TStringList.Create;
 dataStringList.Delimiter := '&';
 ToPost(dataStringList);
 Result := dataStringList.DelimitedText;
 dataStringList.Free;
end;

function TOAuthRequest.ToUrl: string;
begin
    Result := Format('%s?%s', [GetNormalizedHTTPUrl, ToPostData]);
end;

{ TOAuthUtil }
class function TOAuthUtil.urlDecodeRFC3986(URL: string): string;
begin
  result := TIdURI.URLDecode(URL);
end;

class function TOAuthUtil.urlEncodeRFC3986(URL: string): string;
var
  URL1: string;
begin
  URL1 := URLEncode(URL);
  URL1 := StringReplace(URL1, '+', ' ', [rfReplaceAll, rfIgnoreCase]);
  result := URL1;
end;

{ TOAuthSignatureMethod }
function TOAuthSignatureMethod.check_signature(Request:TOAuthRequest;
  Consumer: TOAuthConsumer; Token: TOAuthToken; Signature: string): boolean;
var
  newsig: string;
begin
   newsig:= Self.build_signature(Request, Consumer, Token);
  if (newsig = Signature) then
    Result := True
  else
    Result := False;
end;

{ TOAuthSignatureMethod_HMAC_SHA1 }
function TOAuthSignatureMethod_HMAC_SHA1.build_signature(Request: TOAuthRequest;
  Consumer: TOAuthConsumer; Token: TOAuthToken): string;

  function Base64Encode(const Input: TIdBytes): string;
  begin
    Result := TIdEncoderMIME.EncodeBytes(Input);
  end;

  function EncryptHMACSha1(Input, AKey: string): TIdBytes;
  begin
    with TIdHMACSHA1.Create do
    try
      Key := ToBytes(AKey);
      Result := HashValue(ToBytes(Input));
    finally
      Free;
    end;
  end;
var
  key, raw : string;
begin
  build_signature_base_string(Request, Consumer,Token, key, raw);
  Result := Base64Encode(EncryptHMACSha1(raw, key));
end;

procedure TOAuthSignatureMethod_HMAC_SHA1.build_signature_base_string(
  Request: TOAuthRequest; Consumer: TOAuthConsumer; Token: TOAuthToken; out key,
  raw: string);
var
  sig_list : TStringList;
begin
  sig_list := TStringList.Create;
  sig_list.Add(Escape(Request.GetNormalizedHTTPMethod()));
  sig_list.Add(Escape(Request.GetNormalizedHTTPUrl()));
  sig_list.Add(Escape(Request.GetNormalizedParameters()));
  if Token <> nil then
    key :=Format('%s&%s', [Escape(Consumer.Secret), Escape(Token.Secret)])
  else
    key := Escape(Consumer.Secret)+'&';
  sig_list.Delimiter := '&';
  raw := sig_list.DelimitedText;
  sig_list.Free;
end;

function TOAuthSignatureMethod_HMAC_SHA1.get_name: string;
begin
  result := 'HMAC-SHA1';
end;

{ TOAuthSignatureMethod_PLAINTEXT }
function TOAuthSignatureMethod_PLAINTEXT.build_signature(Request: TOAuthRequest;
  Consumer: TOAuthConsumer; Token: TOAuthToken): string;
var
key, raw: string;
begin
  build_signature_base_string(Request,Consumer,Token,key, raw);
  Result := key;
end;

procedure TOAuthSignatureMethod_PLAINTEXT.build_signature_base_string(
  Request: TOAuthRequest; Consumer: TOAuthConsumer; Token: TOAuthToken; out key,
  raw: string);
  var
  sig : string;
begin
  if Token <> nil then
    key :=Format('%s&%s', [Escape(Consumer.Secret), Escape(Token.Secret)])
  else
    key := Escape(Consumer.Secret)+'&';
  key :=  sig;
  raw := sig;
end;

function TOAuthSignatureMethod_PLAINTEXT.get_name: string;
begin
  Result := 'PLAINTEXT';
end;

end.
