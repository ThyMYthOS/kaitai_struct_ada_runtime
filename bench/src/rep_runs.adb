with Bench_Rep;
with Bench_Rep_Empty;
with Bench_Rep_Fixed;
with Kaitai.Streams; use Kaitai.Streams;
with Rep_Empty;
with Rep_Use;

package body Rep_Runs
  with SPARK_Mode
is

   pragma Warnings (Off, "is set by * but not used after the call");

   --  What the checksum takes from an element
   function Mix (Element : Bench_Rep.Item_Type.T) return U64
   is (U64 (Bench_Rep.Item_Type.Len (Element))
       + 3 * U64 (Bench_Rep.Item_Type.V (Element))
       + U64 (Size (Bench_Rep.Item_Type.Name (Element))))
   with Pre => Bench_Rep.Item_Type.Valid (Element);

   ---------------------------------------------------------------------
   --  The generated Bench_Rep: Parse, Next, Get_Items
   ---------------------------------------------------------------------

   function Run_Access (V : Variant; Data : Bytes) return U64 is
      S        : Kaitai.Streams.Stream := Open (Data);
      This     : Bench_Rep.T;
      Element  : Bench_Rep.Item_Type.T;
      Position : Bench_Rep.Items_Cursor;
      Sum      : U64;
   begin
      Bench_Rep.Parse (This, Data, S);
      if not Bench_Rep.Valid (This) then
         return 0;
      end if;
      declare
         Count : constant Length := Bench_Rep.Items_Count (This);
      begin
         Sum := U64 (Count);
         case V is
            when A_Get_First | A_Get_Mid | A_Get_Last =>
               if Count > 0 then
                  Bench_Rep.Get_Items
                    (This,
                     Data,
                     (case V is
                        when A_Get_First => 0,
                        when A_Get_Mid   => Count / 2,
                        when others      => Count - 1),
                     Element);
                  if Bench_Rep.Item_Type.Valid (Element) then
                     Sum := Sum + Mix (Element);
                  end if;
               end if;

            when A_Next_All                           =>
               Position := Bench_Rep.Items_First (This);
               while Bench_Rep.Has_Element (Position) loop
                  pragma Loop_Invariant (Bench_Rep.Belongs_To (Position, Data));
                  pragma Loop_Variant (Decreases => Bench_Rep.Remaining (Position));
                  Bench_Rep.Next (This, Data, Position, Element);
                  exit when not Bench_Rep.Item_Type.Valid (Element);
                  Sum := Sum + Mix (Element);
               end loop;

            when A_Get_All                            =>
               for I in 0 .. Count - 1 loop
                  Bench_Rep.Get_Items (This, Data, I, Element);
                  exit when not Bench_Rep.Item_Type.Valid (Element);
                  Sum := Sum + Mix (Element);
               end loop;

            when others                               =>
               null;
         end case;
      end;
      return Sum;
   end Run_Access;

   ---------------------------------------------------------------------
   --  items[idx] in the elements of another repetition
   ---------------------------------------------------------------------

   function Run_Index (V : Variant; Data : Bytes) return U64 is
      S     : Kaitai.Streams.Stream := Open (Data);
      Head  : Bench_Rep.T;
      Fixed : Bench_Rep_Fixed.T;
      Num   : U32;
      Ref   : Rep_Use.Ref_Type.T;
      Sum   : U64 := 0;
   begin
      if V in Index_Fixed | Index_Fixed_Mod then
         Bench_Rep_Fixed.Parse (Fixed, Data, S);
      else
         Bench_Rep.Parse (Head, Data, S);
      end if;
      Read_U4le (Data, S, Num);
      if not OK (S) then
         return 0;
      end if;
      case V is
         when Index_Get | Index_Worst =>
            for I in 1 .. To_Count (S64 (Num)) loop
               Rep_Use.Ref_Type.Parse_Get (Data, S, Head, Ref);
               exit when not Rep_Use.Ref_Type.Valid (Ref);
               Sum := Sum * 31 + U64 (Rep_Use.Ref_Type.Idx (Ref)) + U64 (Size (Rep_Use.Ref_Type.Tag (Ref)));
               pragma Loop_Invariant (Is_Valid (S, Data));
            end loop;

         when Index_Fixed             =>
            for I in 1 .. To_Count (S64 (Num)) loop
               Rep_Use.Ref_Type.Parse_Fixed (Data, S, Fixed, Ref);
               exit when not Rep_Use.Ref_Type.Valid (Ref);
               Sum := Sum * 31 + U64 (Rep_Use.Ref_Type.Idx (Ref)) + U64 (Size (Rep_Use.Ref_Type.Tag (Ref)));
               pragma Loop_Invariant (Is_Valid (S, Data));
            end loop;

         when others                  =>
            for I in 1 .. To_Count (S64 (Num)) loop
               Rep_Use.Ref_Type.Parse_Mod (Data, S, Ref);
               exit when not Rep_Use.Ref_Type.Valid (Ref);
               Sum := Sum * 31 + U64 (Rep_Use.Ref_Type.Idx (Ref)) + U64 (Size (Rep_Use.Ref_Type.Tag (Ref)));
               pragma Loop_Invariant (Is_Valid (S, Data));
            end loop;
      end case;
      return Sum;
   end Run_Index;

   ---------------------------------------------------------------------
   --  items.last
   ---------------------------------------------------------------------

   function Run_Last (V : Variant; Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Open (Data);
      Head : Bench_Rep.T;
      Tail : Rep_Use.Tail_Type.T;
      Kept : Rep_Use.Last_Kept.T;
   begin
      case V is
         when Last_Kept =>
            Rep_Use.Last_Kept.Parse (Data, S, Kept);
            if Rep_Use.Last_Kept.Valid (Kept) then
               return U64 (Rep_Use.Last_Kept.Items_Count (Kept)) + U64 (Size (Rep_Use.Last_Kept.Tail (Kept)));
            end if;

         when others    =>
            Bench_Rep.Parse (Head, Data, S);
            if Bench_Rep.Valid (Head) then
               if V = Last_Get then
                  Rep_Use.Tail_Type.Parse_Get (Data, S, Head, Tail);
               else
                  Rep_Use.Tail_Type.Parse_Eos (Data, S, Tail);
               end if;
               if Rep_Use.Tail_Type.Valid (Tail) then
                  return U64 (Bench_Rep.Items_Count (Head)) + U64 (Size (Rep_Use.Tail_Type.Tail (Tail)));
               end if;
            end if;
      end case;
      return 0;
   end Run_Last;

   ---------------------------------------------------------------------
   --  links[_index - 1], the repetition that is being parsed
   ---------------------------------------------------------------------

   function Run_Prev (V : Variant; Data : Bytes) return U64 is
      use Rep_Use.Links;
      S        : Kaitai.Streams.Stream := Open (Data);
      This     : Rep_Use.Links.T;
      Position : Rep_Use.Links.Cursor;
      Element  : Link_Type.T;
      Sum      : U64;
   begin
      if V = Prev_Naive then
         Parse_Naive (Data, S, This);
      else
         Parse_Carried (Data, S, This);
      end if;
      if not Valid (This) then
         return 0;
      end if;
      Sum := U64 (Links_Count (This));
      Position := First (This);
      while Has_Element (Position) loop
         pragma Loop_Invariant (Belongs_To (Position, Data) and then Belongs_To (This, Data));
         pragma Loop_Variant (Decreases => Remaining (Position));
         if V = Prev_Naive then
            Next_Naive (Data, This, Position, Element);
         else
            Next_Carried (Data, This, Position, Element);
         end if;
         exit when not Link_Type.Valid (Element);
         Sum := Sum + U64 (Link_Type.Len (Element)) + U64 (Size (Link_Type.Extra (Element)));
      end loop;
      return Sum;
   end Run_Prev;

   ---------------------------------------------------------------------
   --  items[_index - 1] in the elements of another repetition
   ---------------------------------------------------------------------

   function Run_Other (V : Variant; Data : Bytes) return U64 is
      S        : Kaitai.Streams.Stream := Open (Data);
      Head     : Bench_Rep.T;
      Block    : Rep_Use.Block_Type.T;
      Element  : Bench_Rep.Item_Type.T;
      Position : Bench_Rep.Items_Cursor;
      Prev     : U8 := 0;
      Sum      : U64 := 0;
   begin
      Bench_Rep.Parse (Head, Data, S);
      if not Bench_Rep.Valid (Head) then
         return 0;
      end if;
      declare
         Count : constant Length := Bench_Rep.Items_Count (Head);
      begin
         Position := Bench_Rep.Items_First (Head);
         for I in 0 .. Count - 1 loop
            pragma Loop_Invariant (Is_Valid (S, Data) and then Bench_Rep.Belongs_To (Position, Data));
            if V = Other_Get then
               Rep_Use.Block_Type.Parse_Get (Data, S, Head, I, Block);
            else
               Rep_Use.Block_Type.Parse_Lockstep (Data, S, I, Prev, Block);
               if Bench_Rep.Has_Element (Position) then
                  Bench_Rep.Next (Head, Data, Position, Element);
                  if Bench_Rep.Item_Type.Valid (Element) then
                     Prev := Bench_Rep.Item_Type.Len (Element);
                  end if;
               end if;
            end if;
            exit when not Rep_Use.Block_Type.Valid (Block);
            Sum := Sum + U64 (Size (Rep_Use.Block_Type.Buf (Block)));
         end loop;
         return Sum + U64 (Count);
      end;
   end Run_Other;

   ---------------------------------------------------------------------
   --  A count that is large and elements that read nothing
   ---------------------------------------------------------------------

   function Run_Empty (V : Variant; Data : Bytes) return U64 is
      S       : Kaitai.Streams.Stream := Open (Data);
      Plain   : Bench_Rep_Empty.T;
      Stop    : Rep_Empty.T;
      Element : Bench_Rep_Empty.Item_Type.T;
      Sum     : U64 := 0;
   begin
      case V is
         when Empty_Get =>
            Bench_Rep_Empty.Parse (Plain, Data, S);
            if Bench_Rep_Empty.Valid (Plain) then
               Sum := U64 (Bench_Rep_Empty.Items_Count (Plain));
               if Bench_Rep_Empty.Items_Count (Plain) > 0 then
                  Bench_Rep_Empty.Get_Items (Plain, Data, Bench_Rep_Empty.Items_Count (Plain) - 1, Element);
                  if Bench_Rep_Empty.Item_Type.Valid (Element) then
                     Sum := Sum + 1;
                  end if;
               end if;
            end if;

         when others    =>
            Rep_Empty.Parse (Data, S, Stop);
            if Rep_Empty.Valid (Stop) then
               Sum := U64 (Rep_Empty.Items_Count (Stop));
               if V = Empty_Get_Stop and then Rep_Empty.Items_Count (Stop) > 0 then
                  Rep_Empty.Get_Stop (Data, Stop, Rep_Empty.Items_Count (Stop) - 1, Element);
                  if Bench_Rep_Empty.Item_Type.Valid (Element) then
                     Sum := Sum + 1;
                  end if;
               end if;
            end if;
      end case;
      return Sum;
   end Run_Empty;

   function Run (V : Variant; Data : Bytes; Reps : Positive) return U64 is
      Sum : U64 := 0;
   begin
      for R in 1 .. Reps loop
         Sum :=
           Sum
           + (case Layout_Of (V) is
                when Rep_L                                   => Run_Access (V, Data),
                when Index_L | Index_Fixed_L | Index_Worst_L => Run_Index (V, Data),
                when Last_L                                  => Run_Last (V, Data),
                when Prev_Self_L                             => Run_Prev (V, Data),
                when Prev_Other_L                            => Run_Other (V, Data),
                when Rep_Empty_L                             => Run_Empty (V, Data));
      end loop;
      return Sum;
   end Run;

end Rep_Runs;
