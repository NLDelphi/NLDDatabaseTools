unit INLDClientDataSetU;

interface

uses
  Classes;

type
  TSortOrder = (soAsc, soDesc);
  
type
  INLDClientDataSet = interface
  ['{AFF194F4-74FA-4564-9ED8-DE8F70DAF3BF}']
  procedure Sort(SortFieldName: string);
  function GetSortOrder: TSortOrder;
  end;

implementation

end.
