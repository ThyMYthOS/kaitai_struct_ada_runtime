with Kaitai.Byte_Arrays;
with Kaitai.Strings;

package body Pstr_V1
  with SPARK_Mode
is

   package body Item_Type is

      procedure Parse
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Key : Kaitai.Types.Slice; This : out T) is
      begin
         This.Key := Key;
         Kaitai.Streams.Read_Bytes
           (S,
            Kaitai.Types.To_Size
              (Kaitai.Types.S64 (Kaitai.Strings.Character_Count (Buffer, This.Key, Kaitai.Strings.US_ASCII))),
            This.Body_Field);
         if not Kaitai.Strings.Is_Valid (Buffer, This.Body_Field, Kaitai.Strings.US_ASCII) then
            Kaitai.Streams.Fail (S, Kaitai.Types.Illegal_Sequence);
         end if;
         This.Is_Valid := Kaitai.Streams.OK (S);
      end Parse;

      function Is_Key (Buffer : Kaitai.Types.Bytes; This : T) return Boolean
      is (Kaitai.Byte_Arrays.Equal (Buffer, This.Body_Field, Buffer (This.Key.First .. This.Key.Last)));

   end Item_Type;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      Element : Item_Type.T;
   begin
      Kaitai.Streams.Read_Bytes (S, 4, This.Key);
      if not Kaitai.Strings.Is_Valid (Buffer, This.Key, Kaitai.Strings.US_ASCII) then
         Kaitai.Streams.Fail (S, Kaitai.Types.Illegal_Sequence);
      end if;
      Kaitai.Streams.Read_U1 (Buffer, S, This.Count);
      This.Items_Io := S;
      This.Items_Count := Kaitai.Types.To_Count (Kaitai.Types.S64 (This.Count));
      for I in 1 .. This.Items_Count loop
         Item_Type.Parse (Buffer, S, This.Key, Element);
         exit when not Item_Type.Valid (Element);
         pragma Loop_Invariant (Kaitai.Streams.Is_Valid (S, Buffer) and then Kaitai.Streams.Advanced (S'Loop_Entry, S));
      end loop;
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse;

   procedure Next (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Items_Cursor; Element : out Item_Type.T) is
   begin
      Item_Type.Parse (Buffer, Position.Io, This.Key, Element);
      Position.Left := (if Item_Type.Valid (Element) then Position.Left - 1 else 0);
   end Next;

end Pstr_V1;
