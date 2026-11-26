pragma Extensions_Allowed (On);

with Kaitai.Streams;
with Kaitai.Types;
with Prefixed_Use;
with Showcase;
with Test_Support;

package body Prefixed_Tests is

   use type Kaitai.Types.Length;
   use type Kaitai.Types.U8;
   use type Kaitai.Types.U16;
   use type Showcase.Entry_Type.Body_Kind;

   --  The input of Showcase_Tests: a showcase with two entries (a point and a text) and three samples
   Data : constant Kaitai.Types.Bytes (1 .. 48) :=
     (16#53#,
      16#48#,
      16#02#,
      16#02#,
      16#00#,
      16#07#,
      16#01#,
      16#05#,
      16#41#,
      16#42#,
      16#01#,
      16#01#,
      16#00#,
      16#FE#,
      16#FF#,
      16#09#,
      16#02#,
      16#68#,
      16#69#,
      16#00#,
      16#0A#,
      16#2A#,
      16#00#,
      16#00#,
      16#00#,
      16#05#,
      16#00#,
      16#06#,
      16#00#,
      16#00#,
      16#00#,
      16#07#,
      16#00#,
      16#08#,
      16#01#,
      16#00#,
      16#02#,
      16#00#,
      16#03#,
      16#00#,
      16#04#,
      16#00#,
      16#10#,
      16#00#,
      16#20#,
      16#00#,
      16#30#,
      16#00#);

   procedure Run is
      S        : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      V        : Showcase.T;
      Entry_1  : Showcase.Entry_Type.T;
      Position : Showcase.Entries_Cursor;
      Element  : Showcase.Entry_Type.T;
      Seen     : Natural := 0;
      Found    : Prefixed_Use.Summary;
   begin
      Test_Support.Group ("prefixed notation");

      V.Parse (Data, S, 3);
      Test_Support.Check (V.Valid and then S.OK and then S.Is_EOF, "V.Parse (Buffer, S, 3) and V.Valid");
      if not V.Valid then
         return;
      end if;

      Test_Support.Check (V.Scale = 3 and then V.Num_Entries = 2, "fields as V.Scale and V.Num_Entries");
      Test_Support.Check (V.Header.Version = 7, "a field of a nested type: V.Header.Version");
      Test_Support.Check (V.Samples (Data, 0) = 16 and then V.Samples (Data, 2) = 48, "V.Samples (Buffer, Index)");
      Test_Support.Check (V.Entries_Count = 2, "V.Entries_Count");

      V.Get_Entries (Data, 0, Entry_1);
      Test_Support.Check
        (Entry_1.Valid and then Entry_1.Body_Case = Showcase.Entry_Type.Body_Is_Point,
         "V.Get_Entries (Buffer, Index, Element) and Element.Body_Case");

      Position := V.Entries_First;
      while Position.Has_Element loop
         pragma Loop_Variant (Decreases => Position.Remaining);
         pragma Loop_Invariant (Position.Belongs_To (Data));
         V.Next (Data, Position, Element);
         exit when not Element.Valid;
         Seen := Seen + 1;
      end loop;
      Test_Support.Check (Seen = 2, "the cursor: Position.Has_Element, V.Next (Buffer, Position, Element)");

      Prefixed_Use.Summarise (Data, Found);
      Test_Support.Check
        (Found.Parsed
         and then Found.Complete
         and then Found.Samples = 3
         and then Found.Largest = 48
         and then Found.Has_Text,
         "a caller in SPARK that uses the notation");
      Prefixed_Use.Summarise (Data (1 .. 20), Found);
      Test_Support.Check (not Found.Parsed, "the same on data that are too short");
   end Run;

end Prefixed_Tests;
