with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Showcase;
with Test_Support;   use Test_Support;

package body Showcase_Tests is

   use type Showcase.Kind_Enum;
   use type Showcase.Entry_Type.Body_Kind;

   package Entries renames Showcase.Entry_Type;
   package Points renames Showcase.Entry_Type.Point_Type;

   Data : constant Bytes (1 .. 48) :=
     (16#53#,
      16#48#,          --   0  magic
      16#02#,          --   2  kind: big
      16#02#,
      16#00#,          --   3  num_entries
      16#07#,          --   5  header.version
      16#01#,          --   6  header.flags
      16#05#,          --   7  header.len_name
      16#41#,
      16#42#,          --   8  header.name, len_name - 3 bytes
      16#01#,          --  10  entries[0].code: point
      16#01#,
      16#00#,          --  11  x = 1
      16#FE#,
      16#FF#,          --  13  y = -2
      16#09#,          --  15  extra, because of header.flags
      16#02#,          --  16  entries[1].code: text
      16#68#,
      16#69#,
      16#00#,          --  17  "hi"
      16#0A#,          --  20  extra
      16#2A#,
      16#00#,
      16#00#,
      16#00#,          --  21  tail_len, because kind is big
      16#05#,
      16#00#,
      16#06#,
      16#00#,          --  25  points[0] = (5, 6)
      16#00#,
      16#00#,
      16#07#,
      16#00#,          --  29  points[1] = (0, 7), the last one
      16#08#,          --  33  len_log
      16#01#,
      16#00#,
      16#02#,
      16#00#,          --  34  log.records[0] = (1, 2)
      16#03#,
      16#00#,
      16#04#,
      16#00#,          --  38  log.records[1] = (3, 4)
      16#10#,
      16#00#,          --  42  samples[0]
      16#20#,
      16#00#,
      16#30#,
      16#00#);         --  46  samples[2]

   Minimal : constant Bytes (1 .. 16) := (16#53#, 16#48#, 1, 1, 0, 0, 0, 3, 3, 0, 0, 9, 0, 0, 16#10#, 0);

   --  Offset of samples, from where on a shorter input can be valid again
   Samples_At : constant := 42;

   procedure Test_Fields is
      S : Stream := Open (Data);
      R : Showcase.T;
   begin
      Group ("Showcase fields");
      Showcase.Parse (R, Data, S, 3);
      Check (OK (S) and then Is_EOF (S), "parsed to the end");
      if not Showcase.Valid (R) then
         Check (False, "valid");
         return;
      end if;
      Check (Showcase.Scale (R) = 3, "the parameter is kept");
      Check (Showcase.Kind_Value (R) = 2 and then Showcase.Kind (R) = Showcase.Kind_Big, "enumeration");
      Check (Showcase.Num_Entries (R) = 2, "integer");
      Check (Showcase.Header_Type.Version (Showcase.Header (R)) = 7, "field of a nested type");
      Check (Showcase.Header_Type.Name (Showcase.Header (R)) = (First => 9, Last => 10), "size from an expression");
      Check (Showcase.Has_Tail_Len (R) and then Showcase.Tail_Len (R) = 42, "field with a condition that holds");
      Check (Showcase.Len_Log (R) = 8, "integer after a repetition");
      Check (Showcase.Samples_Count (R) = 3, "elements of a fixed size: count");
      Check
        (Showcase.Samples (R, Data, 0) = 16 and then Showcase.Samples (R, Data, 2) = 48,
         "elements of a fixed size: by index");
      Check (Showcase.Has_Total (R) and then Showcase.Total (R) = 13, "instance with a value");
   end Test_Fields;

   procedure Test_Repetitions is
      S        : Stream := Open (Data);
      R        : Showcase.T;
      E        : Entries.T;
      P        : Points.T;
      Position : Showcase.Entries_Cursor;
      Seen     : Natural := 0;
      Outcome  : Status_Kind;
   begin
      Group ("Showcase repetitions");
      Showcase.Parse (R, Data, S, 3);
      if not Showcase.Valid (R) then
         Check (False, "valid");
         return;
      end if;

      Check (Showcase.Entries_Count (R) = 2, "count");
      Showcase.Get_Entries (R, Data, 0, E);
      if Entries.Valid (E) and then Entries.Body_Case (E) = Entries.Body_Is_Point then
         Check (Entries.Code (E) = 1 and then Entries.Flags (E) = 1, "first element: fields and parameter");
         Check
           (Points.X (Entries.Body_As_Point (E)) = 1 and then Points.Y (Entries.Body_As_Point (E)) = -2,
            "first element: the case of the switch");
         Check (Entries.Has_Extra (E) and then Entries.Extra (E) = 9, "first element: condition on a parameter");
      else
         Check (False, "first element is a point");
      end if;
      Showcase.Get_Entries (R, Data, 1, E);
      if Entries.Valid (E) and then Entries.Body_Case (E) = Entries.Body_Is_Text then
         Check
           (Entries.Text_Type.Value (Entries.Body_As_Text (E)) = (First => 18, Last => 19),
            "second element: the other case");
         Check (Entries.Extra (E) = 10, "second element: field after the switch");
      else
         Check (False, "second element is a text");
      end if;

      Position := Showcase.Entries_First (R);
      while Showcase.Has_Element (Position) loop
         pragma Loop_Variant (Decreases => Showcase.Remaining (Position));
         pragma Loop_Invariant (Showcase.Belongs_To (Position, Data));
         Showcase.Next (R, Data, Position, E);
         exit when not Entries.Valid (E);
         Seen := Seen + 1;
      end loop;
      Check (Seen = 2, "the cursor delivers every element once");

      Check (Showcase.Points_Count (R) = 2, "up to a condition: count includes the last element");
      Showcase.Get_Points (R, Data, 0, P);
      Check (Points.Valid (P) and then Points.X (P) = 5 and then Points.Y (P) = 6, "up to a condition: first");
      Showcase.Get_Points (R, Data, 1, P);
      Check (Points.Valid (P) and then Points.X (P) = 0 and then Points.Y (P) = 7, "up to a condition: last");

      Check (Showcase.Log_Type.Records_Count (Showcase.Log (R)) = 2, "up to the end of a substream: count");
      Showcase.Log_Type.Get_Records (Showcase.Log (R), Data, 1, P);
      Check (Points.Valid (P) and then Points.X (P) = 3 and then Points.Y (P) = 4, "up to the end: last");

      Showcase.First_Entry (R, Data, E, Outcome);
      Check (Outcome = Success and then Entries.Valid (E), "instance with a position");
      if Entries.Valid (E) and then Entries.Body_Case (E) = Entries.Body_Is_Point then
         Check (Points.Y (Entries.Body_As_Point (E)) = -2, "instance: parsed from the position");
         Check (not Entries.Has_Extra (E), "instance: with its own argument");
      else
         Check (False, "instance is a point");
      end if;
   end Test_Repetitions;

   procedure Test_Variations is
      Other : Bytes := Data;
      S     : Stream;
      R     : Showcase.T;
      E     : Entries.T;
      Bad   : Natural := 0;
   begin
      Group ("Showcase variations");

      --  Every shorter input: nothing but a failure before the samples,
      --  and a valid result only where a sample ends after that
      for Last in 0 .. Data'Last - 1 loop
         S := Open (Data (1 .. Last));
         Showcase.Parse (R, Data (1 .. Last), S, 3);
         if Showcase.Valid (R) /= (Last >= Samples_At and then (Last - Samples_At) mod 2 = 0) then
            Bad := Bad + 1;
         end if;
         if Showcase.Valid (R) /= OK (S) then
            Bad := Bad + 1;
         end if;
      end loop;
      Check (Bad = 0, "every shorter input fails or ends at a sample");

      Other (1) := 16#54#;
      S := Open (Other);
      Showcase.Parse (R, Other, S, 3);
      Check (Status (S) = Validation_Not_Equal and then not Showcase.Valid (R), "wrong contents");
      Other := Data;

      Other (8) := 2;
      S := Open (Other);
      Showcase.Parse (R, Other, S, 3);
      Check (Status (S) = End_Of_Stream, "a negative size is a failure");
      Other := Data;

      --  The input ends after a point that is not the last one
      Other (1 .. 9) := Minimal (1 .. 9);
      Other (10 .. 13) := (5, 0, 6, 0);
      S := Open (Other (1 .. 13));
      Showcase.Parse (R, Other (1 .. 13), S, 3);
      Check (Status (S) = End_Of_Stream, "input ends in a repetition up to a condition");
      Other := Data;

      --  kind small, no flags, an empty name, an entry that no case covers,
      --  one point, an empty log and one sample
      S := Open (Minimal);
      Showcase.Parse (R, Minimal, S, 3);
      if Showcase.Valid (R) then
         Check (not Showcase.Has_Tail_Len (R), "field with a condition that does not hold");
         Check (Is_Empty (Showcase.Header_Type.Name (Showcase.Header (R))), "empty byte array");
         Check (Showcase.Points_Count (R) = 1, "a repetition that ends with its first element");
         Check (Showcase.Log_Type.Records_Count (Showcase.Log (R)) = 0, "a repetition without elements");
         Check (Showcase.Samples_Count (R) = 1, "one sample");
         Showcase.Get_Entries (R, Minimal, 0, E);
         Check
           (Entries.Valid (E) and then Entries.Body_Case (E) = Entries.Body_Is_None and then not Entries.Has_Extra (E),
            "a value that no case of the switch covers");
      else
         Check (False, "valid without optional parts");
      end if;

      Other (1 .. 16) := Minimal;
      Other (3) := 77;
      S := Open (Other (1 .. 16));
      Showcase.Parse (R, Other (1 .. 16), S, 3);
      Check
        (Showcase.Valid (R) and then not Showcase.Is_Kind_Enum (S64 (Showcase.Kind_Value (R))),
         "a value the enumeration does not name is kept");
   end Test_Variations;

   procedure Run is
   begin
      Test_Fields;
      Test_Repetitions;
      Test_Variations;
   end Run;

end Showcase_Tests;
