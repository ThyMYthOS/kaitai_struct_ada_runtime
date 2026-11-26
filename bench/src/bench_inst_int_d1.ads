--  Derived by hand from generated/bench_inst_int.ads for formats/unsupported/bench_inst_int.ksy, where the instance
--  `num_chunks` is the count of `chunks`.  It is parsed again at every use: in Parse, where the count needs it, and in
--  the accessor, as today (D1).

with Bench_Inst_Int;
with Kaitai.Streams;
with Kaitai.Types;

package Bench_Inst_Int_D1
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

   function Chunks_Count (This : T) return Kaitai.Types.Length
   with Pre => Valid (This);

   type Chunks_Cursor is private;

   function Belongs_To (Position : Chunks_Cursor; Buffer : Kaitai.Types.Bytes) return Boolean;

   function Chunks_First (This : T) return Chunks_Cursor
   with Pre => Valid (This);

   function Remaining (Position : Chunks_Cursor) return Kaitai.Types.Length;

   function Has_Element (Position : Chunks_Cursor) return Boolean
   is (Remaining (Position) > 0);

   procedure Next
     (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Chunks_Cursor; Element : out Bench_Inst_Int.Chunk_Type.T)
   with
     Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
     Post => Belongs_To (Position, Buffer) and then Remaining (Position) < Remaining (Position'Old);

   procedure Num_Chunks
     (Buffer : Kaitai.Types.Bytes; This : T; Result : out Kaitai.Types.U32; Outcome : out Kaitai.Types.Status_Kind)
   with Pre => Valid (This) and then Belongs_To (This, Buffer);

private

   type Chunks_Cursor is record
      Io   : Kaitai.Streams.Stream;
      Left : Kaitai.Types.Length := 0;
   end record;

   type T is record
      Is_Valid     : Boolean := False;
      Io           : Kaitai.Streams.Stream;
      Chunks_Io    : Kaitai.Streams.Stream;
      Chunks_Count : Kaitai.Types.Length := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (This.Io, Buffer) and then Kaitai.Streams.Is_Valid (This.Chunks_Io, Buffer));

   function Chunks_Count (This : T) return Kaitai.Types.Length
   is (This.Chunks_Count);

   function Belongs_To (Position : Chunks_Cursor; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (Position.Io, Buffer));

   function Chunks_First (This : T) return Chunks_Cursor
   is (Io => This.Chunks_Io, Left => This.Chunks_Count);

   function Remaining (Position : Chunks_Cursor) return Kaitai.Types.Length
   is (Position.Left);

end Bench_Inst_Int_D1;
