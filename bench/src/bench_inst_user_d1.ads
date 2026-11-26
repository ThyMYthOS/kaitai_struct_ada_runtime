--  Derived by hand from generated/bench_inst_user.ads for formats/unsupported/bench_inst_user.ksy, where fields of the
--  instance `header` are the count of `numbers` and the end of `entries`.  The instance is parsed again at every use:
--  in Parse, and in the accessor, as today (D1).

with Bench_Inst_User;
with Kaitai.Streams;
with Kaitai.Types;

package Bench_Inst_User_D1
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.Length;
   use type Kaitai.Types.Status_Kind;

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

   function Numbers_Count (This : T) return Kaitai.Types.Length
   with Pre => Valid (This);

   function Entries_Count (This : T) return Kaitai.Types.Length
   with Pre => Valid (This);

   procedure Header
     (Buffer  : Kaitai.Types.Bytes;
      This    : T;
      Result  : out Bench_Inst_User.Header_Obj_Type.T;
      Outcome : out Kaitai.Types.Status_Kind)
   with
     Pre  => Valid (This) and then Belongs_To (This, Buffer),
     Post =>
       Bench_Inst_User.Header_Obj_Type.Valid (Result) = (Outcome = Kaitai.Types.Success)
       and then Bench_Inst_User.Header_Obj_Type.Belongs_To (Result, Buffer);

private

   type T is record
      Is_Valid : Boolean := False;
      Io       : Kaitai.Streams.Stream;
      Numbers  : Kaitai.Types.Slice;
      Entries  : Kaitai.Types.Slice;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (This.Io, Buffer)
       and then Kaitai.Types.Within (This.Numbers, Buffer)
       and then Kaitai.Types.Within (This.Entries, Buffer));

   function Numbers_Count (This : T) return Kaitai.Types.Length
   is (Kaitai.Types.Size (This.Numbers));

   function Entries_Count (This : T) return Kaitai.Types.Length
   is (Kaitai.Types.Size (This.Entries) / 2);

end Bench_Inst_User_D1;
