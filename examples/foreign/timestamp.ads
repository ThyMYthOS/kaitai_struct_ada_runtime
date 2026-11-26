with Kaitai.Streams;
with Kaitai.Types;

package Timestamp
  with SPARK_Mode, Always_Terminates
is
   --  A type that the description `foreign` uses as `timestamp(100)` without
   --  defining it. This package is written by hand and keeps the contract that
   --  "Foreign code" in docs/codegen.md gives for an opaque type; the parser of
   --  `foreign` is proven against this specification.

   use type Kaitai.Types.S64;

   --  A point in time: a number of seconds of 4 bytes, big endian, and the
   --  number of ticks per second that the description names. It has no
   --  pointers and can be copied.
   type T is private;

   --  True if This is the result of a Parse that succeeded
   function Valid (This : T) return Boolean
   with Global => null;

   --  Parses one `timestamp` at the position of S and leaves S behind it. A
   --  rate below 1 is not accepted: S has failed with Arithmetic_Error then.
   --  @param This The result. Valid if and only if S has not failed
   --  @param Buffer The data. S must be a stream on it
   --  @param S Where to read. Afterwards it is behind the value, or it has failed
   --  @param Rate The ticks per second, the argument of the description
   procedure Parse
     (This : out T; Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Rate : Kaitai.Types.S64)
   with
     Global => null,
     Pre    => Kaitai.Streams.Is_Valid (S, Buffer),
     Post   =>
       Kaitai.Streams.Is_Valid (S, Buffer)
       and then Kaitai.Streams.Advanced (S'Old, S)
       and then Valid (This) = Kaitai.Streams.OK (S)
       and then (if Valid (This) then Ticks_Per_Second (This) = Rate);

   --  The seconds that Parse read
   function Seconds (This : T) return Kaitai.Types.U32
   with Global => null, Pre => Valid (This);

   --  The number of ticks per second that Parse was given
   function Ticks_Per_Second (This : T) return Kaitai.Types.S64
   with Global => null, Pre => Valid (This);

private

   type T is record
      Is_Valid : Boolean := False;
      Seconds  : Kaitai.Types.U32 := 0;
      Rate     : Kaitai.Types.S64 := 1;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Seconds (This : T) return Kaitai.Types.U32
   is (This.Seconds);

   function Ticks_Per_Second (This : T) return Kaitai.Types.S64
   is (This.Rate);

end Timestamp;
