unit MemVector;

interface

uses
  Classes, AuxTypes;

type
  TMemVector = class(TObject)
  private
    fItemSize:    Integer;
    fMemory:      Pointer;
    fOwnsMemory:  Boolean;
    fCapacity:    Integer;
    fCount:       Integer;
    fChanging:    Integer;
    fChanged:     Boolean;
    fOnChange:    TNotifyEvent;
  protected
    fTempItem:    Pointer;
    Function GetItemPtr(Index: Integer): Pointer; virtual;
    procedure SetItemPtr(Index: Integer; Value: Pointer); virtual;
    procedure GetItem; virtual; abstract;
    procedure SetItem; virtual; abstract;
    Function CheckIndex(Index: Integer; RaiseException: Boolean = False; MethodName: String = 'CheckIndex'): Boolean; virtual;
    Function GetNextItemPtr(ItemPtr: Pointer): Pointer; virtual;
    procedure SetCapacity(Value: Integer); virtual;
    procedure SetCount(Value: Integer); virtual;
    Function GetSize: TMemSize; virtual;
    Function GetAllocatedSize: TMemSize; virtual;
    procedure ItemInit(ItemPtr: Pointer); virtual;
    procedure ItemFinal(ItemPtr: Pointer); virtual;
    procedure ItemCopy(SrcItem,DstItem: Pointer); virtual;
    Function ItemCompare(Item1,Item2: Pointer): Integer; virtual;
    Function ItemEqual(Item1,Item2: Pointer): Boolean; virtual;
    procedure FinalizeAllItems; virtual;
    procedure DoOnChange; virtual;
  public
    constructor Create(ItemSize: Integer);
    destructor Destroy; override;
    procedure BeginChanging; virtual;
    Function EndChanging: Integer; virtual;
    Function LowIndex: Integer; virtual;
    Function HighIndex: Integer; virtual;
    Function Firts: Pointer; virtual;
    Function Last: Pointer; virtual;
    Function Grow(Force: Boolean = False): Integer; virtual;
    Function Shrink: Integer; virtual;
    Function IndexOf(Item: Pointer): Integer; virtual;
    Function Add(Item: Pointer): Integer; virtual;
    procedure Insert(Index: Integer; Item: Pointer); virtual;
    Function Remove(Item: Pointer): Integer; virtual;
    Function Extract(Item: Pointer): Pointer; virtual;
    procedure Delete(Index: Integer); virtual;
    procedure Move(SrcIndex,DstIndex: Integer); virtual;
    procedure Exchange(Index1,Index2: Integer); virtual;
    procedure Reverse; virtual;
    procedure Clear; virtual;
    procedure Sort(Reversed: Boolean = False); virtual;
    Function Equals(Vector: TMemVector): Boolean; virtual;
    Function EqualsBinary(Vector: TMemVector): Boolean; virtual;
    procedure Assign(Data: Pointer; Count: Integer; AsCopy: Boolean = False); overload; virtual;
    procedure Assign(Vector: TMemVector; AsCopy: Boolean = False); overload; virtual;
    procedure Append(Data: Pointer; Count: Integer; AsCopy: Boolean = False); overload; virtual;
    procedure Append(Vector: TMemVector; AsCopy: Boolean = False); overload; virtual;
    procedure SaveToStream(Stream: TStream); virtual;
    procedure LoadFromStream(Stream: TStream); virtual;
    procedure SaveToFile(const FileName: String); virtual;
    procedure LoadFromFile(const FileName: String); virtual;  
    property Memory: Pointer read fMemory;
    property Pointers[Index: Integer]: Pointer read GetItemPtr;
  published
    property ItemSize: Integer read fItemSize;
    property OwnsMemory: Boolean read fOwnsMemory write fOwnsMemory;
    property Capacity: Integer read fCapacity write SetCapacity;
    property Count: Integer read fCount write SetCount; 
    property Size: TMemSize read GetSize;
    property AllocatedSize: TMemSize read GetAllocatedSize;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
  end;

implementation

uses
  SysUtils;

Function TMemVector.GetItemPtr(Index: Integer): Pointer;
begin
If CheckIndex(Index) then
  Result := Pointer(PtrUInt(fMemory) + PtrUInt(Index * fItemSize))
else
  raise Exception.CreateFmt('TMemVector.GetItemBase: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TMemVector.SetItemPtr(Index: Integer; Value: Pointer);
begin
end;

//------------------------------------------------------------------------------

Function TMemVector.CheckIndex(Index: Integer; RaiseException: Boolean = False; MethodName: String = 'CheckIndex'): Boolean;
begin
Result := (Index >= 0) and (Index < fCount);
If not Result and RaiseException then
  raise Exception.CreateFmt('TMemVector.%s: Index (%d) out of bounds.',[MethodName,Index]);
end;

//------------------------------------------------------------------------------

Function TMemVector.GetNextItemPtr(ItemPtr: Pointer): Pointer;
begin
Result := Pointer(PtrUInt(ItemPtr) + PtrUInt(fItemSize));
end;

//------------------------------------------------------------------------------

procedure TMemVector.SetCapacity(Value: Integer);
var
  i:  Integer;
begin
If fOwnsMemory then
  begin
    If (Value <> fCapacity) and (Value >= 0) then
      begin
        If Value < fCount then
          For i := Value to Pred(fCount) do ItemFinal(GetItemPtr(i));
        ReallocMem(fMemory,TMemSize(Value) * TMemSize(fItemSize));
        fCapacity := Value;
        DoOnChange;
      end;
  end
else raise Exception.Create('TMemVector.SetCapacity: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.SetCount(Value: Integer);
var
  OldCount: Integer;
  i:        Integer;
begin
If fOwnsMemory then
  begin
    If (Value <> fCount) and (Value >= 0) then
      begin
        BeginChanging;
        try
          If Value > fCapacity then SetCapacity(Value);
          If Value > fCount then
            begin
              OldCount := fCount;
              fCount := Value;
              For i := OldCount to Pred(fCount) do
                ItemInit(GetItemPtr(i));
            end
          else
            begin
              For i := Pred(fCount) downto Value do
                ItemFinal(GetItemPtr(i));
              fCount := Value;
            end;
          DoOnChange;
        finally
          EndChanging;
        end;
      end;
  end
else raise Exception.Create('TMemVector.SetCount: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

Function TMemVector.GetSize: TMemSize;
begin
Result := TMemSize(fCount) * TMemSize(fItemSize);
end;

//------------------------------------------------------------------------------

Function TMemVector.GetAllocatedSize: TMemSize;
begin
Result := TMemSize(fCapacity) * TMemSize(fItemSize); 
end;

//------------------------------------------------------------------------------

procedure TMemVector.ItemInit(ItemPtr: Pointer);
begin
FillChar(ItemPtr^,fItemSize,0);
end;

//------------------------------------------------------------------------------

procedure TMemVector.ItemFinal(ItemPtr: Pointer);
begin
// nothing to do here
end;

//------------------------------------------------------------------------------

procedure TMemVector.ItemCopy(SrcItem,DstItem: Pointer);
begin
System.Move(SrcItem^,DstItem^,fItemSize);
end;

//------------------------------------------------------------------------------

Function TMemVector.ItemCompare(Item1,Item2: Pointer): Integer;
begin
Result := Integer(PtrInt(Item2) - PtrInt(Item1));
end;

//------------------------------------------------------------------------------

Function TMemVector.ItemEqual(Item1,Item2: Pointer): Boolean;
begin
Result := ItemCompare(Item1,Item2) = 0;
end;

//------------------------------------------------------------------------------

procedure TMemVector.FinalizeAllItems;
var
  i:  Integer;
begin
For i := 0 to Pred(fCount) do
  ItemFinal(GetItemPtr(i));
end;

//------------------------------------------------------------------------------

procedure TMemVector.DoOnChange;
begin
fChanged := True;
If (fChanging <= 0) and Assigned(fOnChange) then fOnChange(Self);
end;

//==============================================================================

constructor TMemVector.Create(ItemSize: Integer);
begin
inherited Create;
If ItemSize <= 0 then
  raise Exception.Create('TMemVector.Create: Size of the item must be larger than zero.');
fItemSize := ItemSize;
fMemory := nil;
fOwnsMemory := False;
fCapacity := 0;
fCount := 0;
fChanging := 0;
fChanged := False;
GetMem(fTempItem,ItemSize);
end;

//------------------------------------------------------------------------------

destructor TMemVector.Destroy;
begin
FreeMem(fTempItem,fItemSize);
If fOwnsMemory then
  begin
    FinalizeAllItems;
    FreeMem(fMemory,TMemSize(fCapacity) * TMemSize(fItemSize));
  end;
inherited;
end;

//------------------------------------------------------------------------------

procedure TMemVector.BeginChanging;
begin
If fChanging <= 0 then fChanged := False;
Inc(fChanging);
end;

//------------------------------------------------------------------------------

Function TMemVector.EndChanging: Integer;
begin
Dec(fChanging);
If fChanging <= 0 then
  begin
    fChanging := 0;
    If fChanged and Assigned(fOnChange) then fOnChange(Self);
  end;
Result := fChanging;  
end;

//------------------------------------------------------------------------------

Function TMemVector.LowIndex: Integer;
begin
Result := 0;
end;

//------------------------------------------------------------------------------

Function TMemVector.HighIndex: Integer;
begin
Result := fCount - 1;
end;

//------------------------------------------------------------------------------

Function TMemVector.Firts: Pointer;
begin
Result := GetItemPtr(LowIndex);
end;

//------------------------------------------------------------------------------

Function TMemVector.Last: Pointer;
begin
Result := GetItemPtr(HighIndex);
end;

//------------------------------------------------------------------------------

Function TMemVector.Grow(Force: Boolean = False): Integer;
var
  Delta:  Integer;
begin
If Force then
  begin
    If fCapacity <= 256 then Delta := 32
      else Delta := ((fCapacity div 4) or $F) + 1;
    SetCapacity(fCapacity + Delta);
    Result := fCapacity
  end
else
  begin
    If fCount >= fCapacity then
      Result := Grow(True)
    else
      Result := fCapacity;
  end;
end;

//------------------------------------------------------------------------------

Function TMemVector.Shrink: Integer;
begin
SetCapacity(fCount);
Result := fCapacity;
end;

//------------------------------------------------------------------------------

Function TMemVector.IndexOf(Item: Pointer): Integer;
begin
For Result := 0 to Pred(fCount) do
  If ItemEqual(Item,GetItemPtr(Result)) then Exit;
Result := -1;
end;
 
//------------------------------------------------------------------------------

Function TMemVector.Add(Item: Pointer): Integer;
begin
If fOwnsMemory then
  begin
    Grow;
    Inc(fCount);
    System.Move(Item^,GetItemPtr(Pred(fCount))^,fItemSize);
    Result := fCount;
    DoOnChange;
  end
else raise Exception.Create('TMemVector.Add: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.Insert(Index: Integer; Item: Pointer);
var
  InsertPtr:  Pointer;
begin
If fOwnsMemory then
  begin
    If CheckIndex(Index) then
      begin
        Grow;
        InsertPtr := GetItemPtr(Index);
        System.Move(InsertPtr^,GetNextItemPtr(InsertPtr)^,fItemSize * (fCount - Index));
        System.Move(Item^,InsertPtr^,fItemSize);
        Inc(fCount);
        DoOnChange;
      end
    else
      begin
        If Index >= fCount then Add(Item)
         else raise Exception.CreateFmt('TMemVector.Insert: Index (%d) out of bounds.',[Index]);
      end;
  end
else raise Exception.Create('TMemVector.Add: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

Function TMemVector.Remove(Item: Pointer): Integer;
begin
If fOwnsMemory then
  begin
    Result := IndexOf(Item);
    If Result >= 0 then Delete(Result);
  end
else raise Exception.Create('TMemVector.Remove: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

Function TMemVector.Extract(Item: Pointer): Pointer;
var
  Index:  Integer;
begin
If fOwnsMemory then
  begin
    Index := IndexOf(Item);
    If Index >= 0 then
      begin
        System.Move(GetItemPtr(Index)^,fTempItem^,fItemSize);
        Delete(Index);
        Result := fTempItem;
      end
    else raise Exception.Create('TMemVector.Extract: Requested item not found.');
  end
else raise Exception.Create('TMemVector.Extract: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.Delete(Index: Integer);
var
  DeletePtr: Pointer;
begin
If fOwnsMemory then
  begin
    If CheckIndex(Index) then
      begin
        DeletePtr := GetItemPtr(Index);
        ItemFinal(DeletePtr);
        If Index < Pred(fCount) then
          System.Move(GetNextItemPtr(DeletePtr)^,DeletePtr^,fItemSize * Pred(fCount - Index));
        Dec(fCount);
        DoOnChange;
      end
    else raise Exception.CreateFmt('TMemVector.Delete: Index (%d) out of bounds.',[Index]);
  end
else raise Exception.Create('TMemVector.Delete: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.Move(SrcIndex,DstIndex: Integer);
var
  SrcPtr: Pointer;
  DstPtr: Pointer;
begin
If CheckIndex(SrcIndex,True,'Move') and CheckIndex(DstIndex,True,'Move') then
  If SrcIndex <> DstIndex then
    begin
      SrcPtr := GetItemPtr(SrcIndex);
      DstPtr := GetItemPtr(DstIndex);
      System.Move(SrcPtr^,fTempItem^,fItemSize);
      If SrcIndex < DstIndex then
        System.Move(GetNextItemPtr(SrcPtr)^,SrcPtr^,fItemSize * (DstIndex - SrcIndex))
      else
        System.Move(DstPtr^,GetNextItemPtr(DstPtr)^,fItemSize * (SrcIndex - DstIndex));
      System.Move(fTempItem^,DstPtr^,fItemSize);
      DoOnChange;
    end;
end;

//------------------------------------------------------------------------------

procedure TMemVector.Exchange(Index1,Index2: Integer);
var
  Idx1Ptr:  Pointer;
  Idx2Ptr:  Pointer;
begin
If CheckIndex(Index1,True,'Move') and CheckIndex(Index2,True,'Move') then
  If Index1 <> Index2 then
    begin
      Idx1Ptr := GetItemPtr(Index1);
      Idx2Ptr := GetItemPtr(Index2);
      System.Move(Idx1Ptr^,fTempItem^,fItemSize);
      System.Move(Idx2Ptr^,Idx1Ptr^,fItemSize);
      System.Move(fTempItem^,Idx2Ptr^,fItemSize);
      DoOnChange;
    end;
end;

//------------------------------------------------------------------------------

procedure TMemVector.Reverse;
var
  i:  Integer;
begin
If fCount > 1 then
  begin
    BeginChanging;
    try
      For i := 0 to Pred(fCount shr 1) do
        Exchange(i,Pred(fCount - i));
      DoOnChange;
    finally
      EndChanging;
    end;
  end;
end;

//------------------------------------------------------------------------------

procedure TMemVector.Clear;
begin
If fOwnsMemory then
  begin
    FinalizeAllItems;
    fCount := 0;
    DoOnChange;
  end
else raise Exception.Create('TMemVector.Clear: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.Sort(Reversed: Boolean = False);

  procedure QuickSort(Left,Right: Integer; Coef: Integer);
  var
    Pivot:  Pointer;
    Idx,i:  Integer;
  begin
    If Left < right  then
      begin
        Exchange((Left + Right) shr 1,Right);
        Pivot := GetItemPtr(Right);
        Idx := Left;
        For i := Left to Pred(Right) do
          If (ItemCompare(GetItemPtr(i),Pivot) * Coef) < 0 then
            begin
              Exchange(i,idx);
              Inc(Idx);
            end;
        Exchange(Idx,Right);
        QuickSort(Left,Idx - 1,Coef);
        QuickSort(Idx + 1, Right,Coef);
      end;
  end;

begin
If fCount > 1 then
  begin
    BeginChanging;
    try
      If Reversed then QuickSort(0,Pred(fCount),-1)
        else QuickSort(0,Pred(fCount),0);
       DoOnChange; 
    finally
      EndChanging;
    end;
  end;
end;

//------------------------------------------------------------------------------

Function TMemVector.Equals(Vector: TMemVector): Boolean;
var
  i:  Integer;
begin
Result := False;
If Vector is Self.ClassType then
  begin
    If Vector.Count = fCount then
      begin
        For i := 0 to Pred(fCount) do
          If not ItemEqual(GetItemPtr(i),Vector.Pointers[i]) then Exit;
        Result := True;  
      end;
  end
else raise Exception.CreateFmt('TMemVector.Equals: Object is of incompatible class (%s).',[Vector.ClassName]);
end;

//------------------------------------------------------------------------------

Function TMemVector.EqualsBinary(Vector: TMemVector): Boolean;
var
  i:  PtrUInt;
begin
Result := False;
If Size = Vector.Size then
  begin
    For i := 0 to Pred(Size) do
      If PByte(PtrUInt(fMemory) + i)^ <> PByte(PtrUInt(Vector.Memory) + i)^ then Exit;
    Result := True;
  end;
end;

//------------------------------------------------------------------------------

procedure TMemVector.Assign(Data: Pointer; Count: Integer; AsCopy: Boolean = False);
var
  i:  Integer;
begin
If fOwnsMemory then
  begin
    BeginChanging;
    try
      SetCapacity(Count);
      fCount := Count;
      FinalizeAllItems;      
      If AsCopy then
        For i := 0 to Pred(Count) do
          ItemCopy(Pointer(PtrUInt(Data) + PtrUInt(i * fItemSize)),GetItemPtr(i))
      else
        System.Move(Data^,fMemory^,Count * fItemSize);
      DoOnChange;
    finally
      EndChanging;
    end;
  end
else raise Exception.Create('TMemVector.Assign: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.Assign(Vector: TMemVector; AsCopy: Boolean = False);
begin
If fOwnsMemory then
  begin
    If Vector is Self.ClassType then
      Assign(Vector.Memory,Vector.Count,AsCopy)
    else
      raise Exception.CreateFmt('TMemVector.Assign: Object is of incompatible class (%s).',[Vector.ClassName]);
  end
else raise Exception.Create('TMemVector.Assign: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.Append(Data: Pointer; Count: Integer; AsCopy: Boolean = False);
var
  i:  Integer;
begin
If fOwnsMemory then
  begin
    BeginChanging;
    try
      If (fCount + Count) > fCapacity then
        SetCapacity(fCount + Count);
      fCount := fCount + Count;
      If AsCopy then
        For i := 0 to Pred(Count) do
          ItemCopy(Pointer(PtrUInt(Data) + PtrUInt(i * fItemSize)),GetItemPtr((fCount - Count) + i))
      else
        System.Move(Data^,GetItemPtr(fCount - Count)^,Count * fItemSize);
      DoOnChange;
    finally
      EndChanging;
    end;
  end
else raise Exception.Create('TMemVector.Assign: Operation not allowed for not owned memory.');    
end;

//------------------------------------------------------------------------------

procedure TMemVector.Append(Vector: TMemVector; AsCopy: Boolean = False);
begin
If fOwnsMemory then
  begin
    If Vector is Self.ClassType then
      Append(Vector.Memory,Vector.Count,AsCopy)
    else
      raise Exception.CreateFmt('TMemVector.Append: Object is of incompatible class (%s).',[Vector.ClassName]);
  end
else raise Exception.Create('TMemVector.Append: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.SaveToStream(Stream: TStream);
begin
Stream.WriteBuffer(fMemory^,fCount * fItemSize);
end;

//------------------------------------------------------------------------------

procedure TMemVector.LoadFromStream(Stream: TStream);
begin
If fOwnsMemory then
  begin
    BeginChanging;
    try
      SetCapacity(Integer((Stream.Size - Stream.Position) div fItemSize));
      fCount := fCapacity;
      FinalizeAllItems;      
      Stream.ReadBuffer(fMemory^,fCount * fItemSize);
      DoOnChange;
    finally
      EndChanging;
    end;
  end
else raise Exception.Create('LoadFromStream: Operation not allowed for not owned memory.');
end;

//------------------------------------------------------------------------------

procedure TMemVector.SaveToFile(const FileName: String);
var
  FileStream: TFileStream;
begin
FileStream := TFileStream.Create(FileName,fmCreate or fmShareExclusive);
try
  SaveToStream(FileStream);
finally
  FileStream.Free;
end;
end;

//------------------------------------------------------------------------------

procedure TMemVector.LoadFromFile(const FileName: String);
var
  FileStream: TFileStream;
begin
FileStream := TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
try
  LoadFromStream(FileStream);
finally
  FileStream.Free;
end;
end;

end.
