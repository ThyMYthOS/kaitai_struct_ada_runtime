with Kaitai.Types; use Kaitai.Types;

package body Bench_Inst_User_D1
  with SPARK_Mode
is

   use Kaitai.Streams;

   --  The instance `header`: a header_obj at the position size - 6, parsed from a copy of Origin, so that Origin stays
   --  where it is
   procedure Read_Header
     (Buffer  : Kaitai.Types.Bytes;
      Origin  : Stream;
      Result  : out Bench_Inst_User.Header_Obj_Type.T;
      Outcome : out Status_Kind)
   with
     Pre  => Is_Valid (Origin, Buffer),
     Post =>
       Bench_Inst_User.Header_Obj_Type.Valid (Result) = (Outcome = Success)
       and then Bench_Inst_User.Header_Obj_Type.Belongs_To (Result, Buffer)
   is
      L : Stream := Origin;
   begin
      Seek (L, To_Size (S64 (Size (L)) - 6));
      Bench_Inst_User.Header_Obj_Type.Parse (Buffer, L, Result);
      Outcome := Status (L);
   end Read_Header;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      Start   : Kaitai.Streams.Stream;
      Done    : Boolean;
      Value   : Kaitai.Types.S16;
      Outcome : Status_Kind;
      Header  : Bench_Inst_User.Header_Obj_Type.T;
   begin
      This := (others => <>);
      This.Io := S;
      Read_Header (Buffer, S, Header, Outcome);
      if Outcome = Success then
         Read_Elements (S, To_Count (S64 (Bench_Inst_User.Header_Obj_Type.Qty (Header))), 1, This.Numbers);
      else
         Fail (S, Outcome);
      end if;
      Start := S;
      Done := False;
      for I in 1 .. Remaining (S) + 1 loop
         Read_S2le (Buffer, S, Value);
         exit when not OK (S);
         Read_Header (Buffer, S, Header, Outcome);
         if Outcome /= Success then
            Fail (S, Outcome);
            exit;
         end if;
         Done := S64 (Value) = S64 (Bench_Inst_User.Header_Obj_Type.Limit (Header));
         exit when Done;
         pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (Start, S) and then not Done);
      end loop;
      if OK (S) and then not Done then
         Fail (S, Limit_Exceeded);
      end if;
      This.Entries := Between (Start, S);
      This.Is_Valid := OK (S);
   end Parse;

   procedure Header
     (Buffer  : Kaitai.Types.Bytes;
      This    : T;
      Result  : out Bench_Inst_User.Header_Obj_Type.T;
      Outcome : out Kaitai.Types.Status_Kind) is
   begin
      Read_Header (Buffer, This.Io, Result, Outcome);
   end Header;

end Bench_Inst_User_D1;
