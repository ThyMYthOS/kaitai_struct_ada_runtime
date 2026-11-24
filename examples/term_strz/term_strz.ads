--  Parser for term_strz.ksy, translated by hand in the way the Kaitai Struct
--  compiler is meant to generate it.  See docs/codegen.md.
--
--  Strings are delivered as slices of the buffer.  Their encoding is not
--  checked yet.

with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

package Term_Strz
  with SPARK_Mode, Always_Terminates
is

   type T is private;

   function Valid (This : T) return Boolean;

   --  True if the slices of This lie within Buffer, which they do for the
   --  buffer This was parsed from
   function Belongs_To (This : T; Buffer : Bytes) return Boolean;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
   with
     Pre  => Is_Valid (S, Buffer),
     Post => Is_Valid (S, Buffer) and then Valid (This) = OK (S) and then Belongs_To (This, Buffer);

   function S1 (This : T) return Slice
   with Pre => Valid (This);

   function S2 (This : T) return Slice
   with Pre => Valid (This);

   function S3 (This : T) return Slice
   with Pre => Valid (This);

private

   type T is record
      Is_Valid : Boolean := False;
      S1       : Slice;
      S2       : Slice;
      S3       : Slice;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Belongs_To (This : T; Buffer : Bytes) return Boolean
   is (Within (This.S1, Buffer) and then Within (This.S2, Buffer) and then Within (This.S3, Buffer));

   function S1 (This : T) return Slice
   is (This.S1);

   function S2 (This : T) return Slice
   is (This.S2);

   function S3 (This : T) return Slice
   is (This.S3);

end Term_Strz;
