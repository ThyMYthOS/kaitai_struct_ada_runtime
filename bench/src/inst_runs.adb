with Bench_Inst_Int;
with Bench_Inst_Int_D1;
with Bench_Inst_Int_D2;
with Bench_Inst_Until;
with Bench_Inst_Until_D1;
with Bench_Inst_Until_D2;
with Bench_Inst_User;
with Bench_Inst_User_D1;
with Bench_Inst_User_D2;
with Kaitai.Streams; use Kaitai.Streams;

package body Inst_Runs
  with SPARK_Mode
is

   pragma Warnings (Off, "is set by * but not used after the call");

   Accesses : constant := 4;

   function Is_Access (V : Variant) return Boolean
   is (V in Int_D1_Access | Int_D2_Access | User_D1_Access | User_D2_Access | Until_D1_Access | Until_D2_Access);

   ---------------------------------------------------------------------
   --  One record
   ---------------------------------------------------------------------

   function Int_D1 (Data : Bytes; Item : Slice; With_Access : Boolean) return U64 with Pre => Within (Item, Data) is
      use Bench_Inst_Int_D1;
      S        : Stream := Open (Data, Item);
      This     : T;
      Position : Chunks_Cursor;
      Element  : Bench_Inst_Int.Chunk_Type.T;
      Value    : U32;
      Outcome  : Status_Kind;
      Sum      : U64;
   begin
      Parse (Data, S, This);
      if not Valid (This) then
         return 0;
      end if;
      Sum := U64 (Chunks_Count (This));
      Position := Chunks_First (This);
      while Has_Element (Position) loop
         pragma Loop_Invariant (Belongs_To (Position, Data));
         pragma Loop_Variant (Decreases => Remaining (Position));
         Next (Data, This, Position, Element);
         exit when not Bench_Inst_Int.Chunk_Type.Valid (Element);
         Sum := Sum + U64 (Bench_Inst_Int.Chunk_Type.Offset (Element)) + U64 (Bench_Inst_Int.Chunk_Type.Len (Element));
      end loop;
      if With_Access then
         for A in 1 .. Accesses loop
            Num_Chunks (Data, This, Value, Outcome);
            if Outcome = Success then
               Sum := Sum + U64 (Value);
            end if;
         end loop;
      end if;
      return Sum;
   end Int_D1;

   function Int_D2 (Data : Bytes; Item : Slice; With_Access : Boolean) return U64 with Pre => Within (Item, Data) is
      use Bench_Inst_Int_D2;
      S        : Stream := Open (Data, Item);
      This     : T;
      Position : Chunks_Cursor;
      Element  : Bench_Inst_Int.Chunk_Type.T;
      Sum      : U64;
   begin
      Parse (Data, S, This);
      if not Valid (This) then
         return 0;
      end if;
      Sum := U64 (Chunks_Count (This));
      Position := Chunks_First (This);
      while Has_Element (Position) loop
         pragma Loop_Invariant (Belongs_To (Position, Data));
         pragma Loop_Variant (Decreases => Remaining (Position));
         Next (Data, This, Position, Element);
         exit when not Bench_Inst_Int.Chunk_Type.Valid (Element);
         Sum := Sum + U64 (Bench_Inst_Int.Chunk_Type.Offset (Element)) + U64 (Bench_Inst_Int.Chunk_Type.Len (Element));
      end loop;
      if With_Access then
         for A in 1 .. Accesses loop
            Sum := Sum + U64 (Num_Chunks (This));
         end loop;
      end if;
      return Sum;
   end Int_D2;

   function User_D1 (Data : Bytes; Item : Slice; With_Access : Boolean) return U64 with Pre => Within (Item, Data) is
      use Bench_Inst_User_D1;
      S       : Stream := Open (Data, Item);
      This    : T;
      Result  : Bench_Inst_User.Header_Obj_Type.T;
      Outcome : Status_Kind;
      Sum     : U64;
   begin
      Parse (Data, S, This);
      if not Valid (This) then
         return 0;
      end if;
      Sum := U64 (Numbers_Count (This)) + U64 (Entries_Count (This));
      if With_Access then
         for A in 1 .. Accesses loop
            Header (Data, This, Result, Outcome);
            if Outcome = Success then
               Sum := Sum + U64 (Bench_Inst_User.Header_Obj_Type.Qty (Result));
            end if;
         end loop;
      end if;
      return Sum;
   end User_D1;

   function User_D2 (Data : Bytes; Item : Slice; With_Access : Boolean) return U64 with Pre => Within (Item, Data) is
      use Bench_Inst_User_D2;
      S    : Stream := Open (Data, Item);
      This : T;
      Sum  : U64;
   begin
      Parse (Data, S, This);
      if not Valid (This) then
         return 0;
      end if;
      Sum := U64 (Numbers_Count (This)) + U64 (Entries_Count (This));
      if With_Access then
         for A in 1 .. Accesses loop
            Sum := Sum + U64 (Bench_Inst_User.Header_Obj_Type.Qty (Header (This)));
         end loop;
      end if;
      return Sum;
   end User_D2;

   function Until_D1 (Data : Bytes; Item : Slice; With_Access : Boolean) return U64 with Pre => Within (Item, Data) is
      use Bench_Inst_Until_D1;
      S       : Stream := Open (Data, Item);
      This    : T;
      Result  : Bench_Inst_Until.Header_Obj_Type.T;
      Outcome : Status_Kind;
      Sum     : U64;
   begin
      Parse (Data, S, This);
      if not Valid (This) then
         return 0;
      end if;
      Sum := U64 (Entries_Count (This));
      if With_Access then
         for A in 1 .. Accesses loop
            Header (Data, This, Result, Outcome);
            if Outcome = Success then
               Sum := Sum + U64 (Bench_Inst_Until.Header_Obj_Type.Qty (Result));
            end if;
         end loop;
      end if;
      return Sum;
   end Until_D1;

   function Until_D2 (Data : Bytes; Item : Slice; With_Access : Boolean) return U64 with Pre => Within (Item, Data) is
      use Bench_Inst_Until_D2;
      S    : Stream := Open (Data, Item);
      This : T;
      Sum  : U64;
   begin
      Parse (Data, S, This);
      if not Valid (This) then
         return 0;
      end if;
      Sum := U64 (Entries_Count (This));
      if With_Access then
         for A in 1 .. Accesses loop
            Sum := Sum + U64 (Bench_Inst_Until.Header_Obj_Type.Qty (Header (This)));
         end loop;
      end if;
      return Sum;
   end Until_D2;

   ---------------------------------------------------------------------
   --  All records
   ---------------------------------------------------------------------

   function Run (V : Variant; Data : Bytes) return U64 is
      Size : constant Length := Record_Size (Layout_Of (V));
      Sum  : U64 := 0;
   begin
      if Data'Length = 0 or else Data'Last < Size then
         return 0;
      end if;
      declare
         Pos  : Length := Data'First;
         Item : Slice;
      begin
         while Pos <= Data'Last - (Size - 1) loop
            pragma Loop_Invariant (Pos >= Data'First);
            pragma Loop_Variant (Increases => Pos);
            Item := (First => Pos, Last => Pos + (Size - 1));
            Sum :=
              Sum
              * 31
              + (case V is
                   when Int_D1_Parse | Int_D1_Access     => Int_D1 (Data, Item, Is_Access (V)),
                   when Int_D2_Parse | Int_D2_Access     => Int_D2 (Data, Item, Is_Access (V)),
                   when User_D1_Parse | User_D1_Access   => User_D1 (Data, Item, Is_Access (V)),
                   when User_D2_Parse | User_D2_Access   => User_D2 (Data, Item, Is_Access (V)),
                   when Until_D1_Parse | Until_D1_Access => Until_D1 (Data, Item, Is_Access (V)),
                   when Until_D2_Parse | Until_D2_Access => Until_D2 (Data, Item, Is_Access (V)));
            Pos := Pos + Size;
         end loop;
      end;
      return Sum;
   end Run;

end Inst_Runs;
