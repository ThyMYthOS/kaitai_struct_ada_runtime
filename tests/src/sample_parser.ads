--  A hand-written parser of the kind the Kaitai Struct compiler is meant to
--  generate, used by the tests and proven with GNATprove.  It shows that
--  code built on the library can be proven free of run-time errors from
--  the contracts of the library alone.
--
--  The format: magic u2be = 16#4B53#, version u1, flags u1, length u4le,
--  id s8be, then length bytes of payload.

with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

package Sample_Parser
  with SPARK_Mode, Always_Terminates
is

   Magic_Value : constant U16 := 16#4B53#;
   Header_Size : constant Length := 16;

   type Message is record
      Version : U8 := 0;
      Flags   : U8 := 0;
      Size    : U32 := 0;
      Id      : S64 := 0;
      Payload : Slice;
   end record;

   --  Field by field, with the stream checking every read
   procedure Parse (Buffer : Bytes; S : in out Stream; Result : out Message)
   with
     Pre  => Is_Valid (S, Buffer),
     Post => Is_Valid (S, Buffer) and then (if OK (S) then Within (Result.Payload, Buffer));

   --  With one check for the header, which has a fixed size, and decoding
   --  at fixed offsets
   procedure Parse_Block (Buffer : Bytes; S : in out Stream; Result : out Message)
   with
     Pre  => Is_Valid (S, Buffer),
     Post => Is_Valid (S, Buffer) and then (if OK (S) then Within (Result.Payload, Buffer));

end Sample_Parser;
