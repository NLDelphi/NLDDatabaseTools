unit NLDDBGrid;

interface

uses
  SysUtils, Classes, Controls, Grids, DBGrids, Windows,
  Graphics, Math, DB, INLDClientDataSetU;

type
  TIncSearch = class(TPersistent)
  private
    FActive: Boolean;
    FInterval: Integer;
    FIndexFieldName: string;
    FLastSearch: DWORD;
    FValue: string;
    FLastRecNo: Integer;
  public
    property IndexFieldName: string
      read FIndexFieldName write FIndexFieldName;
    property LastRecNo: Integer read FLastRecNo write FLastRecNo;
    property Value: string read FValue write FValue;
    property LastSeach: DWORD read FLastSearch write FLastSearch;
  published
    property Active: Boolean read FActive write FActive;
    property Interval: Integer read FInterval write FInterval;

    constructor Create(AOwner: TComponent);
  end;

type
  TNLDDBGrid = class(TDBGrid)
  private
    FAutoSort: Boolean;
    FIncSearch: TIncSearch;
    FGridImage: TBitmap;
    FMarkField: string;
    FMarkOrder: Boolean;
    FSortOrder: TSortOrder;
    FSelectedColBold: Boolean;
  protected
    procedure DrawColumnCell(const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState); override;
    procedure TitleClick(Column: TColumn); override;
    procedure KeyPress(var Key: Char); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function GetCellText(ACol: TColumn; ARow: Integer): string;
  published
    property AutoSort: Boolean read FAutoSort write FAutoSort;
    property IncSearch: TIncSearch read FIncSearch write FIncSearch;
    property MarkOrder: Boolean read FMarkOrder write FMarkOrder;
    property SortOrder: TSortOrder read FSortOrder write FSortOrder;
    property SelectedColBold: Boolean
      read FSelectedColBold write FSelectedColBold;
  end;

procedure Register;

implementation

{$R NLDDBGrid.RES }

type
  TGridPicture = (gpMarkDown, gpMarkUp);

const
  GridBmpNames: array [TGridPicture] of PChar =
  ('NLD_DBG_SODOWN', 'NLD_DBG_SOUP');

var
  GridBitmaps: array [TGridPicture] of TBitmap = (nil, nil);

procedure Register;
begin
  RegisterComponents('NLDelphi Database', [TNLDDBGrid]);
end;

function GetGridBitmap(BmpType: TGridPicture): TBitmap;
begin
  Result := GridBitmaps[BmpType];
end;

function MinimizeText(const Text: string; Canvas: TCanvas;
  MaxWidth: Integer): string;
var
  I: Integer;
begin
  Result := Text;
  I := 1;
  while (I <= Length(Text)) and (Canvas.TextWidth(Result) > MaxWidth) do
  begin
    Inc(I);
    Result := Copy(Text, 1, Max(0, Length(Text) - I)) + '...';
  end;
end;


{ TNLDDBGrid }

constructor TNLDDBGrid.Create(AOwner: TComponent);
var
  i: TGridPicture;
begin
  inherited;
  FGridImage := TBitmap.Create;
  FIncSearch := TIncSearch.Create(Self);

  for i := Low(TGridPicture) to High(TGridPicture) do
  begin
    GridBitmaps[i] := TBitmap.Create;
    GridBitmaps[i].LoadFromResourceName(HInstance, GridBmpNames[i]);
  end;

end;

destructor TNLDDBGrid.Destroy;
var
  i: TGridPicture;
begin
  for i := Low(TGridPicture) to High(TGridPicture) do
    FreeAndNil(GridBitmaps[i]);

  FGridImage := nil;

  inherited;

  FIncSearch.Free;
  FGridImage.Free;
end;

procedure TNLDDBGrid.DrawColumnCell(const Rect: TRect; DataCol: Integer;
  Column: TColumn; State: TGridDrawState);
var
  r: TRect;
  TitleRect: TRect;
  FieldCaption: string;

  function RectWidth(R: TRect): Integer;
  begin
    Result := R.Right - R.Left;
  end;

begin
  if (Column.FieldName = FMarkField) and MarkOrder then
    with Canvas do
    begin
      r := Rect;
      OffsetRect(r, 0, -r.Top);

      { Get GridImage ASC or Desc }
      if FSortOrder = soDesc then
        FGridImage := GetGridBitmap(gpMarkDown)
      else
        FGridImage := GetGridBitmap(gpMarkUp);

      FGridImage.Transparent := True;
      FGridImage.Width;

      { Set title rect}
      TitleRect := R;
      TitleRect.Right := TitleRect.Right - FGridImage.Width - 5;

      { Set font and color }
      Font := Column.Title.Font;
      Brush.Color := Column.Title.Color;

      { Check Title size and minimize it. }
      FieldCaption := MinimizeText(Column.Title.Caption, Canvas, RectWidth(TitleRect));
      SetBkMode(Handle, TRANSPARENT);
      FillRect(r);

      { Move R.Left. Workarround for Drawtext }
      r.Left := r.Left + 2;

      Windows.DrawText(Handle, PChar(FieldCaption), Length(FieldCaption), r,
        DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS);

      { Draw GridImage }
      if FGridImage <> nil then
        Draw(r.Right - FGridImage.Width - 3, r.Top + 3, FGridImage);
    end;
end;

function TNLDDBGrid.GetCellText(ACol: TColumn; ARow: Integer): string;
var
  ActiveRecord: TBookmark;
begin
  if (Assigned(DataSource) and (DataSource.State = dsBrowse) and
    Assigned(DataSource.DataSet)) and ((ARow > 0) and (ARow <= RowCount)) then
  begin
    ActiveRecord := DataSource.DataSet.GetBookmark;
    try

    finally
      DataSource.DataSet.GotoBookmark(ActiveRecord);
    end;

  end;
end;

procedure TNLDDBGrid.KeyPress(var Key: Char);
var
  AInterval: Cardinal;

  procedure Search(Key: Char);
  var
    ADataSet: TDataSet;
    NewValue: string;
    Bookmark: TBookmarkStr;
    CanSearch: Boolean;
    SearchField: TFieldDef;
  begin

    { Check Index, non index and more then one aren't valid }
    if (FIncSearch.IndexFieldName = '') or
        (Pos(';', FIncSearch.IndexFieldName) > 0) then
      Exit;

    ADataSet := nil;
    if Assigned(DataSource) and Assigned(DataSource.DataSet) then
      ADataSet := DataSource.DataSet;

    if not Assigned(ADataSet) then
      raise Exception.Create('DataSet not assigned');

    SearchField := ADataSet.FieldDefs.Find(FIncSearch.FIndexFieldName);
    CanSearch := False;
    if SearchField <> nil then
      case SearchField.DataType of
        ftString, ftMemo, ftBoolean:
          CanSearch := (Ord(Key) in [32..122]);
        ftInteger, ftSmallint, ftWord, ftFloat, ftBCD, ftDate, ftCurrency:
          CanSearch := (Key in ['0'..'9', ',' , '.']);
      end
    else
      CanSearch := True;

    if CanSearch then
    begin
      AInterval := FIncSearch.Interval;
      if (GetTickCount - FIncSearch.FLastSearch > AInterval) or
        (DataSource.DataSet.RecNo <> FIncSearch.FLastRecno) then
        FIncSearch.Value := '';

      FIncSearch.FLastSearch := GetTickCount;
      NewValue := FIncSearch.Value + Key;

      Bookmark := ADataSet.Bookmark;
      ADataSet.DisableControls;
      try

        if ADataSet.Locate(FIncSearch.FIndexFieldName,
          NewValue, [loCaseInsensitive, loPartialKey]) then
          FIncSearch.Value := NewValue
        else
          ADataSet.Bookmark := Bookmark;

        FIncSearch.LastRecno := ADataSet.RecNo;
      finally
        ADataSet.EnableControls;
      end;
    end;
  end;

begin
  inherited;


  { Implementation of IncSearch if Active is set to True }
  if FIncSearch.Active then
  begin
    Search(Key);
  end;

end;

procedure TNLDDBGrid.TitleClick(Column: TColumn);
var
  ADataSet: TDataSet;
  SortCDS: INLDClientDataSet;
  i: Integer;
begin
  { Selected Column data font-style bold }
  if FSelectedColBold then
  begin
    for i := 0 to Columns.Count -1 do
      Columns[i].Font.Style := [];

    Column.Font.Style := [fsBold];
  end;

  if Assigned(DataSource) and Assigned(DataSource.DataSet) then
  begin
    ADataSet := DataSource.DataSet;

    { Sort automatic the fields in de CDS when ADataSet supports
      INLDClientDataSet Interface. }
    if ADataSet.GetInterface(INLDClientDataset, SortCDS) then
    begin
      SortCDS.Sort(Column.FieldName);
      FSortOrder := SortCDS.GetSortOrder;
    end;

    { Set MarkField for Title image.. }
    if MarkOrder then
      FMarkField := Column.FieldName;

    { Set IndexFieldName for IncSearch }
    if FIncSearch.Active then
      FIncSearch.IndexFieldName := Column.FieldName;
  end;

  inherited;
end;

{ TIncSearch }

constructor TIncSearch.Create(AOwner: TComponent);
begin
  { Default Interval }
  FInterval := 2000;
end;

end.
