unit NLDDBCheckBox;

interface

uses
  SysUtils, Classes, Controls, StdCtrls, DBCtrls;

type
  TOnAfterToggle = procedure(Sender: TObject) of object;

  TNLDDBCheckBox = class(TDBCheckBox)
  private
    FUpdateRecordOnClick: Boolean;
    FOnAfterToggle: TOnAfterToggle;
    procedure SetUpdateRecordOnClick(const Value: Boolean);
  protected
    procedure Toggle; override;
  public
  published
    property UpdateRecordOnClick: Boolean read FUpdateRecordOnClick
      write SetUpdateRecordOnClick;

    property OnAfterToggle: TOnAfterToggle read FOnAfterToggle write FOnAfterToggle;

   end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('NLDelphi Database', [TNLDDBCheckBox]);
end;

{ TNLDDBCheckBox }

procedure TNLDDBCheckBox.SetUpdateRecordOnClick(const Value: Boolean);
begin
  FUpdateRecordOnClick := Value;
end;

procedure TNLDDBCheckBox.Toggle;
var
  DataLink: TFieldDataLink;
begin
  inherited;

  { Doe een updateRecord. Deze method is verantwoordelijk voor het zetten van de
    boolean waarde in het veld van de dataset. }
  if UpdateRecordOnClick then
  begin
    DataLink := TFieldDataLink(Perform(CM_GETDATALINK, 0, 0));
    DataLink.UpdateRecord;
  end;

  { We kunnen in dit event de waarde uit het veld opvragen. }
  if Assigned(FOnAfterToggle) then
    FOnAfterToggle(Self);
end;

end.
