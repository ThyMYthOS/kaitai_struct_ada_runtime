--  Parser for formats/outside/bench_pstr.ksy, written by hand in the style of generated code.  Variant V2: the
--  parameter `key` of `item`, a string of the parent, is a parameter of Parse and of every accessor of the child that
--  needs it; the type of the child does not keep it.

with Kaitai.Streams;
with Kaitai.Types;

package Pstr_V2
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.Length;

   package Item_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

      procedure Parse
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Key : Kaitai.Types.Slice; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer) and then Kaitai.Types.Within (Key, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      function Body_Field (This : T) return Kaitai.Types.Slice
      with Pre => Valid (This);

      function Is_Key (Buffer : Kaitai.Types.Bytes; This : T; Key : Kaitai.Types.Slice) return Boolean
      with Pre => Valid (This) and then Belongs_To (This, Buffer) and then Kaitai.Types.Within (Key, Buffer);

   private

      type T is record
         Is_Valid   : Boolean := False;
         Body_Field : Kaitai.Types.Slice;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Types.Within (This.Body_Field, Buffer));

      function Body_Field (This : T) return Kaitai.Types.Slice
      is (This.Body_Field);

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

   function Key (This : T) return Kaitai.Types.Slice
   with Pre => Valid (This);

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
     Pre  =>
       Valid (This)
       and then Belongs_To (This, Buffer)
       and then Belongs_To (Position, Buffer)
       and then Has_Element (Position),
     Post =>
       Belongs_To (Position, Buffer)
       and then Remaining (Position) < Remaining (Position'Old)
       and then Item_Type.Belongs_To (Element, Buffer);

   --  `Is_Key` of an element of Items, with the value of `key` that this parent gives to its elements; the caller
   --  cannot give another one
   function Items_Is_Key (Buffer : Kaitai.Types.Bytes; This : T; Element : Item_Type.T) return Boolean
   with
     Pre =>
       Valid (This)
       and then Belongs_To (This, Buffer)
       and then Item_Type.Valid (Element)
       and then Item_Type.Belongs_To (Element, Buffer);

private

   type Items_Cursor is record
      Io   : Kaitai.Streams.Stream;
      Left : Kaitai.Types.Length := 0;
   end record;

   type T is record
      Is_Valid    : Boolean := False;
      Key         : Kaitai.Types.Slice;
      Count       : Kaitai.Types.U8 := 0;
      Items_Io    : Kaitai.Streams.Stream;
      Items_Count : Kaitai.Types.Length := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Types.Within (This.Key, Buffer) and then Kaitai.Streams.Is_Valid (This.Items_Io, Buffer));

   function Key (This : T) return Kaitai.Types.Slice
   is (This.Key);

   function Count (This : T) return Kaitai.Types.U8
   is (This.Count);

   function Items_Count (This : T) return Kaitai.Types.Length
   is (This.Items_Count);

   function Items_Is_Key (Buffer : Kaitai.Types.Bytes; This : T; Element : Item_Type.T) return Boolean
   is (Item_Type.Is_Key (Buffer, Element, This.Key));

   function Belongs_To (Position : Items_Cursor; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Streams.Is_Valid (Position.Io, Buffer));

   function Items_First (This : T) return Items_Cursor
   is (Io => This.Items_Io, Left => This.Items_Count);

   function Remaining (Position : Items_Cursor) return Kaitai.Types.Length
   is (Position.Left);

end Pstr_V2;
