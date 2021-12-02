unit basesrv;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, httpdefs, httproute, fpjson, jsonparser, fpmimetypes;

const
  maxAge = 5 * 60 * 1000; // cached time in seconds

type

  { TAppHandler }

  TAppHandler = class
  protected
    FRootPath: string;
    FPublicPath: string;
    FDataFile: string;
    procedure LoadSettings(const AFileName: string);
    function extractUrlPath(AUrl: string): string;
  public
    constructor Create(ARootPath: string);
    // common
    procedure OnErr(Sender : TObject; E : Exception);

    procedure jsonResponse(res: TResponse; data: TJSONData);
    procedure indexDir(req: TRequest; res: TResponse);
    procedure static(req: TRequest; res: TResponse);
    procedure accessLog(req: TRequest; res: TResponse);
  end;


implementation

uses
  DateUtils, IniFiles;

{ TAppHandler }

procedure TAppHandler.LoadSettings(const AFileName: string);
var
  f: TIniFile;
begin
  FPublicPath := 'public';
  FDataFile := 'data.json';

  if FileExists(AFileName) then
  begin
    f := TIniFile.Create(AFileName);
    try
      FPublicPath := f.ReadString('main', 'publicpath', 'public');
      FDataFile := f.ReadString('main', 'datafile', 'data.json');
    finally
      f.Free;
    end;
  end;
end;

function TAppHandler.extractUrlPath(AUrl: string): string;
var
  k: integer;
begin
  Result := AUrl;
  k := Pos('?', Result);
  if k <> 0 then
    Result := Copy(Result, 1, k-1);
end;

constructor TAppHandler.Create(ARootPath: string);
begin
  FRootPath := ARootPath;

  LoadSettings(FRootPath + 'qnotes.ini');

  MimeTypes.LoadFromFile(FRootPath + 'mime.txt');
end;

procedure TAppHandler.OnErr(Sender : TObject; E : Exception);
begin
  Writeln(E.ToString);
end;

procedure TAppHandler.jsonResponse(res: TResponse; data: TJSONData);
begin
  res.Content := data.FormatJSON(AsCompressedJSON);
  res.Code := 200;
  res.ContentType := 'application/json';
  res.ContentLength := length(res.Content);
  res.SendContent;
end;

procedure TAppHandler.indexDir(req: TRequest; res: TResponse);
begin
  res.Code := 301;
  res.SetCustomHeader('Location', extractUrlPath(req.URI) + 'index.html');
  res.SendContent;

  accessLog(req, res);
end;

procedure TAppHandler.static(req: TRequest; res: TResponse);
var
  url, fn: string;
  fs: TFileStream;
begin
  fs := nil;
  If CompareText(req.Method,'GET')<>0 then
  begin
    Res.Code:=405;
    Res.CodeText:='Method not allowed';
  end
  else
  begin
    url := extractUrlPath(req.URI);
    if url <> '' then
    begin
      if url.EndsWith('/') then
        url := url + 'index.html';
      if url[1] = '/' then
        url := copy(url, 2);
    end;

    fn := FRootPath + FPublicPath + PathDelim + url;
    if fn.EndsWith('/') or not FileExists(fn) then
    begin
      res.Code := 404;
      res.CodeText:='Not found';
    end
    else
    begin
      res.Code := 200;
      res.CodeText := 'OK';

      res.ContentType := MimeTypes.GetMimeType(ExtractFileExt(fn));
      if (res.ContentType = '') then
        res.ContentType:='Application/octet-stream';
      if maxAge > 0 then
        res.CacheControl := Format('max-age=%d',[maxAge]);

      fs := TFileStream.Create(fn,fmOpenRead or fmShareDenyWrite);
      res.ContentLength := fs.Size;
      res.ContentStream := fs;
    end;
  end;

  res.SendResponse;
  if res.ContentStream <> nil then
    res.ContentStream := nil;
  if fs <> nil then
    fs.Free;
  accessLog(req, res);
end;

procedure TAppHandler.accessLog(req: TRequest; res: TResponse);
  function fmtDate(ADate: TDateTime): string;
  var
    d,m,y: integer;
  begin
    d := DayOfTheMonth(ADate);
    m := MonthOfTheYear(ADate);
    y := YearOf(ADate);

    Result := IntToStr(y) + '-';
    if m < 10 then
      Result := Result + '0';
    Result := Result + IntToStr(m) + '-';
    if d < 10 then
      Result := Result + '0';
    Result := Result + IntToStr(d) + ' ';

    Result := Result + TimeToStr(ADate);
  end;
var
  fs: TFormatSettings;
begin
  fs.DateSeparator := '-';
  fs.TimeSeparator := ':';
  fs.ShortDateFormat := 'YYYY-MM-DD';
  fs.LongDateFormat := 'YYYY-MM-DD HH:NN:SS';
  Writeln(Format('%s %d - [%s] %s', [req.Method, res.Code, fmtDate(Now), req.URI], fs));
end;

end.

