--  Parser for formats/outside/bench_puser.ksy, written by hand in the style of generated code.  Variant V1: the
--  parameter `hdr` of `item`, a value of the user type `header`, is stored in the type of the child.

with Kaitai.Streams;
with Kaitai.Types;

package Puser_V1
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.S64;
   use type Kaitai.Types.Length;

   package Header_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S);

      function Width (This : T) return Kaitai.Types.U16
      with Pre => Valid (This);

      function Height (This : T) return Kaitai.Types.U16
      with Pre => Valid (This);

   private

      type T is record
         Is_Valid : Boolean := False;
         Width    : Kaitai.Types.U16 := 0;
         Height   : Kaitai.Types.U16 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Width (This : T) return Kaitai.Types.U16
      is (This.Width);

      function Height (This : T) return Kaitai.Types.U16
      is (This.Height);

   end Header_Type;

   package Item_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Hdr : Header_Type.T; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer) and then Header_Type.Valid (Hdr),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      function Hdr (This : T) return Header_Type.T
      with Pre => Valid (This), Post => Header_Type.Valid (Hdr'Result);

      function X (This : T) return Kaitai.Types.U8
      with Pre => Valid (This);

      function Y (This : T) return Kaitai.Types.U8
      with Pre => Valid (This);

      function Pad (This : T) return Kaitai.Types.Slice
      with Pre => Valid (This);

      function Inside (This : T) return Boolean
      with Pre => Valid (This);

   private

      type T is record
         Is_Valid : Boolean := False;
         Hdr      : Header_Type.T;
         X        : Kaitai.Types.U8 := 0;
         Y        : Kaitai.Types.U8 := 0;
         Pad      : Kaitai.Types.Slice;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid and then Header_Type.Valid (This.Hdr));

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Types.Within (This.Pad, Buffer));

      function Hdr (This : T) return Header_Type.T
      is (This.Hdr);

      function X (This : T) return Kaitai.Types.U8
      is (This.X);

      function Y (This : T) return Kaitai.Types.U8
      is (This.Y);

      function Pad (This : T) return Kaitai.Types.Slice
      is (This.Pad);

      function Inside (This : T) return Boolean
      is (Kaitai.Types.S64 (This.X) < Kaitai.Types.S64 (Header_Type.Width (This.Hdr))
          and then Kaitai.Types.S64 (This.Y) < Kaitai.Types.S64 (Header_Type.Height (This.Hdr)));

   end Item_Type;

   type T is private;

   function Valid (This : T) return Boolean;

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

   procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
   with
     Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
     Post =>
       Kaitai.Streams.Is_Valid (S, Buffer)
       and then Kaitai.Streams.Advanced (S'Old, S)
       and then Valid (This) = Kaitai.Streams.OK (S)
       and then Belongs_To (This, Buffer);

   function Hdr (This : T) return Header_Type.T
   with Pre => Valid (This), Post => Header_Type.Valid (Hdr'Result);

   function Count (This : T) return Kaitai.Types.U8
   with Pre => Valid (This);

   function Items_Count (This : T) return Kaitai.Types.Length
   with Pre => Valid (This);

   type Items_Cursor is private;

   function Belongs_To (Position : Items_Cursor; Buffer : Kaitai.Types.Bytes) return Boolean;

   function Items_First (This : T) return Items_Cursor
   with Pre => Valid (This);

   function Remaining (Position : Items_Cursor) return Kaitai.Types.Length;

   function Has_Element (Position : Items_Cursor) return Boolean
   is (Remaining (Position) > 0);

   procedure Next (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Items_Cursor; Element : out Item_Type.T)
   with
     Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
     Post =>
       Belongs_To (Position, Buffer)
       and then Remaining (Position) < Remaining (Position'Old)
       and then Item_Type.Belongs_To (Element, Buffer);

private

   type Items_Cursor is record
      Io   : Kaitai.Streams.Stream;
      Left : Kaitai.Types.Length := 0;
   end record;

   type T is record
      Is_Valid    : Boolean := False;
      Hdr         : Header_Type.T;
      Count       : Kaitai.Types.U8 := 0;
      Items_Io    : Kaitai.Streams.Stream;
      Items_Count : Kaitai.Types.Length := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid and then Header_Type.Valid (This.Hdr));

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (This.Items_Io, Buffer));

   function Hdr (This : T) return Header_Type.T
   is (This.Hdr);

   function Count (This : T) return Kaitai.Types.U8
   is (This.Count);

   function Items_Count (This : T) return Kaitai.Types.Length
   is (This.Items_Count);

   function Belongs_To (Position : Items_Cursor; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (Position.Io, Buffer));

   function Items_First (This : T) return Items_Cursor
   is (Io => This.Items_Io, Left => This.Items_Count);

   function Remaining (Position : Items_Cursor) return Kaitai.Types.Length
   is (Position.Left);

end Puser_V1;
