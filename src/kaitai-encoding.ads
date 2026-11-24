--  Encoding of integers at a given position of a byte array.
--
--  This is the counterpart of Kaitai.Decoding.  The procedures do not check
--  whether the bytes exist; that is their precondition.  Kaitai.Writers
--  offers the same encoding with the check built in.  Use the procedures
--  here after one check for a whole block of fixed size, which saves the
--  check per field.  What they store is what Kaitai.Decoding reads back, and
--  they change nothing else.

with Kaitai.Decoding;
with Kaitai.Types; use Kaitai.Types;

package Kaitai.Encoding
  with Pure, SPARK_Mode, Always_Terminates
is

   --  True if After is Before with at most the Count bytes from From on
   --  replaced.  This is the frame condition of every operation that stores
   --  bytes.
   function Kept (Before, After : Bytes; From : Length; Count : Length) return Boolean
   is (Before'First = After'First
       and then Before'Last = After'Last
       and then (for all I in After'Range =>
                   (if Count = 0 or else I < From or else I - From >= Count then After (I) = Before (I))))
   with Ghost;

   procedure Put_U8 (Target : in out Bytes; From : Index; Value : U8)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 1),
     Post => Decoding.U8_At (Target, From) = Value and then Kept (Target'Old, Target, From, 1);

   procedure Put_U16_LE (Target : in out Bytes; From : Index; Value : U16)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 2),
     Post => Decoding.U16_LE (Target, From) = Value and then Kept (Target'Old, Target, From, 2);

   procedure Put_U16_BE (Target : in out Bytes; From : Index; Value : U16)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 2),
     Post => Decoding.U16_BE (Target, From) = Value and then Kept (Target'Old, Target, From, 2);

   procedure Put_U32_LE (Target : in out Bytes; From : Index; Value : U32)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 4),
     Post => Decoding.U32_LE (Target, From) = Value and then Kept (Target'Old, Target, From, 4);

   procedure Put_U32_BE (Target : in out Bytes; From : Index; Value : U32)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 4),
     Post => Decoding.U32_BE (Target, From) = Value and then Kept (Target'Old, Target, From, 4);

   procedure Put_U64_LE (Target : in out Bytes; From : Index; Value : U64)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 8),
     Post => Decoding.U64_LE (Target, From) = Value and then Kept (Target'Old, Target, From, 8);

   procedure Put_U64_BE (Target : in out Bytes; From : Index; Value : U64)
   with
     Inline,
     Pre  => Decoding.Has (Target, From, 8),
     Post => Decoding.U64_BE (Target, From) = Value and then Kept (Target'Old, Target, From, 8);

   --  Reinterpretation of a signed value as an unsigned one in two's
   --  complement.  Decoding.To_S8 .. To_S64 are the inverse.

   function To_U8 (Value : S8) return U8
   is (if Value >= 0 then U8 (Value) else not U8 (-1 - Integer (Value)))
   with Inline, Post => Decoding.To_S8 (To_U8'Result) = Value;

   function To_U16 (Value : S16) return U16
   is (U16 (S32 (Value) mod 2**16))
   with Inline, Post => Decoding.To_S16 (To_U16'Result) = Value;

   function To_U32 (Value : S32) return U32
   is (U32 (S64 (Value) mod 2**32))
   with Inline, Post => Decoding.To_S32 (To_U32'Result) = Value;

   function To_U64 (Value : S64) return U64
   with Inline, Post => Decoding.To_S64 (To_U64'Result) = Value;

end Kaitai.Encoding;
