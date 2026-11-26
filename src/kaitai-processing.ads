--  The "process" routines of Kaitai Struct that work byte by byte.  Each of
--  them writes its result to an array provided by the caller, usually to
--  bytes reserved in an arena; see Kaitai.Arenas.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Processing
  with Pure, SPARK_Mode, Always_Terminates
is

   --  Every byte of Source combined with Key by exclusive or.  This is
   --  process_xor_one of the Kaitai Struct stream API.
   procedure Xor_One (Source : Bytes; Key : Byte; Target : out Bytes)
   with
     Relaxed_Initialization => Target,
     Pre                    => Target'Length = Source'Length,
     Post                   =>
       Target'Initialized
       and then (for all I in Target'Range => Target (I) = (Source (Source'First + (I - Target'First)) xor Key));

   --  Every byte of Source combined by exclusive or with a byte of Key,
   --  which is used from its start again whenever its end is reached.  This
   --  is process_xor_many of the Kaitai Struct stream API.
   procedure Xor_Many (Source : Bytes; Key : Bytes; Target : out Bytes)
   with
     Relaxed_Initialization => Target,
     Pre                    => Target'Length = Source'Length and then Key'Length > 0,
     Post                   =>
       Target'Initialized
       and then (for all I in Target'Range =>
                   Target (I)
                   = (Source (Source'First + (I - Target'First))
                      xor Key (Key'First + (I - Target'First) mod Key'Length)));

   --  Every byte of Source rotated to the left by Amount bits.  Any Amount
   --  is allowed and stands for the same amount modulo 8, so that a
   --  rotation to the right by N bits is one to the left by 8 - N.  This is
   --  process_rotate_left of the Kaitai Struct stream API for groups of one
   --  byte.
   procedure Rotate_Left (Source : Bytes; Amount : Integer; Target : out Bytes)
   with
     Relaxed_Initialization => Target,
     Pre                    => Target'Length = Source'Length,
     Post                   =>
       Target'Initialized
       and then (for all I in Target'Range =>
                   Target (I) = Rotate_Left (Source (Source'First + (I - Target'First)), Amount mod 8));

   --  The byte Value after Xor_One, which is what one byte of the result of
   --  process_xor_one is.  An expression that asks for one byte of processed
   --  bytes needs no array for it.
   function Xor_Byte (Value : Byte; Key : Byte) return Byte
   is (Value xor Key)
   with Inline;

   --  The byte Value, which stands at Offset (counted from 0) in the data,
   --  after Xor_Many.
   function Xor_Many_Byte (Value : Byte; Key : Bytes; Offset : Length) return Byte
   is (Value xor Key (Key'First + Offset mod Key'Length))
   with Inline, Pre => Key'Length > 0;

   --  The byte Value after Rotate_Left.
   function Rotate_Byte (Value : Byte; Amount : Integer) return Byte
   is (Rotate_Left (Value, Amount mod 8))
   with Inline;

end Kaitai.Processing;
