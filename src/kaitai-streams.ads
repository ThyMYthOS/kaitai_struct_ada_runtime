--  The Kaitai Struct stream: positioning in a buffer and reading the
--  primitive types of the Kaitai Struct language from it.
--
--  A Stream is a cursor.  It does not hold the data; every operation that
--  looks at the data takes the buffer as a parameter.  A stream therefore
--  contains no pointer, can be copied freely, and several streams can view
--  the same buffer at once.  The caller keeps the buffer unchanged while
--  streams and slices refer to it.
--
--  No operation raises an exception.  An operation that cannot be carried
--  out records the reason in the stream, delivers a zero value and leaves
--  the position where it was.  The first failure is kept, and every later
--  operation on the stream does nothing.  It is therefore enough to look at
--  OK before a decision that depends on values read, and at the end.

with Kaitai.Decoding;
with Kaitai.Types; use Kaitai.Types;

package Kaitai.Streams
  with Pure, SPARK_Mode, Always_Terminates
is

   type Stream is private;

   ---------------------------------------------------------------------
   --  State
   ---------------------------------------------------------------------

   --  True if no operation on the stream has failed
   function OK (S : Stream) return Boolean;

   --  Success, or the reason of the first failure
   function Status (S : Stream) return Status_Kind
   with Post => (Status'Result = Success) = OK (S);

   --  Number of bytes the stream covers
   function Size (S : Stream) return Length;

   --  Number of bytes before the current position
   function Pos (S : Stream) return Length
   with Post => Pos'Result <= Size (S);

   --  Number of bytes from the current position to the end
   function Remaining (S : Stream) return Length
   is (Size (S) - Pos (S));

   --  True if no byte is left to read
   function Is_EOF (S : Stream) return Boolean
   is (Remaining (S) = 0);

   --  Index in the buffer of the byte the next read starts at
   function Next_Index (S : Stream) return Length
   with Post => Next_Index'Result >= 1;

   --  True if the stream lies inside Buffer.  This holds for the buffer a
   --  stream was opened on and is required by every operation that takes
   --  the buffer.
   function Is_Valid (S : Stream; Buffer : Bytes) return Boolean
   with Post => (if Is_Valid'Result then Decoding.Has (Buffer, Next_Index (S), Remaining (S)));

   --  True if Left and Right cover the same bytes
   function Same_Window (Left, Right : Stream) return Boolean
   with Post => (if Same_Window'Result then Size (Left) = Size (Right));

   --  What an attempt to consume Count bytes does to a stream: on success
   --  the position moves on by Count, otherwise the stream fails and stays
   --  where it was
   function Consumed (Before, After : Stream; Count : Length) return Boolean
   is (Same_Window (Before, After)
       and then (if OK (Before) and then Count <= Remaining (Before)
                 then
                   OK (After)
                   and then Pos (After) = Pos (Before) + Count
                   and then Next_Index (After) = Next_Index (Before) + Count
                 else
                   not OK (After)
                   and then Pos (After) = Pos (Before)
                   and then Next_Index (After) = Next_Index (Before)
                   and then Status (After) = (if OK (Before) then End_Of_Stream else Status (Before))))
   with Ghost;

   ---------------------------------------------------------------------
   --  Opening and positioning
   ---------------------------------------------------------------------

   --  A stream over all of Buffer, positioned at its start
   function Open (Buffer : Bytes) return Stream
   with
     Post =>
       Is_Valid (Open'Result, Buffer)
       and then OK (Open'Result)
       and then Pos (Open'Result) = 0
       and then Size (Open'Result) = Buffer'Length;

   --  Move to the position To, counted from the start of the stream.  Fails
   --  with End_Of_Stream if To is beyond the end.
   procedure Seek (S : in out Stream; To : Length)
   with
     Inline,
     Post =>
       Same_Window (S'Old, S)
       and then (if OK (S'Old) and then To <= Size (S'Old)
                 then OK (S) and then Pos (S) = To
                 else
                   not OK (S)
                   and then Pos (S) = Pos (S'Old)
                   and then Status (S) = (if OK (S'Old) then End_Of_Stream else Status (S'Old)));

   --  Move on by Count bytes.  Fails with End_Of_Stream if fewer are left.
   procedure Skip (S : in out Stream; Count : Length)
   with Inline, Post => Consumed (S'Old, S, Count);

   --  Move on by Count bytes that the caller knows to be there.  For use
   --  after one check of Remaining for a block of fixed size, whose fields
   --  are then decoded with Kaitai.Decoding at Next_Index.
   procedure Advance (S : in out Stream; Count : Length)
   with Inline, Pre => OK (S) and then Count <= Remaining (S), Post => Consumed (S'Old, S, Count);

   --  Record a failure that was found outside the stream, for example by a
   --  validation.  An earlier failure is kept.
   procedure Fail (S : in out Stream; Reason : Status_Kind)
   with
     Pre  => Reason /= Success,
     Post =>
       Same_Window (S'Old, S)
       and then not OK (S)
       and then Pos (S) = Pos (S'Old)
       and then Next_Index (S) = Next_Index (S'Old)
       and then Status (S) = (if OK (S'Old) then Reason else Status (S'Old));

   ---------------------------------------------------------------------
   --  Integers
   --
   --  Read_<sign><bytes><order>: u = unsigned, s = signed; 1, 2, 4 or 8
   --  bytes; le = little endian, be = big endian.  The names follow the
   --  Kaitai Struct stream API.  The variants without order in the name
   --  take it as a parameter, for formats that decide it at run time.
   ---------------------------------------------------------------------

   procedure Read_U1 (Buffer : Bytes; S : in out Stream; Value : out U8)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 1)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.U8_At (Buffer, Next_Index (S'Old)) else Value = 0);

   procedure Read_S1 (Buffer : Bytes; S : in out Stream; Value : out S8)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 1)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.To_S8 (Decoding.U8_At (Buffer, Next_Index (S'Old))) else Value = 0);

   procedure Read_U2le (Buffer : Bytes; S : in out Stream; Value : out U16)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 2)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.U16_LE (Buffer, Next_Index (S'Old)) else Value = 0);

   procedure Read_U2be (Buffer : Bytes; S : in out Stream; Value : out U16)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 2)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.U16_BE (Buffer, Next_Index (S'Old)) else Value = 0);

   procedure Read_U2 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out U16)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 2)
       and then Is_Valid (S, Buffer)
       and then (if OK (S)
                 then
                   Value
                   = (if Order = Little_Endian
                      then Decoding.U16_LE (Buffer, Next_Index (S'Old))
                      else Decoding.U16_BE (Buffer, Next_Index (S'Old)))
                 else Value = 0);

   procedure Read_S2le (Buffer : Bytes; S : in out Stream; Value : out S16)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 2)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.To_S16 (Decoding.U16_LE (Buffer, Next_Index (S'Old))) else Value = 0);

   procedure Read_S2be (Buffer : Bytes; S : in out Stream; Value : out S16)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 2)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.To_S16 (Decoding.U16_BE (Buffer, Next_Index (S'Old))) else Value = 0);

   procedure Read_S2 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out S16)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 2)
       and then Is_Valid (S, Buffer)
       and then (if OK (S)
                 then
                   Value
                   = Decoding.To_S16
                       (if Order = Little_Endian
                        then Decoding.U16_LE (Buffer, Next_Index (S'Old))
                        else Decoding.U16_BE (Buffer, Next_Index (S'Old)))
                 else Value = 0);

   procedure Read_U4le (Buffer : Bytes; S : in out Stream; Value : out U32)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 4)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.U32_LE (Buffer, Next_Index (S'Old)) else Value = 0);

   procedure Read_U4be (Buffer : Bytes; S : in out Stream; Value : out U32)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 4)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.U32_BE (Buffer, Next_Index (S'Old)) else Value = 0);

   procedure Read_U4 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out U32)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 4)
       and then Is_Valid (S, Buffer)
       and then (if OK (S)
                 then
                   Value
                   = (if Order = Little_Endian
                      then Decoding.U32_LE (Buffer, Next_Index (S'Old))
                      else Decoding.U32_BE (Buffer, Next_Index (S'Old)))
                 else Value = 0);

   procedure Read_S4le (Buffer : Bytes; S : in out Stream; Value : out S32)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 4)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.To_S32 (Decoding.U32_LE (Buffer, Next_Index (S'Old))) else Value = 0);

   procedure Read_S4be (Buffer : Bytes; S : in out Stream; Value : out S32)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 4)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.To_S32 (Decoding.U32_BE (Buffer, Next_Index (S'Old))) else Value = 0);

   procedure Read_S4 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out S32)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 4)
       and then Is_Valid (S, Buffer)
       and then (if OK (S)
                 then
                   Value
                   = Decoding.To_S32
                       (if Order = Little_Endian
                        then Decoding.U32_LE (Buffer, Next_Index (S'Old))
                        else Decoding.U32_BE (Buffer, Next_Index (S'Old)))
                 else Value = 0);

   procedure Read_U8le (Buffer : Bytes; S : in out Stream; Value : out U64)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 8)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.U64_LE (Buffer, Next_Index (S'Old)) else Value = 0);

   procedure Read_U8be (Buffer : Bytes; S : in out Stream; Value : out U64)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 8)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.U64_BE (Buffer, Next_Index (S'Old)) else Value = 0);

   procedure Read_U8 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out U64)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 8)
       and then Is_Valid (S, Buffer)
       and then (if OK (S)
                 then
                   Value
                   = (if Order = Little_Endian
                      then Decoding.U64_LE (Buffer, Next_Index (S'Old))
                      else Decoding.U64_BE (Buffer, Next_Index (S'Old)))
                 else Value = 0);

   procedure Read_S8le (Buffer : Bytes; S : in out Stream; Value : out S64)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 8)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.To_S64 (Decoding.U64_LE (Buffer, Next_Index (S'Old))) else Value = 0);

   procedure Read_S8be (Buffer : Bytes; S : in out Stream; Value : out S64)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 8)
       and then Is_Valid (S, Buffer)
       and then (if OK (S) then Value = Decoding.To_S64 (Decoding.U64_BE (Buffer, Next_Index (S'Old))) else Value = 0);

   procedure Read_S8 (Buffer : Bytes; S : in out Stream; Order : Byte_Order; Value : out S64)
   with
     Inline,
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Consumed (S'Old, S, 8)
       and then Is_Valid (S, Buffer)
       and then (if OK (S)
                 then
                   Value
                   = Decoding.To_S64
                       (if Order = Little_Endian
                        then Decoding.U64_LE (Buffer, Next_Index (S'Old))
                        else Decoding.U64_BE (Buffer, Next_Index (S'Old)))
                 else Value = 0);

   ---------------------------------------------------------------------
   --  Byte arrays
   --
   --  The data is not copied.  The result is the slice of the buffer that
   --  holds it; if the stream is valid for a buffer, the slice lies within
   --  that buffer.
   ---------------------------------------------------------------------

   --  The next Count bytes.  Fails with End_Of_Stream if fewer are left.
   procedure Read_Bytes (S : in out Stream; Count : Length; Data : out Slice)
   with
     Inline,
     Post =>
       Consumed (S'Old, S, Count)
       and then (if OK (S) then Data.First = Next_Index (S'Old) and then Size (Data) = Count else Is_Empty (Data));

   --  All bytes up to the end of the stream
   procedure Read_Bytes_Full (S : in out Stream; Data : out Slice)
   with
     Inline,
     Post =>
       Same_Window (S'Old, S)
       and then Status (S) = Status (S'Old)
       and then (if OK (S)
                 then Is_EOF (S) and then Data.First = Next_Index (S'Old) and then Size (Data) = Remaining (S'Old)
                 else Pos (S) = Pos (S'Old) and then Is_Empty (Data));

   --  True if Item lies inside the bytes S covers.  Slices delivered by a
   --  stream do; together with Is_Valid this gives Within (Item, Buffer).
   function Covers (S : Stream; Item : Slice) return Boolean
   with Ghost;

private

   --  First .. Last are the indices of the bytes the stream covers, Next is
   --  the index of the next byte to read.
   --
   --  What always holds for a stream is a predicate rather than a type
   --  invariant: for an invariant GNAT wraps the body of every operation,
   --  and on a light run-time library such a body is not inlined into its
   --  callers, which triples the instructions a parser needs.
   type Stream is record
      First : Length := 1;
      Last  : Length := 0;
      Next  : Length := 1;
      State : Status_Kind := Success;
   end record
   with
     Predicate =>
       Stream.First >= 1
       and then Stream.Last < Length'Last
       and then Stream.Last >= Stream.First - 1
       and then Stream.Next >= Stream.First
       and then Stream.Next - 1 <= Stream.Last;

   function OK (S : Stream) return Boolean
   is (S.State = Success);

   function Status (S : Stream) return Status_Kind
   is (S.State);

   function Size (S : Stream) return Length
   is (S.Last - S.First + 1);

   function Pos (S : Stream) return Length
   is (S.Next - S.First);

   function Next_Index (S : Stream) return Length
   is (S.Next);

   function Is_Valid (S : Stream; Buffer : Bytes) return Boolean
   is (S.Last < S.First or else (S.First >= Buffer'First and then S.Last <= Buffer'Last));

   function Same_Window (Left, Right : Stream) return Boolean
   is (Left.First = Right.First and then Left.Last = Right.Last);

   function Covers (S : Stream; Item : Slice) return Boolean
   is (Is_Empty (Item) or else (Item.First >= S.First and then Item.Last <= S.Last));

end Kaitai.Streams;
