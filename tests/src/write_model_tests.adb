with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Kaitai.Writers;
with Test_Support;   use Test_Support;
with Write_Model;

package body Write_Model_Tests is

   --  The inputs of Showcase_Tests: write_model.ksy is showcase.ksy
   Full : constant Bytes (1 .. 48) :=
     (16#53#,
      16#48#,
      16#02#,
      16#02#,
      16#00#,
      16#07#,
      16#01#,
      16#05#,
      16#41#,
      16#42#,
      16#01#,
      16#01#,
      16#00#,
      16#FE#,
      16#FF#,
      16#09#,
      16#02#,
      16#68#,
      16#69#,
      16#00#,
      16#0A#,
      16#2A#,
      16#00#,
      16#00#,
      16#00#,
      16#05#,
      16#00#,
      16#06#,
      16#00#,
      16#00#,
      16#00#,
      16#07#,
      16#00#,
      16#08#,
      16#01#,
      16#00#,
      16#02#,
      16#00#,
      16#03#,
      16#00#,
      16#04#,
      16#00#,
      16#10#,
      16#00#,
      16#20#,
      16#00#,
      16#30#,
      16#00#);

   Minimal : constant Bytes (1 .. 16) := (16#53#, 16#48#, 1, 1, 0, 0, 0, 3, 3, 0, 0, 9, 0, 0, 16#10#, 0);

   Target : Bytes (101 .. 164) := (others => 0);

   --  Parse Input, write the result to Target (101 .. 100 + Room) and tell
   --  how the writer ended and how many bytes it wrote
   procedure Round_Trip (Input : Bytes; Room : Length; Outcome : out Status_Kind; Written : out Length)
   with Pre => Room <= 60;

   procedure Round_Trip (Input : Bytes; Room : Length; Outcome : out Status_Kind; Written : out Length) is
      S : Stream := Open (Input);
      R : Write_Model.T;
      W : Kaitai.Writers.Writer;
   begin
      Target := (others => 16#EE#);
      Outcome := End_Of_Stream;
      Written := 0;
      Write_Model.Parse (R, Input, S, 3);
      if Write_Model.Valid (R) then
         W := Kaitai.Writers.Open (Target (101 .. 100 + Room));
         Write_Model.Write (R, Input, Target (101 .. 100 + Room), W);
         Outcome := Kaitai.Writers.Status (W);
         Written := Kaitai.Writers.Pos (W);
      end if;
   end Round_Trip;

   procedure Run is
      Outcome : Status_Kind;
      Written : Length;
   begin
      Group ("Write_Model round trips");
      Round_Trip (Full, 48, Outcome, Written);
      Check (Outcome = Success and then Written = 48, "everything is written");
      Check (Target (101 .. 148) = Full, "and is what was parsed");
      Check (Target (149) = 16#EE#, "and nothing after it");

      Round_Trip (Full, 60, Outcome, Written);
      Check (Outcome = Success and then Written = 48 and then Target (101 .. 148) = Full, "into a larger target");

      Round_Trip (Minimal, 16, Outcome, Written);
      Check (Outcome = Success and then Written = 16, "without the optional parts: written");
      Check (Target (101 .. 116) = Minimal, "without the optional parts: the same bytes");

      Group ("Write_Model failures");
      for Room in Length range 0 .. 47 loop
         Round_Trip (Full, Room, Outcome, Written);
         if Outcome /= Capacity_Exceeded or else Written > Room then
            Check (False, "a target that is too small");
         end if;
      end loop;
      Check (True, "every target that is too small is noticed");
      Round_Trip (Full, 47, Outcome, Written);
      Check (Target (148) = 16#EE#, "and nothing is written beyond it");
   end Run;

end Write_Model_Tests;
