with Kaitai.Byte_Arrays; use Kaitai.Byte_Arrays;
with Kaitai.Floats;      use Kaitai.Floats;
with Kaitai.Types;       use Kaitai.Types;
with Test_Support;       use Test_Support;

package body Byte_Arrays_Tests is

   --                                    21  22  23  24  25  26  27  28  29  30
   Data : constant Bytes (21 .. 30) := (65, 66, 0, 67, 0, 0, 68, 32, 32, 32);

   All_Of : constant Slice := (First => 21, Last => 30);
   Empty  : constant Slice := (First => 25, Last => 24);

   procedure Run is
   begin
      Group ("Byte_Arrays.Find");
      Check (Find (Data, All_Of, 0) = 23, "first of several");
      Check (Find (Data, All_Of, 65) = 21, "at the start");
      Check (Find (Data, All_Of, 99) = 31, "absent: one past the end");
      Check (Find (Data, (First => 24, Last => 30), 0) = 25, "search starts at the slice");
      Check (Find (Data, (First => 26, Last => 26), 0) = 26, "slice of one byte, present");
      Check (Find (Data, (First => 27, Last => 27), 0) = 28, "slice of one byte, absent");
      Check (Find (Data, Empty, 0) = 25, "empty slice");

      Group ("Byte_Arrays.Terminate_At");
      Check (Terminate_At (Data, All_Of, 0, Include => False) = (First => 21, Last => 22), "without terminator");
      Check (Terminate_At (Data, All_Of, 0, Include => True) = (First => 21, Last => 23), "with terminator");
      Check (Terminate_At (Data, All_Of, 99, Include => False) = All_Of, "no terminator: everything");
      Check (Is_Empty (Terminate_At (Data, All_Of, 65, Include => False)), "terminator first: nothing");
      Check (Is_Empty (Terminate_At (Data, Empty, 0, Include => True)), "empty slice");

      Group ("Byte_Arrays.Strip_Right");
      Check (Strip_Right (Data, All_Of, 32) = (First => 21, Last => 27), "trailing padding removed");
      Check (Strip_Right (Data, All_Of, 0) = All_Of, "nothing to remove");
      Check (Is_Empty (Strip_Right (Data, (First => 28, Last => 30), 32)), "only padding");
      Check (Strip_Right (Data, (First => 21, Last => 26), 0) = (First => 21, Last => 24), "padding of two");
      Check (Is_Empty (Strip_Right (Data, Empty, 32)), "empty slice");

      Group ("Byte_Arrays.Equal");
      Check (Equal (Data, (First => 21, Last => 22), (65, 66)), "equal");
      Check (not Equal (Data, (First => 21, Last => 22), (65, 67)), "differs in the last byte");
      Check (not Equal (Data, (First => 21, Last => 22), (65, 66, 0)), "expected is longer");
      Check (not Equal (Data, (First => 21, Last => 23), (65, 66)), "expected is shorter");
      Check (Equal (Data, Empty, (1 .. 0 => 0)), "both empty");

      Group ("Floats");
      Check (Is_Finite (U32'(16#3F80_0000#)) and then To_F32 (16#3F80_0000#) = 1.0, "f4 one");
      Check (To_F32 (16#BF00_0000#) = -0.5, "f4 minus a half");
      Check (To_F32 (16#0000_0000#) = 0.0 and then To_F32 (16#8000_0000#) = 0.0, "f4 zeros");
      Check (To_F32 (16#4268_0000#) = 58.0, "f4 58");
      Check (To_F32 (16#7F7F_FFFF#) = F32'Last, "f4 largest");
      Check (To_F32 (16#0000_0001#) > 0.0, "f4 smallest subnormal");
      Check (not Is_Finite (U32'(16#7F80_0000#)), "f4 infinity is not finite");
      Check (not Is_Finite (U32'(16#FF80_0000#)), "f4 minus infinity is not finite");
      Check (not Is_Finite (U32'(16#7FC0_0000#)), "f4 not-a-number is not finite");
      Check (Is_Finite (U64'(16#3FF0_0000_0000_0000#)) and then To_F64 (16#3FF0_0000_0000_0000#) = 1.0, "f8 one");
      Check (To_F64 (16#C000_0000_0000_0000#) = -2.0, "f8 minus two");
      Check (To_F64 (16#4028_0000_0000_0000#) = 12.0, "f8 twelve");
      Check (To_F64 (16#7FEF_FFFF_FFFF_FFFF#) = F64'Last, "f8 largest");
      Check (not Is_Finite (U64'(16#7FF0_0000_0000_0000#)), "f8 infinity is not finite");
      Check (not Is_Finite (U64'(16#7FF8_0000_0000_0000#)), "f8 not-a-number is not finite");
   end Run;

end Byte_Arrays_Tests;
