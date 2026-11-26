with Foreign;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Test_Support;   use Test_Support;
with Timestamp;

package body Foreign_Tests is

   Data : constant Bytes (1 .. 23) :=
     (16#05#,                              --   0  key
      16#00#,
      16#00#,
      16#01#,
      16#00#,      --   1  stamp: 256 seconds, 100 ticks per second
      16#03#,                              --   5  len_text
      16#6B#,
      16#97#,
      16#69#,              --   6  text: "abc" scrambled with the key and the mask
      16#05#,                              --   9  len_frame
      16#FF#,
      16#00#,
      16#12#,
      16#34#,
      16#FF#,  --  10  frame: a = 16#0012#, b = 16#34#, in a frame of two bytes
      16#00#,
      16#00#,
      16#00#,
      16#0A#,      --  15  stamps[0]: 10 seconds, key + 1 ticks per second
      16#00#,
      16#00#,
      16#00#,
      16#14#);     --  19  stamps[1]: 20 seconds

   procedure Test_Parse is
      S : Stream := Open (Data);
      R : Foreign.T;
      E : Timestamp.T;
   begin
      Group ("Foreign opaque type");
      Foreign.Parse (Data, S, R);
      Check (OK (S) and then Is_EOF (S), "parsed to the end");
      if not Foreign.Valid (R) then
         Check (False, "valid");
         return;
      end if;
      Check
        (Timestamp.Seconds (Foreign.Stamp (R)) = 256 and then Timestamp.Ticks_Per_Second (Foreign.Stamp (R)) = 100,
         "an opaque type read by the package that is written by hand, with an argument");
      Check (Foreign.Stamps_Count (R) = 2, "a repetition of it");
      Foreign.Get_Stamps (Data, R, 1, E);
      Check
        (Timestamp.Valid (E) and then Timestamp.Seconds (E) = 20 and then Timestamp.Ticks_Per_Second (E) = 6,
         "an element, with an argument that is an expression");
   end Test_Parse;

   procedure Test_Process is
      S       : Stream := Open (Data);
      R       : Foreign.T;
      Target  : Bytes (11 .. 20) := (others => 16#EE#);
      Last    : Length;
      Outcome : Status_Kind;
      Frame   : Foreign.Frame_Type.T;
   begin
      Group ("Foreign custom process");
      Foreign.Parse (Data, S, R);
      if not Foreign.Valid (R) then
         Check (False, "valid");
         return;
      end if;
      Check (Foreign.Text_Raw (R) = (First => 7, Last => 9), "the bytes as they are in the input");
      Foreign.Text (Data, R, Target, Last, Outcome);
      Check (Outcome = Success and then Last = 13, "decoded into the array of the caller");
      Check (Target (11 .. 13) = (16#61#, 16#62#, 16#63#), "with the arguments of the description");
      Check (Target (14) = 16#EE#, "and nothing written behind it");
      Foreign.Text (Data, R, Target (11 .. 12), Last, Outcome);
      Check (Outcome = Capacity_Exceeded and then Last = 10, "an array that is too small");

      Foreign.Frame (Data, R, Target, Frame, Outcome);
      Check (Outcome = Success and then Foreign.Frame_Type.Valid (Frame), "a value parsed from decoded bytes");
      if Foreign.Frame_Type.Valid (Frame) then
         Check (Foreign.Frame_Type.A (Frame) = 16#0012# and then Foreign.Frame_Type.B (Frame) = 16#34#, "its fields");
      end if;
      Foreign.Frame (Data, R, Target (11 .. 12), Frame, Outcome);
      Check (Outcome = Capacity_Exceeded and then not Foreign.Frame_Type.Valid (Frame), "storage that is too small");
   end Test_Process;

   --  A process that does not accept the bytes, and a type that does not accept the decoded bytes
   procedure Test_Failures is
      Short   : Bytes := Data;
      S       : Stream;
      R       : Foreign.T;
      Target  : Bytes (11 .. 20) := (others => 16#EE#);
      Outcome : Status_Kind;
      Frame   : Foreign.Frame_Type.T;
   begin
      Group ("Foreign failures");
      --  A frame of one byte, which Unwrap does not accept
      Short (10) := 1;
      S := Open (Short);
      Foreign.Parse (Short, S, R);
      if Foreign.Valid (R) then
         Foreign.Frame (Short, R, Target, Frame, Outcome);
         Check (Outcome = Illegal_Sequence and then not Foreign.Frame_Type.Valid (Frame), "the status of the package");
      else
         Check (Status (S) = End_Of_Stream, "or the data end");
      end if;

      --  A frame of two bytes: nothing is left for the value
      Short := Data;
      Short (10) := 2;
      S := Open (Short);
      Foreign.Parse (Short, S, R);
      if Foreign.Valid (R) then
         Foreign.Frame (Short, R, Target, Frame, Outcome);
         Check (Outcome = End_Of_Stream and then not Foreign.Frame_Type.Valid (Frame), "the status of the value");
      else
         Check (Status (S) = End_Of_Stream, "or the data end");
      end if;

      --  The data end inside the opaque type
      S := Open (Data (1 .. 3));
      Foreign.Parse (Data (1 .. 3), S, R);
      Check (not Foreign.Valid (R) and then Status (S) = End_Of_Stream, "the opaque type fails the stream");
   end Test_Failures;

   procedure Run is
   begin
      Test_Parse;
      Test_Process;
      Test_Failures;
   end Run;

end Foreign_Tests;
