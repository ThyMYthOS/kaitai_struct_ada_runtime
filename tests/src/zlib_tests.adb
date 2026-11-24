with Kaitai.Types; use Kaitai.Types;
with Kaitai.Zlib;  use Kaitai.Zlib;
with Test_Support; use Test_Support;

package body Zlib_Tests is

   --  Streams made by zlib of Python (compress, compressobj), with the data
   --  they were made from.  The fixed one is made with Z_FIXED, the one of
   --  several blocks with Z_FULL_FLUSH between its parts.

   Empty_Stream : constant Bytes (1 .. 8) := (16#78#, 16#9C#, 16#03#, 16#00#, 16#00#, 16#00#, 16#00#, 16#01#);

   Empty_Text : constant String := "";

   Stored_Stream : constant Bytes (1 .. 32) :=
     (16#78#,
      16#01#,
      16#01#,
      16#15#,
      16#00#,
      16#EA#,
      16#FF#,
      16#53#,
      16#74#,
      16#6F#,
      16#72#,
      16#65#,
      16#64#,
      16#20#,
      16#62#,
      16#6C#,
      16#6F#,
      16#63#,
      16#6B#,
      16#20#,
      16#6F#,
      16#66#,
      16#20#,
      16#74#,
      16#65#,
      16#78#,
      16#74#,
      16#2E#,
      16#55#,
      16#FD#,
      16#07#,
      16#A5#);

   Stored_Text : constant String := "Stored block of text.";

   Fixed_Stream : constant Bytes (1 .. 61) :=
     (16#78#,
      16#01#,
      16#0B#,
      16#C9#,
      16#48#,
      16#55#,
      16#28#,
      16#2C#,
      16#CD#,
      16#4C#,
      16#CE#,
      16#56#,
      16#48#,
      16#2A#,
      16#CA#,
      16#2F#,
      16#CF#,
      16#53#,
      16#48#,
      16#CB#,
      16#AF#,
      16#50#,
      16#C8#,
      16#2A#,
      16#CD#,
      16#2D#,
      16#28#,
      16#56#,
      16#C8#,
      16#2F#,
      16#4B#,
      16#2D#,
      16#52#,
      16#28#,
      16#01#,
      16#4A#,
      16#E7#,
      16#24#,
      16#56#,
      16#55#,
      16#2A#,
      16#A4#,
      16#E4#,
      16#A7#,
      16#EB#,
      16#29#,
      16#84#,
      16#E0#,
      16#54#,
      16#9C#,
      16#98#,
      16#9E#,
      16#98#,
      16#99#,
      16#A7#,
      16#07#,
      16#00#,
      16#42#,
      16#A6#,
      16#1B#,
      16#D8#);

   Fixed_Text : constant String := "The quick brown fox jumps over the lazy dog. The quick brown fox jumps again.";

   Dynamic_Stream : constant Bytes (1 .. 147) :=
     (16#78#,
      16#DA#,
      16#5D#,
      16#50#,
      16#01#,
      16#0E#,
      16#84#,
      16#20#,
      16#0C#,
      16#FB#,
      16#CA#,
      16#5E#,
      16#70#,
      16#7F#,
      16#9A#,
      16#27#,
      16#51#,
      16#22#,
      16#13#,
      16#A2#,
      16#90#,
      16#5C#,
      16#7C#,
      16#BD#,
      16#8C#,
      16#32#,
      16#31#,
      16#97#,
      16#30#,
      16#68#,
      16#D6#,
      16#52#,
      16#3A#,
      16#02#,
      16#CB#,
      16#34#,
      16#33#,
      16#B9#,
      16#74#,
      16#FA#,
      16#10#,
      16#77#,
      16#DA#,
      16#0B#,
      16#4D#,
      16#2E#,
      16#33#,
      16#2D#,
      16#2C#,
      16#C2#,
      16#74#,
      16#FA#,
      16#A5#,
      16#EE#,
      16#B3#,
      16#0B#,
      16#B5#,
      16#23#,
      16#85#,
      16#32#,
      16#77#,
      16#F6#,
      16#58#,
      16#23#,
      16#E9#,
      16#F9#,
      16#92#,
      16#FE#,
      16#BC#,
      16#2E#,
      16#E0#,
      16#BC#,
      16#FE#,
      16#5B#,
      16#54#,
      16#AA#,
      16#69#,
      16#D5#,
      16#01#,
      16#76#,
      16#D0#,
      16#3C#,
      16#8E#,
      16#0A#,
      16#B4#,
      16#EC#,
      16#7D#,
      16#D0#,
      16#0D#,
      16#C2#,
      16#C1#,
      16#02#,
      16#6E#,
      16#9C#,
      16#52#,
      16#F3#,
      16#B3#,
      16#C6#,
      16#3B#,
      16#A3#,
      16#3A#,
      16#40#,
      16#80#,
      16#EE#,
      16#A5#,
      16#F7#,
      16#07#,
      16#A5#,
      16#E5#,
      16#30#,
      16#0A#,
      16#9A#,
      16#50#,
      16#F5#,
      16#D0#,
      16#16#,
      16#A5#,
      16#74#,
      16#63#,
      16#C5#,
      16#C9#,
      16#8F#,
      16#01#,
      16#02#,
      16#7E#,
      16#2A#,
      16#8A#,
      16#FF#,
      16#1E#,
      16#95#,
      16#56#,
      16#BD#,
      16#61#,
      16#B1#,
      16#67#,
      16#11#,
      16#FB#,
      16#1A#,
      16#13#,
      16#3C#,
      16#DE#,
      16#9F#,
      16#1B#,
      16#91#,
      16#8F#,
      16#81#,
      16#DE#);

   Dynamic_Text : constant String :=
     "lambda epsilon nu beta gamma sigma delta mu tau beta rho eta beta gamma xi xi gamma theta "
     & "gamma sigma xi beta tau delta theta tau beta tau tau nu beta theta beta sigma epsilon kapp"
     & "a xi epsilon sigma delta tau kappa sigma zeta delta tau tau eta mu delta sigma gamma tau b"
     & "eta upsilon eta pi sigma xi lambda omicron tau omicron mu kappa theta zeta theta gamma tau"
     & ".";

   Overlap_Stream : constant Bytes (1 .. 13) :=
     (16#78#, 16#DA#, 16#4B#, 16#4C#, 16#1C#, 16#05#, 16#C4#, 16#02#, 16#00#, 16#D8#, 16#A8#, 16#71#, 16#AD#);

   Multi_Stream : constant Bytes (1 .. 85) :=
     (16#78#,
      16#DA#,
      16#CA#,
      16#CF#,
      16#4B#,
      16#55#,
      16#28#,
      16#29#,
      16#CF#,
      16#57#,
      16#28#,
      16#C9#,
      16#28#,
      16#4A#,
      16#4D#,
      16#55#,
      16#C8#,
      16#C7#,
      16#C3#,
      16#03#,
      16#00#,
      16#00#,
      16#00#,
      16#FF#,
      16#FF#,
      16#4A#,
      16#4A#,
      16#A2#,
      16#3D#,
      16#00#,
      16#00#,
      16#00#,
      16#00#,
      16#FF#,
      16#FF#,
      16#73#,
      16#CB#,
      16#CC#,
      16#4B#,
      16#CC#,
      16#51#,
      16#28#,
      16#48#,
      16#2C#,
      16#2A#,
      16#51#,
      16#C8#,
      16#4F#,
      16#53#,
      16#48#,
      16#54#,
      16#28#,
      16#2E#,
      16#29#,
      16#4A#,
      16#4D#,
      16#CC#,
      16#55#,
      16#28#,
      16#CF#,
      16#2C#,
      16#C9#,
      16#50#,
      16#28#,
      16#4E#,
      16#2D#,
      16#4B#,
      16#2D#,
      16#02#,
      16#CA#,
      16#26#,
      16#E5#,
      16#E4#,
      16#27#,
      16#67#,
      16#17#,
      16#EB#,
      16#A0#,
      16#F1#,
      16#F5#,
      16#00#,
      16#A3#,
      16#12#,
      16#4A#,
      16#FE#);

   Multi_Last : constant String := "Final part of a stream with several blocks, several blocks.";

   Bad_Distance_First : constant Bytes (1 .. 9) :=
     (16#78#, 16#9C#, 16#03#, 16#02#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#);

   Bad_Distance_Far : constant Bytes (1 .. 10) :=
     (16#78#, 16#9C#, 16#4B#, 16#04#, 16#42#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#);

   Bad_Block_Type : constant Bytes (1 .. 8) := (16#78#, 16#9C#, 16#07#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#);

   Bad_Stored : constant Bytes (1 .. 12) :=
     (16#78#, 16#9C#, 16#01#, 16#01#, 16#00#, 16#00#, 16#00#, 16#41#, 16#00#, 16#00#, 16#00#, 16#00#);

   --  The same as the fixed one, but short; made with Z_FIXED
   Tiny_Stream : constant Bytes (1 .. 16) :=
     (16#78#,
      16#01#,
      16#CB#,
      16#48#,
      16#CD#,
      16#C9#,
      16#C9#,
      16#57#,
      16#C8#,
      16#40#,
      16#90#,
      16#00#,
      16#3A#,
      16#2E#,
      16#06#,
      16#7D#);

   Tiny_Text : constant String := "hello hello hello";

   Overlap_Text : constant String (1 .. 300) := (others => 'a');

   --  The data of the stream of several blocks
   Multi_Text : constant String := "one two three one two three one two three " & (1 .. 100 => 'b') & Multi_Last;

   --  Buffers are static, as the stack of a small target is small
   Output : Bytes (1 .. 1024);
   Copy   : Bytes (1 .. 256);

   function Matches (Data : Bytes; Text : String) return Boolean
   is (Data'Length = Text'Length
       and then (for all I in Text'Range =>
                   Data (Data'First + Length (I - Text'First)) = Byte (Character'Pos (Text (I)))));

   procedure Expect (Stream : Bytes; Text : String; Name : String; Thorough : Boolean := False) is
      Last   : Length;
      Result : Result_Kind;
      N      : constant Length := Text'Length;
   begin
      Output := (others => 16#EE#);
      Inflate (Stream, Output, Last, Result);
      Check (Result = Done and then Last = N and then Matches (Output (1 .. Last), Text), Name & ": data");

      Output := (others => 16#EE#);
      Inflate (Stream, Output (1 .. N), Last, Result);
      Check (Result = Done and then Last = N and then Matches (Output (1 .. Last), Text), Name & ": exact fit");

      Output := (others => 16#EE#);
      Inflate (Stream, Output (101 .. 100 + N), Last, Result);
      Check
        (Result = Done and then Last = 100 + N and then Matches (Output (101 .. Last), Text),
         Name & ": target not at 1");
      Check (Output (100) = 16#EE# and then Output (101 + N) = 16#EE#, Name & ": nothing else written");

      if N > 0 then
         Inflate (Stream, Output (1 .. N - 1), Last, Result);
         Check (Result = Target_Full and then Last = 0, Name & ": one byte short");
         Inflate (Stream, Output (1 .. 0), Last, Result);
         Check (Result = Target_Full and then Last = 0, Name & ": no room");
      end if;

      if Thorough then
         declare
            Short : Boolean := False;
         begin
            for Cut in 0 .. Stream'Length - 1 loop
               Inflate (Stream (Stream'First .. Stream'First + Length (Cut) - 1), Output, Last, Result);
               if Result /= Corrupt then
                  Short := True;
               end if;
            end loop;
            Check (not Short, Name & ": every truncation is corrupt");
         end;
      end if;

      Copy (1 .. Stream'Length) := Stream;
      Copy (Stream'Length) := Copy (Stream'Length) xor 1;
      Inflate (Copy (1 .. Stream'Length), Output, Last, Result);
      Check (Result = Corrupt and then Last = 0, Name & ": wrong Adler-32");

      --  Every truncation and every flipped bit are tried with one small
      --  stream only, because that is slow on a microcontroller
      if Thorough then
         declare
            Wrong : Natural := 0;
         begin
            for Bit in 0 .. Stream'Length * 8 - 1 loop
               Copy (1 .. Stream'Length) := Stream;
               Copy (1 + Length (Bit / 8)) := Copy (1 + Length (Bit / 8)) xor Shift_Left (1, Bit mod 8);
               Inflate (Copy (1 .. Stream'Length), Output, Last, Result);
               --  Only bits that are not used can change nothing, such as those
               --  after the end of the last block
               if Result = Done and then not (Last = N and then Matches (Output (1 .. Last), Text)) then
                  Wrong := Wrong + 1;
               end if;
            end loop;
            Check (Wrong = 0, Name & ": no flipped bit changes the data");
         end;
      end if;
   end Expect;

   procedure Test_Streams is
   begin
      Group ("Zlib.Inflate");
      Expect (Empty_Stream, Empty_Text, "empty");
      Expect (Stored_Stream, Stored_Text, "stored");
      Expect (Fixed_Stream, Fixed_Text, "fixed");
      Expect (Tiny_Stream, Tiny_Text, "tiny", Thorough => True);
      Expect (Dynamic_Stream, Dynamic_Text, "dynamic");
      Expect (Overlap_Stream, Overlap_Text, "overlapping back-references");
      Expect (Multi_Stream, Multi_Text, "several blocks");
   end Test_Streams;

   procedure Test_Invalid is
      Last   : Length;
      Result : Result_Kind;
      Good   : Bytes (1 .. Fixed_Stream'Length) := Fixed_Stream;
   begin
      Group ("Zlib.Inflate, invalid streams");

      Inflate (Bad_Distance_First, Output, Last, Result);
      Check (Result = Corrupt, "back-reference before the first byte");
      Inflate (Bad_Distance_Far, Output, Last, Result);
      Check (Result = Corrupt, "back-reference further back than the data");
      Inflate (Bad_Block_Type, Output, Last, Result);
      Check (Result = Corrupt, "block type 3");
      Inflate (Bad_Stored, Output, Last, Result);
      Check (Result = Corrupt, "stored block with a wrong complement");

      Inflate (Good, Output, Last, Result);
      Check (Result = Done, "unchanged copy is good");
      Good (1) := 16#79#;
      Inflate (Good, Output, Last, Result);
      Check (Result = Corrupt, "method 9");
      Good (1) := 16#88#;
      Good (2) := 16#1C#;
      Inflate (Good, Output, Last, Result);
      Check (Result = Corrupt, "window of 64 KiB (CINFO 8)");
      Good (1 .. 2) := Fixed_Stream (1 .. 2);
      Good (2) := Good (2) + 1;
      Inflate (Good, Output, Last, Result);
      Check (Result = Corrupt, "wrong check bits");
      Good (1 .. 2) := (16#78#, 16#BB#);
      Inflate (Good, Output, Last, Result);
      Check (Result = Corrupt, "preset dictionary (with right check bits)");
      Good (1 .. 2) := (16#00#, 16#00#);
      Inflate (Good, Output, Last, Result);
      Check (Result = Corrupt, "zero header");

      Inflate (Good (1 .. 0), Output, Last, Result);
      Check (Result = Corrupt, "no bytes");
      Inflate (Fixed_Stream (1 .. 1), Output, Last, Result);
      Check (Result = Corrupt, "one byte");
      Inflate (Fixed_Stream, Output (1 .. 0), Last, Result);
      Check (Result = Target_Full and then Last = 0, "no target");
      Inflate (Fixed_Stream, Output (5 .. 4), Last, Result);
      Check (Result = Target_Full and then Last = 4, "no target, bounds do not start at 1");

      --  Bytes after the stream do not matter
      Output := (others => 16#EE#);
      Copy (1 .. Empty_Stream'Length + 3) := Empty_Stream & (1, 2, 3);
      Inflate (Copy (1 .. Empty_Stream'Length + 3), Output, Last, Result);
      Check (Result = Done and then Last = 0, "bytes after the stream");
   end Test_Invalid;

   procedure Run is
   begin
      Test_Streams;
      Test_Invalid;
   end Run;

end Zlib_Tests;
