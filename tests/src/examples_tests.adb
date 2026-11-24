with Bits_Simple;
with Fixed_Struct;
with Hello_World;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Sample_Data;    use Sample_Data;
with Term_Strz;
with Test_Support;   use Test_Support;

package body Examples_Tests is

   Sample_Fixed_Struct : Bytes renames Sample_Data.Fixed_Struct;
   Sample_Term_Strz    : Bytes renames Sample_Data.Term_Strz;

   procedure Test_Hello_World is
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Hello_World.T;
      None : constant Bytes (1 .. 0) := (others => 0);
   begin
      Group ("examples hello_world");
      Hello_World.Parse (Sample_Fixed_Struct, S, This);
      Check (Hello_World.Valid (This) and then OK (S), "parses");
      Check (Hello_World.One (This) = 16#50#, "one");
      Check (Pos (S) = 1, "one byte consumed");

      S := Open (None);
      Hello_World.Parse (None, S, This);
      Check (not Hello_World.Valid (This) and then Status (S) = End_Of_Stream, "an empty file is rejected");
   end Test_Hello_World;

   procedure Test_Fixed_Struct is
      use Fixed_Struct;
      S       : Stream := Open (Sample_Fixed_Struct);
      This    : Fixed_Struct.T;
      H       : Header.T;
      Outcome : Status_Kind;
      Bad     : Bytes := Sample_Fixed_Struct;
   begin
      Group ("examples fixed_struct");
      Parse (Sample_Fixed_Struct, S, This);
      Check (Valid (This) and then Pos (S) = 0, "parses; the type has no fields in sequence");
      Hdr (Sample_Fixed_Struct, This, H, Outcome);
      Check (Outcome = Success and then Header.Valid (H), "instance hdr parses");
      if Header.Valid (H) then
         Check (Header.Uint8 (H) = 255, "hdr.uint8");
         Check (Header.Uint16 (H) = 65_535, "hdr.uint16");
         Check (Header.Uint32 (H) = 4_294_967_295, "hdr.uint32");
         Check (Header.Uint64 (H) = 18_446_744_073_709_551_615, "hdr.uint64");
         Check (Header.Sint8 (H) = -1, "hdr.sint8");
         Check (Header.Sint16 (H) = -1, "hdr.sint16");
         Check (Header.Sint32 (H) = -1, "hdr.sint32");
         Check (Header.Sint64 (H) = -1, "hdr.sint64");
         Check (Header.Uint16le (H) = 66, "hdr.uint16le");
         Check (Header.Uint32le (H) = 66, "hdr.uint32le");
         Check (Header.Uint64le (H) = 66, "hdr.uint64le");
         Check (Header.Sint16le (H) = -66, "hdr.sint16le");
         Check (Header.Sint32le (H) = -66, "hdr.sint32le");
         Check (Header.Sint64le (H) = -66, "hdr.sint64le");
         Check (Header.Uint16be (H) = 66, "hdr.uint16be");
         Check (Header.Uint32be (H) = 66, "hdr.uint32be");
         Check (Header.Uint64be (H) = 66, "hdr.uint64be");
         Check (Header.Sint16be (H) = -66, "hdr.sint16be");
         Check (Header.Sint32be (H) = -66, "hdr.sint32be");
         Check (Header.Sint64be (H) = -66, "hdr.sint64be");
      end if;
      Hdr (Sample_Fixed_Struct, This, H, Outcome);
      Check (Outcome = Success, "the instance can be asked for again");

      --  A file whose second magic is wrong
      Bad (9) := 16#51#;
      S := Open (Bad);
      Parse (Bad, S, This);
      Hdr (Bad, This, H, Outcome);
      Check (Outcome = Validation_Not_Equal and then not Header.Valid (H), "wrong contents are rejected");

      --  Every truncated file
      for Last in 0 .. Sample_Fixed_Struct'Last - 1 loop
         S := Open (Sample_Fixed_Struct (1 .. Last));
         Parse (Sample_Fixed_Struct (1 .. Last), S, This);
         Hdr (Sample_Fixed_Struct (1 .. Last), This, H, Outcome);
         if Outcome /= End_Of_Stream or else Header.Valid (H) then
            Check (False, "a truncated file runs out of bytes");
         end if;
      end loop;
      Check (True, "truncated files are rejected");
   end Test_Fixed_Struct;

   procedure Test_Bits_Simple is
      use Bits_Simple;
      S    : Stream := Open (Sample_Fixed_Struct);
      This : Bits_Simple.T;
   begin
      Group ("examples bits_simple");
      Parse (Sample_Fixed_Struct, S, This);
      Check (Valid (This) and then Pos (S) = 28, "parses 28 bytes");
      if Valid (This) then
         Check (Byte_1 (This) = 16#50#, "byte_1");
         Check (Byte_2 (This) = 16#41#, "byte_2");
         Check (not Bits_A (This), "bits_a");
         Check (Bits_B (This) = 2#100#, "bits_b");
         Check (Bits_C (This) = 2#0011#, "bits_c");
         Check (Large_Bits_1 (This) = 2#0100101100#, "large_bits_1");
         Check (Spacer (This) = 2#101#, "spacer");
         Check (Large_Bits_2 (This) = 2#10100110001#, "large_bits_2");
         Check (Normal_S2 (This) = -1, "normal_s2");
         Check (Byte_8_9_10 (This) = 16#504143#, "byte_8_9_10");
         Check (Byte_11_To_14 (This) = 16#4B2D552D#, "byte_11_to_14");
         Check (Byte_15_To_19 (This) = 16#444546FFFF#, "byte_15_to_19");
         Check (Byte_20_To_27 (This) = 16#FFFFFFFFFFFFFFFF#, "byte_20_to_27");
         Check (Has_Test_If_B1 (This) and then Test_If_B1 (This) = 123, "test_if_b1");
      end if;

      S := Open (Sample_Fixed_Struct (1 .. 27));
      Parse (Sample_Fixed_Struct (1 .. 27), S, This);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a file one byte short is rejected");
   end Test_Bits_Simple;

   procedure Test_Term_Strz is
      use Term_Strz;
      S    : Stream := Open (Sample_Term_Strz);
      This : Term_Strz.T;

      function Text (Item : Slice) return String is
         Result : String (1 .. Natural (Size (Item)));
      begin
         for I in Result'Range loop
            Result (I) := Character'Val (Sample_Term_Strz (Item.First + Length (I) - 1));
         end loop;
         return Result;
      end Text;
   begin
      Group ("examples term_strz");
      Parse (Sample_Term_Strz, S, This);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check (Text (S1 (This)) = "foo", "s1");
         Check (Text (S2 (This)) = "bar", "s2");
         Check (Text (S3 (This)) = "|baz@", "s3");
      end if;
      Check (Is_EOF (S), "the whole file is consumed");

      S := Open (Sample_Term_Strz (1 .. 11));
      Parse (Sample_Term_Strz (1 .. 11), S, This);
      Check (not Valid (This) and then Status (S) = End_Of_Stream, "a missing terminator is rejected");
   end Test_Term_Strz;

   procedure Run is
   begin
      Test_Hello_World;
      Test_Fixed_Struct;
      Test_Bits_Simple;
      Test_Term_Strz;
   end Run;

end Examples_Tests;
