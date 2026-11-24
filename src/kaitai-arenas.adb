package body Kaitai.Arenas
  with SPARK_Mode
is

   function Open (Storage : Bytes) return Arena is
   begin
      if Storage'Length = 0 then
         return (First => 1, Last => 0, Next => 1);
      else
         return (First => Storage'First, Last => Storage'Last, Next => Storage'First);
      end if;
   end Open;

   procedure Reserve (A : in out Arena; Count : Length; Item : out Slice; OK : out Boolean) is
   begin
      if Count - 1 <= A.Last - A.Next then
         Item := (First => A.Next, Last => A.Next + (Count - 1));
         A.Next := A.Next + Count;
         OK := True;
      else
         Item := (First => 1, Last => 0);
         OK := False;
      end if;
   end Reserve;

   procedure Store (Storage : in out Bytes; A : in out Arena; Source : Bytes; Item : out Slice; OK : out Boolean) is
   begin
      Reserve (A, Source'Length, Item, OK);
      if OK and then Source'Length > 0 then
         Storage (Item.First .. Item.Last) := Source;
      end if;
   end Store;

   procedure Release (A : in out Arena; To : Length) is
   begin
      A.Next := A.First + To;
   end Release;

   procedure Reset (A : in out Arena) is
   begin
      A.Next := A.First;
   end Reset;

end Kaitai.Arenas;
