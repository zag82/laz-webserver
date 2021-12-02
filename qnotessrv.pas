unit qnotessrv;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, httpdefs, httproute, fpjson, jsonparser,
  basesrv;

type

  { TNotesAppHandler }

  TNotesAppHandler = class(TAppHandler)
  private
    function LoadData(): TJSONObject;
    procedure SaveData(AData: TJSONObject);
  public
    constructor Create(ARootPath: string);
    destructor Destroy; override;

    procedure notesApi(req: TRequest; res: TResponse);
  end;

implementation


{ TNotesAppHandler }

function TNotesAppHandler.LoadData(): TJSONObject;
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create();
  try
    ms.LoadFromFile(FRootPath + FDataFile);
    Result := TJSONObject(GetJSON(ms, False));
  finally
    ms.Free;
  end;
end;

procedure TNotesAppHandler.SaveData(AData: TJSONObject);
var
  s: RawByteString;
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create();
  try
    s := AData.FormatJSON(DefaultFormat);
    ms.WriteBuffer(s[1], Length(s));
    ms.SaveToFile(FRootPath + FDataFile);
  finally
    ms.Free;
  end;
end;

constructor TNotesAppHandler.Create(ARootPath: string);
begin
  inherited Create(ARootPath);
end;

destructor TNotesAppHandler.Destroy;
begin
  inherited Destroy;
end;

procedure TNotesAppHandler.notesApi(req: TRequest; res: TResponse);
var
  id: string;
  i: integer;
  jres, jdata, jparam: TJSONObject;
  jnotes: TJSONArray;
  found: boolean;
begin
  If CompareText(req.Method,'GET') = 0 then
  begin
    // get all notes and colors
    try
      jres := LoadData();
      jsonResponse(res, jres);
    finally
      jres.Free;
    end;
  end
  else If CompareText(req.Method,'POST') = 0 then
  begin
    // create new note
    jres := TJSONObject.Create();
    jparam := TJSONObject(GetJSON(req.Content, False));
    try
      jdata := LoadData();
      jnotes := jdata.Arrays['notes'];
      jnotes.Add(jparam);
      SaveData(jdata);

      jsonResponse(res, jres);
    finally
      jdata.Free;
      jres.Free;
    end;
  end
  else If CompareText(req.Method,'PUT') = 0 then
  begin
    // update existing note
    id := req.RouteParams['id'];
    jres := TJSONObject.Create();
    jparam := TJSONObject(GetJSON(req.Content, False));
    try
      jdata := LoadData();
      jnotes := jdata.Arrays['notes'];
      found := false;
      for i := jnotes.Count - 1 downto 0 do
        if AnsiSameText(TJSONObject(jnotes[i]).Strings['id'], id) then
        begin
          found := true;
          jnotes.Delete(i);
          break;
        end;
      if found then
      begin
        jnotes.Add(jparam);
        SaveData(jdata);
      end;

      jsonResponse(res, jres);
    finally
      jdata.Free;
      jres.Free;
    end;
  end
  else If CompareText(req.Method,'DELETE') = 0 then
  begin
    // delete node
    id := req.RouteParams['id'];
    jres := TJSONObject.Create();
    try
      jdata := LoadData();
      jnotes := jdata.Arrays['notes'];
      for i := jnotes.Count - 1 downto 0 do
        if AnsiSameText(TJSONObject(jnotes[i]).Strings['id'], id) then
        begin
          jnotes.Delete(i);
          break;
        end;
      SaveData(jdata);

      jsonResponse(res, jres);
    finally
      jdata.Free;
      jres.Free;
    end;

  end
  else
  begin
    Res.Code := 405;
    Res.CodeText := 'Method not allowed';
    res.SendContent;
    Exit;
  end;

end;


end.
