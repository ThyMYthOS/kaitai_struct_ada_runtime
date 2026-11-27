with Float_Reading;
with Kaitai.Floats;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Sample_Data;
with Test_Support;   use Test_Support;

package body Float_Reading_Tests is

   procedure Run is
      use Float_Reading;
      Data : Bytes := Sample_Data.Float_Reading;
      S    : Stream := Open (Data);
      This : Float_Reading.T;

      function Near (A, B : Kaitai.Floats.F64) return Boolean
      is (abs (A - B) <= 1.0E-9 * (1.0 + abs B));

      procedure Reparse is
      begin
         S := Open (Data);
         Parse (This, Data, S);
      end Reparse;
   begin
      Group ("examples float_reading");
      Parse (This, Data, S);
      Check (Valid (This), "parses");
      if Valid (This) then
         Check
           (Near (Kaitai.Floats.F64 (Celsius (This)), 21.5) and then Near (Gain (This), 1.0E200),
            "the fields are floats");
         Check (Has_Kelvin (This) and then Near (Kelvin (This), 294.65), "a float and a literal");
         Check (Has_Whole_Kelvin (This) and then Whole_Kelvin (This) = 294, "to_i cuts the places after the point");
         Check (Has_Freezing (This) and then not Freezing (This), "a comparison");
         Check (Has_Negated (This) and then Near (Negated (This), -21.5), "unary minus");
         Check (Has_Scaled (This) and then Near (Scaled (This), 3.0E200), "a float and an integer");
         Check (Has_Blend (This) and then Near (Blend (This), 3.5), "an expression of several operations");
         Check (Has_Biased (This) and then Near (Biased (This), 1.0E200), "a conditional with a field under `if`");
         Check (Has_Capped (This) and then Near (Capped (This), 0.25), "a conditional of an integer and a float");
         Check (not Has_Gain_Squared (This), "a product that is more than any float has no value");
         Check (not Has_Gain_Squared_Whole (This), "and nothing computed from it");
      end if;

      --  a gain of 2, a celsius of -3 and a fraction of 0.75
      Data (1 .. 4) := (16#00#, 16#00#, 16#40#, 16#C0#);
      Data (5 .. 12) := (16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#40#);
      Data (15 .. 18) := (16#3F#, 16#40#, 16#00#, 16#00#);
      Reparse;
      Check (Valid (This), "another value parses");
      if Valid (This) then
         Check (Has_Freezing (This) and then Freezing (This), "below zero");
         Check (Has_Gain_Squared (This) and then Near (Gain_Squared (This), 4.0), "a product that fits");
         Check (Has_Gain_Squared_Whole (This) and then Gain_Squared_Whole (This) = 4, "to_i of it");
         Check (Has_Whole_Kelvin (This) and then Whole_Kelvin (This) = 270, "to_i of a number with places");
         Check (Has_Capped (This) and then Near (Capped (This), 1.0), "the integer branch is a float");
         Check (Has_Blend (This) and then Near (Blend (This), -2.0 + (-2.5) * 0.75), "a negative operand");
      end if;

      Data (19) := 0;
      Reparse;
      Check (Valid (This) and then not Has_Bias (This), "no bias");
      if Valid (This) then
         Check (Has_Biased (This) and then Near (Biased (This), 2.0), "the conditional does not read the bias");
      end if;

      --  fraction: 1.5, -0.5, not-a-number, infinity and minus infinity
      Data (15 .. 18) := (16#3F#, 16#C0#, 16#00#, 16#00#);
      Reparse;
      Check (not Valid (This) and then Status (S) = Validation_Greater_Than, "1.5 is above the range");
      Data (15 .. 18) := (16#BF#, 16#00#, 16#00#, 16#00#);
      Reparse;
      Check (not Valid (This) and then Status (S) = Validation_Less_Than, "-0.5 is below the range");
      Data (15 .. 18) := (16#7F#, 16#C0#, 16#00#, 16#00#);
      Reparse;
      Check (not Valid (This) and then Status (S) = Validation_Less_Than, "a not-a-number is not at least 0");
      Data (15 .. 18) := (16#7F#, 16#80#, 16#00#, 16#00#);
      Reparse;
      Check (not Valid (This) and then Status (S) = Validation_Greater_Than, "infinity is above the range");
      Data (15 .. 18) := (16#FF#, 16#80#, 16#00#, 16#00#);
      Reparse;
      Check (not Valid (This) and then Status (S) = Validation_Less_Than, "minus infinity is below the range");
      Data (15 .. 18) := (16#3F#, 16#00#, 16#00#, 16#00#);
      Reparse;
      Check (Valid (This), "0.5 is in the range, and so is 1.0");
      Data (15 .. 18) := (16#3F#, 16#80#, 16#00#, 16#00#);
      Reparse;
      Check (Valid (This), "1.0 is the upper end of the range");

      --  a celsius that is not-a-number: the field is there, and what is computed from it is not defined
      Data (1 .. 4) := (16#00#, 16#00#, 16#C0#, 16#7F#);
      Reparse;
      Check (Valid (This) and then not Has_Kelvin (This) and then not Has_Whole_Kelvin (This), "not-a-number");
      Check
        (not Has_Freezing (This) and then not Has_Negated (This) and then not Has_Blend (This), "in any expression");
      Check (Has_Scaled (This) and then Has_Biased (This), "the other expressions are not affected");

      --  a gain of 1E200 and a count of 65535: 6.5E204 is a float; a bias of 1E308 is above 2**1022,
      --  and the sum with it is refused
      Data (1 .. 4) := (16#00#, 16#00#, 16#AC#, 16#41#);
      Data (5 .. 12) := (16#5A#, 16#62#, 16#D7#, 16#D7#, 16#18#, 16#E7#, 16#74#, 16#69#);
      Data (13 .. 14) := (16#FF#, 16#FF#);
      Data (19) := 1;
      Data (20 .. 27) := (16#7F#, 16#E1#, 16#CC#, 16#F3#, 16#85#, 16#EB#, 16#C8#, 16#A0#);
      Reparse;
      Check (Valid (This) and then Has_Scaled (This) and then Near (Scaled (This), 6.5535E204), "a large product");
      Check (not Has_Biased (This), "the sum of 1E200 and 1E308 is finite but is refused (Add_OK)");
   end Run;

end Float_Reading_Tests;
