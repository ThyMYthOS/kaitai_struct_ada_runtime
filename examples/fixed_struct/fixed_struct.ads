--  Parser for fixed_struct.ksy, translated by hand in the way the Kaitai
--  Struct compiler is meant to generate it.  See docs/codegen.md.

with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

package Fixed_Struct
  with SPARK_Mode, Always_Terminates
is

   package Header is

      --  The values the "contents" fields must have.  They are checked by
      --  Parse and not stored.
      Magic1        : constant Bytes := (16#50#, 16#41#, 16#43#, 16#4B#, 16#2D#, 16#31#);  --  "PACK-1"
      Magic_Uint    : constant Bytes :=
        (16#50#, 16#41#, 16#43#, 16#4B#, 16#2D#, 16#55#, 16#2D#, 16#44#, 16#45#, 16#46#);  --  "PACK-U-DEF"
      Magic_Sint    : constant Bytes :=
        (16#50#, 16#41#, 16#43#, 16#4B#, 16#2D#, 16#53#, 16#2D#, 16#44#, 16#45#, 16#46#);  --  "PACK-S-DEF"
      Magic_Uint_Le : constant Bytes :=
        (16#50#, 16#41#, 16#43#, 16#4B#, 16#2D#, 16#55#, 16#2D#, 16#4C#, 16#45#);  --  "PACK-U-LE"
      Magic_Sint_Le : constant Bytes :=
        (16#50#, 16#41#, 16#43#, 16#4B#, 16#2D#, 16#53#, 16#2D#, 16#4C#, 16#45#);  --  "PACK-S-LE"
      Magic_Uint_Be : constant Bytes :=
        (16#50#, 16#41#, 16#43#, 16#4B#, 16#2D#, 16#55#, 16#2D#, 16#42#, 16#45#);  --  "PACK-U-BE"
      Magic_Sint_Be : constant Bytes :=
        (16#50#, 16#41#, 16#43#, 16#4B#, 16#2D#, 16#53#, 16#2D#, 16#42#, 16#45#);  --  "PACK-S-BE"

      type T is private;

      function Valid (This : T) return Boolean;

      procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
      with Pre => Is_Valid (S, Buffer), Post => Is_Valid (S, Buffer) and then Valid (This) = OK (S);

      function Uint8 (This : T) return U8
      with Pre => Valid (This);
      function Sint8 (This : T) return S8
      with Pre => Valid (This);
      function Uint16 (This : T) return U16
      with Pre => Valid (This);
      function Uint32 (This : T) return U32
      with Pre => Valid (This);
      function Uint64 (This : T) return U64
      with Pre => Valid (This);
      function Sint16 (This : T) return S16
      with Pre => Valid (This);
      function Sint32 (This : T) return S32
      with Pre => Valid (This);
      function Sint64 (This : T) return S64
      with Pre => Valid (This);
      function Uint16le (This : T) return U16
      with Pre => Valid (This);
      function Uint32le (This : T) return U32
      with Pre => Valid (This);
      function Uint64le (This : T) return U64
      with Pre => Valid (This);
      function Sint16le (This : T) return S16
      with Pre => Valid (This);
      function Sint32le (This : T) return S32
      with Pre => Valid (This);
      function Sint64le (This : T) return S64
      with Pre => Valid (This);
      function Uint16be (This : T) return U16
      with Pre => Valid (This);
      function Uint32be (This : T) return U32
      with Pre => Valid (This);
      function Uint64be (This : T) return U64
      with Pre => Valid (This);
      function Sint16be (This : T) return S16
      with Pre => Valid (This);
      function Sint32be (This : T) return S32
      with Pre => Valid (This);
      function Sint64be (This : T) return S64
      with Pre => Valid (This);

   private

      type T is record
         Is_Valid : Boolean := False;
         Uint8    : U8 := 0;
         Sint8    : S8 := 0;
         Uint16   : U16 := 0;
         Uint32   : U32 := 0;
         Uint64   : U64 := 0;
         Sint16   : S16 := 0;
         Sint32   : S32 := 0;
         Sint64   : S64 := 0;
         Uint16le : U16 := 0;
         Uint32le : U32 := 0;
         Uint64le : U64 := 0;
         Sint16le : S16 := 0;
         Sint32le : S32 := 0;
         Sint64le : S64 := 0;
         Uint16be : U16 := 0;
         Uint32be : U32 := 0;
         Uint64be : U64 := 0;
         Sint16be : S16 := 0;
         Sint32be : S32 := 0;
         Sint64be : S64 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Uint8 (This : T) return U8
      is (This.Uint8);
      function Sint8 (This : T) return S8
      is (This.Sint8);
      function Uint16 (This : T) return U16
      is (This.Uint16);
      function Uint32 (This : T) return U32
      is (This.Uint32);
      function Uint64 (This : T) return U64
      is (This.Uint64);
      function Sint16 (This : T) return S16
      is (This.Sint16);
      function Sint32 (This : T) return S32
      is (This.Sint32);
      function Sint64 (This : T) return S64
      is (This.Sint64);
      function Uint16le (This : T) return U16
      is (This.Uint16le);
      function Uint32le (This : T) return U32
      is (This.Uint32le);
      function Uint64le (This : T) return U64
      is (This.Uint64le);
      function Sint16le (This : T) return S16
      is (This.Sint16le);
      function Sint32le (This : T) return S32
      is (This.Sint32le);
      function Sint64le (This : T) return S64
      is (This.Sint64le);
      function Uint16be (This : T) return U16
      is (This.Uint16be);
      function Uint32be (This : T) return U32
      is (This.Uint32be);
      function Uint64be (This : T) return U64
      is (This.Uint64be);
      function Sint16be (This : T) return S16
      is (This.Sint16be);
      function Sint32be (This : T) return S32
      is (This.Sint32be);
      function Sint64be (This : T) return S64
      is (This.Sint64be);

   end Header;

   type T is private;

   function Valid (This : T) return Boolean;

   --  True if This was parsed from a stream that lies within Buffer, which
   --  holds for the buffer This was parsed from
   function Belongs_To (This : T; Buffer : Bytes) return Boolean;

   --  The type has no fields in sequence, so Parse reads nothing.  It still
   --  takes the stream the way every Parse does.
   pragma Warnings (GNATprove, Off, """S"" is not modified, could be IN");
   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
   with
     Pre  => Is_Valid (S, Buffer),
     Post => Is_Valid (S, Buffer) and then Valid (This) = OK (S) and then Belongs_To (This, Buffer);
   pragma Warnings (GNATprove, On, """S"" is not modified, could be IN");

   --  The instance hdr.  It is parsed when asked for, from position 0 of
   --  the stream This was parsed from, and is not kept in This.
   procedure Hdr (Buffer : Bytes; This : T; Result : out Header.T; Outcome : out Status_Kind)
   with Pre => Valid (This) and then Belongs_To (This, Buffer), Post => Header.Valid (Result) = (Outcome = Success);

private

   --  Io is the stream as it was when parsing began.  Instances that have a
   --  position read through a copy of it.
   type T is record
      Is_Valid : Boolean := False;
      Io       : Stream;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Belongs_To (This : T; Buffer : Bytes) return Boolean
   is (Is_Valid (This.Io, Buffer));

end Fixed_Struct;
