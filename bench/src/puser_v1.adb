package body Puser_V1
  with SPARK_Mode
is

   package body Header_Type is

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      begin
         Kaitai.Streams.Read_U2le (Buffer, S, This.Width);
         Kaitai.Streams.Read_U2le (Buffer, S, This.Height);
         This.Is_Valid := Kaitai.Streams.OK (S);
      end Parse;

   end Header_Type;

   package body Item_Type is

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Hdr : Header_Type.T; This : out T)
      is
      begin
         This.Hdr := Hdr;
         Kaitai.Streams.Read_U1 (Buffer, S, This.X);
         Kaitai.Streams.Read_U1 (Buffer, S, This.Y);
         Kaitai.Streams.Read_Bytes (S, Kaitai.Types.To_Size (Kaitai.Types.S64 (Header_Type.Height (Hdr))), This.Pad);
         This.Is_Valid := Kaitai.Streams.OK (S);
      end Parse;

   end Item_Type;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      Element : Item_Type.T;
   begin
      Header_Type.Parse (Buffer, S, This.Hdr);
      Kaitai.Streams.Read_U1 (Buffer, S, This.Count);
      This.Items_Io := S;
      This.Items_Count := Kaitai.Types.To_Count (Kaitai.Types.S64 (This.Count));
      if Header_Type.Valid (This.Hdr) then
         for I in 1 .. This.Items_Count loop
            Item_Type.Parse (Buffer, S, This.Hdr, Element);
            exit when not Item_Type.Valid (Element);
            pragma
              Loop_Invariant (Kaitai.Streams.Is_Valid (S, Buffer) and then Kaitai.Streams.Advanced (S'Loop_Entry, S));
         end loop;
      end if;
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse;

   procedure Next (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Items_Cursor; Element : out Item_Type.T) is
   begin
      Item_Type.Parse (Buffer, Position.Io, This.Hdr, Element);
      Position.Left := (if Item_Type.Valid (Element) then Position.Left - 1 else 0);
   end Next;

end Puser_V1;
