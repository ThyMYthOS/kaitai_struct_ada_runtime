--  Parser for formats/outside/bench_pnav.ksy, written by hand in the style of generated code.  Variant V3: the compiler
--  reduces `_parent.s1` to what the child uses of it, the truth of `_parent.s1 == 'foo'`, which the parent computes. It
--  is a parameter `Parent_S1_Eq_Foo` of Parse of the child and is stored in its type.

with Kaitai.Streams;
with Kaitai.Types;

package Pnav_V3
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.Length;

   package Child_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      procedure Parse
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Parent_S1_Eq_Foo : Boolean; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S);

      function V (This : T) return Kaitai.Types.U8
      with Pre => Valid (This);

      function Has_W (This : T) return Boolean
      with Pre => Valid (This);

      function W (This : T) return Kaitai.Types.U8
      with Pre => Valid (This) and then Has_W (This);

      function Do_Something (This : T) return Boolean
      with Pre => Valid (This);

   private

      type T is record
         Is_Valid         : Boolean := False;
         Parent_S1_Eq_Foo : Boolean := False;
         V                : Kaitai.Types.U8 := 0;
         Has_W            : Boolean := False;
         W                : Kaitai.Types.U8 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function V (This : T) return Kaitai.Types.U8
      is (This.V);

      function Has_W (This : T) return Boolean
      is (This.Has_W);

      function W (This : T) return Kaitai.Types.U8
      is (This.W);

      function Do_Something (This : T) return Boolean
      is (This.Parent_S1_Eq_Foo);

   end Child_Type;

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

   function S1 (This : T) return Kaitai.Types.Slice
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

   procedure Next (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Items_Cursor; Element : out Child_Type.T)
   with
     Pre  =>
       Valid (This)
       and then Belongs_To (This, Buffer)
       and then Belongs_To (Position, Buffer)
       and then Has_Element (Position),
     Post => Belongs_To (Position, Buffer) and then Remaining (Position) < Remaining (Position'Old);

private

   type Items_Cursor is record
      Io   : Kaitai.Streams.Stream;
      Left : Kaitai.Types.Length := 0;
   end record;

   type T is record
      Is_Valid    : Boolean := False;
      S1          : Kaitai.Types.Slice;
      Count       : Kaitai.Types.U8 := 0;
      Items_Io    : Kaitai.Streams.Stream;
      Items_Count : Kaitai.Types.Length := 0;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid);

   function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
   is (Kaitai.Types.Within (This.S1, Buffer) and then Kaitai.Streams.Is_Valid (This.Items_Io, Buffer));

   function S1 (This : T) return Kaitai.Types.Slice
   is (This.S1);

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

end Pnav_V3;
