with Kaitai.Types; use Kaitai.Types;

package body Rep_Empty
  with SPARK_Mode
is

   use Kaitai.Streams;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      Element : Bench_Rep_Empty.Item_Type.T;
      Before  : Kaitai.Streams.Stream;
      Count   : U32;
   begin
      Read_U4le (Buffer, S, Count);
      Read_U1 (Buffer, S, This.Flag);
      This.Items_Io := S;
      This.Items_Count := To_Count (S64 (Count));
      for I in 1 .. This.Items_Count loop
         Before := S;
         Bench_Rep_Empty.Item_Type.Parse (Element, Buffer, S, This.Flag);
         exit when not Bench_Rep_Empty.Item_Type.Valid (Element);
         exit when Pos (S) = Pos (Before) and then Bits_Left (S) = Bits_Left (Before);
         pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
      end loop;
      This.Is_Valid := OK (S);
   end Parse;

   procedure Get_Stop
     (Buffer : Kaitai.Types.Bytes; This : T; Index : Kaitai.Types.Length; Element : out Bench_Rep_Empty.Item_Type.T)
   is
      L      : Kaitai.Streams.Stream := This.Items_Io;
      Before : Kaitai.Streams.Stream;
      Result : Bench_Rep_Empty.Item_Type.T;
   begin
      for I in 0 .. Index loop
         pragma Loop_Invariant (Is_Valid (L, Buffer));
         Before := L;
         Bench_Rep_Empty.Item_Type.Parse (Result, Buffer, L, This.Flag);
         exit when not Bench_Rep_Empty.Item_Type.Valid (Result);
         exit when Pos (L) = Pos (Before) and then Bits_Left (L) = Bits_Left (Before);
      end loop;
      Element := Result;
   end Get_Stop;

end Rep_Empty;
