--  Derived by hand from generated/bench_bits_le.ads: the package is renamed, nothing else is changed.

with Kaitai.Streams;
with Kaitai.Types;

package Bench_Bits_Le_V3a
  with SPARK_Mode, Always_Terminates
is

   type T is private;

   function Valid (This : T) return Boolean;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
   with
     Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
     Post =>
       Kaitai.Streams.Is_Valid (S, Buffer)
       and then Kaitai.Streams.Advanced (S'Old, S)
       and then Valid (This) = Kaitai.Streams.OK (S);

   function A (This : T) return Kaitai.Types.U64
   with Pre => Valid (This);

   function B (This : T) return Kaitai.Types.U64
   with Pre => Valid (This);

   function C (This : T) return Kaitai.Types.U64
   with Pre => Valid (This);

   function D (This : T) return Kaitai.Types.U64
   with Pre => Valid (This);

private

   type T is record
      Is_Valid : Boolean := False;
      A        : Kaitai.Types.U64 := 0;
      B        : Kaitai.Types.U64 := 0;
      C        : Kaitai.Types.U64 := 0;
      D        : Kaitai.Types.U64 := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function A (This : T) return Kaitai.Types.U64
   is (This.A);

   function B (This : T) return Kaitai.Types.U64
   is (This.B);

   function C (This : T) return Kaitai.Types.U64
   is (This.C);

   function D (This : T) return Kaitai.Types.U64
   is (This.D);

end Bench_Bits_Le_V3a;
