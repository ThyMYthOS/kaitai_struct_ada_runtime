with Kaitai.Streams; use Kaitai.Streams;
with Showcase;

package body Fuzz_Targets is

   Showcase_Full : constant Bytes :=
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

   Showcase_Minimal : constant Bytes := (16#53#, 16#48#, 1, 1, 0, 0, 0, 3, 3, 0, 0, 9, 0, 0, 16#10#, 0);

   function Seed (T : Target; Round : Positive) return Bytes is
   begin
      case T is
         when Showcase_Parser =>
            return (if Round mod 4 = 0 then Showcase_Minimal else Showcase_Full);
      end case;
   end Seed;

   procedure Count (Fields : in out Natural; Condition : Boolean := True) is
   begin
      if Condition then
         Fields := Fields + 1;
      end if;
   end Count;

   procedure Run_Showcase (Input : Bytes; Argument : U16; Fields : out Natural) is
      package Entries renames Showcase.Entry_Type;
      package Points renames Showcase.Entry_Type.Point_Type;
      use type Entries.Body_Kind;
      use type Showcase.Kind_Enum;

      S       : Stream := Open (Input);
      R       : Showcase.T;
      E       : Entries.T;
      P       : Points.T;
      Outcome : Status_Kind;

      procedure Read_Entry is
      begin
         if not Entries.Valid (E) then
            return;
         end if;
         Count (Fields, Entries.Code (E) = 0 or else Entries.Flags (E) = 0);
         case Entries.Body_Case (E) is
            when Entries.Body_Is_Point =>
               Count (Fields, Points.X (Entries.Body_As_Point (E)) = Points.Y (Entries.Body_As_Point (E)));

            when Entries.Body_Is_Text  =>
               Count (Fields, Within (Entries.Text_Type.Value (Entries.Body_As_Text (E)), Input));

            when Entries.Body_Is_None  =>
               null;
         end case;
         if Entries.Has_Extra (E) then
            Count (Fields, Entries.Extra (E) = 0);
         end if;
      end Read_Entry;
   begin
      Fields := 0;
      Showcase.Parse (Input, S, Argument, R);
      pragma Assert (Showcase.Valid (R) = OK (S));
      if not Showcase.Valid (R) then
         return;
      end if;
      Fields := 1;
      Count (Fields, Showcase.Scale (R) = Argument);
      if Showcase.Is_Kind_Enum (S64 (Showcase.Kind_Value (R))) then
         Count (Fields, Showcase.Kind (R) = Showcase.Kind_Big);
      end if;
      Count (Fields, Showcase.Num_Entries (R) = 0);
      Count (Fields, Showcase.Header_Type.Version (Showcase.Header (R)) = 0);
      Count (Fields, Within (Showcase.Header_Type.Name (Showcase.Header (R)), Input));
      if Showcase.Has_Tail_Len (R) then
         Count (Fields, Showcase.Tail_Len (R) = 0);
      end if;
      if Showcase.Has_Total (R) then
         Count (Fields, Showcase.Total (R) = 0);
      end if;

      declare
         Position : Showcase.Entries_Cursor := Showcase.Entries_First (R);
      begin
         while Showcase.Has_Element (Position) loop
            Showcase.Next (Input, R, Position, E);
            Read_Entry;
         end loop;
      end;
      if Showcase.Entries_Count (R) > 0 then
         Showcase.Get_Entries (Input, R, Showcase.Entries_Count (R) - 1, E);
         --  What Parse accepted is accepted again
         pragma Assert (Entries.Valid (E));
         Read_Entry;
      end if;

      for I in 0 .. Showcase.Points_Count (R) - 1 loop
         Showcase.Get_Points (Input, R, I, P);
         pragma Assert (Points.Valid (P));
         Count (Fields, Points.X (P) = 0);
      end loop;

      for I in 0 .. Showcase.Log_Type.Records_Count (Showcase.Log (R)) - 1 loop
         Showcase.Log_Type.Get_Records (Input, Showcase.Log (R), I, P);
         pragma Assert (Points.Valid (P));
         Count (Fields, Points.Y (P) = 0);
      end loop;

      for I in 0 .. Showcase.Samples_Count (R) - 1 loop
         Count (Fields, Showcase.Samples (Input, R, I) = 0);
      end loop;

      Showcase.First_Entry (Input, R, E, Outcome);
      pragma Assert (Entries.Valid (E) = (Outcome = Success));
      Read_Entry;
   end Run_Showcase;

   procedure Run (T : Target; Input : Bytes; Argument : U16; Fields : out Natural) is
   begin
      case T is
         when Showcase_Parser =>
            Run_Showcase (Input, Argument, Fields);
      end case;
   end Run;

end Fuzz_Targets;
