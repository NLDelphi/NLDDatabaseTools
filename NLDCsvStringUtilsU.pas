unit NLDCsvStringUtilsU;

interface

uses
  Classes, DB, SysUtils;

type
  TSplitArray = array of string;

type
  TDataSetToCSV = class(TComponent)
  private
    FFileName: string;
    FTextFile: TextFile;
    FSeperator: string;
    procedure CreateFile;
    procedure CloseFile;
  protected
  public
    procedure ExportData(DataSet: TDataSet);
  published
    property FileName: string read FFileName write FFileName;
    property Seperator: string read FSeperator write FSeperator;
  end;

  function SplitFields(Line, FieldDelimiter: string): TSplitArray;

implementation

function SplitFields(Line, FieldDelimiter: string): TSplitArray;
var
  CSV: TSplitArray;
  Delimiter: string;
  DelimiterCount: Integer;
  DelimiterIndexLine: Integer;
  iCount: Integer;
  IndexDelimiter: Integer;
  IndexQuote: Integer;
  Tempstr: string;
  Quote: string;
  Quotes: string;
begin
  Quote := '"';
  Quotes := '""';

  iCount := 0;

  Line := StringReplace(Line, Quotes, '[&quot]', [rfReplaceAll]);

  while Length(Line) > 0 do
  begin
    Line := Trim(Line);

    IndexQuote := Pos(Quote, Line);
    IndexDelimiter := Pos(FieldDelimiter, Line);

    { If there's a quote the field-delimiter changes to "<delimiter>}
    if (IndexQuote <> 0) and (IndexQuote < IndexDelimiter) then
    begin
      Delimiter := Quote + FieldDelimiter;
      DelimiterIndexLine := Pos(Delimiter, Line);
      DelimiterCount := Length(Delimiter);
    end
    { Else if we've found the Delimiter }
    else if (IndexDelimiter > 0) then
    begin
      Delimiter := FieldDelimiter;
      DelimiterIndexLine := Pos(Delimiter, Line);
      DelimiterCount := Length(Delimiter);
    end
    { Else end of string }
    else
    begin
      DelimiterIndexLine := Length(Line);
      DelimiterCount := 1;
    end;

    if DelimiterIndexLine > 0 then
    begin
      Tempstr := Line;
      Delete(Tempstr, DelimiterIndexLine + DelimiterCount,
        (Length(Tempstr) - DelimiterIndexLine));
    end;

    TempStr := StringReplace(TempStr, '[&quot]', Quote, [rfReplaceAll]);
    if (IndexQuote <> 0) and (IndexQuote < IndexDelimiter) or (IndexDelimiter = 0) then
    begin
      if (Copy(Tempstr, 1, 1) = Quote) and
         ((Copy(Tempstr, Length(Tempstr), 1) = Quote) or
         ((Copy(Tempstr, Length(Tempstr) - DelimiterCount + 1, DelimiterCount)
           = Delimiter))) then
      begin
         Delete(Tempstr, 1, Length(Quote));
         Delete(Tempstr, Length(Tempstr) + 1 - DelimiterCount, DelimiterCount);
      end;
    end
    else if IndexDelimiter > 0 then
      Delete(Tempstr, Length(TempStr), 1);

    Inc(iCount);
    SetLength(CSV, iCount);

    CSV[iCount - 1] := Trim(TempStr);
    Line := Copy(Line, DelimiterIndexLine + DelimiterCount, Length(Line));
  end;

  Result := CSV;
end;

{ TDataSetToCSV }

procedure TDataSetToCSV.CloseFile;
begin
  System.CloseFile(FTextFile);
end;

procedure TDataSetToCSV.CreateFile;
begin
  AssignFile(FTextFile, FFileName);
  Rewrite(FTextFile);
end;

procedure TDataSetToCSV.ExportData(DataSet: TDataSet);
var
  SaveRecNo: Integer;
  
  procedure ExportHeader;
  var
    FieldNames: string;
    i: Integer;
  begin
    with DataSet do
      for i := 0 to Fields.Count -1 do
        FieldNames := FieldNames + Fields[i].FieldName + FSeperator;

    System.Writeln(FTextFile, FieldNames);
  end;

  procedure ExportRows;
  var
    i: Integer;
    FieldValue: string;
    RowValue: string;
  begin
    with DataSet do
      while not Eof do
      begin
        RowValue := '';
        for i := 0 to Fields.Count -1  do
        begin
          with Fields[i] do
            if IsNull then
              if DataType in [ftString, ftMemo] then
                FieldValue := '""'
              else
                FieldValue := ''
            else
              if DataType in [ftString, ftMemo] then
                FieldValue := '"' + Value + '"'
              else
                FieldValue := Fields[i].Value;

          RowValue := RowValue + FieldValue + FSeperator;
        end;

        System.Writeln(FTextFile, RowValue);
        Next;
      end;
  end;

begin
  CreateFile;
  with DataSet do
  begin
    DisableControls;
    try
      SaveRecNo := RecNo;
      First;
      ExportHeader;
      ExportRows;
    finally
      RecNo := SaveRecNo;
      EnableControls;
      CloseFile;
    end;
  end;
end;

end.
