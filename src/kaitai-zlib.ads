--  Decompression of zlib streams (RFC 1950) that hold DEFLATE data
--  (RFC 1951).  This is the "process: zlib" of Kaitai Struct.  The result is
--  written to an array of the caller; nothing is allocated.
--
--  Whatever bytes are given as Source, Inflate ends with one of the three
--  results; GNATprove proves that no run-time check can fail and that every
--  loop ends, for all inputs.

with Kaitai.Types; use Kaitai.Types;

package Kaitai.Zlib
  with Pure, SPARK_Mode, Always_Terminates
is

   --  How Inflate ended
   type Result_Kind is
     (Done,         --  Source is a valid stream and Target holds all of its data
      Corrupt,      --  Source is not a valid stream: bad header, malformed or truncated data, wrong Adler-32
      Target_Full); --  the data does not fit into Target

   --  Decompress the zlib stream Source.  Bytes after the end of the stream
   --  are ignored.  If Result is Done, Target (Target'First .. Last) holds
   --  the data, and Last = Target'First - 1 if there is none.  Otherwise
   --  Last = Target'First - 1 as well, and Target holds nothing useful.
   --  Target needs no particular content on entry; it is the window for
   --  back-references too, which are a distance back from the end of the
   --  data produced so far.  The precondition excludes only the bounds that
   --  Ada allows an array without elements to have below its index type.
   procedure Inflate (Source : Bytes; Target : in out Bytes; Last : out Length; Result : out Result_Kind)
   with
     Pre  => Target'First >= 1,
     Post =>
       Last >= Target'First - 1
       and then Last - (Target'First - 1) <= Length (Target'Length)
       and then (if Result /= Done then Last = Target'First - 1);

end Kaitai.Zlib;
