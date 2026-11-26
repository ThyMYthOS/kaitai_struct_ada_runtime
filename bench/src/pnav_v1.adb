with Kaitai.Strings;

package body Pnav_V1
  with SPARK_Mode
is

   package body Child_Type is

      procedure Parse
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Parent_S1 : Kaitai.Types.Slice; This : out T) is
      begin
         This := (others => <>);
         This.Parent_S1 := Parent_S1;
         Kaitai.Streams.Read_U1 (Buffer, S, This.V);
         if Kaitai.Strings.Equal_Literal (Buffer, This.Parent_S1, "foo") then
            This.Has_W := True;
            Kaitai.Streams.Read_U1 (Buffer, S, This.W);
         end if;
         This.Is_Valid := Kaitai.Streams.OK (S);
      end Parse;

      function Do_Something (Buffer : Kaitai.Types.Bytes; This : T) return Boolean
      is (Kaitai.Strings.Equal_Literal (Buffer, This.Parent_S1, "foo"));

   end Child_Type;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      Element : Child_Type.T;
   begin
      Kaitai.Streams.Read_Bytes_Term
        (Buffer, S, Term => 16#7C#, Include => False, Consume => True, EOS_Error => True, Data => This.S1);
      if not Kaitai.Strings.Is_Valid (Buffer, This.S1, Kaitai.Strings.US_ASCII) then
         Kaitai.Streams.Fail (S, Kaitai.Types.Illegal_Sequence);
      end if;
      Kaitai.Streams.Read_U1 (Buffer, S, This.Count);
      This.Items_Io := S;
      This.Items_Count := Kaitai.Types.To_Count (Kaitai.Types.S64 (This.Count));
      for I in 1 .. This.Items_Count loop
         Child_Type.Parse (Buffer, S, This.S1, Element);
         exit when not Child_Type.Valid (Element);
         pragma Loop_Invariant (Kaitai.Streams.Is_Valid (S, Buffer) and then Kaitai.Streams.Advanced (S'Loop_Entry, S));
      end loop;
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse;

   procedure Next (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Items_Cursor; Element : out Child_Type.T) is
   begin
      Child_Type.Parse (Buffer, Position.Io, This.S1, Element);
      Position.Left := (if Child_Type.Valid (Element) then Position.Left - 1 else 0);
   end Next;

end Pnav_V1;
