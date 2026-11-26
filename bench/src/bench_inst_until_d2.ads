--  Derived by hand from generated/bench_inst_until.ads for formats/unsupported/bench_inst_until.ksy, where a field of
--  the instance `header` is the end of `entries`.  The instance is parsed once, at its first use, which is in the
--  first turn of the loop of Parse, and kept in the value; the accessor is a function that returns it (D2).

with Bench_Inst_Until;
with Kaitai.Streams;
with Kaitai.Types;

package Bench_Inst_Until_D2
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

   function Entries_Count (This : T) return Kaitai.Types.Length
   with Pre => Valid (This);

   function Header (This : T) return Bench_Inst_Until.Header_Obj_Type.T
   with Pre => Valid (This), Post => Bench_Inst_Until.Header_Obj_Type.Valid (Header'Result);

private

   type T is record
      Is_Valid   : Boolean := False;
      Io         : Kaitai.Streams.Stream;
      Entries    : Kaitai.Types.Slice;
      Has_Header : Boolean := False;
      Header     : Bench_Inst_Until.Header_Obj_Type.T;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid and then Bench_Inst_Until.Header_Obj_Type.Valid (This.Header));

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (This.Io, Buffer)
       and then Kaitai.Types.Within (This.Entries, Buffer)
       and then (not This.Has_Header or else Bench_Inst_Until.Header_Obj_Type.Belongs_To (This.Header, Buffer)));

   function Entries_Count (This : T) return Kaitai.Types.Length
   is (Kaitai.Types.Size (This.Entries) / 2);

   function Header (This : T) return Bench_Inst_Until.Header_Obj_Type.T
   is (This.Header);

end Bench_Inst_Until_D2;
