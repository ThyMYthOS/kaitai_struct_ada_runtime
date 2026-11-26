with Bench_Bits_Flat;
with Bench_Bits_Flat_V2;
with Bench_Bits_Flat_V3;
with Bench_Bits_Flat_V3a;
with Bench_Bits_Hand;
with Bench_Bits_Le;
with Bench_Bits_Le_V2;
with Bench_Bits_Le_V3;
with Bench_Bits_Le_V3a;
with Bench_Bits_Mixed;
with Bench_Bits_Mixed_V2;
with Bench_Bits_Mixed_V3;
with Bench_Bits_Mixed_V3a;
with Bench_Bits_Nested;
with Bench_Bits_Nested_V2;
with Bench_Bits_Nested_V3;
with Bench_Bits_Nested_V3a;
with Kaitai.Streams;

package body Bit_Runs is

   function Run_Bits_Flat_V1 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Flat.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Flat.Parse (This, Data, S);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Flat.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Flat.A (This) * 31 + Bench_Bits_Flat.B (This)) * 31 + Bench_Bits_Flat.C (This))
              * 31
              + Bench_Bits_Flat.D (This));
      end loop;
      return Sum;
   end Run_Bits_Flat_V1;

   function Run_Bits_Flat_V2 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Flat_V2.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Flat_V2.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Flat_V2.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Flat_V2.A (This) * 31 + Bench_Bits_Flat_V2.B (This)) * 31 + Bench_Bits_Flat_V2.C (This))
              * 31
              + Bench_Bits_Flat_V2.D (This));
      end loop;
      return Sum;
   end Run_Bits_Flat_V2;

   function Run_Bits_Flat_V3 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Flat_V3.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Flat_V3.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Flat_V3.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Flat_V3.A (This) * 31 + Bench_Bits_Flat_V3.B (This)) * 31 + Bench_Bits_Flat_V3.C (This))
              * 31
              + Bench_Bits_Flat_V3.D (This));
      end loop;
      return Sum;
   end Run_Bits_Flat_V3;

   function Run_Bits_Flat_V3a (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Flat_V3a.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Flat_V3a.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Flat_V3a.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Flat_V3a.A (This) * 31 + Bench_Bits_Flat_V3a.B (This)) * 31 + Bench_Bits_Flat_V3a.C (This))
              * 31
              + Bench_Bits_Flat_V3a.D (This));
      end loop;
      return Sum;
   end Run_Bits_Flat_V3a;

   function Run_Bits_Flat_V4 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Hand.Flat_T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Hand.Parse_Flat (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not This.Is_Valid;
         Sum := Sum * 31 + (((This.A * 31 + This.B) * 31 + This.C) * 31 + This.D);
      end loop;
      return Sum;
   end Run_Bits_Flat_V4;

   function Run_Bits_Le_V1 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Le.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Le.Parse (This, Data, S);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Le.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Le.A (This) * 31 + Bench_Bits_Le.B (This)) * 31 + Bench_Bits_Le.C (This))
              * 31
              + Bench_Bits_Le.D (This));
      end loop;
      return Sum;
   end Run_Bits_Le_V1;

   function Run_Bits_Le_V2 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Le_V2.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Le_V2.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Le_V2.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Le_V2.A (This) * 31 + Bench_Bits_Le_V2.B (This)) * 31 + Bench_Bits_Le_V2.C (This))
              * 31
              + Bench_Bits_Le_V2.D (This));
      end loop;
      return Sum;
   end Run_Bits_Le_V2;

   function Run_Bits_Le_V3 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Le_V3.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Le_V3.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Le_V3.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Le_V3.A (This) * 31 + Bench_Bits_Le_V3.B (This)) * 31 + Bench_Bits_Le_V3.C (This))
              * 31
              + Bench_Bits_Le_V3.D (This));
      end loop;
      return Sum;
   end Run_Bits_Le_V3;

   function Run_Bits_Le_V3a (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Le_V3a.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Le_V3a.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Le_V3a.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Le_V3a.A (This) * 31 + Bench_Bits_Le_V3a.B (This)) * 31 + Bench_Bits_Le_V3a.C (This))
              * 31
              + Bench_Bits_Le_V3a.D (This));
      end loop;
      return Sum;
   end Run_Bits_Le_V3a;

   function Run_Bits_Le_V4 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Hand.Flat_T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Hand.Parse_Le (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not This.Is_Valid;
         Sum := Sum * 31 + (((This.A * 31 + This.B) * 31 + This.C) * 31 + This.D);
      end loop;
      return Sum;
   end Run_Bits_Le_V4;

   function Run_Bits_Mixed_V1 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Mixed.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Mixed.Parse (This, Data, S);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Mixed.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Mixed.A (This) * 31 + Bench_Bits_Mixed.B (This)) * 31 + U64 (Bench_Bits_Mixed.C (This)))
              * 31
              + U64 (Bench_Bits_Mixed.D (This)));
      end loop;
      return Sum;
   end Run_Bits_Mixed_V1;

   function Run_Bits_Mixed_V2 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Mixed_V2.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Mixed_V2.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Mixed_V2.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Mixed_V2.A (This) * 31 + Bench_Bits_Mixed_V2.B (This))
               * 31
               + U64 (Bench_Bits_Mixed_V2.C (This)))
              * 31
              + U64 (Bench_Bits_Mixed_V2.D (This)));
      end loop;
      return Sum;
   end Run_Bits_Mixed_V2;

   function Run_Bits_Mixed_V3 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Mixed_V3.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Mixed_V3.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Mixed_V3.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Mixed_V3.A (This) * 31 + Bench_Bits_Mixed_V3.B (This))
               * 31
               + U64 (Bench_Bits_Mixed_V3.C (This)))
              * 31
              + U64 (Bench_Bits_Mixed_V3.D (This)));
      end loop;
      return Sum;
   end Run_Bits_Mixed_V3;

   function Run_Bits_Mixed_V3a (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Mixed_V3a.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Mixed_V3a.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Mixed_V3a.Valid (This);
         Sum :=
           Sum
           * 31
           + (((Bench_Bits_Mixed_V3a.A (This) * 31 + Bench_Bits_Mixed_V3a.B (This))
               * 31
               + U64 (Bench_Bits_Mixed_V3a.C (This)))
              * 31
              + U64 (Bench_Bits_Mixed_V3a.D (This)));
      end loop;
      return Sum;
   end Run_Bits_Mixed_V3a;

   function Run_Bits_Mixed_V4 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Hand.Mixed_T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Hand.Parse_Mixed (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not This.Is_Valid;
         Sum := Sum * 31 + (((This.A * 31 + This.B) * 31 + U64 (This.C)) * 31 + U64 (This.D));
      end loop;
      return Sum;
   end Run_Bits_Mixed_V4;

   function Run_Bits_Nested_V1 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Nested.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Nested.Parse (This, Data, S);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Nested.Valid (This);
         Sum :=
           Sum
           * 31
           + (((U64 (Bench_Bits_Nested.A (This)) * 31 + Bench_Bits_Nested.Inner_Type.X (Bench_Bits_Nested.B (This)))
               * 31
               + Bench_Bits_Nested.Inner_Type.Y (Bench_Bits_Nested.B (This)))
              * 31
              + Bench_Bits_Nested.Inner_Type.Z (Bench_Bits_Nested.B (This)));
      end loop;
      return Sum;
   end Run_Bits_Nested_V1;

   function Run_Bits_Nested_V2 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Nested_V2.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Nested_V2.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Nested_V2.Valid (This);
         Sum :=
           Sum
           * 31
           + (((U64 (Bench_Bits_Nested_V2.A (This))
                * 31
                + Bench_Bits_Nested_V2.Inner_Type.X (Bench_Bits_Nested_V2.B (This)))
               * 31
               + Bench_Bits_Nested_V2.Inner_Type.Y (Bench_Bits_Nested_V2.B (This)))
              * 31
              + Bench_Bits_Nested_V2.Inner_Type.Z (Bench_Bits_Nested_V2.B (This)));
      end loop;
      return Sum;
   end Run_Bits_Nested_V2;

   function Run_Bits_Nested_V3 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Nested_V3.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Nested_V3.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Nested_V3.Valid (This);
         Sum :=
           Sum
           * 31
           + (((U64 (Bench_Bits_Nested_V3.A (This))
                * 31
                + Bench_Bits_Nested_V3.Inner_Type.X (Bench_Bits_Nested_V3.B (This)))
               * 31
               + Bench_Bits_Nested_V3.Inner_Type.Y (Bench_Bits_Nested_V3.B (This)))
              * 31
              + Bench_Bits_Nested_V3.Inner_Type.Z (Bench_Bits_Nested_V3.B (This)));
      end loop;
      return Sum;
   end Run_Bits_Nested_V3;

   function Run_Bits_Nested_V3a (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Nested_V3a.T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Nested_V3a.Parse (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not Bench_Bits_Nested_V3a.Valid (This);
         Sum :=
           Sum
           * 31
           + (((U64 (Bench_Bits_Nested_V3a.A (This))
                * 31
                + Bench_Bits_Nested_V3a.Inner_Type.X (Bench_Bits_Nested_V3a.B (This)))
               * 31
               + Bench_Bits_Nested_V3a.Inner_Type.Y (Bench_Bits_Nested_V3a.B (This)))
              * 31
              + Bench_Bits_Nested_V3a.Inner_Type.Z (Bench_Bits_Nested_V3a.B (This)));
      end loop;
      return Sum;
   end Run_Bits_Nested_V3a;

   function Run_Bits_Nested_V4 (Data : Bytes) return U64 is
      S    : Kaitai.Streams.Stream := Kaitai.Streams.Open (Data);
      This : Bench_Bits_Hand.Nested_T;
      Sum  : U64 := 0;
   begin
      while not Kaitai.Streams.Is_EOF (S) loop
         Bench_Bits_Hand.Parse_Nested (Data, S, This);
         exit when not Kaitai.Streams.OK (S) or else not This.Is_Valid;
         Sum := Sum * 31 + (((U64 (This.A) * 31 + This.X) * 31 + This.Y) * 31 + This.Z);
      end loop;
      return Sum;
   end Run_Bits_Nested_V4;

end Bit_Runs;
