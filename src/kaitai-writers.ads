--  The Kaitai Struct writer: positioning in a byte array and writing the
--  primitive types of the Kaitai Struct language to it.  It is the
--  counterpart of Kaitai.Streams and serves serialization.
--
--  A Writer is a cursor.  It does not own the bytes; every operation that
--  stores data takes the target array as a parameter, in the same way as a
--  Stream takes the buffer it reads from.  A writer therefore contains no
--  pointer and can be copied freely.  The caller keeps the target to itself
--  while a writer refers to it and does not pass a slice of it as Source.
--
--  No operation raises an exception.  An operation that cannot be carried
--  out records the reason in the writer, writes nothing and leaves the
--  position where it was.  The first failure is kept, and every later
--  operation on the writer does nothing.  It is therefore enough to look at
--  OK at the end.  Running out of space is Capacity_Exceeded; a value that
--  does not fit its field, or a byte array that cannot be represented, is a
--  Validation_ status.
--
--  What a writer writes, Kaitai.Streams reads back: the bit fields use the
--  same bit orders and the same alignment rules, and for the integers the
--  contracts state it with the functions of Kaitai.Decoding.
--
--  Position and extent.  Pos is where the next byte goes.  Written is the
--  extent of what has been produced, from the start of the window to the
--  highest position the writer has reached.  Seek can move back to patch a
--  field, for example a length that was not known before; it does not
--  shorten Written.  Seek can also move forward, beyond Written; the bytes
--  in between are not touched, and Written then includes them, so the caller
--  has to write them (Skip does that with zeros) before it hands Written on.

with Kaitai.Bits;     use Kaitai.Bits;
with Kaitai.Decoding;
with Kaitai.Encoding; use Kaitai.Encoding;
with Kaitai.Types;    use Kaitai.Types;

package Kaitai.Writers
  with Pure, SPARK_Mode, Always_Terminates
is

   type Writer is private;

   ---------------------------------------------------------------------
   --  State
   ---------------------------------------------------------------------

   --  True if no operation on the writer has failed
   function OK (W : Writer) return Boolean;

   --  Success, or the reason of the first failure
   function Status (W : Writer) return Status_Kind
   with Post => (Status'Result = Success) = OK (W);

   --  Number of bytes the writer covers
   function Size (W : Writer) return Length;

   --  Number of bytes before the current position
   function Pos (W : Writer) return Length
   with Post => Pos'Result <= Size (W);

   --  Number of bytes from the current position to the end
   function Remaining (W : Writer) return Length
   is (Size (W) - Pos (W));

   --  Index in the target of the byte the next write starts at
   function Next_Index (W : Writer) return Length
   with Post => Next_Index'Result >= 1;

   --  Number of bits that a bit field has left free in the byte before
   --  Next_Index.  They are zero.  It is zero unless the last write was
   --  that of a bit field.
   function Bits_Free (W : Writer) return Bit_Remainder
   with Post => (if Bits_Free'Result > 0 then Pos (W) > 0);

   --  The bytes produced so far, from the start of the window to the
   --  highest position reached, as a slice of the target.  A byte that a bit
   --  field has begun belongs to it.
   function Written (W : Writer) return Slice
   with
     Post =>
       Written'Result.First = Next_Index (W) - Pos (W)
       and then Size (Written'Result) >= Pos (W)
       and then Size (Written'Result) <= Size (W);

   --  True if the writer lies inside Target.  This holds for the target a
   --  writer was opened on and is required by every operation that takes
   --  the target.
   function Is_Valid (W : Writer; Target : Bytes) return Boolean
   with
     Post =>
       (if Is_Valid'Result
        then Decoding.Has (Target, Next_Index (W), Remaining (W)) and then Within (Written (W), Target));

   --  True if Left and Right cover the same bytes
   function Same_Window (Left, Right : Writer) return Boolean
   with Post => (if Same_Window'Result then Size (Left) = Size (Right));

   --  What an operation that refuses to write does to a writer: it fails
   --  for Reason, or keeps an earlier failure, and changes nothing else
   function Refused (Before, After : Writer; Reason : Status_Kind) return Boolean
   is (Same_Window (Before, After)
       and then not OK (After)
       and then Pos (After) = Pos (Before)
       and then Next_Index (After) = Next_Index (Before)
       and then Bits_Free (After) = Bits_Free (Before)
       and then Written (After) = Written (Before)
       and then Status (After) = (if OK (Before) then Reason else Status (Before)))
   with Ghost;

   --  What an attempt to produce Count bytes does to a writer: on success
   --  the position moves on by Count, the bit field in progress ends and
   --  Written grows to the new position if it was shorter; otherwise the
   --  writer fails and stays as it was
   function Produced (Before, After : Writer; Count : Length) return Boolean
   is (Same_Window (Before, After)
       and then (if OK (Before) and then Count <= Remaining (Before)
                 then
                   OK (After)
                   and then Pos (After) = Pos (Before) + Count
                   and then Next_Index (After) = Next_Index (Before) + Count
                   and then Bits_Free (After) = 0
                   and then Written (After).First = Written (Before).First
                   and then Written (After).Last = Length'Max (Written (Before).Last, Next_Index (After) - 1)
                 else Refused (Before, After, Capacity_Exceeded)))
   with Ghost;

   --  Produced, and in addition the target changes only in the Count bytes
   --  from the old position on, and only if the write succeeded
   function Produced_In (Before, After : Writer; Old_Target, Target : Bytes; Count : Length) return Boolean
   is (Produced (Before, After, Count)
       and then Kept (Old_Target, Target, Next_Index (Before), (if OK (After) then Count else 0)))
   with Ghost;

   --  True if Count bytes at From all have the value Value
   function Filled (Target : Bytes; From : Length; Count : Length; Value : Byte) return Boolean
   is (Count = 0
       or else (Decoding.Has (Target, From, Count)
                and then (for all I in From .. From + (Count - 1) => Target (I) = Value)))
   with Ghost;

   --  True if the bytes at From are those of Source
   function Stored (Target : Bytes; From : Length; Source : Bytes) return Boolean
   is (Source'Length = 0
       or else (Decoding.Has (Target, From, Length (Source'Length))
                and then (for all I in 0 .. Length (Source'Length) - 1 =>
                            Target (From + I) = Source (Source'First + I))))
   with Ghost;

   --  True if Source has a byte that equals Term
   function Has_Byte (Source : Bytes; Term : Byte) return Boolean
   is (for some I in Source'Range => Source (I) = Term)
   with Ghost;

   ---------------------------------------------------------------------
   --  Opening and positioning
   ---------------------------------------------------------------------

   --  A writer over all of Target, positioned at its start.  Nothing is
   --  written; Written is empty.
   function Open (Target : Bytes) return Writer
   with
     Inline,
     Post =>
       Is_Valid (Open'Result, Target)
       and then OK (Open'Result)
       and then Pos (Open'Result) = 0
       and then Bits_Free (Open'Result) = 0
       and then Size (Open'Result) = Target'Length
       and then Size (Written (Open'Result)) = 0;

   --  Move to the position To, counted from the start of the window.  Fails
   --  with Capacity_Exceeded if To is beyond the end.  A bit field in
   --  progress ends; the bits it has left free stay zero.
   procedure Seek (W : in out Writer; To : Length)
   with
     Inline,
     Post =>
       Same_Window (W'Old, W)
       and then (if OK (W'Old) and then To <= Size (W'Old)
                 then
                   OK (W)
                   and then Pos (W) = To
                   and then Bits_Free (W) = 0
                   and then Written (W).First = Written (W'Old).First
                   and then Written (W).Last = Length'Max (Written (W'Old).Last, Next_Index (W) - 1)
                 else Refused (W'Old, W, Capacity_Exceeded));

   --  Write Count zero bytes.  Fails with Capacity_Exceeded if fewer are
   --  left.  The output does not depend on what the target held before,
   --  which is why this writes zeros instead of leaving the bytes alone;
   --  use Seek to leave them.
   procedure Skip (Target : in out Bytes; W : in out Writer; Count : Length)
   with
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, Count)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Filled (Target, Next_Index (W'Old), Count, 0));

   --  Record a failure that was found outside the writer, for example by a
   --  validation.  An earlier failure is kept.
   procedure Fail (W : in out Writer; Reason : Status_Kind)
   with Pre => Reason /= Success, Post => Refused (W'Old, W, Reason);

   ---------------------------------------------------------------------
   --  Integers
   --
   --  Write_<sign><bytes><order>: u = unsigned, s = signed; 1, 2, 4 or 8
   --  bytes; le = little endian, be = big endian.  The names follow the
   --  Kaitai Struct stream API.  The variants without order in the name
   --  take it as a parameter, for formats that decide it at run time.
   --  Every one of them starts at the next byte boundary.
   --
   --  The postcondition of each says that Kaitai.Decoding reads Value back
   --  from where it was written.
   ---------------------------------------------------------------------

   procedure Write_U1 (Target : in out Bytes; W : in out Writer; Value : U8)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 1)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.U8_At (Target, Next_Index (W'Old)) = Value);

   procedure Write_S1 (Target : in out Bytes; W : in out Writer; Value : S8)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 1)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.To_S8 (Decoding.U8_At (Target, Next_Index (W'Old))) = Value);

   procedure Write_U2le (Target : in out Bytes; W : in out Writer; Value : U16)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 2)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.U16_LE (Target, Next_Index (W'Old)) = Value);

   procedure Write_U2be (Target : in out Bytes; W : in out Writer; Value : U16)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 2)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.U16_BE (Target, Next_Index (W'Old)) = Value);

   procedure Write_U2 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : U16)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 2)
       and then Is_Valid (W, Target)
       and then (if OK (W)
                 then
                   (if Order = Little_Endian
                    then Decoding.U16_LE (Target, Next_Index (W'Old))
                    else Decoding.U16_BE (Target, Next_Index (W'Old)))
                   = Value);

   procedure Write_S2le (Target : in out Bytes; W : in out Writer; Value : S16)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 2)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.To_S16 (Decoding.U16_LE (Target, Next_Index (W'Old))) = Value);

   procedure Write_S2be (Target : in out Bytes; W : in out Writer; Value : S16)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 2)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.To_S16 (Decoding.U16_BE (Target, Next_Index (W'Old))) = Value);

   procedure Write_S2 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : S16)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 2)
       and then Is_Valid (W, Target)
       and then (if OK (W)
                 then
                   Decoding.To_S16
                     ((if Order = Little_Endian
                       then Decoding.U16_LE (Target, Next_Index (W'Old))
                       else Decoding.U16_BE (Target, Next_Index (W'Old))))
                   = Value);

   procedure Write_U4le (Target : in out Bytes; W : in out Writer; Value : U32)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 4)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.U32_LE (Target, Next_Index (W'Old)) = Value);

   procedure Write_U4be (Target : in out Bytes; W : in out Writer; Value : U32)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 4)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.U32_BE (Target, Next_Index (W'Old)) = Value);

   procedure Write_U4 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : U32)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 4)
       and then Is_Valid (W, Target)
       and then (if OK (W)
                 then
                   (if Order = Little_Endian
                    then Decoding.U32_LE (Target, Next_Index (W'Old))
                    else Decoding.U32_BE (Target, Next_Index (W'Old)))
                   = Value);

   procedure Write_S4le (Target : in out Bytes; W : in out Writer; Value : S32)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 4)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.To_S32 (Decoding.U32_LE (Target, Next_Index (W'Old))) = Value);

   procedure Write_S4be (Target : in out Bytes; W : in out Writer; Value : S32)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 4)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.To_S32 (Decoding.U32_BE (Target, Next_Index (W'Old))) = Value);

   procedure Write_S4 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : S32)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 4)
       and then Is_Valid (W, Target)
       and then (if OK (W)
                 then
                   Decoding.To_S32
                     ((if Order = Little_Endian
                       then Decoding.U32_LE (Target, Next_Index (W'Old))
                       else Decoding.U32_BE (Target, Next_Index (W'Old))))
                   = Value);

   procedure Write_U8le (Target : in out Bytes; W : in out Writer; Value : U64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 8)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.U64_LE (Target, Next_Index (W'Old)) = Value);

   procedure Write_U8be (Target : in out Bytes; W : in out Writer; Value : U64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 8)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.U64_BE (Target, Next_Index (W'Old)) = Value);

   procedure Write_U8 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : U64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 8)
       and then Is_Valid (W, Target)
       and then (if OK (W)
                 then
                   (if Order = Little_Endian
                    then Decoding.U64_LE (Target, Next_Index (W'Old))
                    else Decoding.U64_BE (Target, Next_Index (W'Old)))
                   = Value);

   procedure Write_S8le (Target : in out Bytes; W : in out Writer; Value : S64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 8)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.To_S64 (Decoding.U64_LE (Target, Next_Index (W'Old))) = Value);

   procedure Write_S8be (Target : in out Bytes; W : in out Writer; Value : S64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 8)
       and then Is_Valid (W, Target)
       and then (if OK (W) then Decoding.To_S64 (Decoding.U64_BE (Target, Next_Index (W'Old))) = Value);

   procedure Write_S8 (Target : in out Bytes; W : in out Writer; Order : Byte_Order; Value : S64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, 8)
       and then Is_Valid (W, Target)
       and then (if OK (W)
                 then
                   Decoding.To_S64
                     ((if Order = Little_Endian
                       then Decoding.U64_LE (Target, Next_Index (W'Old))
                       else Decoding.U64_BE (Target, Next_Index (W'Old))))
                   = Value);

   ---------------------------------------------------------------------
   --  Bit fields
   --
   --  Integers of 1 to 64 bits that need not start or end at a byte
   --  boundary.  A bit field continues where the previous one stopped.  Any
   --  other write starts at the next byte boundary, and the bits left free
   --  in the byte before are zero; Align_To_Byte does that explicitly.
   --
   --  The two bit orders differ in which bits of a byte are filled first:
   --  the most significant ones in big endian order, the least significant
   --  ones in little endian order, exactly as in Kaitai.Streams.  Mixing
   --  the orders within one byte is not meaningful; align in between.
   --
   --  Value must not exceed Mask (Count); otherwise nothing is written and
   --  the writer fails with Validation_Greater_Than.  The bits of the field
   --  are not silently cut off, because that would let a wrong value become
   --  a valid file.
   ---------------------------------------------------------------------

   --  End the bit field in progress; the bits it has left free stay zero
   procedure Align_To_Byte (W : in out Writer)
   with
     Inline,
     Post =>
       Same_Window (W'Old, W)
       and then Status (W) = Status (W'Old)
       and then Pos (W) = Pos (W'Old)
       and then Next_Index (W) = Next_Index (W'Old)
       and then Written (W) = Written (W'Old)
       and then Bits_Free (W) = 0;

   --  The number of bytes before Next_Index that a bit field in progress
   --  has begun and that a further bit field changes: one or none
   function Open_Byte (W : Writer) return Length
   is (if Bits_Free (W) > 0 then 1 else 0)
   with Ghost;

   --  What an attempt to write a bit field of Count bits does to a writer
   function Produced_Bits (Before, After : Writer; Count : Bit_Count; Value : U64) return Boolean
   is (Same_Window (Before, After)
       and then (if OK (Before)
                   and then Value <= Mask (Count)
                   and then Bytes_Needed (Count, Bits_Free (Before)) <= Remaining (Before)
                 then
                   OK (After)
                   and then Pos (After) = Pos (Before) + Bytes_Needed (Count, Bits_Free (Before))
                   and then Bits_Free (After) = Left_After (Count, Bits_Free (Before))
                   and then Written (After).First = Written (Before).First
                   and then Written (After).Last = Length'Max (Written (Before).Last, Next_Index (After) - 1)
                 else
                   Refused
                     (Before, After, (if Value > Mask (Count) then Validation_Greater_Than else Capacity_Exceeded))))
   with Ghost;

   --  Produced_Bits, and in addition the target changes only in the byte a
   --  bit field in progress had begun and in the bytes this one takes
   function Produced_Bits_In
     (Before, After : Writer; Old_Target, Target : Bytes; Count : Bit_Count; Value : U64) return Boolean
   is (Produced_Bits (Before, After, Count, Value)
       and then Kept
                  (Old_Target,
                   Target,
                   Next_Index (Before) - Open_Byte (Before),
                   (if OK (After) then Open_Byte (Before) + Bytes_Needed (Count, Bits_Free (Before)) else 0)))
   with Ghost;

   procedure Write_Bits_Int_Be (Target : in out Bytes; W : in out Writer; Count : Bit_Count; Value : U64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post => Produced_Bits_In (W'Old, W, Target'Old, Target, Count, Value) and then Is_Valid (W, Target);

   procedure Write_Bits_Int_Le (Target : in out Bytes; W : in out Writer; Count : Bit_Count; Value : U64)
   with
     Inline,
     Pre  => Is_Valid (W, Target),
     Post => Produced_Bits_In (W'Old, W, Target'Old, Target, Count, Value) and then Is_Valid (W, Target);

   ---------------------------------------------------------------------
   --  Byte arrays
   --
   --  The data is copied.  Every one of these starts at the next byte
   --  boundary.
   ---------------------------------------------------------------------

   --  Source, as it is.  Fails with Capacity_Exceeded if fewer bytes are
   --  left.
   procedure Write_Bytes (Target : in out Bytes; W : in out Writer; Source : Bytes)
   with
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, Length (Source'Length))
       and then Is_Valid (W, Target)
       and then (if OK (W) then Stored (Target, Next_Index (W'Old), Source));

   --  Source followed by the terminator Term.  This is what read_bytes_term
   --  of the Kaitai Struct stream API reads back with Include = False and
   --  Consume = True.  That only works if Source does not contain Term, so
   --  this fails with Validation_Expr if it does, and writes nothing.  It
   --  fails with Capacity_Exceeded if fewer than Source'Length + 1 bytes are
   --  left.
   procedure Write_Bytes_Term (Target : in out Bytes; W : in out Writer; Source : Bytes; Term : Byte)
   with
     Pre  => Is_Valid (W, Target),
     Post =>
       Is_Valid (W, Target)
       and then (if OK (W'Old) and then not Has_Byte (Source, Term) and then Length (Source'Length) < Remaining (W'Old)
                 then
                   Produced_In (W'Old, W, Target'Old, Target, Length (Source'Length) + 1)
                   and then Stored (Target, Next_Index (W'Old), Source)
                   and then Target (Next_Index (W'Old) + Length (Source'Length)) = Term
                 else
                   Refused (W'Old, W, (if Has_Byte (Source, Term) then Validation_Expr else Capacity_Exceeded))
                   and then Target = Target'Old);

   --  Source followed by Pad bytes up to a total of Size bytes: a field of
   --  fixed size whose content is shorter.  Fails with
   --  Validation_Greater_Than if Source is longer than Size, and with
   --  Capacity_Exceeded if fewer than Size bytes are left; it writes nothing
   --  then.  Read it back as Size bytes, or with Read_Bytes_Term if Pad is
   --  also the terminator and Source has no such byte.
   procedure Write_Padded (Target : in out Bytes; W : in out Writer; Source : Bytes; Size : Length; Pad : Byte)
   with
     Pre  => Is_Valid (W, Target),
     Post =>
       Is_Valid (W, Target)
       and then (if OK (W'Old) and then Length (Source'Length) <= Size and then Size <= Remaining (W'Old)
                 then
                   Produced_In (W'Old, W, Target'Old, Target, Size)
                   and then Stored (Target, Next_Index (W'Old), Source)
                   and then Filled
                              (Target, Next_Index (W'Old) + Length (Source'Length), Size - Length (Source'Length), Pad)
                 else
                   Refused
                     (W'Old, W, (if Length (Source'Length) > Size then Validation_Greater_Than else Capacity_Exceeded))
                   and then Target = Target'Old);

   ---------------------------------------------------------------------
   --  Subwriters
   --
   --  A field with a size of its own is written by a writer that covers
   --  just its bytes, so that it cannot write beyond them.  Subwriter makes
   --  that writer and moves the parent past the field.  When the field has
   --  been written, Join hands a failure of the subwriter to the parent.
   --
   --  The bytes of the window are set to zero when the subwriter is made,
   --  so what the field does not write is zero and the output does not
   --  depend on what the target held before.  The subwriter is positioned
   --  at the start of its window and its Written is empty; Written of the
   --  parent covers the whole window at once.
   ---------------------------------------------------------------------

   --  A writer over the next Count bytes of W.  Fails with Capacity_Exceeded
   --  if fewer are left; Sub is then empty and has failed as well.
   procedure Subwriter (Target : in out Bytes; W : in out Writer; Count : Length; Sub : out Writer)
   with
     Pre  => Is_Valid (W, Target),
     Post =>
       Produced_In (W'Old, W, Target'Old, Target, Count)
       and then Is_Valid (W, Target)
       and then Is_Valid (Sub, Target)
       and then Pos (Sub) = 0
       and then Bits_Free (Sub) = 0
       and then Size (Written (Sub)) = 0
       and then Status (Sub) = Status (W)
       and then (if OK (W)
                 then
                   Size (Sub) = Count
                   and then Next_Index (Sub) = Next_Index (W'Old)
                   and then Filled (Target, Next_Index (W'Old), Count, 0)
                 else Size (Sub) = 0);

   --  Let W fail for the reason Sub has failed for, if it has and W has not
   procedure Join (W : in out Writer; Sub : Writer)
   with
     Inline,
     Post =>
       Same_Window (W'Old, W)
       and then Pos (W) = Pos (W'Old)
       and then Next_Index (W) = Next_Index (W'Old)
       and then Bits_Free (W) = Bits_Free (W'Old)
       and then Written (W) = Written (W'Old)
       and then Status (W) = (if OK (W'Old) then Status (Sub) else Status (W'Old));

private

   --  First .. Last are the indices of the bytes the writer covers, Next is
   --  the index of the next byte to write and High is the index after the
   --  highest byte that has been reached.
   --
   --  What always holds for a writer is a predicate rather than a type
   --  invariant, for the reason given in Kaitai.Streams.
   type Writer is record
      First : Length := 1;
      Last  : Length := 0;
      Next  : Length := 1;
      High  : Length := 1;
      State : Status_Kind := Success;

      --  Bits of the byte at Next - 1 that a bit field has not filled yet.
      --  They are zero in the target.
      Free : Bit_Remainder := 0;
   end record
   with
     Predicate =>
       Writer.First >= 1
       and then Writer.Last < Length'Last
       and then Writer.Last >= Writer.First - 1
       and then Writer.Next >= Writer.First
       and then Writer.Next - 1 <= Writer.Last
       and then Writer.High >= Writer.Next
       and then Writer.High - 1 <= Writer.Last
       and then (if Writer.Free > 0 then Writer.Next > Writer.First);

   function OK (W : Writer) return Boolean
   is (W.State = Success);

   function Status (W : Writer) return Status_Kind
   is (W.State);

   function Size (W : Writer) return Length
   is (W.Last - W.First + 1);

   function Pos (W : Writer) return Length
   is (W.Next - W.First);

   function Next_Index (W : Writer) return Length
   is (W.Next);

   function Bits_Free (W : Writer) return Bit_Remainder
   is (W.Free);

   function Written (W : Writer) return Slice
   is (First => W.First, Last => W.High - 1);

   function Is_Valid (W : Writer; Target : Bytes) return Boolean
   is (W.Last < W.First or else (W.First >= Target'First and then W.Last <= Target'Last));

   function Same_Window (Left, Right : Writer) return Boolean
   is (Left.First = Right.First and then Left.Last = Right.Last);

end Kaitai.Writers;
