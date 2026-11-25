--  Derived by hand from generated/bench_bits_nested.ads: the package is renamed, nothing else is changed.

with Kaitai.Streams;
with Kaitai.Types;

package Bench_Bits_Nested_V3
  with SPARK_Mode, Always_Terminates
is

   --  type bench_bits_nested::inner

   package Inner_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S);

      function X (This : T) return Kaitai.Types.U64
      with Pre => Valid (This);

      function Y (This : T) return Kaitai.Types.U64
      with Pre => Valid (This);

      function Z (This : T) return Kaitai.Types.U64
      with Pre => Valid (This);

   private

      type T is record
         Is_Valid : Boolean := False;
         X        : Kaitai.Types.U64 := 0;
         Y        : Kaitai.Types.U64 := 0;
         Z        : Kaitai.Types.U64 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function X (This : T) return Kaitai.Types.U64
      is (This.X);

      function Y (This : T) return Kaitai.Types.U64
      is (This.Y);

      function Z (This : T) return Kaitai.Types.U64
      is (This.Z);

   end Inner_Type;

   type T is private;

   function Valid (This : T) return Boolean;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
   with
     Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
     Post =>
       Kaitai.Streams.Is_Valid (S, Buffer)
       and then Kaitai.Streams.Advanced (S'Old, S)
       and then Valid (This) = Kaitai.Streams.OK (S);

   function A (This : T) return Kaitai.Types.U8
   with Pre => Valid (This);

   function B (This : T) return Inner_Type.T
   with Pre => Valid (This), Post => Inner_Type.Valid (B'Result);

private

   type T is record
      Is_Valid : Boolean := False;
      A        : Kaitai.Types.U8 := 0;
      B        : Inner_Type.T;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid and then Inner_Type.Valid (This.B));

   function A (This : T) return Kaitai.Types.U8
   is (This.A);

   function B (This : T) return Inner_Type.T
   is (This.B);

end Bench_Bits_Nested_V3;
