--  Derived by hand from generated/bench_rep_empty.ads: Get_Stop is Get_Items that stops at the first element that
--  reads nothing, since every element after it starts in the same state and reads nothing either.  Parse stops there
--  as well.

with Bench_Rep_Empty;
with Kaitai.Streams;
with Kaitai.Types;

package Rep_Empty
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.Length;

   type T is private;

   function Valid (This : T) return Boolean;

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
   with
     Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
     Post =>
       Kaitai.Streams.Is_Valid (S, Buffer)
       and then Kaitai.Streams.Advanced (S'Old, S)
       and then Valid (This) = Kaitai.Streams.OK (S)
       and then Belongs_To (This, Buffer);

   function Items_Count (This : T) return Kaitai.Types.Length
   with Pre => Valid (This);

   --  Parses the element with the number Index, counted from 0, and stops as soon as an element has read nothing
   procedure Get_Stop
     (Buffer : Kaitai.Types.Bytes; This : T; Index : Kaitai.Types.Length; Element : out Bench_Rep_Empty.Item_Type.T)
   with Pre => Valid (This) and then Belongs_To (This, Buffer) and then Index < Items_Count (This);

private

   type T is record
      Is_Valid    : Boolean := False;
      Flag        : Kaitai.Types.U8 := 0;
      Items_Io    : Kaitai.Streams.Stream;
      Items_Count : Kaitai.Types.Length := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (This.Items_Io, Buffer));

   function Items_Count (This : T) return Kaitai.Types.Length
   is (This.Items_Count);

end Rep_Empty;
