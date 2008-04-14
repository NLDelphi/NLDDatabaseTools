unit NLDClientDataSet;

interface

uses
  SysUtils, Classes, DB, DBClient, NLDCsvStringUtilsU, INLDClientDataSetU;

type
  TFieldTypeRequest = procedure (Sender: TObject; const FieldName: string;
    var FieldType: TFieldType; var FieldLength: Integer) of object;

type
  TFloatFormat = class(TPersistent)
  private
    FActive: Boolean;
    FDisplayFormat: string;
  protected
  public
  published
    property Active: Boolean read FActive write FActive default False;
    property DisplayFormat: string read FDisplayFormat write FDisplayFormat;
  end;


type
  TNLDClientDataSet = class(TClientDataSet, INLDClientDataSet)
  private
    FSortOrder: TSortOrder;
    FCSVSeperator: string;

    FOnFieldTypeRequest: TFieldTypeRequest;
    FFloatFormat: TFloatFormat;
  private
    function GetSortOrder: TSortOrder; virtual;

    function IndexExists(IndexName: string): Boolean;
    function IndexNameByField(FieldName: string): string;

    procedure CreateIndex(FieldName: string);
    procedure SetFloatFormat;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;



    procedure ExportToCSV(FileName: string);
    procedure ImportFormCSV(FileName: string);
    procedure Sort(SortFieldName: string);

    property SortOrder: TSortOrder read FSortOrder write FSortOrder;
  published
    property OnFieldTypeRequest: TFieldTypeRequest
      read FOnFieldTypeRequest write FOnFieldTypeRequest;

    property CSVSeperator: string read FCSVSeperator write FCSVSeperator;
    property FloatFormat: TFloatFormat read FFloatFormat write FFloatFormat;
  end;

procedure Register;

implementation

uses Math;

procedure Register;
begin
  RegisterComponents('NLDelphi Database', [TNLDClientDataSet]);
end;

{ TNLDClientDataSet }

constructor TNLDClientDataSet.Create(AOwner: TComponent);
begin
  inherited;
  FFloatFormat := TFloatFormat.Create;

  { Default sort-order is Ascending }
  FSortOrder := soAsc;
  FCSVSeperator := ',';
end;

{ Create the index for the ClientDataSet }
procedure TNLDClientDataSet.CreateIndex(FieldName: string);
var
  IndexName: string;
begin
  IndexName := IndexNameByField(FieldName);
  with IndexDefs do
    if SortOrder = soDesc then
      Add(IndexName, FieldName, [ixDescending])
    else
      Add(IndexName, FieldName, []);

end;

destructor TNLDClientDataSet.Destroy;
begin
  FFloatFormat.Free;
  inherited;
end;

procedure TNLDClientDataSet.ExportToCSV(FileName: string);
{ Export the data from te ClientDataSet to a CSV-File }
var
  CSVExport: TDataSetToCSV;
begin
  CSVExport := TDataSetToCSV.Create(Self);
  try
    CSVExport.Seperator := FCSVSeperator;
    CSVExport.FileName := FileName;
    CSVExport.ExportData(Self);
  finally
    CSVExport.Free;
  end;
end;



function TNLDClientDataSet.GetSortOrder: TSortOrder;
begin
  Result := FSortOrder;
end;

procedure TNLDClientDataSet.ImportFormCSV(Filename: string);
{ Imports data from a CSV File and Creates a dataset }
var
  CSVFields: TStrings;
  ContainData: Boolean;
  DataSplit: TSplitArray;
  FieldSplit: TSplitArray;
  ImportData: TStrings;


  function DefineFieldType(Value: string): TFieldType;
  var
    DataDateTime: TDateTime;
    DataFloat: Extended;
    DataInteger: Integer;
  begin
    if TryStrToDateTime(Value, DataDateTime) then
      Result := ftDateTime
    else if TryStrToFloat(Value, DataFloat) then
      Result := ftFloat
    else if TryStrToInt(Value, DataInteger) then
      Result := ftInteger
    else
      Result := ftString;
  end;

  procedure DefineFields;
  var
    i: Integer;
  begin
    { The first line defines the fieldnames }

    FieldSplit := SplitFields(ImportData[0], FCSVSeperator);

    for i := 0 to Length(FieldSplit) - 1 do
      CSVFields.Add(FieldSplit[i]);
  end;

  procedure CreateFields;
  var
    i: Integer;
    FieldType: TFieldType;
    FieldDesc: string;
    FieldLength: Integer;
  begin
    Close;
    FieldDefs.Clear;

    for i := 0 to CSVFields.Count -1 do
    begin
      FieldLength := 255;
      FieldDesc := CSVFields[i];

      if ContainData then
      begin
        DataSplit := SplitFields(ImportData[1], FCSVSeperator);
        FieldType := DefineFieldType(DataSplit[i]);
      end
      else
        FieldType := ftUnknown;

      if Assigned(FOnFieldTypeRequest) then
        FOnFieldTypeRequest(Self, FieldDesc, FieldType, FieldLength);

      if FieldType = ftString then
        FieldDefs.Add(FieldDesc, FieldType, FieldLength)
      else
        FieldDefs.Add(FieldDesc, FieldType);
    end;
  end;

  procedure AddData;
  var
    i: Integer;
    iFields: Integer;
  begin
    { These lines contains the data }
    for i := 1 to ImportData.Count - 1 do
    begin
      DataSplit := SplitFields(ImportData[i], FCSVSeperator);

      Append;

      for iFields := 0 to Length(DataSplit) - 1 do
        with Fields[iFields] do
          case DataType of
            ftBoolean: AsBoolean := StrToBool(DataSplit[iFields]);
            ftDateTime: AsDateTime := StrToDateTime(DataSplit[iFields]);
            ftFloat: AsFloat := StrToFloat(StringReplace(
                  DataSplit[iFields], '.',',',[rfReplaceAll]));
            ftInteger: AsInteger := StrToInt(DataSplit[iFields]);
            ftString: AsString := DataSplit[iFields];
          else
            Value := DataSplit[iFields];
          end;

      Post;
    end;
  end;
begin
  ContainData := False;

  ImportData := TStringList.Create;
  CSVFields := TStringList.Create;
  try
    ImportData.LoadFromFile(FileName);

    if ImportData.Count = 0 then
      raise Exception.Create(FileName + ' contains no data');

    if ImportData.Count > 1 then
      ContainData := True;

    DefineFields;
    CreateFields;
    CreateDataSet;

    if FFloatFormat.Active then
      SetFloatFormat;

    if ContainData then
      AddData;
  finally
    ImportData.Free;
    CSVFields.Free;
  end;
end;

{ Check if de Index already exists }
function TNLDClientDataSet.IndexExists(IndexName: string): Boolean;
begin
  Result := False;
  with IndexDefs do
    if IndexOf(Indexname) <> -1 then
      Result := True;
end;

{ Get the IndexName }
function TNLDClientDataSet.IndexNameByField(FieldName: string): string;
begin
  if FSortOrder = soDesc then
    Result := FieldName + 'DESC'
  else
    Result := FieldName + 'ASC';
end;

{ Procedure to sort the dataset Ascending or Descending }
procedure TNLDClientDataSet.SetFloatFormat;
var
  i: Integer;
begin
  for i := 0 to Fields.Count -1 do
    if Fields[i].DataType = ftFloat then
      TFloatField(Fields[i]).DisplayFormat := FFloatFormat.DisplayFormat;
end;

procedure TNLDClientDataSet.Sort(SortFieldName: string);

  function IndexField: string;
  var
    Count: Integer;
  begin
    if FSortOrder = soAsc then
      Count := 3
    else
      Count := 4;

    Result := IndexName;
    System.Delete(Result, Length(IndexName) - (Count - 1), Count);
  end;

begin
  { controleer of het om hetzelfde veld gaat als waar de index op staat }
  if SameText(SortFieldName, IndexField) then
  begin
    if FSortOrder = soAsc then
      FSortOrder := soDesc
    else
      FSortOrder := soAsc
  end
  else
    FSortOrder := soAsc;

  if not IndexExists(IndexNameByField(SortFieldName)) then
    CreateIndex(SortFieldName);

  IndexName := IndexNameByField(SortFieldName);
end;

end.



