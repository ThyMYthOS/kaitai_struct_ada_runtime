with Kaitai.Bits;    use Kaitai.Bits;
with Kaitai.Decoding;
with Kaitai.Encoding;
with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;
with Kaitai.Writers; use Kaitai.Writers;
with Test_Support;   use Test_Support;

package body Writers_Tests is

   Marker : constant U8 := 16#A5#;

   --  True if Buf starts with Prefix at its first index and holds the marker
   --  everywhere else: the write is where it should be and nothing around it
   --  was touched
   function Only (Buf : Bytes; Prefix : Bytes) return Boolean is
   begin
      if Prefix'Length > Buf'Length then
         return False;
      end if;
      for I in Buf'Range loop
         if Buf (I) /= (if I - Buf'First < Prefix'Length then Prefix (Prefix'First + (I - Buf'First)) else Marker) then
            return False;
         end if;
      end loop;
      return True;
   end Only;

   function Is_Marker (Buf : Bytes) return Boolean
   is (for all B of Buf => B = Marker);

   --  Deterministic pseudo random numbers (xorshift64)
   Seed : U64 := 16#9E37_79B9_7F4A_7C15#;

   function Next return U64 is
   begin
      Seed := Seed xor Shift_Left (Seed, 13);
      Seed := Seed xor Shift_Right (Seed, 7);
      Seed := Seed xor Shift_Left (Seed, 17);
      return Seed;
   end Next;

   ---------------------------------------------------------------------
   --  State
   ---------------------------------------------------------------------

   procedure Test_State is
      Buf   : Bytes (11 .. 18) := (others => Marker);
      Empty : Bytes (1 .. 0);
      W     : Writer := Open (Buf);
      E     : Writer := Open (Empty);
      D     : Writer;
   begin
      Group ("Writers state");
      Check (OK (W) and then Status (W) = Success, "a new writer is OK");
      Check (Size (W) = 8 and then Pos (W) = 0 and then Remaining (W) = 8, "size, position, remaining");
      Check (Next_Index (W) = 11, "next index is the first index of the target");
      Check (Bits_Free (W) = 0, "no bit field in progress");
      Check (Written (W) = (First => 11, Last => 10), "nothing is written yet");
      Check (Is_Valid (W, Buf), "valid for its target");
      Check (Same_Window (W, W), "the same window as itself");
      Check (Is_Marker (Buf), "opening writes nothing");

      Check (OK (E) and then Size (E) = 0 and then Remaining (E) = 0, "a writer over an empty target");
      Check (Is_Valid (E, Buf), "an empty writer is valid for any target");
      Check (not Same_Window (W, E), "different windows");
      Write_U1 (Buf, E, 1);
      Check (Status (E) = Capacity_Exceeded and then Pos (E) = 0, "an empty writer has no room");
      Check (Is_Marker (Buf), "and writes nothing");

      Check (OK (D) and then Size (D) = 0, "a writer that was never opened is empty");
      Write_U1 (Buf, D, 1);
      Check (Status (D) = Capacity_Exceeded, "and cannot write");

      Fail (W, Validation_Expr);
      Check (Status (W) = Validation_Expr and then not OK (W) and then Pos (W) = 0, "Fail records the reason");
      Fail (W, Validation_Not_Equal);
      Check (Status (W) = Validation_Expr, "the first failure is kept");
      Write_U1 (Buf, W, 1);
      Check (Status (W) = Validation_Expr and then Is_Marker (Buf), "a failed writer writes nothing");
      Skip (Buf, W, 1);
      Seek (W, 1);
      Check (Status (W) = Validation_Expr and then Pos (W) = 0 and then Is_Marker (Buf), "nor skips or seeks");
   end Test_State;

   ---------------------------------------------------------------------
   --  Integers: layout, position, surroundings
   ---------------------------------------------------------------------

   --  A window of 10 bytes in the middle of a target of 30; what is outside
   --  the window and behind the written bytes keeps the marker
   procedure Test_Layout is
      Buf : Bytes (5 .. 34);

      procedure Reset (W : out Writer) is
      begin
         Buf := (others => Marker);
         W := Open (Buf (15 .. 24));
      end Reset;

      function Window_Is (Prefix : Bytes) return Boolean
      is (Is_Marker (Buf (5 .. 14)) and then Only (Buf (15 .. 24), Prefix) and then Is_Marker (Buf (25 .. 34)));

      W : Writer;
   begin
      Group ("Writers integer layout");
      Reset (W);
      Write_U1 (Buf, W, 16#12#);
      Check (Window_Is ((16#12#, 0)) = False, "the check itself sees a difference");
      Check (Window_Is ((1 => 16#12#)) and then Pos (W) = 1 and then Next_Index (W) = 16, "u1");
      Check (Written (W) = (First => 15, Last => 15), "written after u1");

      Reset (W);
      Write_S1 (Buf, W, -2);
      Check (Window_Is ((1 => 16#FE#)) and then Pos (W) = 1, "s1");

      Reset (W);
      Write_U2le (Buf, W, 16#1234#);
      Check (Window_Is ((16#34#, 16#12#)) and then Pos (W) = 2, "u2le");
      Reset (W);
      Write_U2be (Buf, W, 16#1234#);
      Check (Window_Is ((16#12#, 16#34#)) and then Pos (W) = 2, "u2be");
      Reset (W);
      Write_U2 (Buf, W, Little_Endian, 16#1234#);
      Check (Window_Is ((16#34#, 16#12#)), "u2 little endian");
      Reset (W);
      Write_U2 (Buf, W, Big_Endian, 16#1234#);
      Check (Window_Is ((16#12#, 16#34#)), "u2 big endian");
      Reset (W);
      Write_S2le (Buf, W, -2);
      Check (Window_Is ((16#FE#, 16#FF#)), "s2le");
      Reset (W);
      Write_S2be (Buf, W, -2);
      Check (Window_Is ((16#FF#, 16#FE#)), "s2be");
      Reset (W);
      Write_S2 (Buf, W, Little_Endian, S16'First);
      Check (Window_Is ((16#00#, 16#80#)), "s2 little endian of the minimum");
      Reset (W);
      Write_S2 (Buf, W, Big_Endian, S16'Last);
      Check (Window_Is ((16#7F#, 16#FF#)), "s2 big endian of the maximum");

      Reset (W);
      Write_U4le (Buf, W, 16#1234_5678#);
      Check (Window_Is ((16#78#, 16#56#, 16#34#, 16#12#)) and then Pos (W) = 4, "u4le");
      Reset (W);
      Write_U4be (Buf, W, 16#1234_5678#);
      Check (Window_Is ((16#12#, 16#34#, 16#56#, 16#78#)) and then Pos (W) = 4, "u4be");
      Reset (W);
      Write_U4 (Buf, W, Little_Endian, 16#1234_5678#);
      Check (Window_Is ((16#78#, 16#56#, 16#34#, 16#12#)), "u4 little endian");
      Reset (W);
      Write_U4 (Buf, W, Big_Endian, 16#1234_5678#);
      Check (Window_Is ((16#12#, 16#34#, 16#56#, 16#78#)), "u4 big endian");
      Reset (W);
      Write_S4le (Buf, W, -2);
      Check (Window_Is ((16#FE#, 16#FF#, 16#FF#, 16#FF#)), "s4le");
      Reset (W);
      Write_S4be (Buf, W, -2);
      Check (Window_Is ((16#FF#, 16#FF#, 16#FF#, 16#FE#)), "s4be");
      Reset (W);
      Write_S4 (Buf, W, Little_Endian, S32'First);
      Check (Window_Is ((16#00#, 16#00#, 16#00#, 16#80#)), "s4 little endian of the minimum");
      Reset (W);
      Write_S4 (Buf, W, Big_Endian, S32'Last);
      Check (Window_Is ((16#7F#, 16#FF#, 16#FF#, 16#FF#)), "s4 big endian of the maximum");

      Reset (W);
      Write_U8le (Buf, W, 16#0102_0304_0506_0708#);
      Check (Window_Is ((16#08#, 16#07#, 16#06#, 16#05#, 16#04#, 16#03#, 16#02#, 16#01#)) and then Pos (W) = 8, "u8le");
      Reset (W);
      Write_U8be (Buf, W, 16#0102_0304_0506_0708#);
      Check (Window_Is ((16#01#, 16#02#, 16#03#, 16#04#, 16#05#, 16#06#, 16#07#, 16#08#)) and then Pos (W) = 8, "u8be");
      Reset (W);
      Write_U8 (Buf, W, Little_Endian, 16#8000_0000_0000_00FF#);
      Check (Window_Is ((16#FF#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#80#)), "u8 little endian");
      Reset (W);
      Write_U8 (Buf, W, Big_Endian, 16#8000_0000_0000_00FF#);
      Check (Window_Is ((16#80#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#FF#)), "u8 big endian");
      Reset (W);
      Write_S8le (Buf, W, -2);
      Check (Window_Is ((1 => 16#FE#, 2 .. 8 => 16#FF#)), "s8le");
      Reset (W);
      Write_S8be (Buf, W, -2);
      Check (Window_Is ((1 .. 7 => 16#FF#, 8 => 16#FE#)), "s8be");
      Reset (W);
      Write_S8 (Buf, W, Little_Endian, S64'First);
      Check (Window_Is ((1 .. 7 => 16#00#, 8 => 16#80#)), "s8 little endian of the minimum");
      Reset (W);
      Write_S8 (Buf, W, Big_Endian, S64'Last);
      Check (Window_Is ((1 => 16#7F#, 2 .. 8 => 16#FF#)), "s8 big endian of the maximum");

      Group ("Writers sequence");
      Reset (W);
      Write_U1 (Buf, W, 1);
      Write_U2le (Buf, W, 16#0302#);
      Write_U4be (Buf, W, 16#0405_0607#);
      Write_U2be (Buf, W, 16#0809#);
      Check (OK (W) and then Pos (W) = 9 and then Remaining (W) = 1, "position after a sequence");
      Check (Window_Is ((1, 2, 3, 4, 5, 6, 7, 8, 9)), "fields follow each other");
      Check (Written (W) = (First => 15, Last => 23), "written covers the sequence");
      Write_U2le (Buf, W, 16#FFFF#);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 9, "one byte is too little for two");
      Check (Window_Is ((1, 2, 3, 4, 5, 6, 7, 8, 9)), "and nothing is written");
   end Test_Layout;

   ---------------------------------------------------------------------
   --  Running out of space
   ---------------------------------------------------------------------

   --  Number of the operations of Try
   Operations : constant := 25;

   --  Bytes the operation Index needs
   function Needs (Index : Positive) return Length
   is (case Index is
         when 1 .. 2   => 1,
         when 3 .. 11  => 2,
         when 12 .. 17 => 4,
         when 18 .. 25 => 8,
         when others   => 0);

   procedure Try (Index : Positive; Target : in out Bytes; W : in out Writer) is
   begin
      case Index is
         when 1      =>
            Write_U1 (Target, W, 16#12#);

         when 2      =>
            Write_S1 (Target, W, -3);

         when 3      =>
            Write_U2le (Target, W, 16#1234#);

         when 4      =>
            Write_U2be (Target, W, 16#1234#);

         when 5      =>
            Write_U2 (Target, W, Little_Endian, 16#1234#);

         when 6      =>
            Write_S2le (Target, W, -3);

         when 7      =>
            Write_S2be (Target, W, -3);

         when 8      =>
            Write_S2 (Target, W, Big_Endian, -3);

         when 9      =>
            Write_U2 (Target, W, Big_Endian, 16#1234#);

         when 10     =>
            Write_S2 (Target, W, Little_Endian, -3);

         when 11     =>
            Write_S2le (Target, W, S16'First);

         when 12     =>
            Write_U4le (Target, W, 16#1234_5678#);

         when 13     =>
            Write_U4be (Target, W, 16#1234_5678#);

         when 14     =>
            Write_U4 (Target, W, Little_Endian, 16#1234_5678#);

         when 15     =>
            Write_S4le (Target, W, -3);

         when 16     =>
            Write_S4be (Target, W, -3);

         when 17     =>
            Write_S4 (Target, W, Big_Endian, -3);

         when 18     =>
            Write_U8le (Target, W, 16#1234_5678_9ABC_DEF0#);

         when 19     =>
            Write_U8be (Target, W, 16#1234_5678_9ABC_DEF0#);

         when 20     =>
            Write_U8 (Target, W, Little_Endian, 16#1234_5678_9ABC_DEF0#);

         when 21     =>
            Write_U8 (Target, W, Big_Endian, 16#1234_5678_9ABC_DEF0#);

         when 22     =>
            Write_S8le (Target, W, -3);

         when 23     =>
            Write_S8be (Target, W, -3);

         when 24     =>
            Write_S8 (Target, W, Little_Endian, -3);

         when 25     =>
            Write_S8 (Target, W, Big_Endian, -3);

         when others =>
            null;
      end case;
   end Try;

   procedure Test_Capacity is
      Buf : Bytes (1 .. 24);
      W   : Writer;
      Bad : Natural := 0;
   begin
      Group ("Writers capacity");
      for Index in 1 .. Operations loop
         declare
            Need : constant Length := Needs (Index);
         begin
            --  One byte short: nothing is written, the writer fails and
            --  stays where it was
            Buf := (others => Marker);
            W := Open (Buf (6 .. 5 + Need - 1));
            Try (Index, Buf, W);
            if Status (W) /= Capacity_Exceeded or else Pos (W) /= 0 or else not Is_Marker (Buf) then
               Bad := Bad + 1;
            end if;

            --  Sticky: even a byte that would fit is not written afterwards
            Write_U1 (Buf, W, 1);
            if Status (W) /= Capacity_Exceeded or else Pos (W) /= 0 or else not Is_Marker (Buf) then
               Bad := Bad + 1;
            end if;

            --  Exactly enough: it works, and only the window is touched
            Buf := (others => Marker);
            W := Open (Buf (6 .. 5 + Need));
            Try (Index, Buf, W);
            if not OK (W)
              or else Pos (W) /= Need
              or else Remaining (W) /= 0
              or else not Is_Marker (Buf (1 .. 5))
              or else Is_Marker (Buf (6 .. 5 + Need))
              or else not Is_Marker (Buf (6 + Need .. 24))
            then
               Bad := Bad + 1;
            end if;

            --  Once the window is full the next write fails
            Try (Index, Buf, W);
            if Status (W) /= Capacity_Exceeded or else Pos (W) /= Need then
               Bad := Bad + 1;
            end if;

            --  Partly used: the field that does not fit is not written at
            --  all, and what was written before stays
            Buf := (others => Marker);
            W := Open (Buf (6 .. 5 + Need));
            Write_U1 (Buf, W, 16#77#);
            if Need > 1 then
               Try (Index, Buf, W);
               if Status (W) /= Capacity_Exceeded
                 or else Pos (W) /= 1
                 or else Buf (6) /= 16#77#
                 or else not Is_Marker (Buf (7 .. 24))
               then
                  Bad := Bad + 1;
               end if;
            end if;
         end;
      end loop;
      Check (Bad = 0, "every integer write fails cleanly when the space is short");
   end Test_Capacity;

   ---------------------------------------------------------------------
   --  Seek, skip, written
   ---------------------------------------------------------------------

   procedure Test_Position is
      Buf : Bytes (11 .. 22) := (others => Marker);
      W   : Writer := Open (Buf);
      S   : Stream;
      V   : U32;
   begin
      Group ("Writers position");
      Write_U4le (Buf, W, 16#0403_0201#);
      Check (Written (W) = (First => 11, Last => 14), "written after four bytes");
      Seek (W, 1);
      Check (OK (W) and then Pos (W) = 1 and then Next_Index (W) = 12, "seek back");
      Check (Written (W) = (First => 11, Last => 14), "seeking back does not shorten what is written");
      Write_U1 (Buf, W, 16#99#);
      Check (Buf (11 .. 14) = (1, 16#99#, 3, 4), "patching a byte");
      Check (Written (W) = (First => 11, Last => 14), "still four bytes written");
      Seek (W, 0);
      Write_U2be (Buf, W, 16#AABB#);
      Check (Buf (11 .. 14) = (16#AA#, 16#BB#, 3, 4) and then Pos (W) = 2, "patching at the start");

      Seek (W, 8);
      Check (OK (W) and then Pos (W) = 8, "seek forward beyond what is written");
      Check (Buf (15 .. 22) = (1 .. 8 => Marker), "the bytes in between are not touched");
      Check (Written (W) = (First => 11, Last => 18), "but written includes them");
      Seek (W, 12);
      Check (OK (W) and then Pos (W) = 12 and then Remaining (W) = 0, "seek to the end");
      Seek (W, 13);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 12, "seek beyond the end fails and stays");
      Seek (W, 0);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 12, "a failed writer does not seek");

      Group ("Writers skip");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_U1 (Buf, W, 7);
      Skip (Buf, W, 3);
      Check (OK (W) and then Pos (W) = 4, "skip moves on");
      Check (Buf (11 .. 14) = (7, 0, 0, 0) and then Is_Marker (Buf (15 .. 22)), "skip writes zeros");
      Check (Written (W) = (First => 11, Last => 14), "skipped bytes are written");
      Skip (Buf, W, 0);
      Check (OK (W) and then Pos (W) = 4, "skipping nothing");
      Skip (Buf, W, 9);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 4, "skip beyond the end fails and stays");
      Check (Is_Marker (Buf (15 .. 22)), "and writes nothing");

      Group ("Writers read back");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_U4be (Buf, W, 16#0A0B_0C0D#);
      Write_U4le (Buf, W, 16#0A0B_0C0D#);
      S := Open (Buf (Written (W).First .. Written (W).Last));
      Read_U4be (Buf, S, V);
      Check (V = 16#0A0B_0C0D# and then OK (S), "the written part is read back, big endian");
      Read_U4le (Buf, S, V);
      Check (V = 16#0A0B_0C0D# and then Is_EOF (S), "and little endian, up to the end of what was written");
   end Test_Position;

   ---------------------------------------------------------------------
   --  Round trips of integers through the reader
   ---------------------------------------------------------------------

   generic
      type T is private;
      type Vec is array (Positive range <>) of T;
      Width : Length;
      with procedure Put_Le (Target : in out Bytes; W : in out Writer; Value : T);
      with procedure Put_Be (Target : in out Bytes; W : in out Writer; Value : T);
      with procedure Put (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : T);
      with procedure Get_Le (Buffer : Bytes; S : in out Stream; Value : out T);
      with procedure Get_Be (Buffer : Bytes; S : in out Stream; Value : out T);
      with procedure Get (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out T);
   procedure Round_Trip (Values : Vec; What : String);

   procedure Round_Trip (Values : Vec; What : String) is
      Count     : constant Length := Length (Values'Length);
      Per_Value : constant Length := 4 * Width;
      Total     : constant Length := Per_Value * Count;
      Buf       : Bytes (21 .. 21 + Total + 3) := (others => Marker);
      W         : Writer := Open (Buf);
      S         : Stream;
      V         : T;
      Wrong     : Natural := 0;
      Mirrored  : Boolean := True;
   begin
      Group (What);
      for K in Values'Range loop
         Put_Le (Buf, W, Values (K));
         Put_Be (Buf, W, Values (K));
         Put (Buf, W, Little_Endian, Values (K));
         Put (Buf, W, Big_Endian, Values (K));
      end loop;
      Check (OK (W) and then Pos (W) = Total, "all values written");
      Check (Written (W) = (First => 21, Last => 20 + Total), "extent");
      Check (Is_Marker (Buf (21 + Total .. Buf'Last)), "nothing behind");

      --  Little and big endian are each other's mirror image
      for K in 0 .. Count - 1 loop
         for B in 0 .. Width - 1 loop
            declare
               Base : constant Length := 21 + K * Per_Value;
            begin
               if Buf (Base + B) /= Buf (Base + Width + (Width - 1 - B))
                 or else Buf (Base + 2 * Width + B) /= Buf (Base + B)
                 or else Buf (Base + 3 * Width + B) /= Buf (Base + Width + B)
               then
                  Mirrored := False;
               end if;
            end;
         end loop;
      end loop;
      Check (Mirrored, "little endian is big endian reversed, with and without the order parameter");

      S := Open (Buf (Written (W).First .. Written (W).Last));
      for K in Values'Range loop
         Get_Le (Buf, S, V);
         Wrong := Wrong + (if V = Values (K) then 0 else 1);
         Get_Be (Buf, S, V);
         Wrong := Wrong + (if V = Values (K) then 0 else 1);
         Get (Buf, S, Little_Endian, V);
         Wrong := Wrong + (if V = Values (K) then 0 else 1);
         Get (Buf, S, Big_Endian, V);
         Wrong := Wrong + (if V = Values (K) then 0 else 1);
      end loop;
      Check (OK (S) and then Is_EOF (S), "the reader consumes exactly what was written");
      Check (Wrong = 0, "the reader delivers the values written");
   end Round_Trip;

   type U8_Vec is array (Positive range <>) of U8;
   type S8_Vec is array (Positive range <>) of S8;
   type U16_Vec is array (Positive range <>) of U16;
   type S16_Vec is array (Positive range <>) of S16;
   type U32_Vec is array (Positive range <>) of U32;
   type S32_Vec is array (Positive range <>) of S32;
   type U64_Vec is array (Positive range <>) of U64;
   type S64_Vec is array (Positive range <>) of S64;

   --  Byte writes have no byte order; adapters give them the shape the
   --  generic wants
   procedure Put_U1_Any (Target : in out Bytes; W : in out Writer; Value : U8) is
   begin
      Write_U1 (Target, W, Value);
   end Put_U1_Any;

   procedure Put_U1_Order (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : U8) is
      pragma Unreferenced (Order);
   begin
      Write_U1 (Target, W, Value);
   end Put_U1_Order;

   procedure Get_U1_Any (Buffer : Bytes; S : in out Stream; Value : out U8) is
   begin
      Read_U1 (Buffer, S, Value);
   end Get_U1_Any;

   procedure Get_U1_Order (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out U8) is
      pragma Unreferenced (Order);
   begin
      Read_U1 (Buffer, S, Value);
   end Get_U1_Order;

   procedure Put_S1_Any (Target : in out Bytes; W : in out Writer; Value : S8) is
   begin
      Write_S1 (Target, W, Value);
   end Put_S1_Any;

   procedure Put_S1_Order (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : S8) is
      pragma Unreferenced (Order);
   begin
      Write_S1 (Target, W, Value);
   end Put_S1_Order;

   procedure Get_S1_Any (Buffer : Bytes; S : in out Stream; Value : out S8) is
   begin
      Read_S1 (Buffer, S, Value);
   end Get_S1_Any;

   procedure Get_S1_Order (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out S8) is
      pragma Unreferenced (Order);
   begin
      Read_S1 (Buffer, S, Value);
   end Get_S1_Order;

   procedure Round_U1 is new
     Round_Trip (U8, U8_Vec, 1, Put_U1_Any, Put_U1_Any, Put_U1_Order, Get_U1_Any, Get_U1_Any, Get_U1_Order);
   procedure Round_S1 is new
     Round_Trip (S8, S8_Vec, 1, Put_S1_Any, Put_S1_Any, Put_S1_Order, Get_S1_Any, Get_S1_Any, Get_S1_Order);
   procedure Round_U2 is new
     Round_Trip (U16, U16_Vec, 2, Write_U2le, Write_U2be, Write_U2, Read_U2le, Read_U2be, Read_U2);
   procedure Round_S2 is new
     Round_Trip (S16, S16_Vec, 2, Write_S2le, Write_S2be, Write_S2, Read_S2le, Read_S2be, Read_S2);
   procedure Round_U4 is new
     Round_Trip (U32, U32_Vec, 4, Write_U4le, Write_U4be, Write_U4, Read_U4le, Read_U4be, Read_U4);
   procedure Round_S4 is new
     Round_Trip (S32, S32_Vec, 4, Write_S4le, Write_S4be, Write_S4, Read_S4le, Read_S4be, Read_S4);
   procedure Round_U8 is new
     Round_Trip (U64, U64_Vec, 8, Write_U8le, Write_U8be, Write_U8, Read_U8le, Read_U8be, Read_U8);
   procedure Round_S8 is new
     Round_Trip (S64, S64_Vec, 8, Write_S8le, Write_S8be, Write_S8, Read_S8le, Read_S8be, Read_S8);

   procedure Test_Round_Trips is
   begin
      Round_U1 ((0, 1, 16#7F#, 16#80#, 16#FF#, 16#A5#), "Writers round trip u1");
      Round_S1 ((S8'First, -2, -1, 0, 1, S8'Last), "Writers round trip s1");
      Round_U2 ((0, 1, 16#00FF#, 16#0100#, 16#7FFF#, 16#8000#, 16#FFFF#, 16#1234#), "Writers round trip u2");
      Round_S2 ((S16'First, -256, -2, -1, 0, 1, 255, S16'Last), "Writers round trip s2");
      Round_U4
        ((0, 1, 16#0000_FFFF#, 16#0001_0000#, 16#7FFF_FFFF#, 16#8000_0000#, U32'Last, 16#1234_5678#),
         "Writers round trip u4");
      Round_S4 ((S32'First, -65_536, -2, -1, 0, 1, 65_535, S32'Last), "Writers round trip s4");
      Round_U8
        ((0, 1, 16#FFFF_FFFF#, 16#1_0000_0000#, 16#7FFF_FFFF_FFFF_FFFF#, 16#8000_0000_0000_0000#, U64'Last),
         "Writers round trip u8");
      Round_S8
        ((S64'First, -4_294_967_296, -2, -1, 0, 1, 4_294_967_295, S64'Last, -16#0123_4567_89AB_CDEF#),
         "Writers round trip s8");
   end Test_Round_Trips;

   ---------------------------------------------------------------------
   --  Encoding
   ---------------------------------------------------------------------

   procedure Test_Encoding is
      use Kaitai.Encoding;
      Buf : Bytes (7 .. 22) := (others => Marker);
   begin
      Group ("Encoding");
      Put_U8 (Buf, 7, 16#12#);
      Put_U16_LE (Buf, 8, 16#3456#);
      Put_U16_BE (Buf, 10, 16#789A#);
      Check (Buf (7 .. 11) = (16#12#, 16#56#, 16#34#, 16#78#, 16#9A#), "u8, u16 little and big endian");
      Put_U32_LE (Buf, 12, 16#0102_0304#);
      Put_U32_BE (Buf, 16, 16#0102_0304#);
      Check (Buf (12 .. 19) = (4, 3, 2, 1, 1, 2, 3, 4), "u32 little and big endian");
      Check (Is_Marker (Buf (20 .. 22)) and then Buf (7) = 16#12#, "nothing else changes");
      Put_U64_LE (Buf, 7, 16#0102_0304_0506_0708#);
      Check (Buf (7 .. 14) = (8, 7, 6, 5, 4, 3, 2, 1), "u64 little endian");
      Put_U64_BE (Buf, 15, 16#0102_0304_0506_0708#);
      Check (Buf (15 .. 22) = (1, 2, 3, 4, 5, 6, 7, 8) and then Buf (7) = 8, "u64 big endian");
      Check
        (Kaitai.Decoding.U64_LE (Buf, 7) = 16#0102_0304_0506_0708#
         and then Kaitai.Decoding.U64_BE (Buf, 15) = 16#0102_0304_0506_0708#,
         "Decoding reads back what was put");

      Check (To_U8 (-1) = 255 and then To_U8 (S8'First) = 128 and then To_U8 (S8'Last) = 127, "to u8");
      Check (To_U16 (-1) = 16#FFFF# and then To_U16 (S16'First) = 16#8000# and then To_U16 (5) = 5, "to u16");
      Check (To_U32 (-1) = U32'Last and then To_U32 (S32'First) = 16#8000_0000# and then To_U32 (7) = 7, "to u32");
      Check
        (To_U64 (-1) = U64'Last
         and then To_U64 (S64'First) = 16#8000_0000_0000_0000#
         and then To_U64 (S64'Last) = 16#7FFF_FFFF_FFFF_FFFF#
         and then To_U64 (0) = 0,
         "to u64");
      Check
        (Kaitai.Decoding.To_S8 (To_U8 (-77)) = -77
         and then Kaitai.Decoding.To_S16 (To_U16 (-7777)) = -7777
         and then Kaitai.Decoding.To_S32 (To_U32 (-777_777)) = -777_777
         and then Kaitai.Decoding.To_S64 (To_U64 (-7_777_777_777)) = -7_777_777_777,
         "to signed gives the value back");
   end Test_Encoding;

   ---------------------------------------------------------------------
   --  Bit fields
   ---------------------------------------------------------------------

   type Bit_Order is (Big, Little);

   procedure Put_Bits (Target : in out Bytes; W : in out Writer; Order : Bit_Order; Count : Bit_Count; Value : U64) is
   begin
      case Order is
         when Big    =>
            Write_Bits_Int_Be (Target, W, Count, Value);

         when Little =>
            Write_Bits_Int_Le (Target, W, Count, Value);
      end case;
   end Put_Bits;

   procedure Get_Bits (Buffer : Bytes; S : in out Stream; Order : Bit_Order; Count : Bit_Count; Value : out U64) is
   begin
      case Order is
         when Big    =>
            Read_Bits_Int_Be (Buffer, S, Count, Value);

         when Little =>
            Read_Bits_Int_Le (Buffer, S, Count, Value);
      end case;
   end Get_Bits;

   --  Reference model: the target as a sequence of single bits.  Bit number
   --  K is in byte K / 8.  In big endian order the most significant bit of a
   --  byte is filled first and the first bit written is the most significant
   --  bit of the value; in little endian order it is the other way round.
   procedure Model_Put (Data : in out Bytes; Order : Bit_Order; From : Natural; Count : Bit_Count; Value : U64) is
      Octet : Length;
      Shift : Natural;
      Bit   : U8;
   begin
      for I in 0 .. Count - 1 loop
         Octet := Data'First + Length ((From + I) / 8);
         case Order is
            when Big    =>
               Bit := U8 (Shift_Right (Value, Count - 1 - I) and 1);
               Shift := 7 - (From + I) mod 8;

            when Little =>
               Bit := U8 (Shift_Right (Value, I) and 1);
               Shift := (From + I) mod 8;
         end case;
         Data (Octet) := (Data (Octet) and not Shift_Left (U8 (1), Shift)) or Shift_Left (Bit, Shift);
      end loop;
   end Model_Put;

   procedure Test_Bit_Examples is
      Buf : Bytes (3 .. 12) := (others => Marker);
      W   : Writer := Open (Buf);
      S   : Stream;
      V   : U64;
   begin
      Group ("Writers bits big endian");
      Write_Bits_Int_Be (Buf, W, 3, 2#101#);
      Check (OK (W) and then Pos (W) = 1 and then Bits_Free (W) = 5 and then Next_Index (W) = 4, "first three bits");
      Check (Buf (3) = 2#1010_0000#, "the free bits of the byte are zero, not the marker");
      Check (Written (W) = (First => 3, Last => 3), "a byte begun belongs to written");
      Write_Bits_Int_Be (Buf, W, 5, 2#01100#);
      Check (Buf (3) = 2#1010_1100# and then Pos (W) = 1 and then Bits_Free (W) = 0, "rest of the byte");
      Write_Bits_Int_Be (Buf, W, 4, 2#1111#);
      Check (Buf (4) = 2#1111_0000# and then Pos (W) = 2 and then Bits_Free (W) = 4, "half of the next byte");
      Write_Bits_Int_Be (Buf, W, 12, 16#012#);
      Check (Buf (4 .. 5) = (2#1111_0000#, 16#12#) and then Pos (W) = 3 and then Bits_Free (W) = 0, "across");
      Check (Is_Marker (Buf (6 .. 12)), "nothing behind");

      Group ("Writers bits little endian");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_Bits_Int_Le (Buf, W, 3, 2#100#);
      Check (Pos (W) = 1 and then Bits_Free (W) = 5 and then Buf (3) = 2#0000_0100#, "first three bits");
      Write_Bits_Int_Le (Buf, W, 5, 2#10101#);
      Check (Buf (3) = 2#1010_1100# and then Bits_Free (W) = 0, "rest of the byte");
      Write_Bits_Int_Le (Buf, W, 4, 0);
      Check (Buf (4) = 0 and then Pos (W) = 2 and then Bits_Free (W) = 4, "low half of the next byte");
      Write_Bits_Int_Le (Buf, W, 12, 16#12F#);
      Check (Buf (4 .. 5) = (16#F0#, 16#12#) and then Pos (W) = 3 and then Bits_Free (W) = 0, "across");

      Group ("Writers bits alignment");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_Bits_Int_Be (Buf, W, 3, 2#101#);
      Align_To_Byte (W);
      Check (Bits_Free (W) = 0 and then Pos (W) = 1 and then Buf (3) = 2#1010_0000#, "align ends the byte with zeros");
      Write_Bits_Int_Be (Buf, W, 4, 2#1111#);
      Check (Buf (4) = 2#1111_0000#, "the next bit field starts at the byte boundary");
      Write_U1 (Buf, W, 16#12#);
      Check (Buf (5) = 16#12# and then Bits_Free (W) = 0 and then Pos (W) = 3, "a byte write starts at the next byte");
      Check (Buf (4) = 2#1111_0000#, "and leaves the free bits zero");
      Write_Bits_Int_Be (Buf, W, 4, 3);
      Seek (W, 3);
      Check (Bits_Free (W) = 0, "seek ends a bit field");
      Write_Bits_Int_Be (Buf, W, 2, 3);
      Skip (Buf, W, 1);
      Check (Bits_Free (W) = 0 and then Pos (W) = 5 and then Buf (6) = 2#1100_0000# and then Buf (7) = 0, "skip too");
      Write_Bits_Int_Le (Buf, W, 2, 1);
      Write_U2le (Buf, W, 16#0201#);
      Check (Buf (8) = 1 and then Buf (9 .. 10) = (1, 2) and then Pos (W) = 8, "a field after a bit field");
      Check (Is_Marker (Buf (11 .. 12)), "nothing behind");

      Group ("Writers bits free bits");
      --  The bits a bit field has left free are zero, even if the caller
      --  touched the byte in between
      Buf := (others => Marker);
      W := Open (Buf);
      Write_Bits_Int_Be (Buf, W, 3, 2#101#);
      Buf (3) := 16#FF#;
      Write_Bits_Int_Be (Buf, W, 2, 0);
      Check (Buf (3) = 2#1110_0000# and then Bits_Free (W) = 3, "big endian, inside the byte begun");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_Bits_Int_Be (Buf, W, 3, 2#101#);
      Buf (3) := 16#FF#;
      Write_Bits_Int_Be (Buf, W, 7, 0);
      Check (Buf (3) = 2#1110_0000# and then Buf (4) = 0 and then Bits_Free (W) = 6, "big endian, across bytes");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_Bits_Int_Le (Buf, W, 3, 2#101#);
      Buf (3) := 16#FF#;
      Write_Bits_Int_Le (Buf, W, 2, 0);
      Check (Buf (3) = 2#0000_0111# and then Bits_Free (W) = 3, "little endian, inside the byte begun");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_Bits_Int_Le (Buf, W, 3, 2#101#);
      Buf (3) := 16#FF#;
      Write_Bits_Int_Le (Buf, W, 7, 0);
      Check (Buf (3) = 2#0000_0111# and then Buf (4) = 0 and then Bits_Free (W) = 6, "little endian, across bytes");

      Group ("Writers bits failure");
      Buf := (others => Marker);
      W := Open (Buf (3 .. 4));
      Write_Bits_Int_Be (Buf, W, 5, 2#11111#);
      Write_Bits_Int_Be (Buf, W, 4, 2#1010#);
      Check (OK (W) and then Pos (W) = 2 and then Bits_Free (W) = 7, "nine bits are in two bytes");
      Check (Buf (3 .. 4) = (2#1111_1101#, 2#0000_0000#), "the bits are where they belong");
      Write_Bits_Int_Be (Buf, W, 8, 1);
      Check
        (Status (W) = Capacity_Exceeded and then Pos (W) = 2 and then Bits_Free (W) = 7, "eight bits with seven free");
      Check (Buf (3 .. 4) = (2#1111_1101#, 2#0000_0000#) and then Is_Marker (Buf (5 .. 12)), "nothing was changed");
      Write_Bits_Int_Be (Buf, W, 1, 1);
      Check (Status (W) = Capacity_Exceeded and then Buf (4) = 0, "a failed writer does nothing");

      Buf := (others => Marker);
      W := Open (Buf (3 .. 12));
      Write_Bits_Int_Be (Buf, W, 3, 2#111#);
      Write_Bits_Int_Be (Buf, W, 3, 8);
      Check
        (Status (W) = Validation_Greater_Than and then Pos (W) = 1 and then Bits_Free (W) = 5,
         "a value that does not fit its bits fails");
      Check (Buf (3) = 2#1110_0000#, "and writes nothing");
      W := Open (Buf (3 .. 12));
      Write_Bits_Int_Le (Buf, W, 64, U64'Last);
      Check (OK (W) and then Pos (W) = 8, "sixty-four bits take eight bytes");
      Write_Bits_Int_Le (Buf, W, 1, 2);
      Check (Status (W) = Validation_Greater_Than, "two does not fit one bit");
      W := Open (Buf (3 .. 3));
      Write_Bits_Int_Le (Buf, W, 9, 300);
      Check (Status (W) = Capacity_Exceeded, "too little space is reported as such");
      W := Open (Buf (3 .. 3));
      Write_Bits_Int_Le (Buf, W, 9, 600);
      Check (Status (W) = Validation_Greater_Than, "and a value that does not fit comes first");

      Group ("Writers bits exact fit");
      --  The last bit of the window can be used, in both bit orders, and
      --  one bit more cannot
      for Order in Bit_Order loop
         Buf := (others => Marker);
         W := Open (Buf (3 .. 3));
         Put_Bits (Buf, W, Order, 8, 16#5A#);
         Check (OK (W) and then Pos (W) = 1 and then Bits_Free (W) = 0, "eight bits fit one byte");
         Buf := (others => Marker);
         W := Open (Buf (3 .. 4));
         Put_Bits (Buf, W, Order, 5, 16#15#);
         Put_Bits (Buf, W, Order, 11, 16#2AA#);
         Check (OK (W) and then Pos (W) = 2 and then Bits_Free (W) = 0, "five and eleven bits fit two bytes");
         Put_Bits (Buf, W, Order, 1, 1);
         Check (Status (W) = Capacity_Exceeded and then Pos (W) = 2, "and a bit more does not");
         Buf := (others => Marker);
         W := Open (Buf (3 .. 3));
         Put_Bits (Buf, W, Order, 3, 5);
         Put_Bits (Buf, W, Order, 5, 16#1F#);
         Check (OK (W) and then Pos (W) = 1 and then Bits_Free (W) = 0, "three and five bits fit one byte");
         Buf := (others => Marker);
         W := Open (Buf (3 .. 3));
         Put_Bits (Buf, W, Order, 3, 5);
         Put_Bits (Buf, W, Order, 6, 1);
         Check (Status (W) = Capacity_Exceeded and then Pos (W) = 1 and then Bits_Free (W) = 5, "three and six do not");
         Buf := (others => Marker);
         W := Open (Buf (3 .. 10));
         Put_Bits (Buf, W, Order, 64, U64'Last);
         Check (OK (W) and then Pos (W) = 8, "64 bits fit eight bytes");
         Buf := (others => Marker);
         W := Open (Buf (3 .. 10));
         Put_Bits (Buf, W, Order, 1, 1);
         Put_Bits (Buf, W, Order, 64, U64'Last);
         Check (Status (W) = Capacity_Exceeded and then Pos (W) = 1, "65 bits do not");
      end loop;

      Group ("Writers bits read back");
      Buf := (others => Marker);
      W := Open (Buf);
      Write_Bits_Int_Be (Buf, W, 7, 2#1010110#);
      Write_Bits_Int_Be (Buf, W, 64, 16#7809_1A2B_3C4D_5E6F#);
      Check (OK (W) and then Pos (W) = 9 and then Bits_Free (W) = 1, "64 bits after seven span nine bytes");
      S := Open (Buf (3 .. 11));
      Read_Bits_Int_Be (Buf, S, 7, V);
      Check (V = 2#1010110#, "seven bits read back");
      Read_Bits_Int_Be (Buf, S, 64, V);
      Check (V = 16#7809_1A2B_3C4D_5E6F# and then Pos (S) = 9 and then Bits_Left (S) = 1, "64 bits read back");
   end Test_Bit_Examples;

   --  Every width in several alignments, both orders, pseudo random values:
   --  the target equals the reference model, and the reader reads the
   --  values back
   procedure Test_Bit_Widths (Order : Bit_Order) is
      Buf    : Bytes (5 .. 20);
      Ref    : Bytes (5 .. 20);
      W      : Writer;
      S      : Stream;
      Lead_V : U64;
      V      : U64;
      Got    : U64;
      Wrong  : Natural := 0;
      Writes : Natural := 0;
   begin
      Group (if Order = Big then "Writers bit widths, big endian" else "Writers bit widths, little endian");
      for Lead in 0 .. 7 loop
         for Count in Bit_Count loop
            for Trial in 1 .. 6 loop
               Lead_V := Next and Mask (Lead);
               V :=
                 (case Trial is
                    when 1      => 0,
                    when 2      => Mask (Count),
                    when 3      => 1,
                    when 4      => Shift_Left (1, Count - 1),
                    when others => Next and Mask (Count));
               Buf := (others => Marker);
               W := Open (Buf);
               if Lead > 0 then
                  Put_Bits (Buf, W, Order, Lead, Lead_V);
               end if;
               Put_Bits (Buf, W, Order, Count, V);
               Writes := Writes + 1;
               declare
                  Bits : constant Natural := Lead + Count;
               begin
                  --  The model: the bytes that are touched are zero apart
                  --  from the bits written; the others keep the marker
                  Ref := (others => Marker);
                  for B in 0 .. (Bits - 1) / 8 loop
                     Ref (5 + Length (B)) := 0;
                  end loop;
                  if Lead > 0 then
                     Model_Put (Ref, Order, 0, Lead, Lead_V);
                  end if;
                  Model_Put (Ref, Order, Lead, Count, V);

                  if not OK (W)
                    or else Natural (Pos (W)) /= (Bits + 7) / 8
                    or else Bits_Free (W) /= (8 - Bits mod 8) mod 8
                    or else Natural (Size (Written (W))) /= (Bits + 7) / 8
                    or else Buf /= Ref
                  then
                     Wrong := Wrong + 1;
                  end if;

                  S := Open (Buf (Written (W).First .. Written (W).Last));
                  if Lead > 0 then
                     Get_Bits (Buf, S, Order, Lead, Got);
                     if Got /= Lead_V then
                        Wrong := Wrong + 1;
                     end if;
                  end if;
                  Get_Bits (Buf, S, Order, Count, Got);
                  if not OK (S) or else Got /= V or else Pos (S) /= Pos (W) or else Bits_Left (S) /= Bits_Free (W) then
                     Wrong := Wrong + 1;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
      Check (Writes = 8 * 64 * 6, "all combinations were written");
      Check (Wrong = 0, "target, position and bits free agree with the model, and the reader reads the values back");
   end Test_Bit_Widths;

   ---------------------------------------------------------------------
   --  A mixture of everything, written and read back
   ---------------------------------------------------------------------

   type Kind is
     (Bits_Be,
      Bits_Le,
      Align,
      Byte_1,
      Signed_1,
      Un_2le,
      Un_2be,
      Si_2be,
      Un_4le,
      Un_4be,
      Si_4le,
      Un_8le,
      Un_8be,
      Si_8be,
      Raw);

   type Operation is record
      What  : Kind := Align;
      Count : Bit_Count := 1;
      Value : U64 := 0;
   end record;

   Max_Operations : constant := 12;

   type Program is array (1 .. Max_Operations) of Operation;

   function Pattern (Value : U64; Index : Natural) return U8
   is (U8 (Shift_Right (Value, 8 * (Index mod 8)) and 16#FF#));

   procedure Test_Mixed is
      Buf       : Bytes (31 .. 31 + 127);
      Prog      : Program;
      Used      : Natural;
      Last_Bits : Kind := Align;
      W         : Writer;
      S         : Stream;
      Wrong     : Natural := 0;
      Fields    : Natural := 0;
      Raw_Out   : Bytes (1 .. 5);
      Slc       : Slice;
      B8        : U8;
      B16       : U16;
      B32       : U32;
      B64       : U64;
      V64       : U64;
      I8        : S8;
      I16       : S16;
      I32       : S32;
      I64       : S64;
   begin
      Group ("Writers mixed");
      for Round in 1 .. 300 loop
         --  Make a program of fields of all kinds.  Bit fields of the other
         --  bit order need an alignment in between.
         Used := 0;
         Last_Bits := Align;
         while Used < Max_Operations - 1 loop
            declare
               Pick : constant Natural := Natural (Next mod 15);
               K    : constant Kind := Kind'Val (Pick);
               Op   : Operation;
            begin
               Op.What := K;
               Op.Value := Next;
               Op.Count := Natural (Next mod 64) + 1;
               if Next mod 3 = 0 then
                  Op.Count := Natural (Next mod 9) + 1;
               end if;
               if K in Bits_Be | Bits_Le then
                  Op.Value := Op.Value and Mask (Op.Count);
                  if Last_Bits /= Align and then Last_Bits /= K then
                     Used := Used + 1;
                     Prog (Used) := (What => Align, Count => 1, Value => 0);
                  end if;
                  Last_Bits := K;
               elsif K = Align or else K in Byte_1 .. Raw then
                  Last_Bits := Align;
               end if;
               if K = Raw then
                  Op.Count := Natural (Next mod 5) + 1;
               end if;
               Used := Used + 1;
               Prog (Used) := Op;
            end;
         end loop;

         Buf := (others => Marker);
         W := Open (Buf);
         for I in 1 .. Used loop
            declare
               Op : Operation renames Prog (I);
            begin
               case Op.What is
                  when Bits_Be  =>
                     Write_Bits_Int_Be (Buf, W, Op.Count, Op.Value);

                  when Bits_Le  =>
                     Write_Bits_Int_Le (Buf, W, Op.Count, Op.Value);

                  when Align    =>
                     Align_To_Byte (W);

                  when Byte_1   =>
                     Write_U1 (Buf, W, U8 (Op.Value and 16#FF#));

                  when Signed_1 =>
                     Write_S1 (Buf, W, Kaitai.Decoding.To_S8 (U8 (Op.Value and 16#FF#)));

                  when Un_2le   =>
                     Write_U2le (Buf, W, U16 (Op.Value and 16#FFFF#));

                  when Un_2be   =>
                     Write_U2be (Buf, W, U16 (Op.Value and 16#FFFF#));

                  when Si_2be   =>
                     Write_S2be (Buf, W, Kaitai.Decoding.To_S16 (U16 (Op.Value and 16#FFFF#)));

                  when Un_4le   =>
                     Write_U4le (Buf, W, U32 (Op.Value and 16#FFFF_FFFF#));

                  when Un_4be   =>
                     Write_U4be (Buf, W, U32 (Op.Value and 16#FFFF_FFFF#));

                  when Si_4le   =>
                     Write_S4le (Buf, W, Kaitai.Decoding.To_S32 (U32 (Op.Value and 16#FFFF_FFFF#)));

                  when Un_8le   =>
                     Write_U8le (Buf, W, Op.Value);

                  when Un_8be   =>
                     Write_U8be (Buf, W, Op.Value);

                  when Si_8be   =>
                     Write_S8be (Buf, W, Kaitai.Decoding.To_S64 (Op.Value));

                  when Raw      =>
                     for K in 1 .. Op.Count loop
                        Raw_Out (Length (K)) := Pattern (Op.Value, K);
                     end loop;
                     Write_Bytes (Buf, W, Raw_Out (1 .. Length (Op.Count)));
               end case;
            end;
         end loop;
         Fields := Fields + Used;

         if not OK (W) or else Natural (Size (Written (W))) /= Natural (Pos (W)) then
            Wrong := Wrong + 1;
         end if;

         S := Open (Buf (Written (W).First .. Written (W).Last));
         for I in 1 .. Used loop
            declare
               Op : Operation renames Prog (I);
            begin
               case Op.What is
                  when Bits_Be  =>
                     Read_Bits_Int_Be (Buf, S, Op.Count, V64);
                     Wrong := Wrong + (if V64 = Op.Value then 0 else 1);

                  when Bits_Le  =>
                     Read_Bits_Int_Le (Buf, S, Op.Count, V64);
                     Wrong := Wrong + (if V64 = Op.Value then 0 else 1);

                  when Align    =>
                     Align_To_Byte (S);

                  when Byte_1   =>
                     Read_U1 (Buf, S, B8);
                     Wrong := Wrong + (if B8 = U8 (Op.Value and 16#FF#) then 0 else 1);

                  when Signed_1 =>
                     Read_S1 (Buf, S, I8);
                     Wrong := Wrong + (if I8 = Kaitai.Decoding.To_S8 (U8 (Op.Value and 16#FF#)) then 0 else 1);

                  when Un_2le   =>
                     Read_U2le (Buf, S, B16);
                     Wrong := Wrong + (if B16 = U16 (Op.Value and 16#FFFF#) then 0 else 1);

                  when Un_2be   =>
                     Read_U2be (Buf, S, B16);
                     Wrong := Wrong + (if B16 = U16 (Op.Value and 16#FFFF#) then 0 else 1);

                  when Si_2be   =>
                     Read_S2be (Buf, S, I16);
                     Wrong := Wrong + (if I16 = Kaitai.Decoding.To_S16 (U16 (Op.Value and 16#FFFF#)) then 0 else 1);

                  when Un_4le   =>
                     Read_U4le (Buf, S, B32);
                     Wrong := Wrong + (if B32 = U32 (Op.Value and 16#FFFF_FFFF#) then 0 else 1);

                  when Un_4be   =>
                     Read_U4be (Buf, S, B32);
                     Wrong := Wrong + (if B32 = U32 (Op.Value and 16#FFFF_FFFF#) then 0 else 1);

                  when Si_4le   =>
                     Read_S4le (Buf, S, I32);
                     Wrong :=
                       Wrong + (if I32 = Kaitai.Decoding.To_S32 (U32 (Op.Value and 16#FFFF_FFFF#)) then 0 else 1);

                  when Un_8le   =>
                     Read_U8le (Buf, S, B64);
                     Wrong := Wrong + (if B64 = Op.Value then 0 else 1);

                  when Un_8be   =>
                     Read_U8be (Buf, S, B64);
                     Wrong := Wrong + (if B64 = Op.Value then 0 else 1);

                  when Si_8be   =>
                     Read_S8be (Buf, S, I64);
                     Wrong := Wrong + (if I64 = Kaitai.Decoding.To_S64 (Op.Value) then 0 else 1);

                  when Raw      =>
                     Read_Bytes (S, Length (Op.Count), Slc);
                     for K in 1 .. Op.Count loop
                        if Buf (Slc.First + Length (K - 1)) /= Pattern (Op.Value, K) then
                           Wrong := Wrong + 1;
                        end if;
                     end loop;
               end case;
            end;
         end loop;
         if not OK (S) or else Pos (S) /= Pos (W) or else Bits_Left (S) /= Bits_Free (W) then
            Wrong := Wrong + 1;
         end if;
      end loop;
      Check (Fields > 3_000, "enough fields were written");
      Check (Wrong = 0, "the reader reads back every field, and ends where the writer did");
   end Test_Mixed;

   ---------------------------------------------------------------------
   --  Byte arrays
   ---------------------------------------------------------------------

   procedure Test_Bytes is
      Buf  : Bytes (2 .. 25) := (others => Marker);
      Src  : constant Bytes (40 .. 44) := (1, 2, 3, 4, 5);
      Zero : constant Bytes (7 .. 6) := (others => 0);
      W    : Writer := Open (Buf (6 .. 15));
      S    : Stream;
      D    : Slice;
   begin
      Group ("Writers bytes");
      Write_Bytes (Buf, W, Src);
      Check (OK (W) and then Pos (W) = 5 and then Buf (6 .. 10) = (1, 2, 3, 4, 5), "bytes are copied");
      Check (Is_Marker (Buf (2 .. 5)) and then Is_Marker (Buf (11 .. 25)), "and nothing around them");
      Write_Bytes (Buf, W, Src (41 .. 42));
      Check (OK (W) and then Pos (W) = 7 and then Buf (11 .. 12) = (2, 3), "a slice, whose bounds do not start at one");
      Write_Bytes (Buf, W, Zero);
      Check (OK (W) and then Pos (W) = 7, "no bytes");
      Write_Bytes (Buf, W, Src);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 7, "five bytes do not fit into three");
      Check (Buf (13 .. 15) = (1 .. 3 => Marker), "and none is written");

      W := Open (Buf (6 .. 10));
      Write_U1 (Buf, W, 9);
      Write_Bits_Int_Be (Buf, W, 3, 7);
      Write_Bytes (Buf, W, Src (40 .. 42));
      Check (OK (W) and then Pos (W) = 5 and then Bits_Free (W) = 0, "bytes start at a byte boundary");
      Check (Buf (6 .. 10) = (9, 2#1110_0000#, 1, 2, 3), "after a bit field");

      Group ("Writers terminated bytes");
      Buf := (others => Marker);
      W := Open (Buf (6 .. 15));
      Write_Bytes_Term (Buf, W, Src (40 .. 42), 0);
      Check (OK (W) and then Pos (W) = 4 and then Buf (6 .. 9) = (1, 2, 3, 0), "bytes and the terminator");
      Check (Is_Marker (Buf (10 .. 25)) and then Is_Marker (Buf (2 .. 5)), "nothing around");
      Write_Bytes_Term (Buf, W, Zero, 9);
      Check (OK (W) and then Pos (W) = 5 and then Buf (10) = 9, "empty bytes and the terminator");
      Write_Bytes_Term (Buf, W, Src (40 .. 42), 2);
      Check (Status (W) = Validation_Expr and then Pos (W) = 5, "a terminator inside is refused");
      Check (Is_Marker (Buf (11 .. 25)), "and nothing is written");

      W := Open (Buf (6 .. 9));
      Write_Bytes_Term (Buf, W, Src (40 .. 42), 0);
      Check (OK (W) and then Remaining (W) = 0, "exactly enough room");
      W := Open (Buf (6 .. 8));
      Buf := (others => Marker);
      Write_Bytes_Term (Buf, W, Src (40 .. 42), 0);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 0 and then Is_Marker (Buf), "one byte short");
      Write_Bytes_Term (Buf, W, Src (40 .. 42), 3);
      Check (Status (W) = Capacity_Exceeded, "the first failure is kept");

      W := Open (Buf (6 .. 15));
      Write_Bytes_Term (Buf, W, Src (40 .. 43), 0);
      Write_Bytes_Term (Buf, W, Src (44 .. 44), 0);
      S := Open (Buf (Written (W).First .. Written (W).Last));
      Read_Bytes_Term (Buf, S, 0, Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (D = (First => 6, Last => 9) and then Pos (S) = 5, "the reader finds the first string");
      Read_Bytes_Term (Buf, S, 0, Include => False, Consume => True, EOS_Error => True, Data => D);
      Check (D = (First => 11, Last => 11) and then Is_EOF (S) and then OK (S), "and the second");

      Group ("Writers padded bytes");
      Buf := (others => Marker);
      W := Open (Buf (6 .. 15));
      Write_Padded (Buf, W, Src (40 .. 42), 6, 0);
      Check (OK (W) and then Pos (W) = 6 and then Buf (6 .. 11) = (1, 2, 3, 0, 0, 0), "padded with zeros");
      Check (Is_Marker (Buf (12 .. 25)) and then Is_Marker (Buf (2 .. 5)), "nothing around");
      Write_Padded (Buf, W, Src (40 .. 41), 2, 7);
      Check (OK (W) and then Pos (W) = 8 and then Buf (12 .. 13) = (1, 2), "as long as the size: no padding");
      Write_Padded (Buf, W, Zero, 2, 16#20#);
      Check (OK (W) and then Pos (W) = 10 and then Buf (14 .. 15) = (16#20#, 16#20#), "empty: only padding");
      Write_Padded (Buf, W, Zero, 0, 16#20#);
      Check (OK (W) and then Pos (W) = 10, "empty and size zero");
      Write_Padded (Buf, W, Zero, 1, 0);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 10, "the size does not fit");

      Buf := (others => Marker);
      W := Open (Buf (6 .. 15));
      Write_Padded (Buf, W, Src, 4, 0);
      Check (Status (W) = Validation_Greater_Than and then Pos (W) = 0, "the bytes are longer than the size");
      Check (Is_Marker (Buf), "and nothing is written");
      W := Open (Buf (6 .. 8));
      Write_Padded (Buf, W, Src, 4, 0);
      Check (Status (W) = Validation_Greater_Than, "that is a validation failure even if the space is short too");
      W := Open (Buf (6 .. 8));
      Write_Padded (Buf, W, Src (40 .. 41), 4, 0);
      Check (Status (W) = Capacity_Exceeded and then Is_Marker (Buf), "and a lack of space is a capacity failure");
   end Test_Bytes;

   ---------------------------------------------------------------------
   --  Subwriters
   ---------------------------------------------------------------------

   procedure Test_Subwriters is
      Buf : Bytes (11 .. 30) := (others => Marker);
      W   : Writer := Open (Buf (13 .. 28));
      Sub : Writer;
      Inn : Writer;
      S   : Stream;
      V   : U16;
   begin
      Group ("Writers subwriter");
      Write_U1 (Buf, W, 16#11#);
      Subwriter (Buf, W, 6, Sub);
      Check (OK (W) and then OK (Sub), "made");
      Check (Pos (W) = 7 and then Next_Index (W) = 20, "the parent is behind the window");
      Check (Size (Sub) = 6 and then Pos (Sub) = 0 and then Next_Index (Sub) = 14, "the window of the subwriter");
      Check (Buf (14 .. 19) = (1 .. 6 => 0), "the window is zero from the start");
      Check (Written (W) = (First => 13, Last => 19), "the parent has written the window");
      Check (Written (Sub) = (First => 14, Last => 13), "the subwriter has written nothing yet");
      Check (Is_Valid (Sub, Buf) and then not Same_Window (W, Sub), "valid, another window");
      Check (Is_Marker (Buf (11 .. 12)) and then Is_Marker (Buf (20 .. 30)), "nothing outside");

      Write_U2be (Buf, Sub, 16#ABCD#);
      Write_U1 (Buf, Sub, 16#EE#);
      Check
        (OK (Sub) and then Pos (Sub) = 3 and then Written (Sub) = (First => 14, Last => 16), "the field is written");
      Check (Buf (13 .. 19) = (16#11#, 16#AB#, 16#CD#, 16#EE#, 0, 0, 0), "the rest of the window stays zero");
      Join (W, Sub);
      Check (OK (W) and then Pos (W) = 7, "joining a good subwriter changes nothing");
      Write_U2le (Buf, W, 16#0302#);
      Check (Buf (20 .. 21) = (2, 3) and then Pos (W) = 9, "the parent continues behind the window");
      Check (Is_Marker (Buf (22 .. 30)), "and nothing is written beyond that");

      Group ("Writers subwriter bytes left over");
      Buf := (others => 16#FF#);
      W := Open (Buf (13 .. 28));
      Subwriter (Buf, W, 4, Sub);
      Write_U1 (Buf, Sub, 5);
      Check (Buf (13 .. 16) = (5, 0, 0, 0), "what the target held before does not show through");
      Seek (Sub, 3);
      Write_U1 (Buf, Sub, 8);
      Check (Buf (13 .. 16) = (5, 0, 0, 8) and then Written (Sub) = (First => 13, Last => 16), "seek in a subwriter");
      Seek (Sub, 5);
      Check (Status (Sub) = Capacity_Exceeded, "not beyond its window");
      Check (OK (W), "which the parent does not notice");

      Group ("Writers subwriter nested and bit fields");
      Buf := (others => Marker);
      W := Open (Buf (13 .. 28));
      Write_Bits_Int_Be (Buf, W, 3, 2#111#);
      Subwriter (Buf, W, 8, Sub);
      Check
        (OK (Sub) and then Pos (W) = 9 and then Bits_Free (W) = 0, "a subwriter after a bit field starts on a byte");
      Check (Buf (13) = 2#1110_0000# and then Buf (14 .. 21) = (1 .. 8 => 0), "the bit field byte is kept");
      Write_U1 (Buf, Sub, 1);
      Subwriter (Buf, Sub, 4, Inn);
      Write_U4le (Buf, Inn, 16#0403_0201#);
      Join (Sub, Inn);
      Write_U2be (Buf, Sub, 16#0506#);
      Join (W, Sub);
      Check (OK (W) and then Buf (14 .. 21) = (1, 1, 2, 3, 4, 5, 6, 0), "nested windows");

      Group ("Writers subwriter failure");
      Buf := (others => Marker);
      W := Open (Buf (13 .. 28));
      Subwriter (Buf, W, 2, Sub);
      Write_U4le (Buf, Sub, 1);
      Check (Status (Sub) = Capacity_Exceeded and then Pos (Sub) = 0, "the field is larger than its window");
      Check (Buf (13 .. 14) = (0, 0), "nothing of it is written");
      Check (OK (W), "the parent does not know yet");
      Join (W, Sub);
      Check (Status (W) = Capacity_Exceeded and then Pos (W) = 2, "Join hands the failure on, the position stays");
      Write_U1 (Buf, W, 1);
      Check (Is_Marker (Buf (15 .. 28)), "the parent is now failed and writes nothing");

      W := Open (Buf (13 .. 28));
      Fail (W, Validation_Expr);
      Subwriter (Buf, W, 2, Sub);
      Check (Status (Sub) = Validation_Expr and then Size (Sub) = 0 and then Pos (W) = 0, "a failed parent: no window");
      Fail (Sub, Validation_Not_Equal);
      Join (W, Sub);
      Check (Status (W) = Validation_Expr, "Join keeps the first failure of the parent");

      W := Open (Buf (13 .. 14));
      Subwriter (Buf, W, 3, Sub);
      Check
        (Status (W) = Capacity_Exceeded
         and then Status (Sub) = Capacity_Exceeded
         and then Size (Sub) = 0
         and then Pos (W) = 0,
         "a window that does not fit: both fail, the parent stays");
      Write_U1 (Buf, Sub, 1);
      Check (Status (Sub) = Capacity_Exceeded, "an empty subwriter has no room");

      W := Open (Buf (13 .. 28));
      Subwriter (Buf, W, 4, Sub);
      Fail (Sub, Validation_Less_Than);
      Join (W, Sub);
      Check (Status (W) = Validation_Less_Than and then Pos (W) = 4, "a failure of any kind is handed on");

      W := Open (Buf (13 .. 28));
      Subwriter (Buf, W, 4, Sub);
      Fail (W, Validation_Expr);
      Fail (Sub, Validation_Less_Than);
      Join (W, Sub);
      Check (Status (W) = Validation_Expr, "the parent's own failure comes first");
      W := Open (Buf (13 .. 28));
      Subwriter (Buf, W, 4, Sub);
      Fail (W, Validation_Expr);
      Join (W, Sub);
      Check
        (Status (W) = Validation_Expr and then not OK (W), "a good subwriter does not undo a failure of the parent");

      Group ("Writers subwriter read back");
      Buf := (others => Marker);
      W := Open (Buf (13 .. 28));
      Subwriter (Buf, W, 4, Sub);
      Write_U2le (Buf, Sub, 16#0102#);
      Subwriter (Buf, W, 0, Inn);
      Check (OK (Inn) and then Size (Inn) = 0 and then Pos (W) = 4, "a subwriter of no bytes");
      Write_U2le (Buf, W, 16#0304#);
      S := Open (Buf (Written (W).First .. Written (W).Last));
      Read_U2le (Buf, S, V);
      Check (V = 16#0102#, "the field of the subwriter is read back");
      Read_U2le (Buf, S, V);
      Check (V = 0, "its unwritten rest is zero");
      Read_U2le (Buf, S, V);
      Check (V = 16#0304# and then Is_EOF (S), "and the parent's field follows");
   end Test_Subwriters;

   procedure Run is
   begin
      Test_State;
      Test_Layout;
      Test_Capacity;
      Test_Position;
      Test_Round_Trips;
      Test_Encoding;
      Test_Bit_Examples;
      Test_Bit_Widths (Big);
      Test_Bit_Widths (Little);
      Test_Mixed;
      Test_Bytes;
      Test_Subwriters;
   end Run;

end Writers_Tests;
