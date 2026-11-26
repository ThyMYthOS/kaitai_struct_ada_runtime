with Kaitai.Types; use Kaitai.Types;

package body Bench_Inst_Int_D1
  with SPARK_Mode
is

   use Kaitai.Streams;

   --  The instance `num_chunks`: a u4 at the position size - 4, read from a copy of Origin, so that Origin stays where
   --  it is
   procedure Read_Num_Chunks
     (Buffer : Kaitai.Types.Bytes; Origin : Stream; Result : out Kaitai.Types.U32; Outcome : out Status_Kind)
   with Pre => Is_Valid (Origin, Buffer)
   is
      L : Stream := Origin;
   begin
      Seek (L, To_Size (S64 (Size (L)) - 4));
      Read_U4le (Buffer, L, Result);
      Outcome := Status (L);
   end Read_Num_Chunks;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      Element : Bench_Inst_Int.Chunk_Type.T;
      Count   : Kaitai.Types.U32;
      Outcome : Status_Kind;
   begin
      This.Io := S;
      Read_Num_Chunks (Buffer, S, Count, Outcome);
      if Outcome /= Success then
         Fail (S, Outcome);
      end if;
      This.Chunks_Io := S;
      This.Chunks_Count := To_Count (S64 (Count));
      for I in 1 .. This.Chunks_Count loop
         Bench_Inst_Int.Chunk_Type.Parse (Element, Buffer, S);
         exit when not Bench_Inst_Int.Chunk_Type.Valid (Element);
         pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
      end loop;
      This.Is_Valid := OK (S);
   end Parse;

   procedure Next
     (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Chunks_Cursor; Element : out Bench_Inst_Int.Chunk_Type.T)
   is
      pragma Unreferenced (This);
   begin
      Bench_Inst_Int.Chunk_Type.Parse (Element, Buffer, Position.Io);
      Position.Left := (if Bench_Inst_Int.Chunk_Type.Valid (Element) then Position.Left - 1 else 0);
   end Next;

   procedure Num_Chunks
     (Buffer : Kaitai.Types.Bytes; This : T; Result : out Kaitai.Types.U32; Outcome : out Kaitai.Types.Status_Kind) is
   begin
      Read_Num_Chunks (Buffer, This.Io, Result, Outcome);
   end Num_Chunks;

end Bench_Inst_Int_D1;
