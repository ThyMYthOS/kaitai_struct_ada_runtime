package body Bench_Bits_Hand is

   procedure Parse_Flat (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Flat_T) is
      V : U32;
   begin
      Kaitai.Streams.Read_U4be (Buffer, S, V);
      This :=
        (Is_Valid => Kaitai.Streams.OK (S),
         A        => U64 (Shift_Right (V, 29)),
         B        => U64 (Shift_Right (V, 24) and 16#1F#),
         C        => U64 (Shift_Right (V, 12) and 16#FFF#),
         D        => U64 (V and 16#FFF#));
   end Parse_Flat;

   procedure Parse_Le (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Flat_T) is
      V : U32;
   begin
      Kaitai.Streams.Read_U4le (Buffer, S, V);
      This :=
        (Is_Valid => Kaitai.Streams.OK (S),
         A        => U64 (V and 16#7#),
         B        => U64 (Shift_Right (V, 3) and 16#1F#),
         C        => U64 (Shift_Right (V, 8) and 16#FFF#),
         D        => U64 (Shift_Right (V, 20)));
   end Parse_Le;

   procedure Parse_Mixed (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Mixed_T) is
      V : U8;
   begin
      Kaitai.Streams.Read_U1 (Buffer, S, V);
      This.A := U64 (Shift_Right (V, 4));
      This.B := U64 (V and 16#F#);
      Kaitai.Streams.Read_U1 (Buffer, S, This.C);
      Kaitai.Streams.Read_U2le (Buffer, S, This.D);
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse_Mixed;

   procedure Parse_Nested (Buffer : Bytes; S : in out Kaitai.Streams.Stream; This : out Nested_T) is
      V : U8;
      Z : U8;
   begin
      Kaitai.Streams.Read_U1 (Buffer, S, This.A);
      Kaitai.Streams.Read_U1 (Buffer, S, V);
      Kaitai.Streams.Read_U1 (Buffer, S, Z);
      This.X := U64 (Shift_Right (V, 4));
      This.Y := U64 (V and 16#F#);
      This.Z := U64 (Z);
      This.Is_Valid := Kaitai.Streams.OK (S);
   end Parse_Nested;

end Bench_Bits_Hand;
