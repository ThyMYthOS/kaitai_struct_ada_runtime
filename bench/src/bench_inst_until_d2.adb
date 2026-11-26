with Kaitai.Types; use Kaitai.Types;

package body Bench_Inst_Until_D2
  with SPARK_Mode
is

   use Kaitai.Streams;

   --  The instance `header`: a header_obj at the position size - 6, parsed from a copy of Origin, so that Origin stays
   --  where it is
   procedure Read_Header
     (Buffer  : Kaitai.Types.Bytes;
      Origin  : Stream;
      Result  : out Bench_Inst_Until.Header_Obj_Type.T;
      Outcome : out Status_Kind)
   with
     Pre  => Is_Valid (Origin, Buffer),
     Post =>
       Bench_Inst_Until.Header_Obj_Type.Valid (Result) = (Outcome = Success)
       and then Bench_Inst_Until.Header_Obj_Type.Belongs_To (Result, Buffer)
   is
      L : Stream := Origin;
   begin
      Seek (L, To_Size (S64 (Size (L)) - 6));
      Bench_Inst_Until.Header_Obj_Type.Parse (Result, Buffer, L);
      Outcome := Status (L);
   end Read_Header;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      Start   : Kaitai.Streams.Stream;
      Done    : Boolean;
      Value   : Kaitai.Types.S16;
      Outcome : Status_Kind;
   begin
      This := (others => <>);
      This.Io := S;
      Start := S;
      Done := False;
      for I in 1 .. Remaining (S) + 1 loop
         Read_S2le (Buffer, S, Value);
         exit when not OK (S);
         if not This.Has_Header then
            Read_Header (Buffer, S, This.Header, Outcome);
            if Outcome /= Success then
               Fail (S, Outcome);
               exit;
            end if;
            This.Has_Header := True;
         end if;
         Done := S64 (Value) = S64 (Bench_Inst_Until.Header_Obj_Type.Limit (This.Header));
         exit when Done;
         pragma
           Loop_Invariant
             (Is_Valid (S, Buffer)
                and then Advanced (Start, S)
                and then not Done
                and then (if This.Has_Header then Bench_Inst_Until.Header_Obj_Type.Valid (This.Header))
                and then (not This.Has_Header
                          or else Bench_Inst_Until.Header_Obj_Type.Belongs_To (This.Header, Buffer)));
      end loop;
      if OK (S) and then not Done then
         Fail (S, Limit_Exceeded);
      end if;
      This.Entries := Between (Start, S);
      This.Is_Valid := OK (S);
   end Parse;

end Bench_Inst_Until_D2;
