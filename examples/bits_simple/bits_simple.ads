--  Parser for bits_simple.ksy, translated by hand in the way the Kaitai
--  Struct compiler is meant to generate it.  See docs/codegen.md.

with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

package Bits_Simple
  with SPARK_Mode, Always_Terminates
is

   type T is private;

   function Valid (This : T) return Boolean;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
   with Pre => Is_Valid (S, Buffer), Post => Is_Valid (S, Buffer) and then Valid (This) = OK (S);

   function Byte_1 (This : T) return U64
   with Pre => Valid (This);
   function Byte_2 (This : T) return U64
   with Pre => Valid (This);
   function Bits_A (This : T) return Boolean
   with Pre => Valid (This);
   function Bits_B (This : T) return U64
   with Pre => Valid (This);
   function Bits_C (This : T) return U64
   with Pre => Valid (This);
   function Large_Bits_1 (This : T) return U64
   with Pre => Valid (This);
   function Spacer (This : T) return U64
   with Pre => Valid (This);
   function Large_Bits_2 (This : T) return U64
   with Pre => Valid (This);
   function Normal_S2 (This : T) return S16
   with Pre => Valid (This);
   function Byte_8_9_10 (This : T) return U64
   with Pre => Valid (This);
   function Byte_11_To_14 (This : T) return U64
   with Pre => Valid (This);
   function Byte_15_To_19 (This : T) return U64
   with Pre => Valid (This);
   function Byte_20_To_27 (This : T) return U64
   with Pre => Valid (This);

   --  The instance test_if_b1 has a value only if its condition holds
   function Has_Test_If_B1 (This : T) return Boolean
   with Pre => Valid (This);
   function Test_If_B1 (This : T) return S64
   with Pre => Valid (This) and then Has_Test_If_B1 (This);

private

   type T is record
      Is_Valid      : Boolean := False;
      Byte_1        : U64 := 0;
      Byte_2        : U64 := 0;
      Bits_A        : Boolean := False;
      Bits_B        : U64 := 0;
      Bits_C        : U64 := 0;
      Large_Bits_1  : U64 := 0;
      Spacer        : U64 := 0;
      Large_Bits_2  : U64 := 0;
      Normal_S2     : S16 := 0;
      Byte_8_9_10   : U64 := 0;
      Byte_11_To_14 : U64 := 0;
      Byte_15_To_19 : U64 := 0;
      Byte_20_To_27 : U64 := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Byte_1 (This : T) return U64
   is (This.Byte_1);
   function Byte_2 (This : T) return U64
   is (This.Byte_2);
   function Bits_A (This : T) return Boolean
   is (This.Bits_A);
   function Bits_B (This : T) return U64
   is (This.Bits_B);
   function Bits_C (This : T) return U64
   is (This.Bits_C);
   function Large_Bits_1 (This : T) return U64
   is (This.Large_Bits_1);
   function Spacer (This : T) return U64
   is (This.Spacer);
   function Large_Bits_2 (This : T) return U64
   is (This.Large_Bits_2);
   function Normal_S2 (This : T) return S16
   is (This.Normal_S2);
   function Byte_8_9_10 (This : T) return U64
   is (This.Byte_8_9_10);
   function Byte_11_To_14 (This : T) return U64
   is (This.Byte_11_To_14);
   function Byte_15_To_19 (This : T) return U64
   is (This.Byte_15_To_19);
   function Byte_20_To_27 (This : T) return U64
   is (This.Byte_20_To_27);

   function Has_Test_If_B1 (This : T) return Boolean
   is (not This.Bits_A);
   function Test_If_B1 (This : T) return S64
   is (123);

end Bits_Simple;
