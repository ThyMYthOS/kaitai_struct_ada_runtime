pragma Extensions_Allowed (On);

with Kaitai.Streams;
with Showcase;

package body Prefixed_Use
  with SPARK_Mode
is

   use type Kaitai.Types.Length;
   use type Showcase.Entry_Type.Body_Kind;

   procedure Summarise (Buffer : Kaitai.Types.Bytes; Result : out Summary) is
      S        : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);
      V        : Showcase.T;
      Position : Showcase.Entries_Cursor;
      Element  : Showcase.Entry_Type.T;
      Index    : Kaitai.Types.Length := 0;
   begin
      Result := (others => <>);
      V.Parse (Buffer, S, 3);
      if V.Valid then
         Result.Parsed := True;
         Result.Complete := S.Is_EOF;
         Result.Samples := V.Samples_Count;
         while Index < V.Samples_Count loop
            pragma Loop_Invariant (V.Valid and then V.Belongs_To (Buffer));
            pragma Loop_Variant (Increases => Index);
            Result.Largest := Kaitai.Types.U16'Max (Result.Largest, V.Samples (Buffer, Index));
            Index := Index + 1;
         end loop;
         Position := V.Entries_First;
         while Position.Has_Element loop
            pragma Loop_Invariant (V.Valid and then Position.Belongs_To (Buffer));
            pragma Loop_Variant (Decreases => Position.Remaining);
            V.Next (Buffer, Position, Element);
            exit when not Element.Valid;
            if Element.Body_Case = Showcase.Entry_Type.Body_Is_Text then
               Result.Has_Text := True;
            end if;
         end loop;
      end if;
   end Summarise;

end Prefixed_Use;
