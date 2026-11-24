package body Fixed_Struct
  with SPARK_Mode
is

   package body Header is

      procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
         L : Stream := S;
      begin
         Read_Contents (Buffer, L, Magic1);
         Read_U1 (Buffer, L, This.Uint8);
         Read_S1 (Buffer, L, This.Sint8);
         Read_Contents (Buffer, L, Magic_Uint);
         Read_U2le (Buffer, L, This.Uint16);
         Read_U4le (Buffer, L, This.Uint32);
         Read_U8le (Buffer, L, This.Uint64);
         Read_Contents (Buffer, L, Magic_Sint);
         Read_S2le (Buffer, L, This.Sint16);
         Read_S4le (Buffer, L, This.Sint32);
         Read_S8le (Buffer, L, This.Sint64);
         Read_Contents (Buffer, L, Magic_Uint_Le);
         Read_U2le (Buffer, L, This.Uint16le);
         Read_U4le (Buffer, L, This.Uint32le);
         Read_U8le (Buffer, L, This.Uint64le);
         Read_Contents (Buffer, L, Magic_Sint_Le);
         Read_S2le (Buffer, L, This.Sint16le);
         Read_S4le (Buffer, L, This.Sint32le);
         Read_S8le (Buffer, L, This.Sint64le);
         Read_Contents (Buffer, L, Magic_Uint_Be);
         Read_U2be (Buffer, L, This.Uint16be);
         Read_U4be (Buffer, L, This.Uint32be);
         Read_U8be (Buffer, L, This.Uint64be);
         Read_Contents (Buffer, L, Magic_Sint_Be);
         Read_S2be (Buffer, L, This.Sint16be);
         Read_S4be (Buffer, L, This.Sint32be);
         Read_S8be (Buffer, L, This.Sint64be);
         This.Is_Valid := OK (L);
         S := L;
      end Parse;

   end Header;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
   begin
      --  The type has no fields in sequence; all it has is an instance
      This := (Is_Valid => OK (S), Io => S);
   end Parse;

   procedure Hdr (Buffer : Bytes; This : T; Result : out Header.T; Outcome : out Status_Kind) is
      L : Stream := This.Io;
   begin
      Seek (L, 0);
      Header.Parse (Buffer, L, Result);
      Outcome := Status (L);
   end Hdr;

end Fixed_Struct;
